// screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';

// Dashboards – USE MAIN DASHBOARD (role + subrole)
import '../dashboard/superadmin/superadmin_dashboard.dart';
import '../dashboard/manager/manager_dashboard.dart';
import '../dashboard/pengawas/pengawas_dashboard.dart';
import '../dashboard/mitra/mitra_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), _checkLogin);
  }

  // ============================================================
  //            CHECK FIREBASE LOGIN + REDIRECT DASHBOARD
  // ============================================================

  Future<void> _checkLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _navigate(const WelcomeScreen());
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        FirebaseAuth.instance.signOut();
        _navigate(const LoginScreen());
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      final role = (data["role"] ?? "").toLowerCase();
      final subRole = (data["sub_role"] ?? "").toLowerCase();
      final statusAkun = (data["status_akun"] ?? "").toLowerCase();

      // Jika belum diverifikasi admin
      if (statusAkun != "verified") {
        FirebaseAuth.instance.signOut();
        _navigate(const LoginScreen());
        return;
      }

      final dashboard = _dashboardFor(role, subRole);

      if (dashboard == null) {
        _navigate(const WelcomeScreen());
        return;
      }

      _navigate(dashboard);
    } catch (e) {
      FirebaseAuth.instance.signOut();
      _navigate(const LoginScreen());
    }
  }

  // ============================================================
  //                  PEMILIHAN DASHBOARD
  // ============================================================

  Widget? _dashboardFor(String role, String sub) {
    switch (role) {
      case "superadmin":
        return const SuperAdminDashboard(); // SuperAdminDashboard tidak menerima parameter

      case "manager":
        // PERBAIKAN: ManagerDashboard mungkin tidak menerima parameter
        // Cek file manager_dashboard.dart, mungkin konstruktornya seperti ini:
        return const ManagerDashboard(); 
        // Atau jika butuh parameter:
        // return ManagerDashboard(role: role, subrole: sub); // Hanya jika konstruktor menerima parameter

      case "pengawas":
        // PERBAIKAN: PengawasDashboard mungkin tidak menerima parameter
        return const PengawasDashboard();
        // Atau jika butuh parameter:
        // return PengawasDashboard(role: role, subrole: sub);

      case "mitra":
        // PERBAIKAN: MitraDashboard mungkin tidak menerima parameter
        return const MitraDashboard();
        // Atau jika butuh parameter:
        // return MitraDashboard(role: role, subrole: sub);

      default:
        return null;
    }
  }

  // ============================================================

  void _navigate(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  //                       UI SPLASH
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}