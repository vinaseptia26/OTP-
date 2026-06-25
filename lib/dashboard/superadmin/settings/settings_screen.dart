// ============================================================
// FILE : lib/dashboard/superadmin/settings/settings_screen.dart
// FINAL VERSION - CLEAN SETTINGS UI + GO ROUTER + BOTTOM NAV
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '/widgets/bottom_nav/superadmin_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;

  int totalUsers = 0;
  int totalLogs = 0;

  List<SettingMenu> settingsMenus = [];

  @override
  void initState() {
    super.initState();

    _initializeMenus();
    _loadSystemData();
  }

  // =========================================================
  // INITIAL MENU
  // =========================================================

  void _initializeMenus() {
    settingsMenus = [
      SettingMenu(
        title: 'Manajemen Tarif Lembur',
        subtitle:
            'Atur tarif lembur hari kerja, hari libur, shift dan insentif.',
        icon: Icons.payments_rounded,
        color: const Color(0xFF22C55E),
        route: '/settings/overtime-rates',
      ),

      SettingMenu(
        title: 'Akun & Profil',
        subtitle:
            'Kelola profil, password, email, dan data akun pengguna.',
        icon: Icons.person_rounded,
        color: const Color(0xFF3B82F6),
        route: '/profile',
      ),

      SettingMenu(
        title: 'System Logs',
        subtitle:
            'Monitoring aktivitas sistem, login, approval, dan error logs.',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF97316),
        route: '/system-logs',
      ),

      SettingMenu(
        title: 'Tentang Aplikasi',
        subtitle:
            'Informasi aplikasi, versi sistem, dan pengembang.',
        icon: Icons.info_rounded,
        color: const Color(0xFF8B5CF6),
        route: '/settings/about-app',
      ),
    ];
  }

  // =========================================================
  // LOAD FIREBASE DATA
  // =========================================================

  Future<void> _loadSystemData() async {
    try {
      final users =
          await _firestore.collection('users').get();

      final logs =
          await _firestore.collection('system_logs').get();

      if (mounted) {
        setState(() {
          totalUsers = users.docs.length;
          totalLogs = logs.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      bottomNavigationBar: const SuperAdminBottomNav(
        currentIndex: 2,
      ),

      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        120,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildHeader(user),

                          const SizedBox(height: 22),

                          _buildSystemOverview(),

                          const SizedBox(height: 28),

                          Text(
                            'Pengaturan Utama',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),

                          const SizedBox(height: 16),

                          ...settingsMenus.map(
                            (menu) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 16,
                              ),
                              child: _buildMenuCard(menu),
                            ),
                          ),

                          const SizedBox(height: 10),

                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(User? user) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3C72),
            Color(0xFF2A5298),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF1E3C72).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              user?.email
                      ?.substring(0, 1)
                      .toUpperCase() ??
                  'A',
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E3C72),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan Sistem',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  user?.email ??
                      'superadmin@app.com',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Text(
              'v2.0.0',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // OVERVIEW
  // =========================================================

  Widget _buildSystemOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Pengguna',
            value: totalUsers.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: _buildOverviewCard(
            title: 'Logs',
            value: totalLogs.toString(),
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF97316),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MENU CARD
  // =========================================================

  Widget _buildMenuCard(SettingMenu menu) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        context.push(menu.route);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(20),
                color: menu.color.withOpacity(0.1),
              ),
              child: Icon(
                menu.icon,
                color: menu.color,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          const Color(0xFF1E293B),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    menu.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    menu.color.withOpacity(0.12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: menu.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            color: Colors.green.shade600,
            size: 34,
          ),

          const SizedBox(height: 12),

          Text(
            'Sistem berjalan dengan baik',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: const Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Terakhir diperbarui ${DateFormat('dd MMM yyyy • HH:mm').format(DateTime.now())}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class SettingMenu {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  SettingMenu({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}