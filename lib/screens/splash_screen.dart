// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _opacity;
  
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    // Delay 2 detik lalu cek auth
    Future.delayed(const Duration(seconds: 2), _checkAuthAndRedirect);
  }

  /// Cek login & arahkan ke halaman yang tepat
  Future<void> _checkAuthAndRedirect() async {
    final destination = await _authService.checkAuthAndGetDestination();
    _navigate(destination);
  }

  /// Pindah halaman dengan animasi fade
  void _navigate(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              errorBuilder: (context, error, stackTrace) {
                // Fallback kalau logo ga ada
                return const Icon(
                  Icons.local_fire_department_rounded,
                  size: 100,
                  color: Color(0xFF1E3C72),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}