// lib/features/pengawas/widgets/pengawas_menu.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/pengawas_service.dart';

class PengawasMenu extends StatelessWidget {
  final PengawasDashboardData data;
  final PengawasService service;

  const PengawasMenu({super.key, required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _MenuItem(
        title: 'Riwayat\nLembur',
        icon: Icons.history_rounded,
        count: data.recentList.length,
        countColor: const Color(0xFF818CF8),
        route: '/overtime-data',
        gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        iconBgColor: const Color(0xFF6366F1).withAlpha(40),
      ),
      _MenuItem(
        title: 'Tim\nSaya',
        icon: Icons.people_alt_rounded,
        count: data.totalTeamMembers,
        countColor: const Color(0xFF34D399),
        route: '/my-team',
        gradient: const [Color(0xFF059669), Color(0xFF00B4D8)],
        iconBgColor: const Color(0xFF10B981).withAlpha(40),
      ),
      _MenuItem(
        title: 'Monitoring\nLokasi',
        icon: Icons.location_on_rounded,
        count: data.onlineMembers,
        countColor: const Color(0xFFFB923C),
        route: '/location-monitoring',
        gradient: const [Color(0xFFEA580C), Color(0xFFD946EF)],
        iconBgColor: const Color(0xFFF97316).withAlpha(40),
      ),
      _MenuItem(
        title: 'Laporan\nAktif',
        icon: Icons.assessment_rounded,
        count: 0,
        countColor: const Color(0xFFFB7185),
        route: '/reports',
        gradient: const [Color(0xFFBE123C), Color(0xFFE11D48)],
        iconBgColor: const Color(0xFFF43F5E).withAlpha(40),
      ),
      _MenuItem(
        title: 'Bantuan\n& FAQ',
        icon: Icons.support_agent_rounded,
        count: 0,
        countColor: const Color(0xFF7DD3FC),
        route: '/faq',
        gradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
        iconBgColor: const Color(0xFF0EA5E9).withAlpha(40),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return _buildMenuCard(context, item, index);
        },
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(item.route),
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withAlpha(40),
          highlightColor: Colors.white.withAlpha(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: item.gradient[0].withAlpha(77),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: item.gradient[1].withAlpha(51),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(30),
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                // Background decorative circles
                Positioned(
                  top: -25,
                  right: -25,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -15,
                  left: -15,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(5),
                    ),
                  ),
                ),

                // Glassmorphism overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha(15),
                          Colors.transparent,
                          Colors.black.withAlpha(10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

                // Content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Container with glass effect
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withAlpha(50),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            color: Colors.white,
                            size: 26,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title with enhanced styling
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Badge Count with pulse animation for active counts
                if (item.count > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _AnimatedBadge(
                      count: item.count,
                      color: item.countColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Badge Widget
class _AnimatedBadge extends StatefulWidget {
  final int count;
  final Color color;

  const _AnimatedBadge({
    required this.count,
    required this.color,
  });

  @override
  State<_AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<_AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(80),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(150),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.white.withAlpha(40),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Text(
              widget.count > 99 ? '99+' : '${widget.count}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Enhanced Menu Item Model
class _MenuItem {
  final String title;
  final IconData icon;
  final int count;
  final Color countColor;
  final String route;
  final List<Color> gradient;
  final Color iconBgColor;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.count,
    required this.countColor,
    required this.route,
    required this.gradient,
    required this.iconBgColor,
  });
}