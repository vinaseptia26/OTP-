// lib/dashboard/mitra/pendapatan_screen.dart
// ============================================================================
// PENDAPATAN SCREEN - Estimasi Pendapatan Mitra
// ============================================================================
//
// Screen untuk menampilkan estimasi pendapatan mitra berdasarkan lembur
// yang sudah selesai (check-in & check-out).
//
// Fitur:
// - Stream real-time dari Firestore
// - Filter berdasarkan bulan
// - Header card dengan ringkasan
// - List item dengan staggered animation
// - Detail bottom sheet
// - Empty state dengan tips
// - Error handling dengan retry
// - Pull-to-refresh
// - Lifecycle aware (auto-refresh saat resume)
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/pendapatan_service.dart';
import '/widgets/pendapatan/pendapatan_header_card.dart';
import '/widgets/pendapatan/pendapatan_list_item.dart';
import '/widgets/pendapatan/pendapatan_detail_sheet.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';

class PendapatanScreen extends StatefulWidget {
  const PendapatanScreen({super.key});

  @override
  State<PendapatanScreen> createState() => _PendapatanScreenState();
}

class _PendapatanScreenState extends State<PendapatanScreen>
    with WidgetsBindingObserver {
  final PendapatanService _pendapatanService = PendapatanService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userId;
  String _userName = 'Mitra';
  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  bool _isInitialLoad = true;

  // Ringkasan
  double _totalPendapatan = 0;
  int _totalLembur = 0;
  double _totalJam = 0;
  int _tepatWaktu = 0;
  int _terlambat = 0;
  bool _isLoadingRingkasan = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendapatanService.clearCache();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data saat app resume dari background
    if (state == AppLifecycleState.resumed && _userId != null) {
      if (mounted) {
        setState(() {
          _isLoadingRingkasan = true;
        });
      }
    }
  }

 
  // LOAD USER DATA
 
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'User tidak terautentikasi. Silakan login ulang.';
            _isLoadingRingkasan = false;
          });
        }
        return;
      }

      // Ambil nama lengkap dari Firestore
      String? namaLengkap;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        namaLengkap = userDoc.data()?['nama_lengkap'] as String?;
      } catch (e) {
        debugPrint('⚠️ Gagal load user data dari Firestore: $e');
      }

      if (mounted) {
        setState(() {
          _userId = user.uid;
          _userName = namaLengkap ?? user.displayName ?? 'Mitra';
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data pengguna: $e';
          _isLoadingRingkasan = false;
          _isInitialLoad = false;
        });
      }
    }
  }

 
  // BUILD
 
  @override
  Widget build(BuildContext context) {
    // SAFEGUARD: Kalau initial load gagal total, tampilkan error screen
    if (_errorMessage != null && _userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            'Pendapatan Saya',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: _buildErrorScreen(
          icon: Icons.person_off_rounded,
          title: 'Tidak Dapat Memuat',
          message: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
              _isLoadingRingkasan = true;
              _isInitialLoad = true;
            });
            _loadUserData();
          },
        ),
      );
    }

    // Loading screen awal
    if (_isInitialLoad || _userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLoadingIndicator(),
              const SizedBox(height: 20),
              Text(
                _isInitialLoad
                    ? 'Memuat data pengguna...'
                    : 'Mohon tunggu...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            const MitraBottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }

 
  // APP BAR
 
  PreferredSizeWidget _buildAppBar() {
    final displayBulan = _formatBulanDisplay(_selectedBulan);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pendapatan Saya',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: _showMonthPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayBulan,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1B5E20),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        // Tombol refresh
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22),
          onPressed: _refreshData,
          tooltip: 'Refresh Data',
        ),
        // Month picker button
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            onPressed: _showMonthPicker,
            tooltip: 'Pilih Bulan',
          ),
        ),
      ],
    );
  }

 
  // MAIN CONTENT
 
  Widget _buildContent() {
    return StreamBuilder<List<PendapatanItem>>(
      stream: _pendapatanService.getPendapatanStream(
        mitraId: _userId!,
        bulan: _selectedBulan,
      ),
      builder: (context, snapshot) {
        // ─── LOADING STATE ────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting &&
            _isLoadingRingkasan) {
          return _buildLoadingContent();
        }

        // ─── ERROR STATE ──────────────────────────────
        if (snapshot.hasError) {
          return _buildErrorScreen(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal Memuat Data',
            message: 'Terjadi kesalahan saat mengambil data pendapatan.\n'
                'Periksa koneksi internet Anda dan coba lagi.',
            errorDetail: snapshot.error.toString(),
            onRetry: _refreshData,
          );
        }

        // ─── DATA STATE ───────────────────────────────
        final items = snapshot.data ?? [];
        _isLoadingRingkasan = false;

        // Update ringkasan
        _updateRingkasan(items);

        // ─── EMPTY STATE ──────────────────────────────
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // ─── CONTENT WITH DATA ────────────────────────
        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF1B5E20),
          displacement: 20,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header Card
              SliverToBoxAdapter(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: PendapatanHeaderCard(
                    totalPendapatan: _totalPendapatan,
                    totalLembur: _totalLembur,
                    totalJam: _totalJam,
                    bulan: _selectedBulan,
                    tepatWaktu: _tepatWaktu,
                    terlambat: _terlambat,
                  ),
                ),
              ),

              // Disclaimer
              SliverToBoxAdapter(
                child: _buildDisclaimer(),
              ),

              // Section Header
              SliverToBoxAdapter(
                child: _buildSectionHeader(count: items.length),
              ),

              // List Items dengan staggered animation
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 350 + (index * 60)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(40 * (1 - value), 0),
                            child: child,
                          ),
                        );
                      },
                      child: PendapatanListItem(
                        item: item,
                        onTap: () => PendapatanDetailSheet.show(context, item),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),

              // Bottom Summary
              SliverToBoxAdapter(
                child: _buildBottomSummary(),
              ),

              // Bottom padding untuk safe area
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

 
  // LOADING CONTENT
 
  Widget _buildLoadingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoadingIndicator(),
          const SizedBox(height: 20),
          Text(
            'Memuat data pendapatan...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatBulanDisplay(_selectedBulan),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

 
  // DISCLAIMER WIDGET
 
  Widget _buildDisclaimer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade100.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Estimasi Pendapatan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pendapatan ini hanya ESTIMASI berdasarkan tarif lembur per jam. '
                  'Nominal final ditentukan oleh bagian keuangan.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 
  // SECTION HEADER
 
  Widget _buildSectionHeader({required int count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Riwayat Lembur',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF1B5E20).withOpacity(0.15),
              ),
            ),
            child: Text(
              '$count item',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

 
  // BOTTOM SUMMARY
 
  Widget _buildBottomSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total Pendapatan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total Pendapatan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                _formatRupiah(_totalPendapatan),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                icon: Icons.work_history_rounded,
                label: 'Total Lembur',
                value: '${_totalLembur}x',
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                icon: Icons.timer_rounded,
                label: 'Total Jam',
                value: _formatJam(_totalJam),
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                icon: Icons.check_circle_rounded,
                label: 'Tepat Waktu',
                value: '$_tepatWaktu',
              ),
              if (_terlambat > 0) ...[
                _buildSummaryDivider(),
                _buildSummaryItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Terlambat',
                  value: '$_terlambat',
                  isWarning: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: isWarning
                ? Colors.orange.shade600
                : const Color(0xFF1B5E20).withOpacity(0.7),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isWarning ? Colors.orange.shade800 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.grey.shade200,
    );
  }

 
  // ERROR SCREEN (FIXED - NO fontFamily PARAMETER)
 
  Widget _buildErrorScreen({
    required IconData icon,
    required String title,
    required String message,
    String? errorDetail,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade100.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 72,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),

            // Error detail (jika ada)
            if (errorDetail != null && errorDetail.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  errorDetail.length > 150
                      ? '${errorDetail.substring(0, 150)}...'
                      : errorDetail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.3,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Retry button
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 
  // EMPTY STATE
 
  Widget _buildEmptyState() {
    final displayBulan = _formatBulanDisplay(_selectedBulan);
    final isCurrentMonth = _selectedBulan ==
        DateFormat('yyyy-MM').format(DateTime.now());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasi icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade50,
                        Colors.green.shade100,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade100.withOpacity(0.6),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.green.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                isCurrentMonth
                    ? 'Belum Ada Pendapatan'
                    : 'Tidak Ada Data',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                isCurrentMonth
                    ? 'Pendapatan akan muncul setelah Anda\n'
                        'menyelesaikan absensi lembur\n'
                        '(check-in & check-out).'
                    : 'Tidak ada data pendapatan untuk\n'
                        '$displayBulan.\n'
                        'Coba pilih bulan lain.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              // Tips card (hanya untuk bulan ini)
              if (isCurrentMonth) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade100,
                                  Colors.amber.shade200,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 22,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tips Mendapatkan Pendapatan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTipItem(
                        '1',
                        'Terima jadwal lembur dari pengawas',
                        Icons.assignment_turned_in_rounded,
                      ),
                      _buildTipItem(
                        '2',
                        'Lakukan absensi check-in tepat waktu',
                        Icons.login_rounded,
                      ),
                      _buildTipItem(
                        '3',
                        'Selesaikan lembur & lakukan check-out',
                        Icons.logout_rounded,
                      ),
                      _buildTipItem(
                        '4',
                        'Pendapatan akan otomatis terhitung',
                        Icons.auto_graph_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tombol pilih bulan
              OutlinedButton.icon(
                onPressed: _showMonthPicker,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  isCurrentMonth ? 'Lihat Bulan Lain' : 'Pilih Bulan',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Bottom spacing
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B5E20).withOpacity(0.12),
                  const Color(0xFF2E7D32).withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 15,
              color: const Color(0xFF1B5E20).withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          // Number
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

 
  // LOADING INDICATOR
 
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const CircularProgressIndicator(
        color: Color(0xFF1B5E20),
        strokeWidth: 3,
      ),
    );
  }

 
  // UPDATE RINGKASAN
 
  void _updateRingkasan(List<PendapatanItem> items) {
    double total = 0;
    double totalJam = 0;
    int tepat = 0;
    int lambat = 0;

    for (var item in items) {
      total += item.estimasiPendapatan;
      totalJam += item.totalJam;
      if (item.statusAbsensi == 'selesai') {
        tepat++;
      } else if (item.statusAbsensi == 'selesai_terlambat') {
        lambat++;
      }
    }

    // Update state hanya jika ada perubahan (optimasi rebuild)
    if (total != _totalPendapatan ||
        items.length != _totalLembur ||
        totalJam != _totalJam ||
        tepat != _tepatWaktu ||
        lambat != _terlambat) {
      if (mounted) {
        setState(() {
          _totalPendapatan = total;
          _totalLembur = items.length;
          _totalJam = totalJam;
          _tepatWaktu = tepat;
          _terlambat = lambat;
        });
      }
    }
  }

 
  // REFRESH DATA
 
  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRingkasan = true;
    });

    _pendapatanService.clearCache();

    // Biarkan stream update otomatis
    await Future.delayed(const Duration(milliseconds: 600));
  }

 
  // MONTH PICKER
 
  void _showMonthPicker() async {
    final currentDate = DateTime.parse('$_selectedBulan-01');

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime? selectedDate = currentDate;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 22,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pilih Bulan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                height: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Navigasi tahun
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: selectedDate!.year > 2024
                                ? () {
                                    setDialogState(() {
                                      selectedDate = DateTime(
                                        selectedDate!.year - 1,
                                        selectedDate!.month,
                                      );
                                    });
                                  }
                                : null,
                            tooltip: 'Tahun Sebelumnya',
                          ),
                          Text(
                            '${selectedDate!.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: selectedDate!.year < 2030
                                ? () {
                                    setDialogState(() {
                                      selectedDate = DateTime(
                                        selectedDate!.year + 1,
                                        selectedDate!.month,
                                      );
                                    });
                                  }
                                : null,
                            tooltip: 'Tahun Berikutnya',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid bulan
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final date = DateTime(selectedDate!.year, month);
                          final isSelected = month == currentDate.month &&
                              selectedDate!.year == currentDate.year;
                          final isCurrentMonth =
                              month == DateTime.now().month &&
                                  selectedDate!.year == DateTime.now().year;
                          final isDisabled = date.isAfter(DateTime.now());

                          return GestureDetector(
                            onTap: isDisabled
                                ? null
                                : () => Navigator.pop(context, date),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1B5E20)
                                    : isCurrentMonth
                                        ? const Color(0xFF1B5E20)
                                            .withOpacity(0.08)
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isCurrentMonth
                                            ? const Color(0xFF1B5E20)
                                                .withOpacity(0.25)
                                            : Colors.grey.shade300,
                                        width: isCurrentMonth ? 1.5 : 1,
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1B5E20)
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM', 'id_ID').format(date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : isDisabled
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, DateTime.now());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Bulan Ini',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedBulan = DateFormat('yyyy-MM').format(result);
        _isLoadingRingkasan = true;
      });
    }
  }

 
  // FORMATTING HELPERS
 

  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatJam(double hours) {
    if (hours == 0) return '0 jam';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0 && m == 0) return '0 mnt';
    if (h == 0) return '$m mnt';
    if (m == 0) return '$h jam';
    return '$h jam $m mnt';
  }

  String _formatBulanDisplay(String tahunBulan) {
    try {
      final parts = tahunBulan.split('-');
      if (parts.length != 2) return tahunBulan;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final date = DateTime(year, month);
      return DateFormat('MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return tahunBulan;
    }
  }
}