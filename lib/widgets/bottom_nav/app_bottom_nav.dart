import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import semua bottom nav widget kamu
import '/widgets/bottom_nav/manager_bottom_nav.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';
import '/widgets/bottom_nav/superadmin_bottom_nav.dart';

class AppBottomNav extends StatelessWidget {
  final String userRole;
  final int currentIndex;
  
  const AppBottomNav({
    super.key,
    required this.userRole,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 Pilih bottom nav sesuai role
    switch (userRole.toLowerCase()) {
      case 'manager':
        return ManagerBottomNav(currentIndex: currentIndex);
      
      case 'mitra':
        return MitraBottomNav(currentIndex: currentIndex);
      
      case 'pengawas':
        return PengawasBottomNav(currentIndex: currentIndex);
      
      case 'superadmin':
        return SuperAdminBottomNav(currentIndex: currentIndex);
      
      default:
        // Fallback kalo role nggak dikenal
        return const SizedBox.shrink();
    }
  }
}