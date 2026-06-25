import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '/core/app_colors.dart';
import '../../core/services/superadmin_service.dart';

import '../../widgets/superadmin/stats_grid.dart';
import '../../widgets/superadmin/analytics_section.dart';
import '../../widgets/superadmin/user_distribution.dart';
import '../../widgets/superadmin/quick_actions.dart';
import '../../widgets/menu/superadmin_menu.dart';
import '../../widgets/superadmin/location_monitoring.dart';
import '../../widgets/superadmin/recent_activities.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';

// 🔥 =============== MASTER DATA PEKERJA IMPORT ===============
import '../superadmin/master_pekerja_screen.dart'; // Jika ada
// ============================================================

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() =>
      _SuperAdminDashboardState();
}

class _SuperAdminDashboardState
    extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: _DashboardBody(
        user: user,
        currentIndex: _currentIndex,
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  final User? user;
  final int currentIndex;

  const _DashboardBody({
    required this.user,
    required this.currentIndex,
  });

  @override
  State<_DashboardBody> createState() =>
      _DashboardBodyState();
}

class _DashboardBodyState
    extends State<_DashboardBody>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver {
  final _service = DashboardService();

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

  Timer? _heartbeatTimer;

  static const double sectionGap = 18;

  String _getCorporateGreetingMessage() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return 'Semoga aktivitas operasional dan persetujuan lembur hari ini berjalan optimal dan produktif.';
    } else if (hour >= 11 && hour < 15) {
      return 'Pantau aktivitas sistem dan kelola persetujuan lembur secara real-time dengan efisien.';
    } else if (hour >= 15 && hour < 18) {
      return 'Pastikan seluruh proses operasional tetap stabil hingga akhir jam kerja.';
    } else {
      return 'Monitoring aktivitas lembur dan performa sistem tetap terkendali dengan baik.';
    }
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
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
      _loadData(),
    ]);

    _startHeartbeat();
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final results = await Future.wait([
        _service.getGreetingWithNameAndEmoji(),
        _service.getCurrentUserProfile(),
      ]);

      final greeting = results[0] as String;

      final profile =
          results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _greeting = greeting;
          _isGreetingLoading = false;

          if (profile != null) {
            _userName =
                profile['nama_lengkap']
                        ?.toString() ??
                    '';

            _userRole =
                profile['role']
                        ?.toString() ??
                    '';

            _userPhotoUrl =
                profile['photo_url']
                    ?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting =
              '${_service.getGreeting()}, ${widget.user?.displayName ?? 'Admin'} 👋';

          _isGreetingLoading = false;
        });
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _service.updateHeartbeat();
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingMessage =
          'Memuat dashboard...';
    });

    final provider =
        context.read<DashboardProvider>();

    await provider.loadData();

    if (mounted) {
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

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.updateHeartbeat();
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final provider =
          context.read<DashboardProvider>();

      provider.clearCache();

      await Future.wait([
        provider.loadData(),
        _loadGreetingAndProfile(),
      ]);

      _fadeController.reset();
      _fadeController.forward();

      if (mounted) {
        _showSnackBar(
          'Dashboard berhasil diperbarui',
          success: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Gagal memperbarui dashboard',
          success: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool success = true,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,

          margin: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.1,
          ),

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),

          backgroundColor: success
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),

          content: Row(
            children: [
              Icon(
                success
                    ? Icons
                        .check_circle_rounded
                    : Icons.error_rounded,
                color: Colors.white,
                size: 18,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<DashboardProvider>();

    final width =
        MediaQuery.of(context).size.width;

    final useHorizontalLayout =
        width >= 850;

    if (provider.isLoading ||
        _isGreetingLoading) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF5F7FB),

        bottomNavigationBar:
            SuperAdminBottomNav(
          currentIndex:
              widget.currentIndex,
        ),

        body: _buildLoadingScreen(),
      );
    }

    if (provider.data == null) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF5F7FB),

        bottomNavigationBar:
            SuperAdminBottomNav(
          currentIndex:
              widget.currentIndex,
        ),

        body: _buildErrorScreen(
          provider.errorMessage,
        ),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FB),

      bottomNavigationBar:
          SuperAdminBottomNav(
        currentIndex:
            widget.currentIndex,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryBlue,
          backgroundColor: Colors.white,
          strokeWidth: 3,

          child: CustomScrollView(
            controller:
                _scrollController,

            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,

            physics:
                const BouncingScrollPhysics(),

            slivers: [
              _buildContent(
                data,
                useHorizontalLayout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    DashboardData data,
    bool useHorizontalLayout,
  ) {
    return SliverPadding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        100,
      ),

      sliver: SliverList(
        delegate:
            SliverChildListDelegate(
          [
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildHeaderCard(),
            ),

            const SizedBox(
                height: sectionGap),

            SlideTransition(
              position:
                  Tween<Offset>(
                begin:
                    const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(_fadeAnimation),

              child: const StatsGrid(),
            ),

            const SizedBox(
                height: sectionGap),

            // 🔥 =============== MASTER DATA PEKERJA QUICK STATS ===============
            // Stats ringkas sebelum analytics
            _buildMasterDataQuickStats(data),
            
            const SizedBox(
                height: sectionGap),
            // ================================================================

            AnalyticsSection(data: data),

            const SizedBox(
                height: sectionGap),

            if (useHorizontalLayout)
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Expanded(
                    flex: 6,
                    child:
                        UserDistribution(
                      distribution: data
                          .roleDistribution,

                      verifiedUsers:
                          data
                              .verifiedUsers,

                      lockedAccounts:
                          data
                              .lockedAccounts,

                      activeToday:
                          data.activeToday,

                      getRoleColor:
                          _service
                              .getRoleColor,
                    ),
                  ),

                  const SizedBox(
                      width: 16),

                  const Expanded(
                    flex: 4,
                    child:
                        QuickActions(),
                  ),
                ],
              )
            else ...[
              UserDistribution(
                distribution:
                    data.roleDistribution,

                verifiedUsers:
                    data.verifiedUsers,

                lockedAccounts:
                    data.lockedAccounts,

                activeToday:
                    data.activeToday,

                getRoleColor:
                    _service.getRoleColor,
              ),

              const SizedBox(
                  height: sectionGap),

              const QuickActions(),
            ],

            const SizedBox(
                height: sectionGap),

            AdminMenu(
              data: data,
              service: _service,
            ),

            const SizedBox(
                height: sectionGap),

            LocationMonitoring(
              service: _service,
            ),

            const SizedBox(
                height: sectionGap),

            RecentActivities(
              activities:
                  data.recentActivities,
              service: _service,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 🔥 =============== MASTER DATA QUICK STATS WIDGET ===============
  Widget _buildMasterDataQuickStats(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E7D32).withAlpha(230),
            const Color(0xFF1B5E20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Master Data Pekerja',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // 🔥 Quick action button
              GestureDetector(
                onTap: () => context.push('/superadmin/master-pekerja'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kelola',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              // Total Workers
              Expanded(
                child: _buildMasterDataStatItem(
                  icon: Icons.people_rounded,
                  label: 'Total Pekerja',
                  value: '${data.totalWorkers}',
                  valueColor: Colors.white,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              // Active Workers
              Expanded(
                child: _buildMasterDataStatItem(
                  icon: Icons.check_circle_rounded,
                  label: 'Aktif',
                  value: '${data.activeWorkers}',
                  valueColor: const Color(0xFFA5D6A7),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              // By Fungsi
              Expanded(
                child: _buildMasterDataStatItem(
                  icon: Icons.work_rounded,
                  label: 'Fungsi',
                  value: '${data.workerFungsiCount}',
                  valueColor: const Color(0xFFFFF9C4),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
        ],
      ),
    );
  }

  Widget _buildMasterDataStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  // ================================================================

  // =========================
  // HEADER CARD
  // =========================

  Widget _buildHeaderCard() {
    final width =
        MediaQuery.of(context).size.width;

    final avatarSize =
        width < 360 ? 46.0 : 52.0;

    return Container(
      padding: EdgeInsets.all(
        width < 360 ? 14 : 18,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),

        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB)
                .withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withAlpha(
                  18,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 100,
              height: 100,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withAlpha(
                  10,
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder:
                    (context, constraints) {
                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Hero(
                        tag: 'admin-avatar',

                        child: Container(
                          width: avatarSize,
                          height: avatarSize,

                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            border: Border.all(
                              color:
                                  Colors.white,
                              width: 2.5,
                            ),
                          ),

                          child: CircleAvatar(
                            backgroundColor:
                                Colors.white,

                            backgroundImage:
                                (_userPhotoUrl !=
                                            null &&
                                        _userPhotoUrl!
                                            .isNotEmpty)
                                    ? NetworkImage(
                                        _userPhotoUrl!,
                                      )
                                    : null,

                            child:
                                (_userPhotoUrl ==
                                            null ||
                                        _userPhotoUrl!
                                            .isEmpty)
                                    ? Text(
                                        _userName
                                                .isNotEmpty
                                            ? _userName[
                                                    0]
                                                .toUpperCase()
                                            : 'A',

                                        style:
                                            TextStyle(
                                          color:
                                              const Color(
                                            0xFF1E3A8A,
                                          ),
                                          fontSize:
                                              width <
                                                      360
                                                  ? 18
                                                  : 20,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                      ),

                      const Spacer(),

                      Flexible(
                        child: Align(
                          alignment:
                              Alignment
                                  .topRight,

                          child:
                              AnimatedContainer(
                            duration:
                                const Duration(
                              milliseconds:
                                  300,
                            ),

                            padding:
                                const EdgeInsets
                                    .all(12),

                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .white
                                  .withAlpha(
                                      30),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),

                            child:
                                _isRefreshing
                                    ? const SizedBox(
                                        width:
                                            18,
                                        height:
                                            18,

                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap:
                                            _refreshData,

                                        child:
                                            const Icon(
                                          Icons
                                              .refresh_rounded,
                                          color:
                                              Colors.white,
                                          size:
                                              22,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              SizedBox(
                  height:
                      width < 360 ? 14 : 18),

              Text(
                _greeting,

                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,

                style: TextStyle(
                  fontSize:
                      width < 360 ? 18 : 22,

                  fontWeight:
                      FontWeight.bold,

                  color: Colors.white,

                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _userName.isNotEmpty
                    ? _userName
                    : 'Super Administrator',

                style: TextStyle(
                  fontSize:
                      width < 360 ? 12 : 13,

                  color:
                      Colors.white.withAlpha(
                    220,
                  ),

                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _getCorporateGreetingMessage(),

                maxLines: 3,

                overflow:
                    TextOverflow.ellipsis,

                style: TextStyle(
                  fontSize:
                      width < 360
                          ? 11
                          : 12.5,

                  height: 1.5,

                  color:
                      Colors.white.withAlpha(
                    210,
                  ),

                  fontWeight:
                      FontWeight.w400,
                ),
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeaderBadge(
                    icon: Icons
                        .admin_panel_settings,

                    label:
                        _userRole.isNotEmpty
                            ? _userRole
                                .toUpperCase()
                            : 'SUPERADMIN',
                  ),

                  _buildHeaderBadge(
                    icon:
                        Icons.verified_rounded,
                    label: 'ACTIVE',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color:
            Colors.white.withAlpha(28),

        borderRadius:
            BorderRadius.circular(30),

        border: Border.all(
          color: Colors.white24,
        ),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 13,
          ),

          const SizedBox(width: 6),

          Text(
            label,

            style: const TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // LOADING SCREEN
  // =========================

  Widget _buildLoadingScreen() {
    final size =
        MediaQuery.of(context).size.width <
                360
            ? 72.0
            : 90.0;

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: size,
            height: size,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF1E3A8A),
                  Color(0xFF2563EB),
                ],
              ),

              boxShadow: [
                BoxShadow(
                  color: const Color(
                          0xFF2563EB)
                      .withAlpha(70),

                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),

            child: Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: size * 0.45,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'SUPER ADMIN',

            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color: Color(0xFF1E3A8A),
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Loading Dashboard...',

            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(
            width: 24,
            height: 24,

            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
            ),
          ),

          if (_loadingMessage != null) ...[
            const SizedBox(height: 14),

            Text(
              _loadingMessage!,

              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // =========================
  // ERROR SCREEN
  // =========================

  Widget _buildErrorScreen(
      String? errorMessage) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Container(
                width: 90,
                height: 90,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: const Color(
                          0xFF2563EB)
                      .withAlpha(20),
                ),

                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 42,
                  color: Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Gagal Memuat Dashboard',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                errorMessage ??
                    'Terjadi kesalahan saat memuat data.',

                textAlign: TextAlign.center,

                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: () {
                  context
                      .read<DashboardProvider>()
                      .clearCache();

                  context
                      .read<DashboardProvider>()
                      .loadData();

                  _loadGreetingAndProfile();
                },

                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),

                label: const Text(
                  'Muat Ulang',
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF1E3A8A,
                  ),

                  foregroundColor:
                      Colors.white,

                  minimumSize:
                      const Size(
                    double.infinity,
                    52,
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// PROVIDER
// =========================

class DashboardProvider
    extends ChangeNotifier {
  final _service = DashboardService();

  bool isLoading = true;

  DashboardData? data;

  String? errorMessage;

  Future<void> loadData() async {
    isLoading = true;

    errorMessage = null;

    notifyListeners();

    try {
      data =
          await _service.loadDashboardData();
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;

    notifyListeners();
  }

  void clearCache() {
    _service.clearCache();
    data = null;
  }
}