// lib/features/admin/approval/admin_approval_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

import '/widgets/approval/manager/approval_detail_bottom_sheet.dart';
import '/widgets/approval/manager/approval_dialogs.dart';
import '/widgets/approval/manager/approval_list_builder.dart';

class AdminApprovalScreen extends StatefulWidget {
  final VoidCallback? onApprovalComplete;
  const AdminApprovalScreen({super.key, this.onApprovalComplete});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen>
    with TickerProviderStateMixin {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  final OvertimeRateService _rateService = OvertimeRateService();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isDarkMode = false;
  String? _userId;
  String? _userName;
  String? _userEmail;

  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _fungsiFilter;

  int _totalPending = 0;
  int _totalApproved = 0;
  int _totalRejected = 0;
  double _totalBiayaBulanIni = 0;
  double _totalJamBulanIni = 0;
  Map<String, int> _perFungsi = {};

  bool _isBulkMode = false;
  final Set<String> _selectedIds = {};
  bool _isSelectAll = false;
  List<Map<String, dynamic>> _allPendingData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadUserData();
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userName = data['nama_lengkap'] ?? user.email ?? 'Admin';
      } else {
        _userName = user.email ?? 'Admin';
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      _userName = user.email ?? 'Admin';
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _approvalService.getStatisticsForSuperadmin(
        fungsiFilter: _fungsiFilter,
      );
      if (mounted) {
        setState(() {
          _totalPending = stats['totalPending'] ?? 0;
          _totalApproved = stats['totalApproved'] ?? 0;
          _totalRejected = stats['totalRejected'] ?? 0;
          _totalBiayaBulanIni = (stats['totalEstimasiBiaya'] ?? 0).toDouble();
          _totalJamBulanIni = (stats['totalJamBulanIni'] ?? 0).toDouble();
          _perFungsi = Map<String, int>.from(stats['perFungsi'] ?? {});
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFF),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3C72)))
          : Column(
              children: [
                _buildStatsSection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 12),
                      _buildFungsiDropdown(),
                    ],
                  ),
                ),
                _buildTabBar(),
                if (_isBulkMode && _tabController.index == 0 && _selectedIds.isNotEmpty)
                  _buildBulkActionBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingTab(),
                        ApprovalListBuilder(
                          status: 'disetujui',
                          userRole: 'superadmin',
                          fungsiFilter: _fungsiFilter,
                          searchQuery: _searchQuery,
                          isDarkMode: _isDarkMode,
                          onTap: _showDetail,
                        ),
                        ApprovalListBuilder(
                          status: 'ditolak',
                          userRole: 'superadmin',
                          fungsiFilter: _fungsiFilter,
                          searchQuery: _searchQuery,
                          isDarkMode: _isDarkMode,
                          onTap: _showDetail,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Approval Lembur Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18)),
      backgroundColor: _isBulkMode ? const Color(0xFF2D5AA0) : const Color(0xFF1E3C72),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      actions: [
        if (_isBulkMode)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.checklist, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text('${_selectedIds.length} dipilih', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pending, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text('$_totalPending', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: Colors.white30),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('$_totalApproved', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        if (_tabController.index == 0)
          PopupMenuButton<String>(
            icon: Icon(_fungsiFilter != null ? Icons.filter_alt : Icons.filter_list, color: _fungsiFilter != null ? Colors.orange : Colors.white),
            onSelected: (value) {
              setState(() {
                _fungsiFilter = value == 'semua' ? null : value;
                _selectedIds.clear();
                _isSelectAll = false;
              });
              _loadStatistics();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'semua', child: Text('Semua Fungsi')),
              PopupMenuItem(value: 'operation', child: Text('Operation')),
              PopupMenuItem(value: 'lab', child: Text('Laboratorium')),
              PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
              PopupMenuItem(value: 'hsse', child: Text('HSSE')),
              PopupMenuItem(value: 'gpr', child: Text('GPR')),
              PopupMenuItem(value: 'bs', child: Text('BS')),
            ],
          ),
        if (_totalPending > 0)
          IconButton(
            icon: Icon(_isBulkMode ? Icons.close : Icons.checklist, color: Colors.white),
            onPressed: () {
              setState(() {
                _isBulkMode = !_isBulkMode;
                _selectedIds.clear();
                _isSelectAll = false;
              });
            },
            tooltip: _isBulkMode ? 'Keluar Mode Bulk' : 'Mode Bulk Approval',
          ),
        IconButton(
          icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
          onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
        ),
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadStatistics),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.white.withOpacity(0.8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Superadmin: ${_userName ?? "Loading..."}',
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode ? [const Color(0xFF2A2A3E), const Color(0xFF1A1A2E)] : [const Color(0xFF1E3C72), const Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3C72).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Pending', _totalPending, Colors.orange, Icons.hourglass_empty),
              _buildStatItem('Disetujui', _totalApproved, Colors.green, Icons.check_circle),
              _buildStatItem('Ditolak', _totalRejected, Colors.red, Icons.cancel),
              _buildStatItem('Biaya/bln', _rateService.formatRupiahCompact(_totalBiayaBulanIni), Colors.amber, Icons.attach_money, isRupiah: true),
            ],
          ),
          if (_perFungsi.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _perFungsi.entries.map((e) => _buildFungsiChip(e.key, e.value)).toList(),
            ),
          ],
          if (_totalJamBulanIni > 0) ...[
            const SizedBox(height: 12),
            Text('Total Jam Bulan Ini: ${_totalJamBulanIni.toStringAsFixed(1)} jam', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, Color color, IconData icon, {bool isRupiah = false}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          isRupiah ? value.toString() : value.toString(),
          style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildFungsiChip(String fungsi, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Text('${fungsi.toUpperCase()}: $count', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF1E3C72)),
        labelColor: Colors.white,
        unselectedLabelColor: _isDarkMode ? Colors.white70 : Colors.grey[600],
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: 'Pending ($_totalPending)'),
          Tab(text: 'Disetujui ($_totalApproved)'),
          Tab(text: 'Ditolak ($_totalRejected)'),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _approvalService.getApprovalListForSuperadmin(
        status: 'pending',
        fungsiFilter: _fungsiFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data ?? [];
        final filteredDocs = docs.where((data) {
          if (_searchQuery.isEmpty) return true;
          final nama = (data['nama_pengawas'] ?? '').toString().toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          return nama.contains(_searchQuery) || groupId.contains(_searchQuery);
        }).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _allPendingData = filteredDocs;
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Tidak ada data', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index];
            final groupId = data['group_id'] ?? '';
            final isSelected = _selectedIds.contains(groupId);
            return Stack(
              children: [
                _buildApprovalCard(data, groupId),
                if (_isBulkMode)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF1E3C72),
                      onChanged: (checked) => _onSelectionChanged(groupId, checked ?? false),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> data, String groupId) {
    final isUrgent = data['urgensi'] == 'kritis';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';
    final isOutside = data['lokasi']?['is_outside_radius'] ?? false;

    DateTime? parsedTanggal;
    final tanggalData = data['tanggal'] ?? data['tanggal_lembur'];
    if (tanggalData != null && tanggalData is Timestamp) {
      parsedTanggal = tanggalData.toDate();
    }

    return GestureDetector(
      onTap: () => _showDetail(groupId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUrgent
              ? Border.all(color: Colors.red, width: 2)
              : isOverride
                  ? Border.all(color: Colors.orange, width: 1.5)
                  : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['nama_pengawas'] ?? '-',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : const Color(0xFF1E293B)),
                            ),
                          ),
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                              child: Text('URGENT', style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          _buildChip(_getFungsiLabel(data['pengawas_fungsi']), Colors.blue),
                          _buildChip('${data['total_mitra']} mitra', Colors.purple),
                          _buildChip('${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam', Colors.green),
                          if (isWeekend) _buildChip('LIBUR', Colors.purple),
                          if (isOverride) _buildChip('OVERRIDE', Colors.orange),
                          if (isOutside) _buildChip('LUAR RADIUS', Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            parsedTanggal != null ? DateFormat('dd/MM/yyyy').format(parsedTanggal) : '-',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${data['jam_mulai']} - ${data['jam_selesai']}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _rateService.formatRupiahCompact((data['estimasi_biaya_total'] ?? 0).toDouble()),
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                          ),
                        ],
                      ),
                      if (data['detail_mitra'] != null && (data['detail_mitra'] as List).isNotEmpty)
                        Builder(builder: (_) {
                          final mitraList = data['detail_mitra'] as List;
                          final displayNames = mitraList.take(3).map((m) => m['nama'] ?? '?').join(', ');
                          final more = mitraList.length > 3 ? ' +${mitraList.length - 3} lainnya' : '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.people, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '$displayNames$more',
                                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _showDetail(String groupId) async {
    final detail = await _approvalService.getDetailPengajuan(groupId);
    if (detail == null || !mounted) return;

    final mitraList = (detail['mitra_list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasSpkl = detail['spkl_pdf_path'] != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApprovalDetailBottomSheet(
        data: detail,
        mitraList: mitraList,
        isDarkMode: _isDarkMode,
        userRole: 'superadmin',
        userName: _userName ?? 'Admin',
        isManager: false,
        isSuperadmin: true,
        onApprove: () => _showApproveDialog(groupId, detail, mitraList),
        onReject: () => _showRejectDialog(groupId),
        onPreviewSpkl: hasSpkl
            ? () async {
                Navigator.pop(context);
                await OpenFile.open(detail['spkl_pdf_path']);
              }
            : null,
      ),
    );
  }

  void _showApproveDialog(String groupId, Map<String, dynamic> data, List<Map<String, dynamic>> mitraList) {
    showDialog(
      context: context,
      builder: (context) => ApprovalApproveDialog(
        data: data,
        mitraList: mitraList,
        onConfirm: (notes) async {
          Navigator.pop(context);
          await _processApproval(groupId, true, notes);
        },
      ),
    );
  }

  void _showRejectDialog(String groupId) {
    showDialog(
      context: context,
      builder: (context) => ApprovalRejectDialog(
        onConfirm: (notes) async {
          if (notes.isEmpty) {
            _showSnackbar('Alasan penolakan wajib diisi', isError: true);
            return;
          }
          Navigator.pop(context);
          await _processApproval(groupId, false, notes);
        },
      ),
    );
  }

  Future<void> _processApproval(String groupId, bool isApprove, String notes) async {
    try {
      final result = await _approvalService.processApproval(
        groupId: groupId,
        isApprove: isApprove,
        notes: notes,
        userRole: 'superadmin',
        approverName: _userName ?? 'Admin',
        approverEmail: _userEmail,
        approverId: _userId,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar(result.message, isError: !result.success);
        if (result.success && result.spklNomor != null) {
          _showSpklSuccessDialog(result);
        }
        _loadStatistics();
        widget.onApprovalComplete?.call();
        setState(() {
          _selectedIds.remove(groupId);
          _isSelectAll = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memproses', isError: true);
    }
  }

  void _showSpklSuccessDialog(ApprovalResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 28), SizedBox(width: 8), Text('Berhasil!')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.message),
            if (result.spklNomor != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  const Text('SPKL Otomatis Dibuat:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(result.spklNomor!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          if (result.spklPdfPath != null)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await OpenFile.open(result.spklPdfPath!);
              },
              icon: const Icon(Icons.preview, size: 18),
              label: const Text('Lihat SPKL'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
        ],
      ),
    );
  }

  void _onSelectionChanged(String groupId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedIds.add(groupId);
      } else {
        _selectedIds.remove(groupId);
        _isSelectAll = false;
      }
    });
  }

  void _onSelectAllChanged(List<String> allIds, bool isSelectAll) {
    setState(() {
      _isSelectAll = isSelectAll;
      if (isSelectAll) {
        _selectedIds.addAll(allIds);
      } else {
        _selectedIds.clear();
      }
    });
  }

  Widget _buildBulkActionBar() {
    final selectedCount = _isSelectAll ? _allPendingData.length : _selectedIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2D5AA0) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3C72).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isSelectAll,
            activeColor: const Color(0xFF1E3C72),
            onChanged: (_) => _onSelectAllChanged(
              _isSelectAll ? [] : _allPendingData.map((d) => d['group_id'] as String).toList(),
              !_isSelectAll,
            ),
          ),
          Text('$selectedCount dipilih', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : const Color(0xFF1E3C72))),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showBulkApproveDialog(),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Approve Semua'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showBulkRejectDialog(),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Tolak Semua'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ],
      ),
    );
  }

  void _showBulkApproveDialog() {
    final List<String> ids = _isSelectAll ? _allPendingData.map((d) => d['group_id'] as String).toList() : _selectedIds.toList();
    if (ids.isEmpty) { _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true); return; }
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk Approve', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Setujui ${ids.length} pengajuan sekaligus?'),
            const SizedBox(height: 16),
            TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _bulkProcess(ids, true, notesController.text.trim()); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui Semua'),
          ),
        ],
      ),
    );
  }

  void _showBulkRejectDialog() {
    final List<String> ids = _isSelectAll ? _allPendingData.map((d) => d['group_id'] as String).toList() : _selectedIds.toList();
    if (ids.isEmpty) { _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true); return; }
    final alasanController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tolak ${ids.length} pengajuan sekaligus?'),
            const SizedBox(height: 16),
            TextField(controller: alasanController, maxLines: 3, decoration: const InputDecoration(labelText: 'Alasan Penolakan *', hintText: 'Jelaskan mengapa ditolak...', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (alasanController.text.trim().isEmpty) { _showSnackbar('Alasan penolakan wajib diisi', isError: true); return; }
              Navigator.pop(context);
              _bulkProcess(ids, false, alasanController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak Semua'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkProcess(List<String> groupIds, bool isApprove, String notes) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1E3C72)),
              const SizedBox(height: 16),
              Text('Memproses ${groupIds.length} pengajuan...', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _approvalService.bulkApproval(
        groupIds: groupIds,
        isApprove: isApprove,
        notes: notes,
        approverName: _userName ?? 'Admin',
        approverEmail: _userEmail ?? '',
        approverId: _userId ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Bulk done: ${result['totalSuccess']} sukses, ${result['totalFail']} gagal', isError: result['totalFail'] > 0);
        _loadStatistics();
        setState(() {
          _selectedIds.clear();
          _isBulkMode = false;
          _isSelectAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Gagal memproses', isError: true);
      }
    }
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: TextField(
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            setState(() => _searchQuery = value.toLowerCase());
          });
        },
        style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Cari pengawas, group ID...',
          hintStyle: TextStyle(color: _isDarkMode ? Colors.grey[400] : Colors.grey),
          prefixIcon: Icon(Icons.search, color: _isDarkMode ? Colors.grey[400] : const Color(0xFF1E3C72)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFungsiDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _fungsiFilter ?? 'semua',
        underline: const SizedBox(),
        style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87, fontSize: 13),
        dropdownColor: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        items: const [
          DropdownMenuItem(value: 'semua', child: Text('Semua', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'operation', child: Text('Operation', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'lab', child: Text('Lab', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'maintenance', child: Text('MTC', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'hsse', child: Text('HSSE', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'gpr', child: Text('GPR', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'bs', child: Text('BS', style: TextStyle(fontSize: 13))),
        ],
        onChanged: (value) {
          setState(() {
            _fungsiFilter = value == 'semua' ? null : value;
            _selectedIds.clear();
            _isSelectAll = false;
          });
          _loadStatistics();
        },
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getFungsiLabel(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi ?? 'Unknown';
    }
  }
}