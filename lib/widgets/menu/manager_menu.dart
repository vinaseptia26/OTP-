// lib/features/manager/widgets/manager_menu.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // 🔥 Tambahkan import GoRouter
import '../../core/services/manager_service.dart';


class ManagerMenu extends StatelessWidget {
  final ManagerDashboardData data;
  final ManagerService service;

  const ManagerMenu({super.key, required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'title': 'Riwayat Lembur',
        'icon': Icons.history,
        'count': data.totalApproved + data.totalRejected,
        'countColor': Colors.blue,
        'route': '/overtime-data'
      },
      {
        'title': 'Tim Saya',
        'icon': Icons.people,
        'count': data.totalTeamMembers,
        'countColor': Colors.purple,
        'route': '/my-team'
      },
      {
        'title': 'Monitoring Lokasi',
        'icon': Icons.location_on,
        'count': data.onlineMembers,
        'countColor': Colors.teal,
        'route': '/location-monitoring'
      },
      {
        'title': 'Laporan',
        'icon': Icons.assessment_rounded,
        'count': data.recentActivities.length,
        'route': '/reports-audit',
      },
       {
        'title': 'FAQ',
        'icon': Icons.help_center,
        'count': data.recentActivities.length,
        'route': '/faq'
      },
    ];

    final colors = const [
      Color(0xFFFF6B35),  // Orange
      Color(0xFF2196F3),  // Blue
      Color(0xFF4CAF50),  // Green
      Color(0xFF9C27B0),  // Purple
      Color(0xFF00BCD4),  // Cyan
      Color(0xFF607D8B),  // Blue Grey
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final color = colors[index % colors.length];

        // Ambil count dengan aman
        final count = item['count'] as int? ?? 0;
        final countColor = item['countColor'] as Color? ?? Colors.red;

        return GestureDetector(
          onTap: () {
            // Navigasi ke route
            final route = item['route'] as String?;
            if (route != null) {
              _navigateTo(context, item['title'] as String, route);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(230), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(77),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Menu content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          item['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge count (hanya jika count > 0)
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: countColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navigasi ke halaman sesuai menu
  void _navigateTo(BuildContext context, String menu, String route) {
    // 🔥 Ganti Navigator.pushNamed dengan context.push (GoRouter)
    try {
      context.push(route);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka $menu...'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}