// FILE: lib/dashboard/superadmin/settings/settings_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

var logger = Logger();

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // UI State
  bool isLoading = false;
  bool isDarkMode = false;
  String searchQuery = '';
  List<SettingsCategory> filteredCategories = [];

  // Data
  late List<SettingsCategory> _categories;
  Map<String, dynamic> systemStats = {};
  int pendingChanges = 0;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();

    _initializeCategories();
    _loadSystemStats();
    _loadPendingChanges();
  }

  void _initializeCategories() {
    _categories = [
      // KATEGORI 1: MANAJEMEN TARIF & BIAYA
      SettingsCategory(
        id: 'tarif',
        title: 'Manajemen Tarif & Biaya',
        description: 'Atur tarif lembur, transport, insentif, dan potongan',
        icon: Icons.attach_money,
        iconBackground: const Color(0xFF4CAF50),
        gradientColors: const [Color(0xFF43A047), Color(0xFF66BB6A)],
        itemCount: 4,
        items: [
          SettingsItem(
            id: 'overtime_rates',
            title: 'Tarif Lembur',
            description: 'Atur tarif lembur per jam, hari libur, dan shift',
            icon: Icons.timer,
            route: '/settings/overtime-rates',
            badge: BadgeType.hot,
            badgeText: 'PRIORITAS',
            color: const Color(0xFF4CAF50),
          ),
          SettingsItem(
            id: 'deductions',
            title: 'Potongan & Denda',
            description: 'Konfigurasi potongan keterlambatan dan denda',
            icon: Icons.remove_circle,
            route: '/settings/deductions',
            color: const Color(0xFF4CAF50),
          ),
        ],
      ),

      // KATEGORI 2: MANAJEMEN ROLE & AKSES
      SettingsCategory(
        id: 'roles',
        title: 'Manajemen Role & Akses',
        description: 'Kelola hak akses, dan struktur organisasi',
        icon: Icons.admin_panel_settings,
        iconBackground: const Color(0xFF9C27B0),
        gradientColors: const [Color(0xFF8E24AA), Color(0xFFAB47BC)],
        itemCount: 3,
        items: [
          SettingsItem(
            id: 'roles_permissions',
            title: 'Role & Permission',
            description: 'Kelola hak akses untuk setiap role',
            icon: Icons.security,
            route: '/settings/roles',
            badge: BadgeType.newFeature,
            badgeText: 'BARU',
            color: const Color(0xFF9C27B0),
          ),
          SettingsItem(
            id: 'positions',
            title: 'Jabatan & Struktur',
            description: 'Atur struktur organisasi dan jabatan',
            icon: Icons.account_tree,
            route: '/settings/positions',
            color: const Color(0xFF9C27B0),
          ),
          SettingsItem(
            id: 'approval_matrix',
            title: 'Approval Matrix',
            description: 'Konfigurasi alur persetujuan bertingkat',
            icon: Icons.approval,
            route: '/settings/approval-matrix',
            color: const Color(0xFF9C27B0),
          ),
        ],
      ),

      // KATEGORI 3: MANAJEMEN FUNGSI
      SettingsCategory(
        id: 'functions',
        title: 'Manajemen Fungsi',
        description: 'Kelola fungsi/departemen, lokasi site, dan shift',
        icon: Icons.business,
        iconBackground: const Color(0xFF2196F3),
        gradientColors: const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        itemCount: 3,
        items: [
          SettingsItem(
            id: 'functions_list',
            title: 'Daftar Fungsi',
            description: 'Kelola fungsi/departemen (Operation, Lab, HSSE)',
            icon: Icons.departure_board,
            route: '/settings/functions',
            badge: BadgeType.updated,
            badgeText: 'UPDATE',
            color: const Color(0xFF2196F3),
          ),
          SettingsItem(
            id: 'locations',
            title: 'Lokasi & Site',
            description: 'Konfigurasi lokasi kerja dan site',
            icon: Icons.location_city,
            route: '/settings/locations',
            color: const Color(0xFF2196F3),
          ),
          SettingsItem(
            id: 'shifts',
            title: 'Shift & Jadwal',
            description: 'Atur pola shift dan jam kerja',
            icon: Icons.schedule,
            route: '/jadwal-lembur-menu',
            color: const Color(0xFF2196F3),
          ),
        ],
      ),

      // KATEGORI 4: MANAJEMEN SISTEM
      SettingsCategory(
        id: 'system',
        title: 'Manajemen Sistem',
        description: 'Konfigurasi aplikasi, maintenance, dan backup',
        icon: Icons.settings_suggest,
        iconBackground: const Color(0xFFFF9800),
        gradientColors: const [Color(0xFFFB8C00), Color(0xFFFFA726)],
        itemCount: 5,
        items: [
          SettingsItem(
            id: 'app_config',
            title: 'Konfigurasi Aplikasi',
            description: 'Pengaturan umum aplikasi dan fitur',
            icon: Icons.app_settings_alt,
            route: '/settings/app-config',
            color: const Color(0xFFFF9800),
          ),
          SettingsItem(
            id: 'maintenance',
            title: 'Mode Maintenance',
            description: 'Aktifkan/nonaktifkan mode pemeliharaan',
            icon: Icons.build,
            route: '/settings/maintenance',
            color: const Color(0xFFFF9800),
          ),
          SettingsItem(
            id: 'backup',
            title: 'Backup & Restore',
            description: 'Manajemen backup database',
            icon: Icons.backup,
            route: '/settings/backup',
            badge: BadgeType.warning,
            badgeText: 'SEGERA',
            color: const Color(0xFFFF9800),
          ),
          SettingsItem(
            id: 'audit',
            title: 'Audit Trail',
            description: 'Lihat log aktivitas sistem',
            icon: Icons.list_alt,
            route: '/settings/audit',
            color: const Color(0xFFFF9800),
          ),
          SettingsItem(
            id: 'cache',
            title: 'Cache Management',
            description: 'Bersihkan cache dan optimasi',
            icon: Icons.cleaning_services,
            route: '/settings/cache',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),

      // KATEGORI 5: NOTIFIKASI & KOMUNIKASI
      SettingsCategory(
        id: 'notifications',
        title: 'Notifikasi & Komunikasi',
        description: 'Template email, broadcast, dan push notification',
        icon: Icons.notifications,
        iconBackground: const Color(0xFFE91E63),
        gradientColors: const [Color(0xFFD81B60), Color(0xFFEC407A)],
        itemCount: 3,
        items: [
          SettingsItem(
            id: 'notification_templates',
            title: 'Template Notifikasi',
            description: 'Atur template email dan notifikasi',
            icon: Icons.email,
            route: '/settings/notification-templates',
            color: const Color(0xFFE91E63),
          ),
          SettingsItem(
            id: 'broadcast',
            title: 'Broadcast Messages',
            description: 'Kirim pesan broadcast ke pengguna',
            icon: Icons.campaign,
            route: '/settings/broadcast',
            color: const Color(0xFFE91E63),
          ),
          SettingsItem(
            id: 'push_notifications',
            title: 'Push Notification',
            description: 'Konfigurasi notifikasi push',
            icon: Icons.notifications_active,
            route: '/settings/push-notifications',
            color: const Color(0xFFE91E63),
          ),
        ],
      ),

      // KATEGORI 6: LAPORAN & EXPORT
      SettingsCategory(
        id: 'reports',
        title: 'Laporan & Export',
        description: 'Template laporan, export, dan laporan terjadwal',
        icon: Icons.report,
        iconBackground: const Color(0xFF00BCD4),
        gradientColors: const [Color(0xFF00ACC1), Color(0xFF26C6DA)],
        itemCount: 3,
        items: [
          SettingsItem(
            id: 'report_templates',
            title: 'Template Laporan',
            description: 'Atur format dan template laporan',
            icon: Icons.description,
            route: '/settings/report-templates',
            color: const Color(0xFF00BCD4),
          ),
          SettingsItem(
            id: 'export_config',
            title: 'Export Configuration',
            description: 'Konfigurasi format export (Excel, PDF)',
            icon: Icons.download,
            route: '/settings/export-config',
            color: const Color(0xFF00BCD4),
          ),
          SettingsItem(
            id: 'scheduled_reports',
            title: 'Scheduled Reports',
            description: 'Atur laporan terjadwal',
            icon: Icons.schedule_send,
            route: '/settings/scheduled-reports',
            badge: BadgeType.newFeature,
            badgeText: 'BARU',
            color: const Color(0xFF00BCD4),
          ),
        ],
      ),

      // KATEGORI 8: KEAMANAN
      SettingsCategory(
        id: 'security',
        title: 'Keamanan',
        description: 'Password policy, session, dan 2FA',
        icon: Icons.security,
        iconBackground: const Color(0xFFF44336),
        gradientColors: const [Color(0xFFE53935), Color(0xFFEF5350)],
        itemCount: 4,
        items: [
          SettingsItem(
            id: 'password_policy',
            title: 'Password Policy',
            description: 'Atur kebijakan password',
            icon: Icons.password,
            route: '/settings/password-policy',
            color: const Color(0xFFF44336),
          ),
          SettingsItem(
            id: 'sessions',
            title: 'Session Management',
            description: 'Kelola sesi pengguna',
            icon: Icons.history, // Ganti Icons.session dengan Icons.history
            route: '/settings/sessions',
            color: const Color(0xFFF44336),
          ),
        ],
      ),

      // KATEGORI 9: LOG & MONITORING
      SettingsCategory(
        id: 'monitoring',
        title: 'Log & Monitoring',
        description: 'System health, error logs, dan performa',
        icon: Icons.analytics, // Ganti Icons.monitoring dengan Icons.analytics
        iconBackground: const Color(0xFF607D8B),
        gradientColors: const [Color(0xFF546E7A), Color(0xFF78909C)],
        itemCount: 3,
        items: [
          SettingsItem(
            id: 'system_health',
            title: 'System Health',
            description: 'Monitor kesehatan sistem',
            icon: Icons.health_and_safety,
            route: '/settings/system-health',
            badge: BadgeType.warning,
            badgeText: 'CEK',
            color: const Color(0xFF607D8B),
          ),
          SettingsItem(
            id: 'error_logs',
            title: 'Error Logs',
            description: 'Lihat log error sistem',
            icon: Icons.bug_report,
            route: '/settings/error-logs',
            color: const Color(0xFF607D8B),
          ),
          SettingsItem(
            id: 'performance',
            title: 'Performance Metrics',
            description: 'Monitor performa sistem',
            icon: Icons.speed,
            route: '/settings/performance',
            color: const Color(0xFF607D8B),
          ),
        ],
      ),
    ];

    filteredCategories = _categories;
  }

  Future<void> _loadSystemStats() async {
    try {
      final statsDoc = await _firestore
          .collection('system_stats')
          .doc('current')
          .get();

      if (statsDoc.exists) {
        setState(() {
          systemStats = statsDoc.data() ?? {};
        });
      }
    } catch (e) {
      logger.e('Error loading system stats: $e');
    }
  }

  Future<void> _loadPendingChanges() async {
    try {
      final snapshot = await _firestore
          .collection('settings')
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        pendingChanges = snapshot.docs.length;
      });
    } catch (e) {
      logger.e('Error loading pending changes: $e');
    }
  }

  void _filterCategories(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredCategories = _categories;
      } else {
        filteredCategories = _categories.where((category) {
          // Search in category title
          if (category.title.toLowerCase().contains(query.toLowerCase())) {
            return true;
          }
          
          // Search in category description
          if (category.description.toLowerCase().contains(query.toLowerCase())) {
            return true;
          }
          
          // Search in items
          return category.items.any((item) =>
              item.title.toLowerCase().contains(query.toLowerCase()) ||
              item.description.toLowerCase().contains(query.toLowerCase()));
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Helper method untuk mengganti withOpacity yang deprecated
  Color _withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // App Bar dengan search
          _buildSliverAppBar(),
          
          // Main content
          SliverPadding(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header dengan greeting
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildHeader(),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Stats cards
                _buildStatsCards(),
                
                const SizedBox(height: 24),
                
                // Search bar
                _buildSearchBar(),
                
                const SizedBox(height: 20),
                
                // Quick actions
                _buildQuickActions(),
                
                const SizedBox(height: 24),
                
                // Settings categories
                ...filteredCategories.map((category) => Column(
                  children: [
                    _buildCategoryCard(category),
                    const SizedBox(height: 16),
                  ],
                )),
                
                const SizedBox(height: 24),
                
                // Footer info
                _buildFooter(),
                
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
      
      // Floating action button untuk menyimpan perubahan
      floatingActionButton: pendingChanges > 0
          ? FloatingActionButton.extended(
              onPressed: _showPendingChangesDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              label: Text(
                '$pendingChanges Perubahan Tertunda',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E3C72),
                Color(0xFF2A4F8C),
                Color(0xFFFF6B35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Theme toggle
        IconButton(
          icon: Icon(
            isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              isDarkMode = !isDarkMode;
            });
          },
        ),
        
        // Help button
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: () => _showHelpDialog(context),
        ),
        
        const SizedBox(width: 8),
      ],
      title: Text(
        'Pengaturan',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeader() {
    final user = _auth.currentUser;
    final hour = DateTime.now().hour;
    
    String greeting;
    if (hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3C72),
            Color(0xFF2A4F8C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _withOpacity(const Color(0xFF1E3C72), 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFFF6B35)],
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      user?.email?[0].toUpperCase() ?? 'SA',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E3C72),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayName ?? 'Super Admin',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Panel Pengaturan Sistem',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'v2.0.0',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Pengaturan',
            '${_categories.fold(0, (int previous, cat) => previous + cat.items.length)}',
            Icons.settings,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Kategori',
            '${_categories.length}',
            Icons.category,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Perubahan',
            pendingChanges.toString(),
            Icons.pending_actions,
            pendingChanges > 0 ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: _filterCategories,
        decoration: InputDecoration(
          hintText: 'Cari pengaturan...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3C72)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _filterCategories('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: GoogleFonts.poppins(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Aksi Cepat',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  'Tarif Lembur',
                  Icons.timer,
                  () => _navigateTo('/settings/overtime-rates'),
                ),
                _buildQuickActionChip(
                  'Role & Akses',
                  Icons.security,
                  () => _navigateTo('/settings/roles'),
                ),
                _buildQuickActionChip(
                  'Backup DB',
                  Icons.backup,
                  () => _performQuickBackup(),
                ),
                _buildQuickActionChip(
                  'Mode Maintenance',
                  Icons.build,
                  () => _showMaintenanceDialog(),
                ),
                _buildQuickActionChip(
                  'Broadcast',
                  Icons.campaign,
                  () => _navigateTo('/settings/broadcast'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: _withOpacity(const Color(0xFF1E3C72), 0.1),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1E3C72)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF1E3C72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(SettingsCategory category) {
    final isSearching = searchQuery.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _withOpacity(category.iconBackground, 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: category.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        category.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.description,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${category.items.length} item',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Items
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: category.items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final item = category.items[index];
                    
                    // Filter berdasarkan search jika sedang mencari
                    if (isSearching &&
                        !item.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
                        !item.description.toLowerCase().contains(searchQuery.toLowerCase())) {
                      return const SizedBox.shrink();
                    }

                    return _buildSettingsItem(item, category.iconBackground);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(SettingsItem item, Color categoryColor) {
    return InkWell(
      onTap: () => _navigateTo(item.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Icon dengan background
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _withOpacity(item.color, 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(item.badge!, item.badgeText ?? ''),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BadgeType type, String text) {
    Color color;
    Color textColor;
    
    switch (type) {
      case BadgeType.hot:
        color = Colors.red;
        textColor = Colors.white;
        break;
      case BadgeType.newFeature:
        color = Colors.green;
        textColor = Colors.white;
        break;
      case BadgeType.updated:
        color = Colors.blue;
        textColor = Colors.white;
        break;
      case BadgeType.warning:
        color = Colors.orange;
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _withOpacity(color, 0.3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8,
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFooterItem(
                Icons.support_agent,
                'Support',
                () => _launchUrl('mailto:admin@support.com'),
              ),
              _buildFooterItem(
                Icons.document_scanner,
                'Dokumentasi',
                () => _navigateTo('/documentation'),
              ),
              _buildFooterItem(
                Icons.help_center,
                'FAQ',
                () => _navigateTo('/faq'),
              ),
              _buildFooterItem(
                Icons.info,
                'Tentang',
                () => _showAboutDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Terakhir sync: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2024 Super Admin Panel. All rights reserved.',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _withOpacity(const Color(0xFF1E3C72), 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1E3C72)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NAVIGATION & ACTIONS ====================

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help, color: Colors.white, size: 50),
              const SizedBox(height: 16),
              Text(
                'Bantuan Pengaturan',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildHelpItem('1', 'Manajemen Tarif & Biaya', 'Atur tarif lembur, transport, insentif'),
                    _buildHelpItem('2', 'Manajemen Role & Akses', 'Kelola hak akses pengguna'),
                    _buildHelpItem('3', 'Manajemen Fungsi', 'Atur fungsi/departemen'),
                    _buildHelpItem('4', 'Manajemen Sistem', 'Konfigurasi aplikasi dan maintenance'),
                    _buildHelpItem('5', 'Notifikasi & Komunikasi', 'Template dan broadcast'),
                    _buildHelpItem('6', 'Laporan & Export', 'Konfigurasi laporan'),
                    _buildHelpItem('7', 'Integrasi', 'API dan integrasi eksternal'),
                    _buildHelpItem('8', 'Keamanan', 'Kebijakan password dan keamanan'),
                    _buildHelpItem('9', 'Log & Monitoring', 'Monitoring sistem'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3C72),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3C72),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tentang Aplikasi', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 60, color: Color(0xFF1E3C72)),
            const SizedBox(height: 16),
            Text(
              'Super Admin Panel',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi 2.0.0',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildAboutRow('Developer', 'PT. Teknologi Integrasi'),
            _buildAboutRow('Release Date', 'Januari 2024'),
            _buildAboutRow('Last Update', DateFormat('dd MMM yyyy').format(DateTime.now())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Tutup', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showPendingChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Perubahan Tertunda', style: GoogleFonts.poppins()),
        content: Text(
          'Ada $pendingChanges perubahan pengaturan yang belum disimpan. '
          'Apakah Anda ingin menyimpan semua perubahan sekarang?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Nanti', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
              _saveAllChanges();
            },
            child: Text('Simpan Semua', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllChanges() async {
    setState(() => isLoading = true);
    
    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulasi proses
      
      if (mounted) {
        setState(() {
          pendingChanges = 0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Semua perubahan berhasil disimpan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _performQuickBackup() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memulai backup database...'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup berhasil!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mode Maintenance', style: GoogleFonts.poppins()),
        content: Text(
          'Aktifkan mode maintenance? Pengguna tidak dapat mengakses sistem.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode maintenance diaktifkan'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Aktifkan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ==================== MODEL CLASSES ====================

enum BadgeType {
  hot,
  newFeature, // Diubah dari new_feature menjadi newFeature (camelCase)
  updated,
  warning,
}

class SettingsCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final List<Color> gradientColors;
  final int itemCount;
  final List<SettingsItem> items;

  SettingsCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.gradientColors,
    required this.itemCount,
    required this.items,
  });
}

class SettingsItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final BadgeType? badge;
  final String? badgeText;
  final Color color;

  SettingsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.badge,
    this.badgeText,
    required this.color,
  });
}