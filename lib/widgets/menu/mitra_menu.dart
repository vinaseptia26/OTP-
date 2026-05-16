// lib/features/mitra/widgets/mitra_menu.dart
import 'package:flutter/material.dart';
import '../../../core/services/mitra_service.dart';

class MitraMenu extends StatelessWidget {
  final MitraDashboardData data;
  final MitraService service;

  const MitraMenu({super.key, required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    final menus = [
      {'icon': Icons.calendar_month, 'title': 'Jadwal', 'route': '/jadwal-lembur-menu'},
      {'icon': Icons.history, 'title': 'Riwayat Lembur', 'route': '/overtime-data'},
      {'icon': Icons.fingerprint, 'title': 'Riwayat Absensi', 'route': '/riwayat-absensi'},
      {'icon': Icons.receipt, 'title': 'Pendapatan', 'route': '/income'},
      {'icon': Icons.person, 'title': 'Profil', 'route': '/profile'},
      {'icon': Icons.help, 'title': 'Bantuan', 'route': '/help'},
    ];

    final colors = const [
      Color(0xFF1A2B4C), Color(0xFF4158D0), Color(0xFFFF6B35),
      Color(0xFF2E7D32), Color(0xFF834d9b), Color(0xFFE91E63),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final m = menus[index];
        final color = colors[index % colors.length];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, m['route'] as String),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withAlpha(180)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(m['icon'] as IconData, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(m['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      },
    );
  }
}