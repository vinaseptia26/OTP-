// lib/dashboard/mitra/mitra_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/mitra_service.dart';
import '../../core/services/auth_service.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/live_location_service.dart';
import '/widgets/menu/mitra_menu.dart';
import '/widgets/absensi/absensi_dialog.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';
import '/widgets/mitra/mitra_welcome_card.dart';
import '/widgets/mitra/mitra_income_card.dart';
import '/widgets/mitra/mitra_metrics_grid.dart';
import '/widgets/mitra/mitra_history_card.dart';
import '/widgets/mitra/mitra_performance_chart.dart';
import '/widgets/mitra/mitra_section_helper.dart';
import '/widgets/mitra/mitra_attendance_overtime_card.dart';

class MitraDashboard extends StatefulWidget {
  const MitraDashboard({super.key});

  @override
  State<MitraDashboard> createState() => _MitraDashboardState();
}

class _MitraDashboardState extends State<MitraDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider(
      create: (_) => MitraProvider(),
      child: _MitraBody(
        user: user,
        currentIndex: _currentIndex,
      ),
    );
  }
}

class _MitraBody extends StatefulWidget {
  final User? user;
  final int currentIndex;
  
  _MitraBody({
    required this.user,
    required this.currentIndex,
  });

  @override
  State<_MitraBody> createState() => _MitraBodyState();
}

class _MitraBodyState extends State<_MitraBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = MitraService();
  final _authService = AuthService();
  final _scrollController = ScrollController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;

  bool _isRefreshing = false;
  String? _loadingMessage;
  Timer? _snackbarTimer;

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _recentOvertimeHistory = [];
  Map<String, dynamic>? _attendanceToday;
  List<Map<String, dynamic>> _performanceData = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    await Future.wait([
      _loadGreetingAndProfile(),
      _loadDataWithMessage(),
      _loadAdditionalData(),
    ]);
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final results = await Future.wait([
        _service.getGreetingWithNameAndEmoji(),
        _service.getGreetingMotivation(),
        _service.getCurrentUserProfile(),
      ]);

      final greeting = results[0] as String;
      final motivation = results[1] as String;
      final profile = results[2] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _greeting = greeting;
          _motivation = motivation;
          _isGreetingLoading = false;

          if (profile != null) {
            _userName = profile['nama_lengkap']?.toString() ?? '';
            _userRole = profile['role']?.toString() ?? 'mitra';
            _userPhotoUrl = profile['photo_url']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting = '${_service.getGreeting()}, ${widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? 'Mitra'}!';
          _motivation = 'Semangat bekerja hari ini!';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataWithMessage() async {
    setState(() => _loadingMessage = 'Memuat data mitra...');
    final provider = context.read<MitraProvider>();
    await provider.loadData();
    if (mounted && provider.data != null) {
      setState(() => _loadingMessage = null);
    }
  }

  Future<void> _loadAdditionalData() async {
    try {
      final results = await Future.wait([
        _service.getUpcomingSchedules(),
        _service.getRecentOvertimeHistory(limit: 5),
        _service.getTodayAttendance(),
        _service.getPerformanceData(months: 6),
      ]);

      if (mounted) {
        setState(() {
          _schedules = results[0] as List<Map<String, dynamic>>;
          _recentOvertimeHistory = results[1] as List<Map<String, dynamic>>;
          _attendanceToday = results[2] as Map<String, dynamic>?;
          _performanceData = results[3] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data tambahan: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _scrollController.dispose();
    _snackbarTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<MitraProvider>();
      provider.clearCache();
      await Future.wait([
        provider.loadData(),
        _loadGreetingAndProfile(),
        _loadAdditionalData(),
      ]);
      _fadeController.reset();
      _fadeController.forward();
      if (mounted) {
        _showSnackBar('Data berhasil diperbarui', success: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal memperbarui data', success: false);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    if (!mounted) return;
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
        ]),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).size.height * 0.12),
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _showNotifications() async {
    final notifs = await _service.getNotifications();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.notifications, color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 10),
              const Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (notifs.any((n) => n['isRead'] == false))
                TextButton.icon(
                  onPressed: () async {
                    await _service.markAllNotificationsRead();
                    if (mounted) context.read<MitraProvider>().loadData();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackBar('Semua notifikasi telah dibaca');
                  },
                  icon: const Icon(Icons.done_all, size: 15),
                  label: const Text('Tandai Semua', style: TextStyle(fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: notifs.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.notifications_none, size: 50, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('Tidak ada notifikasi', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ]))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: notifs.length,
                      itemBuilder: (ctx, index) {
                        final n = notifs[index];
                        final isRead = n['isRead'] ?? false;
                        return _buildNotificationItem(n, isRead);
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> n, bool isRead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFF1565C0).withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRead ? Colors.grey[200]! : const Color(0xFF1565C0).withAlpha(51)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isRead ? Colors.grey : const Color(0xFF1565C0)).withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications, size: 14, color: isRead ? Colors.grey : const Color(0xFF1565C0)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n['title'] ?? 'Notifikasi',
              style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text(n['body'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2),
          const SizedBox(height: 3),
          Text(_service.getTimeAgo(n['createdAt']), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
        ])),
        if (!isRead) Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
        ),
      ]),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_rounded, size: 20, color: Colors.blue),
              ),
              title: const Text('Profil Saya', style: TextStyle(fontSize: 14)),
              onTap: () { Navigator.pop(ctx); context.push('/profile'); },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.settings_rounded, size: 20, color: Colors.green),
              ),
              title: const Text('Pengaturan', style: TextStyle(fontSize: 14)),
              onTap: () { Navigator.pop(ctx); context.push('/settings'); },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
              ),
              title: const Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); _showLogoutConfirmation(); },
            ),
          ],
        ),
      ),
    );
  }

  bool _canCheckInNow(String jamMulai) {
    final now = DateTime.now();
    final parts = jamMulai.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final todayStart = DateTime(now.year, now.month, now.day, hour, minute);
    final canCheckInFrom = todayStart.subtract(const Duration(hours: 1));
    return now.isAfter(canCheckInFrom) || now.isAtSameMomentAs(canCheckInFrom);
  }

  Future<void> _handleCheckIn(Map<String, dynamic> overtime) async {
    final overtimeItem = await OvertimeHistoryService().getOvertimeById(overtime['id']);
    if (overtimeItem == null) {
      if (mounted) _showSnackBar('Data lembur tidak ditemukan', success: false);
      return;
    }

    final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
    if (absensiSuccess != true || !mounted) return;

    await _service.checkInLembur(overtime['id'], _userName);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // FIX: Tambah userName dan lemburId
        await LiveLocationService().startTracking(
          userId: currentUser.uid,
          userName: _userName,
          overtimeId: overtime['id'],
          lemburId: overtime['id'],
        );
        debugPrint('Live tracking dimulai dari mitra_dashboard');
      } catch (e) {
        debugPrint('Gagal mulai live tracking: $e');
      }
    }

    if (mounted) {
      await context.read<MitraProvider>().loadData();
      await _loadAdditionalData();
      _showSnackBar('Check-in berhasil! (Live tracking aktif)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MitraProvider>();

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
        body: _buildLoadingScreen(provider.errorMessage),
      );
    }
    if (provider.data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
        body: _buildErrorScreen(provider.errorMessage),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF1565C0),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 40,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _buildContentSliver(data),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSliver(MitraDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
      sliver: SliverList(delegate: SliverChildListDelegate([
        FadeTransition(
          opacity: _fadeAnimation,
          child: MitraWelcomeCard(
            greeting: _greeting,
            motivation: _motivation,
            userName: _userName,
            userRole: _userRole,
            userPhotoUrl: _userPhotoUrl,
            formattedDate: _formatDate(DateTime.now()),
            isRefreshing: _isRefreshing,
            onRefresh: _refreshData,
            onNotificationsTap: _showNotifications,
            onProfileTap: _showProfileMenu,
          ),
        ),
        const SizedBox(height: 16),

        if (_attendanceToday != null || data.hasTodayOvertime || _schedules.isNotEmpty) ...[
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(_fadeAnimation),
            child: MitraAttendanceOvertimeCard(
              attendanceData: _attendanceToday,
              overtime: data.hasTodayOvertime ? data.todayOvertime : null,
              upcomingSchedules: _schedules.isNotEmpty ? _schedules : null,
              isCheckedIn: data.isLemburCheckedIn,
              isCheckedOut: data.isLemburCheckedOut,
              canCheckIn: data.hasTodayOvertime 
                  ? _canCheckInNow(data.todayOvertime!['jam_mulai']?.toString() ?? '19:00') 
                  : false,
              formattedCheckInTime: data.hasTodayOvertime 
                  ? _formatCheckInTime(data.todayOvertime!['jam_mulai']?.toString() ?? '19:00') 
                  : '--:--',
              userName: _userName,
              overtimeSettings: data.overtimeSettings,
              onCheckIn: () => _handleCheckIn(data.todayOvertime!),
              onCheckOut: () async {
                await context.read<MitraProvider>().loadData();
                await _loadAdditionalData();
              },
              onViewAllSchedules: () => context.push('/full-schedule'),
            ),
          ),
          const SizedBox(height: 24),
        ],

        FadeTransition(
          opacity: _fadeAnimation,
          child: MitraIncomeCard(
            totalIncome: data.totalIncomeStat,
            targetIncome: 10000000.0,
            periodLabel: 'Bulan Ini',
          ),
        ),
        const SizedBox(height: 16),

        FadeTransition(
          opacity: _fadeAnimation,
          child: MitraMetricsGrid(
            totalLembur: data.totalLemburStat,
            totalJam: data.totalJamStat.toDouble(),
            pending: data.pendingStat,
            disetujui: data.disetujuiStat,
            totalIncome: data.totalIncomeStat,
            sisaKuota: data.sisaKuotaStat.toDouble(),
          ),
        ),
        const SizedBox(height: 20),

        if (_performanceData.isNotEmpty) ...[
          const MitraCorporateDivider(title: 'PERFORMA'),
          const SizedBox(height: 14),
          FadeTransition(
            opacity: _fadeAnimation,
            child: MitraPerformanceChart(performanceData: _performanceData),
          ),
          const SizedBox(height: 20),
        ],

        const MitraCorporateDivider(title: 'MENU UTAMA'),
        const SizedBox(height: 14),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(_fadeAnimation),
          child: MitraMenu(data: data, service: _service),
        ),
        const SizedBox(height: 20),

        if (_recentOvertimeHistory.isNotEmpty) ...[
          const MitraCorporateDivider(title: 'RIWAYAT TERBARU'),
          const SizedBox(height: 14),
          FadeTransition(
            opacity: _fadeAnimation,
            child: MitraHistoryCard(
              historyList: _recentOvertimeHistory,
              onViewAll: () => context.push('/overtime-history'),
            ),
          ),
          const SizedBox(height: 20),
        ],

      ])),
    );
  }

  Widget _buildLoadingScreen(String? errorMessage) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFE3F2FD)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80, right: -40,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 3),
              builder: (context, value, child) => Transform.rotate(
                angle: value * 6.28318,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1565C0).withAlpha(25), width: 2),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF1565C0).withAlpha(30), blurRadius: 30, spreadRadius: 5),
                          BoxShadow(color: const Color(0xFFFFAB40).withAlpha(20), blurRadius: 40, spreadRadius: 2),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.engineering_rounded, size: 50, color: const Color(0xFF1565C0).withAlpha(200)),
                          Positioned(
                            bottom: 15, right: 15,
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFAB40),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: const Color(0xFFFFAB40).withAlpha(80), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.bolt, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFFFFAB40)],
                  ).createShader(bounds),
                  child: const Text('MITRA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
                ),
                const SizedBox(height: 6),
                const Text('DASHBOARD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.grey, letterSpacing: 6)),
                const SizedBox(height: 28),
                SizedBox(
                  width: 30, height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1565C0).withAlpha(204))),
                ),
                const SizedBox(height: 16),
                if (_loadingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF1565C0).withAlpha(20), const Color(0xFFFFAB40).withAlpha(10)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1565C0).withAlpha(30)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1565C0).withAlpha(150)))),
                      const SizedBox(width: 8),
                      Text(_loadingMessage!, style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String? errorMessage) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF8FAFC), Color(0xFFFFF3E0)]),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF1565C0).withAlpha(30), const Color(0xFFFFAB40).withAlpha(20)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF1565C0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Gagal Memuat Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
              const SizedBox(height: 10),
              Text(errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.', style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<MitraProvider>().clearCache();
                    context.read<MitraProvider>().loadData();
                    _loadGreetingAndProfile();
                    _loadAdditionalData();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatCheckInTime(String jamMulai) {
    final parts = jamMulai.split(':');
    if (parts.length != 2) return jamMulai;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final checkInFrom = DateTime(2024, 1, 1, hour, minute).subtract(const Duration(hours: 1));
    return '${checkInFrom.hour.toString().padLeft(2, '0')}:${checkInFrom.minute.toString().padLeft(2, '0')}';
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.logout_rounded, size: 36, color: Colors.red),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontSize: 16)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(fontSize: 13))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text('Ya, Logout', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFF1565C0)),
                SizedBox(height: 16),
                Text('Sedang logout...', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ),
          ),
        ),
      );
      await _service.logout();
      if (mounted) context.read<MitraProvider>().clearCache();
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSnackBar('Gagal logout: ${e.toString()}', success: false);
      }
    }
  }
}

class MitraProvider extends ChangeNotifier {
  final _service = MitraService();
  bool isLoading = true;
  MitraDashboardData? data;
  String? errorMessage;

  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      data = await _service.loadDashboardData();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void clearCache() {
    data = null;
  }
}