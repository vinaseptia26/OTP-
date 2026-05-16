// lib/features/superadmin/widgets/admin_menu.dart
import 'package:flutter/material.dart';
import '../../core/services/superadmin_service.dart';

class AdminMenu extends StatelessWidget {
  final DashboardData data;
  final DashboardService service;

  const AdminMenu({super.key, required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'title': 'User Management',
        'icon': Icons.people,
        'count': data.totalUsers,
        'route': '/user-management'
      },
      // ✅ TAMBAHAN: Menu Approval Lembur untuk Admin
      {
        'title': 'Approval Lembur',
        'icon': Icons.approval,
        'count': data.pendingApprovals,
        'countColor': Colors.red,
        'route': '/admin/approval'
      },
      {
        'title': 'Riwayat Lembur',
        'icon': Icons.work_history,
        'count': data.pendingApprovals,
        'countColor': Colors.orange,
        'route': '/overtime-data'
      },
      {
        'title': 'Riwayat Absensi',
        'icon': Icons.checklist,
        'count': 0,
        'route': '/riwayat-absensi'
      },
      {
        'title': 'Monitoring Lokasi',
        'icon': Icons.location_on,
        'count': 0,
        'route': '/location-monitoring'
      },
      {
        'title': 'Laporan',
        'icon': Icons.assessment,
        'count': data.recentActivities.length,
        'route': '/reports-audit'
      },
      {
        'title': 'Logs',
        'icon': Icons.list_alt,
        'count': data.recentActivities.length,
        'route': '/system-logs'
      },
      {
        'title': 'Settings',
        'icon': Icons.settings,
        'route': '/settings'
      },
      {
        'title': 'Jadwal Shift',
        'icon': Icons.schedule,
        'route': '/jadwal-shift'
      },
      {
        'title': 'FAQ',
        'icon': Icons.help_center,
        'count': data.recentActivities.length,
        'route': '/faq'
      },
    ];

    final colors = const [
      Color(0xFF1E3C72),  // User Management
      Color(0xFF00b09b),  // ✅ Approval Lembur (hijau teal)
      Color(0xFFFF6B35),  // Data Lembur
      Color(0xFF2196F3),  // Data Absensi
      Color(0xFFf12711),  // Monitoring Lokasi
      Color(0xFF834d9b),  // Laporan
      Color(0xFF4CAF50),  // Logs
      Color(0xFFFF9800),  // Settings
      Color(0xFF9C27B0),  // Jadwal Shift
      Color(0xFF607D8B),  // FAQ
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
                colors: [color.withValues(alpha: 0.9), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
    // Cek apakah route terdaftar
    try {
      Navigator.pushNamed(context, route);
    } catch (e) {
      // Fallback: tampilkan snackbar
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