// lib/features/pengawas/widgets/pengawas_menu.dart
import 'package:flutter/material.dart';
import '../../core/services/pengawas_service.dart';

class PengawasMenu extends StatelessWidget {
  final PengawasDashboardData data;
  final PengawasService service;

  const PengawasMenu({super.key, required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'title': 'Ajukan Lembur',
        'icon': Icons.add_alert,
        'count': 0,
        'countColor': Colors.orange,
        'route': '/ajukan-lembur'
      },
      {
        'title': 'Riwayat',
        'icon': Icons.history,
        'count': data.recentList.length,
        'countColor': Colors.blue,
        'route': '/overtime-data'
      },
      {
        'title': 'Tim Saya',
        'icon': Icons.people,
        'count': data.totalTeamMembers,
        'countColor': Colors.green,
        'route': '/my-team'
      },
      {
        'title': 'Monitoring',
        'icon': Icons.location_on,
        'count': data.onlineMembers,
        'countColor': Colors.teal,
        'route': '/location-monitoring'
      },
      {
        'title': 'Laporan',
        'icon': Icons.assessment,
        'route': '/reports'
      },
      {
        'title': 'Pengaturan',
        'icon': Icons.settings,
        'route': '/settings'
      },
    ];

    final colors = const [
      Color(0xFF448AFF), Color(0xFF7C4DFF),
      Color(0xFF69F0AE), Color(0xFF18FFFF),
      Color(0xFFFFAB40), Color(0xFFFF80AB),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final color = colors[index % colors.length];
        final count = item['count'] as int? ?? 0;
        final countColor = item['countColor'] as Color? ?? Colors.red;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, item['route'] as String),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withAlpha(230), color]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withAlpha(77), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(51), shape: BoxShape.circle),
                        child: Icon(item['icon'] as IconData, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(item['title'] as String, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: countColor, borderRadius: BorderRadius.circular(12)),
                      child: Text(count > 99 ? '99+' : '$count',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}