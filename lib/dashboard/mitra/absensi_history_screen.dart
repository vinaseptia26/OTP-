import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/overtime_absensi_service.dart';
import '/widgets/absensi/absensi_stats_card.dart';
import '/widgets/absensi/absensi_filter_chips.dart';
import '/widgets/absensi/absensi_list_view.dart';
import '/widgets/absensi/month_picker_sheet.dart';

class AbsensiHistoryScreen extends StatefulWidget {
  final String? initialTab;
  final String? lemburId;
  final bool fromNotification;

  const AbsensiHistoryScreen({
    super.key,
    this.initialTab,
    this.lemburId,
    this.fromNotification = false,
  });

  @override
  State<AbsensiHistoryScreen> createState() => _AbsensiHistoryScreenState();
}

class _AbsensiHistoryScreenState extends State<AbsensiHistoryScreen> {
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String _userName = 'Mitra';
  String? _userPhotoUrl;

  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedStatus = 'semua';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  Map<String, dynamic>? _expirySummary;
  Timer? _autoCheckTimer;
  Timer? _summaryRefreshTimer;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _selectedStatus = widget.initialTab!;
    }
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _userId = user.uid;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _userRole = data?['role'] ?? 'mitra';
          _userFungsi = data?['fungsi']?.toString().toLowerCase();
          _userName = (data?['nama_lengkap'] ?? user.displayName) ?? 'Mitra';
          _userPhotoUrl = data?['photo_url'] ?? user.photoURL;
        });
      } else {
        setState(() {
          _userName = user.displayName ?? 'Mitra';
          _userPhotoUrl = user.photoURL;
        });
      }

      // 🔥 Setelah user data loaded, jalankan auto-check & load summary
      _initTenggatFeatures();
    } catch (e) {
      debugPrint('Error loading user: $e');
      setState(() {
        _userName = user.displayName ?? 'Mitra';
        _userPhotoUrl = user.photoURL;
      });
    }
  }


  void _initTenggatFeatures() {
    if (_userId == null) return;

    // Auto check expired saat pertama kali buka
    _autoCheckExpired();

    // Load expiry summary
    _loadExpirySummary();

    // Set timer untuk auto check setiap 5 menit
    _autoCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _autoCheckExpired();
    });

    // Refresh summary setiap 2 menit
    _summaryRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _loadExpirySummary();
    });
  }

  Future<void> _autoCheckExpired() async {
    try {
      final result = await _absensiService.autoUpdateExpired(userId: _userId);
      if (result['success'] == true && result['expiredCount'] > 0) {
        debugPrint('🔄 Auto-check: ${result['expiredCount']} lembur expired');
        // Refresh UI jika ada yang expired
        if (mounted) {
          setState(() {});
          _loadExpirySummary();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Auto-check expired error: $e');
    }
  }

  Future<void> _loadExpirySummary() async {
    if (_userId == null) return;

    setState(() => _isLoadingSummary = true);

    try {
      final summary = await _absensiService.getExpirySummary(
        userId: _userId!,
        bulan: _selectedBulan,
      );

      if (mounted) {
        setState(() {
          _expirySummary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load expiry summary error: $e');
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _autoCheckTimer?.cancel();
    _summaryRefreshTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _searchQuery = query.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _autoCheckExpired();
          await _loadExpirySummary();
          if (mounted) setState(() {});
        },
        color: const Color(0xFF1A237E),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ================================================================
            // USER HEADER
            // ================================================================
            SliverToBoxAdapter(
              child: _buildUserHeader(),
            ),

            SliverToBoxAdapter(
              child: const SizedBox(height: 8),
            ),

            // ================================================================
            // 🔥 TENGGAT ALERT BANNER - EXPIRY WARNING
            // ================================================================
            if (_expirySummary != null && _hasUrgentItems)
              SliverToBoxAdapter(
                child: _buildTenggatAlertBanner(),
              ),

            // ================================================================
            // STATS CARD
            // ================================================================
            SliverToBoxAdapter(
              child: AbsensiStatsCard(
                absensiService: _absensiService,
                userRole: _userRole!,
                userFungsi: _userFungsi,
                userId: _userId,
                selectedBulan: _selectedBulan,
              ),
            ),

            // ================================================================
            // 🔥 EXPIRY SUMMARY MINI CARDS
            // ================================================================
            if (_expirySummary != null)
              SliverToBoxAdapter(
                child: _buildExpirySummaryCards(),
              ),

            // ================================================================
            // FILTER CHIPS
            // ================================================================
            SliverToBoxAdapter(
              child: AbsensiFilterChips(
                selectedStatus: _selectedStatus,
                onStatusChanged: (status) {
                  setState(() => _selectedStatus = status);
                  _loadExpirySummary();
                },
              ),
            ),

            // ================================================================
            // SEARCH BAR
            // ================================================================
            SliverToBoxAdapter(
              child: _buildSearchBar(),
            ),

            SliverToBoxAdapter(
              child: const SizedBox(height: 8),
            ),

            // ================================================================
            // LIST VIEW
            // ================================================================
            SliverFillRemaining(
              child: AbsensiListView(
                userRole: _userRole!,
                userFungsi: _userFungsi,
                userId: _userId,
                selectedBulan: _selectedBulan,
                selectedStatus: _selectedStatus,
                searchQuery: _searchQuery,
                lemburIdHighlight: widget.lemburId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 TENGGAT ALERT BANNER                                               ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  bool get _hasUrgentItems {
    if (_expirySummary == null) return false;
    final akanExpired = (_expirySummary!['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary!['kritis'] as int?) ?? 0;
    final sudahLewatNormal = (_expirySummary!['sudahLewatNormal'] as int?) ?? 0;
    return (akanExpired + kritis + sudahLewatNormal) > 0;
  }

  Widget _buildTenggatAlertBanner() {
    final akanExpired = (_expirySummary!['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary!['kritis'] as int?) ?? 0;
    final sudahLewatNormal = (_expirySummary!['sudahLewatNormal'] as int?) ?? 0;
    final totalUrgent = akanExpired + kritis + sudahLewatNormal;

    // Tentukan warna dan icon berdasarkan level urgensi
    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;

    if (akanExpired > 0 || sudahLewatNormal > 0) {
      bannerColor = const Color(0xFFEF5350);
      bannerIcon = Icons.warning_rounded;
      bannerTitle = 'PERHATIAN! $totalUrgent lembur mendesak';
    } else if (kritis > 0) {
      bannerColor = const Color(0xFFFF9800);
      bannerIcon = Icons.info_rounded;
      bannerTitle = '$totalUrgent lembur butuh perhatian';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bannerColor, bannerColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Filter ke status belum_absen untuk melihat urgent items
            setState(() => _selectedStatus = 'belum_absen');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(bannerIcon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bannerTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildUrgentDetailText(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LIHAT',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildUrgentDetailText() {
    final parts = <String>[];
    final akanExpired = (_expirySummary!['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary!['kritis'] as int?) ?? 0;
    final sudahLewatNormal = (_expirySummary!['sudahLewatNormal'] as int?) ?? 0;

    if (akanExpired > 0) parts.add('🔥 $akanExpired akan kadaluarsa');
    if (kritis > 0) parts.add('⚠️ $kritis dalam 1-2 jam');
    if (sudahLewatNormal > 0) parts.add('💀 $sudahLewatNormal sudah lewat');

    return parts.join(' • ');
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 EXPIRY SUMMARY MINI CARDS                                          ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildExpirySummaryCards() {
    final akanExpired = (_expirySummary!['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary!['kritis'] as int?) ?? 0;
    final warning = (_expirySummary!['warning'] as int?) ?? 0;
    final perhatian = (_expirySummary!['perhatian'] as int?) ?? 0;
    final aman = (_expirySummary!['aman'] as int?) ?? 0;
    final totalPending = (_expirySummary!['totalPending'] as int?) ?? 0;

    // Jika tidak ada pending, jangan tampilkan
    if (totalPending == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, size: 16, color: Color(0xFF1A237E)),
                const SizedBox(width: 6),
                Text(
                  'Status Tenggat Absensi',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A237E),
                  ),
                ),
                const Spacer(),
                if (_isLoadingSummary)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Cards dalam horizontal scroll
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (akanExpired > 0)
                  _buildMiniStatCard(
                    label: 'Kadaluarsa',
                    count: akanExpired,
                    color: const Color(0xFFEF5350),
                    icon: Icons.timer_off_rounded,
                    emoji: '🔥',
                  ),
                if (kritis > 0)
                  _buildMiniStatCard(
                    label: 'Kritis',
                    count: kritis,
                    color: const Color(0xFFFF9800),
                    icon: Icons.hourglass_bottom_rounded,
                    emoji: '🔴',
                  ),
                if (warning > 0)
                  _buildMiniStatCard(
                    label: 'Warning',
                    count: warning,
                    color: const Color(0xFFFFC107),
                    icon: Icons.hourglass_top_rounded,
                    emoji: '🟠',
                  ),
                if (perhatian > 0)
                  _buildMiniStatCard(
                    label: 'Perhatian',
                    count: perhatian,
                    color: const Color(0xFF42A5F5),
                    icon: Icons.info_outline_rounded,
                    emoji: '🟡',
                  ),
                if (aman > 0)
                  _buildMiniStatCard(
                    label: 'Aman',
                    count: aman,
                    color: const Color(0xFF66BB6A),
                    icon: Icons.check_circle_outline_rounded,
                    emoji: '🟢',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required String emoji,
  }) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                emoji,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // APP BAR - CORPORATE STYLE
  // ===========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Riwayat Absensi',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black26,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(0),
        ),
      ),
      actions: [
        // 🔥 Notifikasi urgent badge
        if (_hasUrgentItems)
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_active_rounded, size: 22),
                  onPressed: () {
                    setState(() => _selectedStatus = 'belum_absen');
                  },
                  tooltip: 'Lembur Mendesak',
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${(_expirySummary?['akanExpired'] ?? 0) + (_expirySummary?['kritis'] ?? 0) + (_expirySummary?['sudahLewatNormal'] ?? 0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Month Picker
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.calendar_month, size: 22),
            onPressed: () => MonthPickerSheet.show(
              context,
              selectedMonth: _selectedBulan,
              onMonthSelected: (month) {
                setState(() => _selectedBulan = month);
                _loadExpirySummary();
              },
            ),
            tooltip: 'Pilih Bulan',
          ),
        ),

        // Filter Status
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, size: 22),
            tooltip: 'Filter Status',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            elevation: 8,
            onSelected: (value) {
              setState(() => _selectedStatus = value);
              _loadExpirySummary();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'semua',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.list_alt, size: 18, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Semua Status',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'belum_absen',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pending_actions, size: 18, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Belum Absen',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sudah_absen',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sudah Absen',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'kadaluarsa',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.timer_off, size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Kadaluarsa',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // USER HEADER - CORPORATE CARD
  // ===========================================================================

  Widget _buildUserHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
              image: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(_userPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                ? Center(
                    child: Text(
                      (_userName.isNotEmpty ? _userName[0] : '?').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang,',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID')
                            .format(DateTime.parse('$_selectedBulan-01')),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.badge, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(
                  (_userRole ?? 'MITRA').toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH BAR - CLEAN DESIGN
  // ===========================================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800),
        decoration: InputDecoration(
          hintText: 'Cari mitra, pengawas, atau jam...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade500,
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }
}