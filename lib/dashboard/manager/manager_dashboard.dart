// lib/dashboard/manager/manager_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/manager_service.dart';
import '/widgets/team_summary.dart';
import '../../widgets/menu/manager_menu.dart';
import '../../widgets/bottom_nav/manager_bottom_nav.dart';
import '../../widgets/manager/manager_analytics_section.dart';
import '../../widgets/manager/manager_welcome_card.dart';
import '../../widgets/manager/manager_stats_grid.dart';
import '../../widgets/manager/manager_pending_section.dart';
import '../../widgets/manager/manager_section_helper.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider(
      create: (_) => ManagerProvider(),
      child: _ManagerBody(user: user),
    );
  }
}

class _ManagerBody extends StatefulWidget {
  final User? user;
  const _ManagerBody({required this.user});

  @override
  State<_ManagerBody> createState() => _ManagerBodyState();
}

class _ManagerBodyState extends State<_ManagerBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = ManagerService();
  final _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _greeting = 'Selamat Datang';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;
  bool _isRefreshing = false;
  String? _loadingMessage;

  int _currentNavIndex = 0;

  static const Color primaryColor = Color(0xFF1E3C72);
  static const Color bgColor = Color(0xFFF1F5F9);

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    await Future.wait([
      _loadGreetingAndProfile(),
      _loadData(),
    ]);
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final userData = await _service.getUserData();
      if (mounted) {
        setState(() {
          _userName = userData['nama_lengkap']?.toString() ?? '';
          _userRole = userData['role']?.toString() ?? 'manager';
          _userPhotoUrl = userData['photo_url']?.toString();
          _greeting = '${_service.getGreeting()}, $_userName! ${_service.getGreetingEmoji()}';
          _isGreetingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting = '${_service.getGreeting()}, ${widget.user?.displayName ?? 'Manager'}! 👋';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loadingMessage = 'Memuat data manager...');
    final provider = context.read<ManagerProvider>();
    await provider.loadData();
    if (mounted) setState(() => _loadingMessage = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<ManagerProvider>();
      provider.clearCache();
      await Future.wait([
        provider.loadData(),
        _loadGreetingAndProfile(),
      ]);
      _fadeController.reset();
      _fadeController.forward();
      if (mounted) _showSnackBar('✅ Data berhasil diperbarui', success: true);
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui data', success: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    if (!mounted) return;
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
        margin: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).size.height * 0.1),
        duration: const Duration(seconds: 2),
      ));
  }

  // Navigasi aman dengan fallback
  void _navigateToMyTeam() {
    try {
      context.push('/my-team');
    } catch (e) {
      debugPrint('Navigasi ke /my-team gagal: $e');
      if (mounted) {
        _showSnackBar('Halaman tim sedang dalam pengembangan', success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerProvider>();

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar: ManagerBottomNav(currentIndex: _currentNavIndex),
        body: _buildLoadingScreen(provider.errorMessage),
      );
    }
    if (provider.data == null) {
      return Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar: ManagerBottomNav(currentIndex: _currentNavIndex),
        body: _buildErrorScreen(provider.errorMessage),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: ManagerBottomNav(currentIndex: _currentNavIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryColor,
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 10,
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

  // ==================== CONTENT SLIVER ====================
  Widget _buildContentSliver(ManagerDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      sliver: SliverList(delegate: SliverChildListDelegate([
        // WELCOME CARD
        FadeTransition(
          opacity: _fadeAnimation,
          child: ManagerWelcomeCard(
            greeting: _greeting,
            userName: _userName,
            userRole: _userRole,
            userPhotoUrl: _userPhotoUrl,
            formattedDate: _formatDate(DateTime.now()),
            isRefreshing: _isRefreshing,
            onRefresh: _refreshData,
            onNotificationsTap: _showNotifications,
          ),
        ),
        const SizedBox(height: 16),

        // STATS GRID
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fadeAnimation),
          child: ManagerStatsGrid(
            totalTeamMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            totalPending: data.totalPending,
            totalApproved: data.totalApproved,
            totalHoursThisMonth: data.totalHoursThisMonth,
          ),
        ),
        const SizedBox(height: 14),

        // ANALYTICS
        const ManagerCorporateDivider(title: 'ANALYTICS'),
        const SizedBox(height: 14),
        FadeTransition(
          opacity: _fadeAnimation,
          child: ManagerAnalyticsSection(
            totalApproved: data.totalApproved,
            totalRejected: data.totalRejected,
            totalPending: data.totalPending,
            totalHoursThisMonth: data.totalHoursThisMonth,
            getTimeAgo: _service.getTimeAgo,
          ),
        ),
        const SizedBox(height: 20),

        // QUICK ACTION
        const ManagerCorporateDivider(title: 'MENU UTAMA'),
        const SizedBox(height: 14),
        ManagerMenu(data: data, service: _service),
        const SizedBox(height: 18),

        // PENDING APPROVAL
        const ManagerCorporateDivider(title: 'PERSETUJUAN'),
        const SizedBox(height: 14),
        const ManagerSectionHeader(
          icon: Icons.pending_actions_rounded,
          title: 'Menunggu Persetujuan',
          iconColor: Color(0xFFFF6B35),
        ),
        const SizedBox(height: 10),
        ManagerPendingSection(
          pendingList: data.pendingList,
          getTimeAgo: _service.getTimeAgo,
          onApprove: _approveLembur,
          onReject: _rejectLembur,
        ),
        const SizedBox(height: 18),

        // TEAM SUMMARY
        const ManagerCorporateDivider(title: 'TEAM'),
        const SizedBox(height: 14),
        const ManagerSectionHeader(
          icon: Icons.group_rounded,
          title: 'Ringkasan Tim',
          iconColor: Color(0xFF11998E),
        ),
        const SizedBox(height: 10),
        TeamSummary(
          teamMembers: data.teamMembers,
          totalMembers: data.totalTeamMembers,
          onlineMembers: data.onlineMembers,
          getRoleColor: _service.getRoleColor,
          accentColor: primaryColor,
          onViewAll: _navigateToMyTeam, // ✅ Menggunakan method yang aman
        ),
        const SizedBox(height: 20),
      ])),
    );
  }

  // ==================== LOADING SCREEN ====================
  Widget _buildLoadingScreen(String? errorMessage) {
    return Stack(
      children: [
        Positioned(
          top: -100, right: -100,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(13)),
          ),
        ),
        Positioned(
          bottom: -50, left: -50,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(13)),
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
                      boxShadow: [BoxShadow(color: Colors.white.withAlpha(77), blurRadius: 40, spreadRadius: 5)],
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, size: 50, color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('MANAGER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72), letterSpacing: 3)),
              const SizedBox(height: 4),
              const Text('DASHBOARD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: Colors.grey, letterSpacing: 6)),
              const SizedBox(height: 30),
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1E3C72).withAlpha(204)),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF1E3C72).withAlpha(26), borderRadius: BorderRadius.circular(20)),
                  child: Text(_loadingMessage!, style: const TextStyle(color: Color(0xFF1E3C72), fontSize: 12)),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(errorMessage, style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== ERROR SCREEN ====================
  Widget _buildErrorScreen(String? errorMessage) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: const Color(0xFF1E3C72).withAlpha(26), shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF1E3C72)),
              ),
              const SizedBox(height: 20),
              const Text('Gagal Memuat Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72))),
              const SizedBox(height: 10),
              Text(
                errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.',
                style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<ManagerProvider>().clearCache();
                  context.read<ManagerProvider>().loadData();
                  _loadGreetingAndProfile();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== NOTIFICATIONS ====================
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
              Icon(Icons.notifications, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              const Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (notifs.any((n) => n['isRead'] == false))
                TextButton.icon(
                  onPressed: () async {
                    await _service.markAllNotificationsRead();
                    if (mounted) context.read<ManagerProvider>().loadData();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackBar('✅ Semua notifikasi telah dibaca');
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
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : primaryColor.withAlpha(13),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isRead ? Colors.grey[200]! : primaryColor.withAlpha(51)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (isRead ? Colors.grey : primaryColor).withAlpha(26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications, size: 14, color: isRead ? Colors.grey : primaryColor),
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
                              decoration: const BoxDecoration(color: Color(0xFF1E3C72), shape: BoxShape.circle),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================
  Future<void> _approveLembur(Map<String, dynamic> lembur) async {
    await _service.approveLembur(lembur['id'], true, note: 'Disetujui oleh Manager');
    if (mounted) { context.read<ManagerProvider>().loadData(); _showSnackBar('✅ Lembur disetujui'); }
  }

  Future<void> _rejectLembur(Map<String, dynamic> lembur) async {
    await _service.approveLembur(lembur['id'], false, note: 'Ditolak oleh Manager');
    if (mounted) { context.read<ManagerProvider>().loadData(); _showSnackBar('❌ Lembur ditolak', success: false); }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ==================== PROVIDER ====================
class ManagerProvider extends ChangeNotifier {
  final _service = ManagerService();
  bool isLoading = true;
  ManagerDashboardData? data;
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