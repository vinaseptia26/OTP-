// lib/features/superadmin/widgets/admin_menu.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/superadmin_service.dart';

class AdminMenu extends StatelessWidget {
  final DashboardData data;
  final DashboardService service;

  const AdminMenu({
    super.key,
    required this.data,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final crossAxisCount =
        width >= 1200
            ? 5
            : width >= 900
                ? 4
                : width >= 600
                    ? 4
                    : 3;

    final childAspectRatio =
        width < 360
            ? 0.82
            : width < 430
                ? 0.88
                : 0.95;

    final menuItems = [
      // 🔥 =============== MENU #1: MASTER DATA PEKERJA ===============
      _MenuItem(
        title: 'Master Data\nPekerja',
        icon: Icons.badge_rounded,
        count: data.totalWorkers ?? 0,
        countColor: const Color(0xFF1B5E20),
        route: '/superadmin/master-pekerja',
        color: const Color(0xFF2E7D32),
      ),
      // ================================================================

      _MenuItem(
        title: 'Persetujuan\nLembur',
        icon: Icons.approval_rounded,
        count: data.pendingApprovals,
        countColor: const Color(0xFFFF3B30),
        route: '/admin/approval',
        color: const Color(0xFF00B4D8),
      ),
      _MenuItem(
        title: 'Riwayat\nLembur',
        icon: Icons.work_history_rounded,
        count: data.pendingApprovals,
        countColor: const Color(0xFFE65100),
        route: '/overtime-data',
        color: const Color(0xFFFF6B35),
      ),
      _MenuItem(
        title: 'Riwayat\nAbsensi',
        icon: Icons.fact_check_rounded,
        count: 0,
        countColor: const Color(0xFF1565C0),
        route: '/riwayat-absensi',
        color: const Color(0xFF4A90D9),
      ),
      _MenuItem(
        title: 'Monitoring\nLokasi',
        icon: Icons.location_on_rounded,
        count: 0,
        countColor: const Color(0xFFD32F2F),
        route: '/location-monitoring',
        color: const Color(0xFFE74C3C),
      ),
      _MenuItem(
        title: 'Laporan',
        icon: Icons.assessment_rounded,
        count: data.recentActivities.length,
        countColor: const Color(0xFF6A1B9A),
        route: '/reports',
        color: const Color(0xFF7C3AED),
      ),
      _MenuItem(
        title: 'Jadwal\nLembur',
        icon: Icons.schedule_rounded,
        count: 0,
        countColor: const Color(0xFF4A148C),
        route: '/jadwal-lembur',
        color: const Color(0xFF9B59B6),
      ),
      _MenuItem(
        title: 'FAQ',
        icon: Icons.help_center_rounded,
        count: 0,
        countColor: const Color(0xFF37474F),
        route: '/faq',
        color: const Color(0xFF5C6BC0),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: menuItems.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final item = menuItems[index];

        return _AnimatedMenuCard(
          item: item,
          onTap: () => _navigateTo(
            context,
            item.title,
            item.route,
          ),
        );
      },
    );
  }

  void _navigateTo(
    BuildContext context,
    String menu,
    String route,
  ) {
    try {
      context.push(route);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka $menu...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }
}

class _AnimatedMenuCard extends StatefulWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _AnimatedMenuCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_AnimatedMenuCard> createState() =>
      _AnimatedMenuCardState();
}

class _AnimatedMenuCardState
    extends State<_AnimatedMenuCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.95),
                item.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -15,
                bottom: -20,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item.icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      if (item.count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: item.countColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: item.countColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            item.count > 99 ? '99+' : '${item.count}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Open Menu',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final int count;
  final Color countColor;
  final String route;
  final Color color;

  _MenuItem({
    required this.title,
    required this.icon,
    required this.count,
    required this.countColor,
    required this.route,
    required this.color,
  });
}