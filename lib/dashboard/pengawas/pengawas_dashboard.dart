// lib/dashboard/pengawas/pengawas_dashboard.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/services/pengawas_service.dart';
import '/widgets/pengawas/pengawas_stats_grid.dart';
import '/widgets/pengawas/pengawas_key_metrics.dart';
import '/widgets/calendar_card.dart';
import '/widgets/team_summary.dart';
import '/widgets/recent_activitiess.dart';
import '/widgets/menu/pengawas_menu.dart';
import '/widgets/system_health.dart';

class PengawasDashboard extends StatelessWidget {
  const PengawasDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ChangeNotifierProvider(
      create: (_) => PengawasProvider(),
      child: _PengawasBody(user: user),
    );
  }
}

class _PengawasBody extends StatefulWidget {
  final User? user;
  const _PengawasBody({required this.user});

  @override
  State<_PengawasBody> createState() => _PengawasBodyState();
}

class _PengawasBodyState extends State<_PengawasBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = PengawasService();
  final _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ==================== GREETING STATE ====================
  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;

  bool _isRefreshing = false;
  String? _loadingMessage;
  Timer? _heartbeatTimer;

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
    await _loadGreetingAndProfile();
    await _loadDataWithMessage();
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
            _userRole = profile['role']?.toString() ?? 'pengawas';
            _userPhotoUrl = profile['photo_url']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting = '${_service.getGreeting()}, ${widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? 'Pengawas'}! 👋';
          _motivation = 'Semoga harimu produktif! 💪';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataWithMessage() async {
    setState(() {
      _loadingMessage = 'Memuat data pengawas...';
    });

    final provider = context.read<PengawasProvider>();
    await provider.loadData();

    if (mounted && provider.data != null) {
      setState(() {
        _loadingMessage = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final provider = context.read<PengawasProvider>();
      provider.clearCache();
      await provider.loadData();
      await _loadGreetingAndProfile();

      _fadeController.reset();
      _fadeController.forward();

      if (mounted) {
        _showSnackBar('✅ Data berhasil diperbarui', success: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Gagal memperbarui data: ${e.toString()}', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PengawasProvider>();

    if (provider.isLoading || _isGreetingLoading) {
      return _buildLoadingScreen(provider.errorMessage);
    }

    if (provider.data == null) {
      return _buildErrorScreen(provider.errorMessage);
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      floatingActionButton: _buildFloatingActionButton(data),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF448AFF),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 10,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            _buildContentSliver(data),
          ],
        ),
      ),
    );
  }

  // ==================== LOADING SCREEN ====================
  Widget _buildLoadingScreen(String? errorMessage) {
    return Scaffold(
      backgroundColor: const Color(0xFF448AFF),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(13),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(13),
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
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withAlpha(77),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.supervisor_account_rounded,
                          size: 65,
                          color: Color(0xFF448AFF),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                const Text(
                  'PENGAWAS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'DASHBOARD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withAlpha(204),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_loadingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _loadingMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ERROR SCREEN ====================
  Widget _buildErrorScreen(String? errorMessage) {
    return Scaffold(
      backgroundColor: const Color(0xFF448AFF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gagal Memuat Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = context.read<PengawasProvider>();
                    provider.clearCache();
                    provider.loadData();
                    _loadGreetingAndProfile();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF448AFF),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Kembali ke Login',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FLOATING ACTION BUTTON ====================
  Widget _buildFloatingActionButton(PengawasDashboardData data) {
    if (data.isCheckedIn) {
      return FloatingActionButton.extended(
        onPressed: () async {
          if (data.activeLembur?['check_in'] != null) {
            final checkIn = (data.activeLembur!['check_in'] as Timestamp).toDate();
            final totalJam = DateTime.now().difference(checkIn).inHours.toDouble();
            await _service.checkOut(data.activeLembur!['id'], totalJam);
            if (mounted) {
              context.read<PengawasProvider>().loadData();
              _showSnackBar('✅ Check-out berhasil! Total: ${totalJam.toStringAsFixed(1)} jam');
            }
          }
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.logout),
        label: const Text('Check-out'),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/ajukan-lembur'),
        backgroundColor: const Color(0xFFFFAB40),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Lembur'),
      );
    }
  }

  // ==================== CONTENT SLIVER ====================
  Widget _buildContentSliver(PengawasDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ========== PERSONAL WELCOME CARD ==========
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildPersonalWelcomeCard(),
          ),
          const SizedBox(height: 16),

          // ========== STATS GRID PENGAWAS ==========
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_fadeAnimation),
            child: PengawasStatsGrid(data: data),
          ),
          const SizedBox(height: 16),

          // ========== KEY METRICS PENGAWAS ==========
          PengawasKeyMetrics(
            totalLemburWeek: data.totalLemburWeek,
            pendingApprovals: data.pendingApproval,
            totalTeamMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            formatNumber: _service.formatNumber,
          ),
          const SizedBox(height: 16),

          // ========== PENGAWAS MENU ==========
          PengawasMenu(data: data, service: _service),
          const SizedBox(height: 16),

          // ========== TEAM SUMMARY ==========
          TeamSummary(
            teamMembers: data.teamMembers,
            totalMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            getRoleColor: _service.getRoleColor,
            accentColor: const Color(0xFF69F0AE),
            onViewAll: () => Navigator.pushNamed(context, '/my-team'),
          ),
          const SizedBox(height: 16),

          // ========== CALENDAR + OVERTIME SUMMARY ==========
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 5, child: CalendarCard(primaryColor: Color(0xFF448AFF))),
            ],
          ),
          const SizedBox(height: 16),

          // ========== RECENT ACTIVITIES ==========
          RecentActivitiesWidget(
            activities: data.recentActivities,
            getTimeAgo: _service.getTimeAgo,
            getRoleColor: _service.getRoleColor,
          ),
          const SizedBox(height: 16),

          // ========== SYSTEM HEALTH ==========
          SystemHealthWidget(
            accentColor: const Color(0xFF448AFF),
            getTimeAgo: _service.getTimeAgo,
          ),
          const SizedBox(height: 24),

          // ========== LOGOUT BUTTON ==========
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ==================== PERSONAL WELCOME CARD ====================
  Widget _buildPersonalWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                      ? Text(
                          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3C72),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _motivation,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(204),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Role: ${_userRole.isNotEmpty ? _userRole.toUpperCase() : 'PENGAWAS'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 16, color: Colors.white30),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ==================== SLIVER APP BAR ====================
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E3C72),
                Color(0xFF2A4F8C),
                Color(0xFFFF6B35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        IconButton(
          icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
          onPressed: _showNotifications,
          tooltip: 'Notifikasi',
        ),
        PopupMenuButton<String>(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_userPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          offset: const Offset(0, 50),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                Navigator.pushNamed(context, '/profile');
                break;
              case 'settings':
                Navigator.pushNamed(context, '/settings');
                break;
              case 'logout':
                _showLogoutConfirmation();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_rounded, size: 16, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  const Text('Profil Saya', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings_rounded, size: 16, color: Colors.green),
                  ),
                  const SizedBox(width: 10),
                  const Text('Pengaturan', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  const Text('Logout',
                      style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ==================== LOGOUT BUTTON ====================
  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFF6D00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withAlpha(77),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _showLogoutConfirmation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.zero,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== NOTIFICATIONS ====================
  Future<void> _showNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Gunakan service untuk ambil notifikasi
    final notifs = await _service.getNotifications();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: Color(0xFF448AFF), size: 24),
                      const SizedBox(width: 12),
                      const Text('Notifikasi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (notifs.any((n) => n['isRead'] == false))
                        TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) {
                              context.read<PengawasProvider>().loadData();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('✅ Semua notifikasi telah dibaca');
                          },
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('Tandai Semua'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('Tidak ada notifikasi', style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: notifs.length,
                            itemBuilder: (ctx, index) {
                              final n = notifs[index]; // ✅ Map langsung
                              final isRead = n['isRead'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : const Color(0xFF448AFF).withAlpha(13),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRead
                                        ? Colors.grey[200]!
                                        : const Color(0xFF448AFF).withAlpha(51),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isRead ? Colors.grey : const Color(0xFF448AFF))
                                            .withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications,
                                        size: 16,
                                        color: isRead ? Colors.grey : const Color(0xFF448AFF),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['title'] ?? 'Notifikasi',
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            n['body'] ?? '',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _service.getTimeAgo(n['createdAt']),
                                            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF448AFF),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== LOGOUT DIALOG & PROCESS ====================
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.logout_rounded, size: 48, color: Colors.red),
        title: const Text('Konfirmasi Logout'),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF448AFF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sedang logout...',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      _heartbeatTimer?.cancel();
      await _service.logout(); // sudah include set offline & signOut

      if (mounted) {
        final provider = context.read<PengawasProvider>();
        provider.clearCache();
      }

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSnackBar('Gagal logout: ${e.toString()}', success: false);
      }
    }
  }
}

// ==================== PROVIDER ====================
class PengawasProvider extends ChangeNotifier {
  final _service = PengawasService();
  bool isLoading = true;
  PengawasDashboardData? data;
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