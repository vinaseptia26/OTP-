// lib/dashboard/manager/approval_lembur_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

import '../../widgets/approval/approval_detail_bottom_sheet.dart';
import '../../widgets/approval/approval_dialogs.dart';
import '../../widgets/approval/approval_list_builder.dart';
import '../../widgets/approval/hsse_pending_list.dart';
import '../../widgets/approval/risk_checklist_dialog.dart';
import '../../widgets/approval/pending_approval_list.dart';
import '../../widgets/approval/risky_overtime_list.dart';
import '../../widgets/approval/approval_header_section.dart';
import '../../widgets/bottom_nav/manager_bottom_nav.dart';

class ManagerApprovalLemburScreen extends StatefulWidget {
  final VoidCallback? onApprovalComplete;
  const ManagerApprovalLemburScreen({super.key, this.onApprovalComplete});

  @override
  State<ManagerApprovalLemburScreen> createState() =>
      _ManagerApprovalLemburScreenState();
}

class _ManagerApprovalLemburScreenState
    extends State<ManagerApprovalLemburScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ==================== SERVICES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  // ignore: unused_field
  final OvertimeRateService _rateService = OvertimeRateService();

  // ==================== CONTROLLERS & ANIMATIONS ====================
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ==================== STATE ====================
  bool _isLoading = true;
  String? _userId, _userRole, _userFungsi, _userName, _userEmail;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _fungsiFilter;
  bool _isApproving = false;

  // ==================== STATISTICS ====================
  int _totalPending = 0, _totalApproved = 0, _totalRejected = 0, _totalPendingHSSE = 0;
  int _totalAllPending = 0;
  int _criticalCount = 0, _highCount = 0, _mediumCount = 0, _lowCount = 0;

  // ==================== BULK SELECTION ====================
  bool _isBulkMode = false;
  final Set<String> _selectedIds = {};
  bool _isSelectAll = false;
  List<Map<String, dynamic>> _allPendingData = [];

  // ==================== OPTIMIZATION ====================
  DateTime? _lastStatsLoad;
  StreamSubscription? _authSubscription;
  static final Map<String, Color> _fungsiColorCache = {};
  static final Map<String, String> _fungsiLabelCache = {};

  // ==================== STATIC CONSTANTS ====================
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color hsseColor = Color(0xFF9C27B0);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color riskyColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);

  static const LinearGradient appBarGradientManager = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient appBarGradientHSSE = LinearGradient(
    colors: [hsseColor, Color(0xFF6A1B9A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<String> _hsseActionableStatuses = [
    OvertimeApprovalService.statusPendingHSSE,
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ==================== GETTERS ====================
  bool get isSuperadmin => _userRole == 'superadmin';
  bool get isManager => _userRole == 'manager';
  bool get isHSSEManager =>
      _userRole == 'manager_hsse' ||
      (_userRole == 'manager' && _userFungsi == 'hsse');

  int get _tabCount => isHSSEManager ? 7 : 3;
  bool get isPendingTabActive => _tabController.index == (isHSSEManager ? 2 : 0);
  bool get isRiskyTabActive => isHSSEManager && _tabController.index == 0;
  bool get isHsseTabActive => isHSSEManager && _tabController.index == 1;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initControllers();
    _listenAuthChanges();
    _initializeData();
  }

  void _initControllers() {
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  void _listenAuthChanges() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _animationController.dispose();
    _searchDebounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadStatistics();
    }
  }

  // ==================== INITIALIZATION ====================
  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadUserData();

      if (_tabController.length != _tabCount) {
        _tabController.dispose();
        _tabController = TabController(length: _tabCount, vsync: this);
        _tabController.addListener(() {
          if (mounted) setState(() {});
        });
      }

      await _loadStatistics();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      if (mounted) _showSnackbar('Gagal memuat data', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _userId = user.uid;
    _userEmail = user.email;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userRole = data['role']?.toString().toLowerCase() ?? '';
        _userFungsi = data['fungsi']?.toString().toLowerCase() ?? '';
        _userName = data['nama_lengkap']?.toString() ?? user.email ?? 'User';
        debugPrint('👤 USER DATA LOADED: $_userName, role=$_userRole, fungsi=$_userFungsi');
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      _userName = user.email ?? 'User';
    }
  }

  // ================================================================
  // LOAD STATISTICS
  // ================================================================
  Future<void> _loadStatistics() async {
    if (_lastStatsLoad != null &&
        DateTime.now().difference(_lastStatsLoad!) < const Duration(seconds: 2)) {
      return;
    }
    _lastStatsLoad = DateTime.now();

    try {
      Map<String, dynamic> stats;

      if (isSuperadmin) {
        stats = await _approvalService.getStatisticsForSuperadmin(
          fungsiFilter: _fungsiFilter,
        );
      } else if (isManager && _userFungsi != null) {
        stats = await _approvalService.getStatisticsForManager(_userFungsi!);
      } else if (isHSSEManager) {
        stats = await _approvalService.getStatisticsForHSSEManager(
          fungsiFilter: _fungsiFilter,
        );
      } else {
        return;
      }

      if (mounted) _updateStats(stats);
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
    }
  }

  void _updateStats(Map<String, dynamic> stats) {
    if (!mounted) return;
    setState(() {
      _totalPending = stats['totalPending'] ?? 0;
      _totalPendingHSSE = stats['totalPendingHSSE'] ?? 0;
      _totalApproved = stats['totalApproved'] ?? 0;
      _totalRejected = stats['totalRejected'] ?? 0;
      _totalAllPending = stats['totalAllPending'] ?? (_totalPending + _totalPendingHSSE);

      if (isHSSEManager) {
        _criticalCount = stats['criticalCount'] ?? 0;
        _highCount = stats['highCount'] ?? 0;
        _mediumCount = stats['mediumCount'] ?? 0;
        _lowCount = stats['lowCount'] ?? 0;
      }
    });
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: isHSSEManager ? hsseColor : primaryColor,
              displacement: 20,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ApprovalHeaderSection(
                      isHSSEManager: isHSSEManager,
                      pendingCount: isHSSEManager ? _totalAllPending : _totalPending,
                      showRiskSummary: isHSSEManager,
                      subtitle: isSuperadmin
                          ? 'Kelola semua approval'
                          : isHSSEManager
                              ? 'Validasi risiko K3 & HSSE (Semua Fungsi)'
                              : 'Review pengajuan lembur',
                    ),
                  ),

                  if (isHSSEManager && _totalAllPending > 0)
                    SliverToBoxAdapter(child: _buildHSSERiskSummaryCards()),

                  SliverToBoxAdapter(child: _buildSearchAndFilter()),
                  SliverToBoxAdapter(child: _buildTabBar()),

                  if (isSuperadmin && _isBulkMode && isPendingTabActive && _selectedIds.isNotEmpty)
                    SliverToBoxAdapter(child: _buildBulkActionBar()),

                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TabBarView(
                        controller: _tabController,
                        children: _buildTabViews(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const ManagerBottomNav(currentIndex: 1),
    );
  }

  // ================================================================
  // HSSE RISK SUMMARY CARDS
  // ================================================================
  Widget _buildHSSERiskSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildRiskMiniCard('Critical', '🔴', const Color(0xFFDC2626), _criticalCount),
            const SizedBox(width: 8),
            _buildRiskMiniCard('High', '🟠', const Color(0xFFEF4444), _highCount),
            const SizedBox(width: 8),
            _buildRiskMiniCard('Medium', '🟡', const Color(0xFFF59E0B), _mediumCount),
            const SizedBox(width: 8),
            _buildRiskMiniCard('Low', '🟢', const Color(0xFF10B981), _lowCount),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMiniCard(String label, String emoji, Color color, int count) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('$count', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ================================================================
  // TAB VIEWS
  // ================================================================
  List<Widget> _buildTabViews() {
    final role = _userRole ?? 'manager';
    
    if (isHSSEManager) {
      return [
        RiskyOvertimeList(
          searchQuery: _searchQuery,
          fungsiFilter: _fungsiFilter,
          isDarkMode: false,
          onTap: _showDetail,
          onHSSEReview: (groupId) => _onHSSEReviewRequested(groupId),
        ),
        HSSEPendingList(
          searchQuery: _searchQuery,
          fungsiFilter: _fungsiFilter,
          isDarkMode: false,
          onTap: _showDetail,
          onHSSEApprove: (groupId) => _onHSSEReviewRequested(groupId),
          onHSSEReject: (groupId) => _onHSSERejectRequested(groupId),
        ),
        PendingApprovalList(
          isSuperadmin: false,
          fungsiFilterSuperadmin: _fungsiFilter,
          userFungsi: _userFungsi,
          userRole: _userRole,
          isHSSEManagerMode: true,
          searchQuery: _searchQuery,
          isBulkMode: false,
          selectedIds: _selectedIds,
          onShowDetail: _showDetail,
          onSelectionChanged: _onSelectionChanged,
          onDataLoaded: (data) => _allPendingData = data,
        ),
        ApprovalListBuilder(
          status: 'disetujui',
          userRole: role,
          userFungsi: null,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
          isHSSETab: true,
        ),
        ApprovalListBuilder(
          status: 'ditolak',
          userRole: role,
          userFungsi: null,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
          isHSSETab: true,
        ),
        ApprovalListBuilder(
          status: 'disetujui',
          userRole: role,
          userFungsi: null,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
        ),
        ApprovalListBuilder(
          status: 'ditolak',
          userRole: role,
          userFungsi: null,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
        ),
      ];
    } else {
      return [
        PendingApprovalList(
          isSuperadmin: isSuperadmin,
          fungsiFilterSuperadmin: _fungsiFilter,
          userFungsi: _userFungsi,
          userRole: _userRole,
          isHSSEManagerMode: false,
          searchQuery: _searchQuery,
          isBulkMode: _isBulkMode,
          selectedIds: _selectedIds,
          onShowDetail: _showDetail,
          onSelectionChanged: _onSelectionChanged,
          onDataLoaded: (data) => _allPendingData = data,
        ),
        ApprovalListBuilder(
          status: 'disetujui',
          userRole: role,
          userFungsi: _userFungsi,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
        ),
        ApprovalListBuilder(
          status: 'ditolak',
          userRole: role,
          userFungsi: _userFungsi,
          fungsiFilter: _fungsiFilter,
          searchQuery: _searchQuery,
          isDarkMode: false,
          onTap: _showDetail,
        ),
      ];
    }
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        isHSSEManager ? 'Validasi K3 HSSE' : 'Approval Lembur',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18, letterSpacing: -0.3),
      ),
      centerTitle: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: isHSSEManager ? appBarGradientHSSE : appBarGradientManager,
        ),
      ),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      actions: _buildAppBarActions(),
      bottom: _buildAppBarBottom(),
    );
  }

  List<Widget> _buildAppBarActions() {
    final showFungsiFilter =
        (isSuperadmin && isPendingTabActive) || (isHSSEManager && (isRiskyTabActive || isHsseTabActive || isPendingTabActive));

    return [
      if (isSuperadmin && _isBulkMode)
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checklist, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text('${_selectedIds.length} dipilih',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ),
      if (showFungsiFilter) _buildFungsiFilterButton(),
      if (isSuperadmin && _totalPending > 0 && !isHSSEManager) _buildBulkModeToggle(),
      _buildRefreshButton(),
    ];
  }

  Widget _buildFungsiFilterButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _fungsiFilter != null ? Colors.orange.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: _fungsiFilter != null ? Border.all(color: Colors.orange.withValues(alpha: 0.4)) : null,
          ),
          child: Icon(Icons.filter_alt_outlined, color: _fungsiFilter != null ? Colors.orange : Colors.white, size: 20),
        ),
        onSelected: _onFungsiFilterChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'semua', child: _PopupMenuItemContent('Semua Fungsi', Icons.all_inclusive)),
          const PopupMenuItem(value: 'operation', child: _PopupMenuItemContent('Operation', Icons.engineering)),
          const PopupMenuItem(value: 'lab', child: _PopupMenuItemContent('Laboratorium', Icons.science)),
          const PopupMenuItem(value: 'maintenance', child: _PopupMenuItemContent('Maintenance', Icons.build)),
          const PopupMenuItem(value: 'hsse', child: _PopupMenuItemContent('HSSE', Icons.health_and_safety)),
          const PopupMenuItem(value: 'gpr', child: _PopupMenuItemContent('GPR', Icons.radar)),
          const PopupMenuItem(value: 'bs', child: _PopupMenuItemContent('BS', Icons.business)),
        ],
      ),
    );
  }

  Widget _buildBulkModeToggle() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isBulkMode ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_isBulkMode ? Icons.close : Icons.checklist_rtl, color: Colors.white, size: 20),
        ),
        onPressed: _toggleBulkMode,
        tooltip: _isBulkMode ? 'Tutup Bulk Mode' : 'Bulk Select',
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () async {
          await _loadStatistics();
          _showSnackbar('Data diperbarui');
        },
        tooltip: 'Refresh',
      ),
    );
  }

  PreferredSize _buildAppBarBottom() {
    final gradientColors = isSuperadmin
        ? [Colors.orange.shade400, Colors.deepOrange.shade700]
        : isHSSEManager
            ? [Colors.purple.shade400, Colors.purple.shade700]
            : [Colors.blue.shade400, Colors.indigo.shade700];
    final shadowColor = isSuperadmin ? Colors.orange : isHSSEManager ? Colors.purple : Colors.blue;
    final iconData = isSuperadmin
        ? Icons.admin_panel_settings_rounded
        : isHSSEManager
            ? Icons.health_and_safety_rounded
            : Icons.manage_accounts_rounded;

    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: shadowColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(iconData, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSuperadmin
                          ? 'Superadmin Access'
                          : isHSSEManager
                              ? 'Manager HSSE - Lintas Fungsi'
                              : 'Manager ${_getFungsiLabel(_userFungsi)}',
                      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName ?? "Loading...",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if ((isManager || isHSSEManager) && _userFungsi != null) _buildFungsiBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFungsiBadge() {
    final color = isHSSEManager ? hsseColor : _getFungsiColor(_userFungsi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(
        isHSSEManager ? 'HSSE (All)' : _getFungsiLabel(_userFungsi).toUpperCase(),
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );
  }

  // ==================== SEARCH & FILTER ====================
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _buildSearchField()),
          if (isSuperadmin || isHSSEManager) ...[
            const SizedBox(width: 10),
            _buildDropdownFilter(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        style: GoogleFonts.poppins(fontSize: 13, color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari pengawas, group ID...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: isHSSEManager ? hsseColor : primaryColor, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: Icon(Icons.close, color: Colors.grey[400], size: 20), onPressed: () => setState(() => _searchQuery = ''))
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: DropdownButton<String>(
        value: _fungsiFilter ?? 'semua',
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down_rounded, size: 24, color: isHSSEManager ? hsseColor : primaryColor),
        style: GoogleFonts.poppins(fontSize: 12, color: textPrimary),
        dropdownColor: cardColor,
        borderRadius: BorderRadius.circular(12),
        items: const [
          DropdownMenuItem(value: 'semua', child: Text('Semua')),
          DropdownMenuItem(value: 'operation', child: Text('Ops')),
          DropdownMenuItem(value: 'lab', child: Text('Lab')),
          DropdownMenuItem(value: 'maintenance', child: Text('MTC')),
          DropdownMenuItem(value: 'hsse', child: Text('HSSE')),
          DropdownMenuItem(value: 'gpr', child: Text('GPR')),
          DropdownMenuItem(value: 'bs', child: Text('BS')),
        ],
        onChanged: (value) => _onFungsiFilterChanged(value!),
      ),
    );
  }

  // ================================================================
  // TAB BAR — DYNAMIC & EYE-CATCHING
  // ================================================================
  Widget _buildTabBar() {
    final List<_TabData> allTabs = [
      if (isHSSEManager)
        _TabData(
          icon: Icons.warning_amber_rounded,
          label: 'Berisiko',
          badge: _totalAllPending > 0 ? '$_totalAllPending' : null,
          badgeColor: const Color(0xFFDC2626),
          color: const Color(0xFFDC2626),
        ),
      if (isHSSEManager)
        _TabData(
          icon: Icons.health_and_safety_rounded,
          label: 'K3',
          badge: _totalPendingHSSE > 0 ? '$_totalPendingHSSE' : null,
          badgeColor: const Color(0xFF9C27B0),
          color: const Color(0xFF9C27B0),
        ),
      _TabData(
        icon: Icons.pending_actions_rounded,
        label: 'Pending',
        badge: _totalPending > 0 ? '$_totalPending' : null,
        badgeColor: const Color(0xFFF59E0B),
        color: const Color(0xFFF59E0B),
      ),
      if (isHSSEManager)
        _TabData(
          icon: Icons.verified_rounded,
          label: 'K3 Setuju',
          badge: null,
          badgeColor: const Color(0xFF10B981),
          color: const Color(0xFF10B981),
        ),
      if (isHSSEManager)
        _TabData(
          icon: Icons.gpp_bad_rounded,
          label: 'K3 Tolak',
          badge: null,
          badgeColor: const Color(0xFFEF4444),
          color: const Color(0xFFEF4444),
        ),
      _TabData(
        icon: Icons.check_circle_rounded,
        label: 'Setuju',
        badge: _totalApproved > 0 ? '$_totalApproved' : null,
        badgeColor: const Color(0xFF10B981),
        color: const Color(0xFF10B981),
      ),
      _TabData(
        icon: Icons.cancel_rounded,
        label: 'Tolak',
        badge: _totalRejected > 0 ? '$_totalRejected' : null,
        badgeColor: const Color(0xFFEF4444),
        color: const Color(0xFFEF4444),
      ),
    ];

    final tabCount = allTabs.length;
    final isHSSE = isHSSEManager;
    
    final indicatorColors = isHSSE
        ? [hsseColor, const Color(0xFF6A1B9A)]
        : [primaryColor, secondaryColor];
    final shadowColor = isHSSE ? hsseColor : primaryColor;

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;
    final double tabBarHeight = isSmallScreen ? 62 : 68;
    final double iconSize = isSmallScreen ? 18 : 20;
    final double fontSize = isSmallScreen ? 9 : 10;
    final double indicatorPad = isSmallScreen ? 4 : 6;

    return Container(
      height: tabBarHeight,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: indicatorColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.all(indicatorPad),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: fontSize - 1,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        isScrollable: tabCount > 4,
        tabAlignment: tabCount > 4 ? TabAlignment.start : TabAlignment.fill,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 4 : 8,
          vertical: isSmallScreen ? 4 : 5,
        ),
        tabs: allTabs.map((tab) {
          final tabIndex = allTabs.indexOf(tab);
          final isActive = tabIndex == _tabController.index;
          return Tab(
            height: tabBarHeight - (indicatorPad * 2) - 8,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 3 : 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.2)
                          : tab.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      tab.icon,
                      size: iconSize,
                      color: isActive ? Colors.white : tab.color,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 5 : 7),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tab.badge != null && !isActive) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: tab.badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tab.badge!,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tab.badgeColor,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                        if (tab.badge != null && isActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // SHOW DETAIL
  // ================================================================
  Future<void> _showDetail(String groupId) async {
    final detail = await _approvalService.getDetailPengajuan(groupId);
    if (detail == null || !mounted) return;

    final mitraList = (detail['mitra_list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasSpkl = detail['spkl_pdf_path'] != null;

    final status = detail['status']?.toString() ?? '';
    final isPendingHSSE = status.contains('pending_hsse');
    final requiresHsseApproval = detail['requires_hsse_approval'] == true;
    final needHsseConfirmation = detail['need_hsse_confirmation'] == true;
    final riskLevel = detail['risk_level']?.toString() ?? '';
    final isHighRisk = riskLevel == 'high' || riskLevel == 'critical' || riskLevel == 'tinggi';
    final fungsiPengajuan = detail['pengawas_fungsi']?.toString() ?? '';

    final isHSSEApproval = isHSSEManager && (isPendingHSSE || requiresHsseApproval || needHsseConfirmation || isHighRisk);
    final isRisky = isHighRisk || requiresHsseApproval || detail['is_risky'] == true;

    debugPrint('🔍 Show Detail - Group: $groupId, Status: $status, Fungsi: $fungsiPengajuan');
    debugPrint('   isHSSEApproval: $isHSSEApproval, isRisky: $isRisky');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ApprovalDetailBottomSheet(
        data: detail,
        mitraList: mitraList,
        isDarkMode: false,
        userRole: _userRole ?? 'manager',
        userName: _userName ?? 'User',
        isManager: isManager || isHSSEManager,
        isSuperadmin: isSuperadmin,
        onApprove: () {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _isApproving) return;
            _isApproving = true;
            try {
              if (isHSSEManager) {
                await _onHSSEReviewRequested(groupId);
              } else if (isRisky && isManager) {
                _showManagerRiskyConfirmation(groupId, detail, mitraList);
              } else {
                _showApproveDialog(groupId, detail, mitraList);
              }
            } finally {
              _isApproving = false;
            }
          });
        },
        onReject: () {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _isApproving) return;
            _isApproving = true;
            try {
              if (isHSSEManager) {
                await _onHSSERejectRequested(groupId);
              } else {
                _showRejectDialog(groupId);
              }
            } finally {
              _isApproving = false;
            }
          });
        },
        onPreviewSpkl: hasSpkl ? () => _previewSpkl(ctx, detail['spkl_pdf_path']) : null,
      ),
    );
  }

  // ================================================================
  // GUARD
  // ================================================================
  Future<bool> _isStillHsseActionable(String groupId) async {
    try {
      final doc = await _firestore.collection('pengajuan_lembur').doc(groupId).get();
      if (!doc.exists) {
        if (mounted) _showSnackbar('Pengajuan tidak ditemukan', isError: true);
        return false;
      }
      final data = doc.data()!;
      final status = data['status']?.toString() ?? '';
      final requiresHsse = data['requires_hsse_approval'] == true;
      final riskLevel = data['risk_level']?.toString().toLowerCase() ?? '';
      final isHighRisk = riskLevel == 'high' || riskLevel == 'critical' || riskLevel == 'tinggi';

      final stillActionable = _hsseActionableStatuses.any((s) => status.contains(s)) || requiresHsse || isHighRisk;

      if (!stillActionable) {
        if (mounted) _showSnackbar('Pengajuan ini sudah diproses atau tidak lagi memerlukan validasi K3', isError: true);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Gagal cek status terbaru: $e');
      return true;
    }
  }

  Future<void> _onHSSEReviewRequested(String groupId) async {
    final ok = await _isStillHsseActionable(groupId);
    if (!ok) { await _loadStatistics(); return; }
    _showHSSEApproveDialog(groupId);
  }

  Future<void> _onHSSERejectRequested(String groupId) async {
    final ok = await _isStillHsseActionable(groupId);
    if (!ok) { await _loadStatistics(); return; }
    _showHSSERejectDialog(groupId);
  }

  void _showHSSEApproveDialog(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => RiskChecklistDialog(
        onApprove: (notes) {
          Navigator.pop(ctx);
          _handleHSSEApproval(groupId, true, notes);
        },
      ),
    );
  }

  void _previewSpkl(BuildContext ctx, String? path) {
    Navigator.pop(ctx);
    if (path == null) return;
    OpenFile.open(path).then((result) {
      if (result.type != ResultType.done && mounted) _showSnackbar('Gagal membuka file SPKL', isError: true);
    }).catchError((_) {
      if (mounted) _showSnackbar('File SPKL tidak ditemukan', isError: true);
    });
  }

  // ==================== APPROVAL ACTIONS (MANAGER BIASA) ====================
  void _showManagerRiskyConfirmation(String groupId, Map<String, dynamic> data, List<Map<String, dynamic>> mitraList) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Konfirmasi Risiko', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Pekerjaan ini memiliki risiko', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                    ]),
                    const SizedBox(height: 8),
                    _buildInfoLine('Pengawas', data['nama_pengawas'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildInfoLine('Fungsi', data['pengawas_fungsi'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildInfoLine('Lokasi', data['lokasi']?['alamat'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Apakah pekerjaan ini memerlukan persetujuan K3 dari Manager HSSE?', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
                child: Column(children: [
                  _buildRadioOption(
                    value: true, icon: Icons.health_and_safety, iconColor: riskyColor,
                    title: 'Ya, butuh persetujuan Manager HSSE', subtitle: 'Diteruskan ke Manager HSSE untuk review K3',
                    onTap: () { Navigator.pop(ctx); _confirmNeedHSSE(groupId, true); },
                  ),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.3)),
                  _buildRadioOption(
                    value: false, icon: Icons.thumb_up_alt, iconColor: successColor,
                    title: 'Tidak, langsung setujui', subtitle: 'Pekerjaan aman tanpa pengawasan K3 khusus',
                    // 🔥 PERBAIKAN: Langsung approve dengan skipHSSE = true
                    onTap: () { 
                      Navigator.pop(ctx); 
                      _processApprovalDirect(groupId, true, 'Disetujui oleh Manager (tanpa validasi K3)', skipHSSE: true); 
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Center(child: TextButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 16), label: const Text('Batal'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption({required bool value, required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: textPrimary))),
    ]);
  }

  // 🔥 PERBAIKAN: _confirmNeedHSSE untuk opsi "Ya, butuh HSSE"
  Future<void> _confirmNeedHSSE(String groupId, bool needHSSE, {Map<String, dynamic>? fallbackData, List<Map<String, dynamic>>? fallbackMitra}) async {
    try {
      await _firestore.collection('pengajuan_lembur').doc(groupId).update({
        'need_hsse_confirmation': needHSSE,
        'need_hsse_confirmed_by': _userId,
        'need_hsse_confirmed_at': FieldValue.serverTimestamp(),
        if (needHSSE) 'status': 'pending_hsse',
        if (needHSSE) 'requires_hsse_approval': true,
      });
      if (!mounted) return;

      if (needHSSE) {
        _showSnackbar('Diteruskan ke Manager HSSE untuk persetujuan K3');
      }
      await _loadStatistics();
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memproses konfirmasi', isError: true);
    }
  }

  void _showHSSERejectDialog(String groupId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.cancel, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Text('Tolak Validasi HSSE', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.red)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Jelaskan alasan penolakan dari sisi K3:', style: GoogleFonts.poppins(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: controller, maxLines: 4, style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(hintText: 'Contoh: APD tidak lengkap, risiko tinggi...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) { _showSnackbar('Alasan K3 wajib diisi', isError: true); return; }
              Navigator.pop(ctx);
              _handleHSSEApproval(groupId, false, 'Ditolak HSSE: ${controller.text.trim()}');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Tolak', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleHSSEApproval(String groupId, bool isApprove, String notes) async {
    try {
      debugPrint('🔄 Processing HSSE Approval: $groupId, approve: $isApprove');
      final result = await _approvalService.processApproval(
        groupId: groupId, isApprove: isApprove, notes: notes,
        userRole: 'manager_hsse', userFungsi: null,
        approverName: _userName ?? 'Manager HSSE', approverEmail: _userEmail ?? '', approverId: _userId ?? '',
      );
      debugPrint('✅ HSSE Approval Result: ${result.message}');
      if (mounted) {
        _showSnackbar(result.message, isError: !result.success);
        if (result.success && result.spklNomor != null) _showSpklSuccessDialog(result);
        await _loadStatistics();
        widget.onApprovalComplete?.call();
      }
    } catch (e) {
      debugPrint('❌ HSSE Approval Error: $e');
      if (mounted) _showSnackbar('Gagal memproses approval HSSE: $e', isError: true);
    }
  }

  void _showApproveDialog(String groupId, Map<String, dynamic> data, List<Map<String, dynamic>> mitraList) {
    showDialog(
      context: context,
      builder: (ctx) => ApprovalApproveDialog(
        data: data, mitraList: mitraList,
        onConfirm: (notes) { Navigator.pop(ctx); _processApproval(groupId, true, notes); },
      ),
    );
  }

  void _showRejectDialog(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => ApprovalRejectDialog(
        onConfirm: (notes) {
          if (notes.isEmpty) { _showSnackbar('Alasan penolakan wajib diisi', isError: true); return; }
          Navigator.pop(ctx);
          _processApproval(groupId, false, notes);
        },
      ),
    );
  }

  // 🔥 PERBAIKAN: _processApproval delegasi ke _processApprovalDirect
  Future<void> _processApproval(String groupId, bool isApprove, String notes) async {
    await _processApprovalDirect(groupId, isApprove, notes);
  }

  // 🔥 NEW: Method dengan dukungan skipHSSE
  Future<void> _processApprovalDirect(
    String groupId, 
    bool isApprove, 
    String notes, {
    bool skipHSSE = false,
  }) async {
    try {
      debugPrint('🔄 Processing Approval: $groupId, approve: $isApprove, role: $_userRole, skipHSSE: $skipHSSE');
      final result = await _approvalService.processApproval(
        groupId: groupId, 
        isApprove: isApprove, 
        notes: notes,
        userRole: _userRole ?? 'manager', 
        userFungsi: _userFungsi,
        approverName: _userName ?? 'Unknown', 
        approverEmail: _userEmail, 
        approverId: _userId,
        skipHSSE: skipHSSE, // ✅ NEW
      );
      debugPrint('✅ Approval Result: ${result.message}');
      if (mounted) {
        _showSnackbar(result.message, isError: !result.success);
        if (result.success && result.spklNomor != null) _showSpklSuccessDialog(result);
        await _loadStatistics();
        widget.onApprovalComplete?.call();
        setState(() { _selectedIds.remove(groupId); _isSelectAll = false; });
      }
    } catch (e) {
      debugPrint('❌ Approval Error: $e');
      if (mounted) _showSnackbar('Gagal memproses: $e', isError: true);
    }
  }

  void _showSpklSuccessDialog(ApprovalResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(width: 8),
          Text('Berhasil!', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(result.message, style: GoogleFonts.poppins(fontSize: 13)),
          if (result.spklNomor != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('SPKL Otomatis Dibuat:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                Text(result.spklNomor!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Tutup', style: GoogleFonts.poppins())),
          if (result.spklPdfPath != null)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try { await OpenFile.open(result.spklPdfPath!); } catch (_) { if (mounted) _showSnackbar('Gagal membuka SPKL', isError: true); }
              },
              icon: const Icon(Icons.preview, size: 18),
              label: Text('Lihat SPKL', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
        ],
      ),
    );
  }

  // ==================== BULK OPERATIONS ====================
  Widget _buildBulkActionBar() {
    final count = _isSelectAll ? _allPendingData.length : _selectedIds.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _onSelectAllToggle,
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: _isSelectAll ? Colors.white : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: _isSelectAll ? const Icon(Icons.check, color: primaryColor, size: 16) : null,
          ),
        ),
        const SizedBox(width: 12),
        Text('$count dipilih', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        _buildBulkButton('Approve', Colors.green, _showBulkApproveDialog),
        const SizedBox(width: 8),
        _buildBulkButton('Tolak', Colors.red, _showBulkRejectDialog),
      ]),
    );
  }

  Widget _buildBulkButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _toggleBulkMode() => setState(() { _isBulkMode = !_isBulkMode; _selectedIds.clear(); _isSelectAll = false; });
  void _onSelectionChanged(String groupId, bool isSelected) => setState(() { if (isSelected) { _selectedIds.add(groupId); } else { _selectedIds.remove(groupId); _isSelectAll = false; } });
  void _onSelectAllToggle() => setState(() { if (_isSelectAll) { _selectedIds.clear(); _isSelectAll = false; } else { _selectedIds.addAll(_allPendingData.map((d) => d['group_id'] as String)); _isSelectAll = true; } });
  void _onSearchChanged(String value) { _searchDebounce?.cancel(); _searchDebounce = Timer(const Duration(milliseconds: 400), () { if (mounted) setState(() => _searchQuery = value.toLowerCase()); }); }
  void _onFungsiFilterChanged(String value) { setState(() { _fungsiFilter = value == 'semua' ? null : value; _selectedIds.clear(); _isSelectAll = false; }); _loadStatistics(); }
  List<String> _getBulkIds() => _isSelectAll ? _allPendingData.map((d) => d['group_id'] as String).toList() : _selectedIds.toList();

  void _showBulkApproveDialog() {
    final ids = _getBulkIds();
    if (ids.isEmpty) { _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true); return; }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bulk Approve', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Setujui ${ids.length} pengajuan sekaligus?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _bulkProcess(ids, true, 'Bulk approval'); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Setujui Semua', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showBulkRejectDialog() {
    final ids = _getBulkIds();
    if (ids.isEmpty) { _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true); return; }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bulk Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tolak ${ids.length} pengajuan sekaligus?', style: GoogleFonts.poppins(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Alasan Penolakan *', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) { _showSnackbar('Alasan penolakan wajib diisi', isError: true); return; }
              Navigator.pop(ctx);
              _bulkProcess(ids, false, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Tolak Semua', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkProcess(List<String> groupIds, bool isApprove, String notes) async {
    if (!isSuperadmin) return;
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Memproses ${groupIds.length} pengajuan...', style: GoogleFonts.poppins(fontSize: 13)),
            ]),
          ),
        ),
      );
    }
    try {
      final result = await _approvalService.bulkApproval(
        groupIds: groupIds, isApprove: isApprove, notes: notes,
        approverName: _userName ?? 'Admin', approverEmail: _userEmail ?? '', approverId: _userId ?? '',
      );
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Berhasil: ${result['totalSuccess']}, Gagal: ${result['totalFail']}', isError: result['totalFail'] > 0);
        await _loadStatistics();
        setState(() { _selectedIds.clear(); _isBulkMode = false; _isSelectAll = false; });
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showSnackbar('Gagal memproses', isError: true); }
    }
  }

  // ==================== SNACKBAR ====================
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12))),
      ]),
      backgroundColor: isError ? errorColor : successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ==================== LOADING SCREEN ====================
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0), duration: const Duration(milliseconds: 800), curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isHSSEManager ? [hsseColor, const Color(0xFF6A1B9A)] : [primaryColor, secondaryColor],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: (isHSSEManager ? hsseColor : primaryColor).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: Icon(isHSSEManager ? Icons.health_and_safety_rounded : Icons.assignment_turned_in_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(isHSSEManager ? hsseColor : primaryColor))),
        const SizedBox(height: 20),
        Text('Memuat Data Approval...', style: GoogleFonts.poppins(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ==================== UTILITY (CACHED) ====================
  Color _getFungsiColor(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiColorCache[key] ??= _computeFungsiColor(key);
  }

  Color _computeFungsiColor(String fungsi) {
    switch (fungsi) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFEF4444);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}

// ================================================================
// TAB DATA MODEL (INTERNAL)
// ================================================================
class _TabData {
  final IconData icon;
  final String label;
  final String? badge;
  final Color badgeColor;
  final Color color;

  _TabData({
    required this.icon,
    required this.label,
    this.badge,
    required this.badgeColor,
    required this.color,
  });
}

// ==================== POPUP MENU ITEM CONTENT ====================
class _PopupMenuItemContent extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PopupMenuItemContent(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF6366F1)),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}