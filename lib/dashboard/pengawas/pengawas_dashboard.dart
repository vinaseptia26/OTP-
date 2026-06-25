// lib/dashboard/pengawas/pengawas_dashboard.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/pengawas_service.dart';
import '../../core/services/auth_service.dart';
import '/widgets/pengawas/pengawas_stats_grid.dart';
import '/widgets/team_summary.dart';
import '/widgets/menu/pengawas_menu.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';
import '/widgets/pengawas/analytics_section.dart';

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() => _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ChangeNotifierProvider(
      create: (_) => PengawasProvider(),
      child: _PengawasBody(
        user: user,
        currentIndex: _currentIndex,
      ),
    );
  }
}

class _PengawasBody extends StatefulWidget {
  final User? user;
  final int currentIndex;

  const _PengawasBody({
    required this.user,
    required this.currentIndex,
  });

  @override
  State<_PengawasBody> createState() => _PengawasBodyState();
}

class _PengawasBodyState extends State<_PengawasBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = PengawasService();
  final _authService = AuthService();
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
  Timer? _snackbarTimer;

  // ==================== COLOR CONSTANTS ====================
  static const Color primaryBlue = Color(0xFF448AFF);
  static const Color darkBlue = Color(0xFF1E3C72);
  static const Color mediumBlue = Color(0xFF2A5298);
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color textDark = Color(0xFF1A2332);
  static const Color textMedium = Color(0xFF475569);
  static const Color accentOrange = Color(0xFFFFAB40);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentRed = Color(0xFFE53935);
  static const Color dividerGrey = Color(0xFFE2E8F0);

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
          _greeting =
              '${_service.getGreeting()}, ${widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? 'Pengawas'}! 👋';
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
    _snackbarTimer?.cancel();
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
        _showAutoHideSnackBar('✅ Data berhasil diperbarui', success: true);
      }
    } catch (e) {
      if (mounted) {
        _showAutoHideSnackBar('❌ Gagal memperbarui data', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showAutoHideSnackBar(String message, {bool success = true}) {
    if (!mounted) return;

    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
            success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).size.height * 0.12,
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    _snackbarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PengawasProvider>();

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar:
            PengawasBottomNav(currentIndex: widget.currentIndex),
        body: _buildLoadingScreen(provider.errorMessage),
      );
    }

    if (provider.data == null) {
      return Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar:
            PengawasBottomNav(currentIndex: widget.currentIndex),
        body: _buildErrorScreen(provider.errorMessage),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar:
          PengawasBottomNav(currentIndex: widget.currentIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryBlue,
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 10,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildContentSliver(data),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(data),
    );
  }

  // ==================== LOADING SCREEN ====================
  Widget _buildLoadingScreen(String? errorMessage) {
    return Stack(
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
                      width: 100,
                      height: 100,
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
                        size: 50,
                        color: primaryBlue,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'PENGAWAS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3C72),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'DASHBOARD',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF1E3C72).withAlpha(204),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingMessage != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3C72).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _loadingMessage!,
                    style: const TextStyle(
                        color: Color(0xFF1E3C72), fontSize: 12),
                  ),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3C72).withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 40,
                  color: Color(0xFF1E3C72),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3C72),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage ??
                    'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  final provider = context.read<PengawasProvider>();
                  provider.clearCache();
                  provider.loadData();
                  _loadGreetingAndProfile();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label:
                    const Text('Coba Lagi', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== FLOATING ACTION BUTTON ====================
  Widget? _buildFloatingActionButton(PengawasDashboardData data) {
    if (data.isCheckedIn) {
      return FloatingActionButton.extended(
        onPressed: () async {
          if (data.activeLembur?['check_in'] != null) {
            final checkIn =
                (data.activeLembur!['check_in'] as Timestamp).toDate();
            final totalJam =
                DateTime.now().difference(checkIn).inHours.toDouble();
            await _service.checkOut(data.activeLembur!['id'], totalJam);
            if (mounted) {
              context.read<PengawasProvider>().loadData();
              _showAutoHideSnackBar(
                  '✅ Check-out berhasil! Total: ${totalJam.toStringAsFixed(1)} jam');
            }
          }
        },
        backgroundColor: accentRed,
        icon: const Icon(Icons.logout),
        label: const Text('Check-out'),
      );
    }
    return null;
  }

  // ==================== CONTENT SLIVER ====================
  Widget _buildContentSliver(PengawasDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // SECTION 1: WELCOME CARD
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildWelcomeCard(),
          ),
          const SizedBox(height: 16),

          // SECTION 2: STATS GRID
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_fadeAnimation),
            child: PengawasStatsGrid(data: data),
          ),

          const SizedBox(height: 14),

          // SECTION 4: ANALYTICS
          _buildCorporateDivider('ANALYTICS'),
          const SizedBox(height: 14),
          _buildSectionHeader(
            icon: Icons.analytics_rounded,
            title: 'Analisis Lembur Mingguan',
            iconColor: primaryBlue,
          ),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: _fadeAnimation,
            child: AnalyticsSection(data: data),
          ),

          const SizedBox(height: 20),

          // SECTION 5: QUICK ACTION
          _buildCorporateDivider('MENU UTAMA'),
          const SizedBox(height: 14),
          _buildSectionHeader(
            icon: Icons.bolt_rounded,
            title: 'Menu Utama',
            iconColor: accentOrange,
          ),
          const SizedBox(height: 10),
          PengawasMenu(
            data: data,
            service: _service,
          ),

          const SizedBox(height: 18),

          // SECTION 6: TEAM SUMMARY
          _buildCorporateDivider('TEAM'),
          const SizedBox(height: 14),
          _buildSectionHeader(
            icon: Icons.group_rounded,
            title: 'Ringkasan Tim',
            iconColor: accentGreen,
          ),
          const SizedBox(height: 10),
          TeamSummary(
            teamMembers: data.teamMembers,
            totalMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            getRoleColor: (role) => _service.getRoleColor(role),
          ),

          const SizedBox(height: 18),
        ]),
      ),
    );
  }

  // ==================== SECTION HELPER WIDGETS ====================
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textDark,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ==================== WELCOME CARD ====================
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [darkBlue, mediumBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withAlpha(100),
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
              // Avatar
              Container(
                width: 48,
                height: 48,
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
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage: _userPhotoUrl != null &&
                          _userPhotoUrl!.isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                      ? Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Greeting & Motivation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _motivation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(204),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Notification Icon
              GestureDetector(
                onTap: _showNotifications,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role and Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Role: ${_userRole.isNotEmpty ? _userRole.toUpperCase() : 'PENGAWAS'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 14, color: Colors.white30),
                const SizedBox(width: 10),
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(
                  _formatDate(DateTime.now()),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SUMMARY ITEM ====================
  Widget _buildSummaryItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== CORPORATE DIVIDER ====================
  Widget _buildCorporateDivider(String title) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: dividerGrey),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: dividerGrey),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textMedium,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: dividerGrey),
        ),
      ],
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

  // ==================== NOTIFICATIONS ====================
  Future<void> _showNotifications() async {
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.notifications,
                          color: primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Notifikasi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (notifs.any((n) => n['isRead'] == false))
                        TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) {
                              context.read<PengawasProvider>().loadData();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showAutoHideSnackBar(
                                '✅ Semua notifikasi telah dibaca');
                          },
                          icon: const Icon(Icons.done_all, size: 15),
                          label: const Text('Tandai Semua',
                              style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 50, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text(
                                  'Tidak ada notifikasi',
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 13),
                                ),
                              ],
                            ),
                          )
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
                                  color: isRead
                                      ? Colors.white
                                      : primaryBlue.withAlpha(13),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isRead
                                        ? Colors.grey[200]!
                                        : primaryBlue.withAlpha(51),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: (isRead
                                                ? Colors.grey
                                                : primaryBlue)
                                            .withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications,
                                        size: 14,
                                        color:
                                            isRead ? Colors.grey : primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
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
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            n['body'] ?? '',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600]),
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _service.getTimeAgo(
                                                n['createdAt']),
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: primaryBlue,
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