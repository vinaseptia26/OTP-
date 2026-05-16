// lib/dashboard/manager/manager_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/services/manager_service.dart';
import '/widgets/calendar_card.dart';
import '/widgets/team_summary.dart';
import '/widgets/recent_activitiess.dart';
import '/widgets/system_health.dart';
import '../../widgets/menu/manager_menu.dart';

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
      final userData = await _service.getUserData();
      if (mounted) {
        setState(() {
          _userName = userData['nama_lengkap']?.toString() ?? '';
          _userRole = userData['role']?.toString() ?? 'manager';
          _userPhotoUrl = userData['photo_url']?.toString();
          _greeting =
              '${_service.getGreeting()}, $_userName! ${_service.getGreetingEmoji()}';
          _motivation = _buildMotivation();
          _isGreetingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting =
              '${_service.getGreeting()}, ${widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? 'Manager'}! 👋';
          _motivation = 'Semangat mengelola tim hari ini! 💪';
          _isGreetingLoading = false;
        });
      }
    }
  }

  String _buildMotivation() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Semoga semua pengajuan lancar hari ini! ☀️';
    if (hour < 15) return 'Tetap semangat memantau tim! 💼';
    if (hour < 18) return 'Sore yang produktif untuk menyetujui lembur. 🌆';
    return 'Jaga kesehatan dan tetap awasi tim malam ini. 🌙';
  }

  Future<void> _loadDataWithMessage() async {
    setState(() => _loadingMessage = 'Memuat data manager...');
    final provider = context.read<ManagerProvider>();
    await provider.loadData();
    if (mounted && provider.data != null) {
      setState(() => _loadingMessage = null);
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
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<ManagerProvider>();
      provider.clearCache();
      await provider.loadData();
      await _loadGreetingAndProfile();
      _fadeController.reset();
      _fadeController.forward();
      if (mounted) _showSnackBar('✅ Data berhasil diperbarui', success: true);
    } catch (e) {
      if (mounted)
        _showSnackBar('❌ Gagal memperbarui data: ${e.toString()}',
            success: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
              child: Text(message,
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor:
            success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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

  Future<void> _approveLembur(Map<String, dynamic> lembur) async {
    await _service.approveLembur(lembur['id'], true,
        note: 'Disetujui oleh Manager');
    if (mounted) {
      context.read<ManagerProvider>().loadData();
      _showSnackBar('✅ Lembur disetujui');
    }
  }

  Future<void> _rejectLembur(Map<String, dynamic> lembur) async {
    await _service.approveLembur(lembur['id'], false,
        note: 'Ditolak oleh Manager');
    if (mounted) {
      context.read<ManagerProvider>().loadData();
      _showSnackBar('❌ Lembur ditolak', success: false);
    }
  }

  Future<void> _showNotifications() async {
    final notifs = await _service.getNotifications();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.notifications,
                          color: Color(0xFF7B1FA2), size: 24),
                      const SizedBox(width: 12),
                      const Text('Notifikasi',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (notifs.any((n) => n['isRead'] == false))
                        TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) {
                              context.read<ManagerProvider>().loadData();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar(
                                '✅ Semua notifikasi telah dibaca');
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
                                Icon(Icons.notifications_none,
                                    size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('Tidak ada notifikasi',
                                    style:
                                        TextStyle(color: Colors.grey[400])),
                              ]))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: notifs.length,
                            itemBuilder: (ctx, index) {
                              final n = notifs[index];
                              final isRead = n['isRead'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.white
                                      : const Color(0xFF7B1FA2)
                                          .withAlpha(13),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isRead
                                          ? Colors.grey[200]!
                                          : const Color(0xFF7B1FA2)
                                              .withAlpha(51)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isRead
                                                ? Colors.grey
                                                : const Color(0xFF7B1FA2))
                                            .withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.notifications,
                                          size: 16,
                                          color: isRead
                                              ? Colors.grey
                                              : const Color(0xFF7B1FA2)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['title'] ?? 'Notifikasi',
                                            style: TextStyle(
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(n['body'] ?? '',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600]),
                                              maxLines: 2),
                                          const SizedBox(height: 4),
                                          Text(
                                              _service.getTimeAgo(
                                                  n['createdAt']),
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[400])),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: Color(0xFF7B1FA2),
                                              shape: BoxShape.circle)),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerProvider>();

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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B1FA2),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => Navigator.pushNamed(context, '/ajukan-lembur'),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF7B1FA2),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 10,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
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
      backgroundColor: const Color(0xFF7B1FA2),
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
                        child: const Icon(Icons.manage_accounts_rounded,
                            size: 65, color: Color(0xFF7B1FA2)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                const Text(
                  'MANAGER',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_loadingMessage!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(errorMessage,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center),
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
      backgroundColor: const Color(0xFF7B1FA2),
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
                  child: const Icon(Icons.wifi_off_rounded,
                      size: 50, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('Gagal Memuat Data',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  errorMessage ??
                      'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = context.read<ManagerProvider>();
                    provider.clearCache();
                    provider.loadData();
                    _loadGreetingAndProfile();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7B1FA2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Kembali ke Login',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                Color(0xFF4A148C), // ungu tua
                Color(0xFF7B1FA2), // ungu
                Color(0xFFFF6B35), // aksen oranye
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
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 22),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        IconButton(
          icon: const Icon(Icons.notifications_rounded,
              color: Colors.white, size: 22),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: const Icon(Icons.person_rounded,
                        size: 16, color: Colors.blue),
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
                    child: const Icon(Icons.settings_rounded,
                        size: 16, color: Colors.green),
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
                    child: const Icon(Icons.logout_rounded,
                        size: 16, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  const Text('Logout',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ==================== CONTENT SLIVER ====================
  Widget _buildContentSliver(ManagerDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Personal Welcome Card
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildPersonalWelcomeCard(),
          ),
          const SizedBox(height: 16),

          // Stats Grid (dibuat manual sesuai data)
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_fadeAnimation),
            child: _buildStatsGrid(data),
          ),
          const SizedBox(height: 16),

          // Key Metrics
          _buildKeyMetrics(data),
          const SizedBox(height: 16),

          // Manager Menu
          ManagerMenu(data: data, service: _service),
          const SizedBox(height: 16),

          // Pending Approvals
          _buildPendingSection(data),
          const SizedBox(height: 16),

          // Team Summary
          TeamSummary(
            teamMembers: data.teamMembers,
            totalMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            getRoleColor: _service.getRoleColor,
            accentColor: const Color(0xFF7B1FA2),
            onViewAll: () => Navigator.pushNamed(context, '/my-team'),
          ),
          const SizedBox(height: 16),

          // Calendar + Overtime
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                  flex: 5,
                  child: CalendarCard(primaryColor: Color(0xFF7B1FA2))),
            ],
          ),
          const SizedBox(height: 16),

          // System Health
          SystemHealthWidget(
            accentColor: const Color(0xFF7B1FA2),
            getTimeAgo: _service.getTimeAgo,
          ),
          const SizedBox(height: 16),

          // Recent Activities
          RecentActivitiesWidget(
            activities: data.recentActivities,
            getTimeAgo: _service.getTimeAgo,
            getRoleColor: _service.getRoleColor,
          ),
          const SizedBox(height: 24),

          // Logout Button
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
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)], // ungu tua ke ungu
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withAlpha(77),
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
                  backgroundImage: _userPhotoUrl != null &&
                          _userPhotoUrl!.isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                      ? Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A148C),
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
                const Icon(Icons.shield_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Role: ${_userRole.isNotEmpty ? _userRole.toUpperCase() : 'MANAGER'}',
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
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
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

  // ==================== STATS GRID ====================
  Widget _buildStatsGrid(ManagerDashboardData data) {
    final items = [
      _StatItem(
        title: 'Total Tim',
        value: '${data.totalTeamMembers}',
        icon: Icons.people_rounded,
        subtitle: 'Online: ${data.onlineMembers}',
        gradientColors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
      ),
      _StatItem(
        title: 'Pending',
        value: '${data.totalPending}',
        icon: Icons.pending_actions_rounded,
        subtitle: 'Perlu persetujuan',
        gradientColors: [Color(0xFFf12711), Color(0xFFf5af19)],
      ),
      _StatItem(
        title: 'Disetujui',
        value: '${data.totalApproved}',
        icon: Icons.check_circle_rounded,
        subtitle: 'Approved',
        gradientColors: [Color(0xFF00b09b), Color(0xFF96c93d)],
      ),
      _StatItem(
        title: 'Jam Bln Ini',
        value: '${data.totalHoursThisMonth.toStringAsFixed(0)} jam',
        icon: Icons.timer_rounded,
        subtitle: 'Total lembur',
        gradientColors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildStatCard(items[index]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors[0].withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1)),
              const SizedBox(height: 4),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500)),
              Text(item.subtitle,
                  style:
                      const TextStyle(fontSize: 9, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== KEY METRICS ====================
  Widget _buildKeyMetrics(ManagerDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔑 Metrik Manager',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4C))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                    Icons.work_history_rounded,
                    'Lembur Bulan Ini',
                    '${data.totalHoursThisMonth.toStringAsFixed(0)} jam',
                    const Color(0xFF7B1FA2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                    Icons.pending_actions_rounded,
                    'Pending',
                    '${data.totalPending}',
                    Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(Icons.check_circle_rounded, 'Disetujui',
                    '${data.totalApproved}', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(Icons.cancel_rounded, 'Ditolak',
                    '${data.totalRejected}', Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==================== PENDING SECTION ====================
  Widget _buildPendingSection(ManagerDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.purple.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pending_actions,
                        color: Color(0xFF7B1FA2), size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('Menunggu Persetujuan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${data.totalPending} pending',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7B1FA2),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.pendingList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 40, color: Colors.green),
                    SizedBox(height: 8),
                    Text('Tidak ada pengajuan pending',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...data.pendingList.take(5).map((lembur) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF7B1FA2).withAlpha(51)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B1FA2).withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.work_history,
                            color: Color(0xFF7B1FA2), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lembur['pengawas_nama'] ??
                                  lembur['nama_pengawas'] ??
                                  'Unknown',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(lembur['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam - ${lembur['alasan'] ?? '-'}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _service.getTimeAgo(lembur['created_at']),
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _approveLembur(lembur),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.check,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _rejectLembur(lembur),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          if (data.pendingList.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/approval-lembur'),
                  child: Text('Lihat ${data.pendingList.length - 5} lainnya...'),
                ),
              ),
            ),
        ],
      ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  // ==================== LOGOUT DIALOG & PROCESS ====================
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.logout_rounded, size: 48, color: Colors.red),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?',
            textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  const CircularProgressIndicator(color: Color(0xFF7B1FA2)),
                  const SizedBox(height: 16),
                  Text('Sedang logout...',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      );

      _heartbeatTimer?.cancel();
      await _service.logout();

      if (mounted) {
        final provider = context.read<ManagerProvider>();
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

// ==================== HELPER CLASS ====================
class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
  });
}