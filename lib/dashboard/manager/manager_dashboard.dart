// FILE: lib/dashboard/manager/manager_dashboard.dart
// VERSION: Manager Dashboard with Complete Features - FIXED

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

// Import menu screens
import '/dashboard/manager/approval_lembur_screen.dart';
import '/dashboard/superadmin/overtime_history_screen.dart';

// Placeholder screens untuk menu lain
class HistoryMenuScreen extends StatelessWidget {
  final List<Map<String, dynamic>> approvedLembur;
  final List<Map<String, dynamic>> rejectedLembur;
  const HistoryMenuScreen({super.key, required this.approvedLembur, required this.rejectedLembur});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('History')));
}

class AnalyticsMenuScreen extends StatelessWidget {
  final List<Map<String, dynamic>> projectStats;
  final List<Map<String, dynamic>> teamMembers;
  final double totalHours;
  final int overtimeThreshold;
  const AnalyticsMenuScreen({super.key, required this.projectStats, required this.teamMembers, required this.totalHours, required this.overtimeThreshold});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Analytics')));
}

class LocationMenuScreen extends StatelessWidget {
  final List<Map<String, dynamic>> teamMembers;
  final List<Map<String, dynamic>> locations;
  const LocationMenuScreen({super.key, required this.teamMembers, required this.locations});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Location')));
}

class SettingsMenuScreen extends StatelessWidget {
  final int currentThreshold;
  final VoidCallback onSettingsChanged;
  const SettingsMenuScreen({super.key, required this.currentThreshold, required this.onSettingsChanged});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')));
}

class ProfileMenuScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const ProfileMenuScreen({super.key, required this.userData});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')));
}

var logger = Logger();

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Data Collections
  Map<String, dynamic> userData = {};
  List<Map<String, dynamic>> pendingLembur = [];
  List<Map<String, dynamic>> approvedLembur = [];
  List<Map<String, dynamic>> rejectedLembur = [];
  List<Map<String, dynamic>> teamMembers = [];
  List<Map<String, dynamic>> projectStats = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> recentActivities = [];
  Map<String, dynamic> systemHealth = {};
  
  // Statistics
  int totalPending = 0;
  int totalApproved = 0;
  int totalRejected = 0;
  double totalHoursThisMonth = 0.0;
  int activeProjects = 0;
  int totalTeamMembers = 0;
  int onlineMembers = 0;
  int overtimeThreshold = 60;
  int totalLemburMonth = 0;
  
  // Chart indices
  int selectedChartIndex = -1;
  int selectedPieIndex = -1;
  
  // Time range
  String selectedTimeRange = 'week';
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  
  // UI State
  bool isLoading = true;
  bool isRefreshing = false;
  bool isDarkMode = false;
  int unreadNotifications = 0;
  
  // Session management
  String? _currentSessionId;
  
  // Stream subscriptions
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  
  // Refresh indicator key
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = 
      GlobalKey<RefreshIndicatorState>();

  // Warna-warna untuk menu yang berbeda
  final List<Color> _menuColors = const [
    Color(0xFFFF6B35), // Oranye (Approval)
    Color(0xFF2196F3), // Biru (History)
    Color(0xFF4CAF50), // Hijau (Analytics)
    Color(0xFF9C27B0), // Ungu (Location)
    Color(0xFFFF9800), // Oranye Muda
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
    
    _generateSessionId();
    _initializeData();
    _setupListeners();
    _initSampleLocations();
    _checkUnreadNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeData();
    }
  }

  // ==================== SESSION MANAGEMENT ====================
  void _generateSessionId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    _currentSessionId = base64Url.encode(bytes);
  }

  // ==================== DATA INITIALIZATION ====================

  void _initSampleLocations() {
    // Sample locations for Jakarta area
    locations = [
      {
        'id': 'loc1',
        'name': 'Site A - Jakarta Pusat',
        'lat': -6.2088,
        'lng': 106.8456,
        'status': 'Normal',
        'color': Colors.green,
        'address': 'Jl. Sudirman No. 1, Jakarta Pusat',
        'lastUpdate': DateTime.now().subtract(const Duration(minutes: 5)),
        'workers': 8,
        'cctv': 4,
        'battery': 87,
        'signal': '4G',
      },
      {
        'id': 'loc2',
        'name': 'Site B - Jakarta Selatan',
        'lat': -6.2388,
        'lng': 106.8256,
        'status': 'Normal',
        'color': Colors.green,
        'address': 'Jl. Rasuna Said Kav. 3-4',
        'lastUpdate': DateTime.now().subtract(const Duration(minutes: 12)),
        'workers': 6,
        'cctv': 3,
        'battery': 92,
        'signal': '4G',
      },
      {
        'id': 'loc3',
        'name': 'Site C - Jakarta Utara',
        'lat': -6.1288,
        'lng': 106.8856,
        'status': 'Warning',
        'color': Colors.orange,
        'address': 'Jl. Pluit Raya No. 45',
        'lastUpdate': DateTime.now().subtract(const Duration(minutes: 2)),
        'workers': 4,
        'cctv': 2,
        'battery': 45,
        'signal': '3G',
        'warning': 'Battery rendah'
      },
      {
        'id': 'loc4',
        'name': 'Site D - Jakarta Barat',
        'lat': -6.1688,
        'lng': 106.7656,
        'status': 'Normal',
        'color': Colors.green,
        'address': 'Jl. Daan Mogot Km. 12',
        'lastUpdate': DateTime.now().subtract(const Duration(minutes: 8)),
        'workers': 7,
        'cctv': 4,
        'battery': 78,
        'signal': '4G',
      },
      {
        'id': 'loc5',
        'name': 'Site E - Jakarta Timur',
        'lat': -6.2188,
        'lng': 106.8956,
        'status': 'Anomali',
        'color': Colors.red,
        'address': 'Jl. Pemuda No. 23',
        'lastUpdate': DateTime.now().subtract(const Duration(minutes: 15)),
        'workers': 5,
        'cctv': 2,
        'battery': 23,
        'signal': '2G',
        'anomaly': 'Tidak ada aktivitas 1 jam'
      },
    ];
  }

  // ==================== REAL-TIME UPDATES ====================

  void _setupListeners() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to notifications
    try {
      final notifSub = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            unreadNotifications = snapshot.docs.length;
          });
        }
      }, onError: (error) {
        logger.e('Error listening to notifications: $error');
      });
      _subscriptions.add(notifSub);
    } catch (e) {
      logger.e('Error setting up notifications listener: $e');
    }

    // Listen to lembur collection for real-time updates
    try {
      final fungsi = userData['fungsi'] ?? userData['unit'] ?? 'operation';
      
      final lemburSub = _firestore
          .collection('lembur')
          .where('pengawas_fungsi', isEqualTo: fungsi)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _processLemburData(snapshot.docs);
        }
      }, onError: (error) {
        logger.e('Error listening to lembur: $error');
      });
      _subscriptions.add(lemburSub);
    } catch (e) {
      logger.e('Error setting up lembur listener: $e');
    }

    // Listen to team members status
    try {
      final fungsi = userData['fungsi'] ?? userData['unit'] ?? 'operation';
      
      final teamSub = _firestore
          .collection('users')
          .where('role', whereIn: ['pengawas', 'mitra'])
          .where('fungsi', isEqualTo: fungsi)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _processTeamData(snapshot.docs);
        }
      }, onError: (error) {
        logger.e('Error listening to team: $error');
      });
      _subscriptions.add(teamSub);
    } catch (e) {
      logger.e('Error setting up team listener: $e');
    }

    // Listen to system_settings
    try {
      final settingsSub = _firestore
          .collection('settings')
          .doc('lembur_config')
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            overtimeThreshold = data['max_jam_per_bulan'] ?? 60;
          });
        }
      }, onError: (error) {
        logger.e('Error listening to settings: $error');
      });
      _subscriptions.add(settingsSub);
    } catch (e) {
      logger.e('Error setting up settings listener: $e');
    }
  }

  void _processLemburData(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    List<Map<String, dynamic>> pending = [];
    List<Map<String, dynamic>> approved = [];
    List<Map<String, dynamic>> rejected = [];
    double monthHours = 0.0;
    Map<String, Map<String, dynamic>> projectMap = {};

    for (var doc in docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['id'] = doc.id;

      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      
      if (status == 'pending') {
        pending.add(data);
      } else if (status == 'approved' || status == 'disetujui') {
        approved.add(data);
        
        final tanggal = (data['tanggal'] as Timestamp?)?.toDate();
        if (tanggal != null && tanggal.isAfter(startOfMonth)) {
          monthHours += _toDouble(data['total_jam_desimal']);
        }

        // For project stats
        String proyek = 'Proyek Umum';
        final alasan = data['alasan'] as String?;
        if (alasan != null && alasan.isNotEmpty) {
          proyek = alasan.split(' ').take(3).join(' ');
          if (proyek.length > 20) proyek = '${proyek.substring(0, 20)}...';
        }

        final durasi = _toDouble(data['total_jam_desimal']);

        if (!projectMap.containsKey(proyek)) {
          projectMap[proyek] = {
            'nama': proyek,
            'totalJam': 0.0,
            'totalAnggota': 0,
            'totalPengajuan': 0,
          };
        }

        projectMap[proyek]!['totalJam'] = projectMap[proyek]!['totalJam'] + durasi;
        projectMap[proyek]!['totalPengajuan'] = projectMap[proyek]!['totalPengajuan'] + 1;
      } else if (status == 'rejected' || status == 'ditolak') {
        rejected.add(data);
      }
    }

    if (mounted) {
      setState(() {
        pendingLembur = pending;
        approvedLembur = approved;
        rejectedLembur = rejected;
        totalPending = pending.length;
        totalApproved = approved.length;
        totalRejected = rejected.length;
        totalHoursThisMonth = monthHours;
        totalLemburMonth = approved.length;
        projectStats = projectMap.values.toList();
        activeProjects = projectStats.length;
      });
    }
  }

  void _processTeamData(List<QueryDocumentSnapshot> docs) {
    final List<Map<String, dynamic>> members = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      members.add({
        'id': doc.id,
        'nama': data['nama_lengkap'] ?? data['email'] ?? 'Unknown',
        'role': data['role'] ?? 'anggota',
        'isOnline': data['isOnline'] ?? false,
        'fungsi': data['fungsi'] ?? userData['fungsi'] ?? 'operation',
        'totalLembur': _toDouble(data['totalLemburBulanIni']),
        'lastActive': data['last_active'],
        'phone': data['phone'] ?? '-',
      });
    }

    if (mounted) {
      setState(() {
        teamMembers = members;
        totalTeamMembers = members.length;
        onlineMembers = members.where((m) => m['isOnline'] == true).length;
      });
    }
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (mounted) {
        setState(() {
          unreadNotifications = snapshot.docs.length;
        });
      }
    } catch (e) {
      logger.e('Error checking notifications: $e');
    }
  }

  // ==================== DATA LOADING ====================

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await _loadUserData();
      
      // Load all data concurrently
      await Future.wait([
        _loadTeamMembers(),
        _loadLemburData(),
        _loadProjectStats(),
        _loadSystemSettings(),
        _loadRecentActivities(),
        _loadSystemHealth(),
      ]);
      
      _logSystemActivity('dashboard_view', 'Manager melihat dashboard');
    } catch (e) {
      logger.e('Error initializing: $e');
      _showErrorSnackbar('Error loading data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _fadeController.reset();
        _fadeController.forward();
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      userData = Map<String, dynamic>.from(doc.data() as Map);
      userData['uid'] = user.uid;
    }
  }

  Future<void> _loadTeamMembers() async {
    final fungsi = userData['fungsi'] ?? userData['unit'] ?? 'operation';
    
    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['pengawas', 'mitra'])
        .where('fungsi', isEqualTo: fungsi)
        .get();

    teamMembers = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'nama': data['nama_lengkap'] ?? data['email'] ?? 'Unknown',
        'role': data['role'] ?? 'anggota',
        'isOnline': data['isOnline'] ?? false,
        'fungsi': data['fungsi'] ?? fungsi,
        'totalLembur': _toDouble(data['totalLemburBulanIni']),
        'lastActive': data['last_active'],
        'phone': data['phone'] ?? '-',
      };
    }).toList();

    totalTeamMembers = teamMembers.length;
    onlineMembers = teamMembers.where((m) => m['isOnline'] == true).length;
  }

  Future<void> _loadLemburData() async {
    final fungsi = userData['fungsi'] ?? userData['unit'] ?? 'operation';
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final snapshot = await _firestore
        .collection('lembur')
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .orderBy('created_at', descending: true)
        .limit(100)
        .get();

    List<Map<String, dynamic>> pending = [];
    List<Map<String, dynamic>> approved = [];
    List<Map<String, dynamic>> rejected = [];
    double monthHours = 0.0;

    for (var doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;

      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      
      if (status == 'pending') {
        pending.add(data);
      } else if (status == 'approved' || status == 'disetujui') {
        approved.add(data);
        
        final tanggal = (data['tanggal'] as Timestamp?)?.toDate();
        if (tanggal != null && tanggal.isAfter(startOfMonth)) {
          monthHours += _toDouble(data['total_jam_desimal']);
        }
      } else if (status == 'rejected' || status == 'ditolak') {
        rejected.add(data);
      }
    }

    pendingLembur = pending;
    approvedLembur = approved;
    rejectedLembur = rejected;
    totalPending = pending.length;
    totalApproved = approved.length;
    totalRejected = rejected.length;
    totalHoursThisMonth = monthHours;
    totalLemburMonth = approved.length;
  }

  Future<void> _loadProjectStats() async {
    final fungsi = userData['fungsi'] ?? userData['unit'] ?? 'operation';

    final snapshot = await _firestore
        .collection('lembur')
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .where('status', isEqualTo: 'approved')
        .get();

    Map<String, Map<String, dynamic>> projectMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      String proyek = 'Proyek Umum';
      final alasan = data['alasan'] as String?;
      if (alasan != null && alasan.isNotEmpty) {
        proyek = alasan.split(' ').take(3).join(' ');
        if (proyek.length > 20) proyek = '${proyek.substring(0, 20)}...';
      }

      final durasi = _toDouble(data['total_jam_desimal']);

      if (!projectMap.containsKey(proyek)) {
        projectMap[proyek] = {
          'nama': proyek,
          'totalJam': 0.0,
          'totalAnggota': 0,
          'totalPengajuan': 0,
        };
      }

      projectMap[proyek]!['totalJam'] = projectMap[proyek]!['totalJam'] + durasi;
      projectMap[proyek]!['totalPengajuan'] = projectMap[proyek]!['totalPengajuan'] + 1;
    }

    projectStats = projectMap.values.toList();
    activeProjects = projectStats.length;
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('lembur_config')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        overtimeThreshold = data['max_jam_per_bulan'] ?? 60;
      }
    } catch (e) {
      overtimeThreshold = 60;
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final logsSnapshot = await _firestore
          .collection('system_logs')
          .where('target_user', isEqualTo: _auth.currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      recentActivities = logsSnapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).toDate() 
            : DateTime.now();
        
        return {
          'id': doc.id,
          'type': data['type'] ?? 'info',
          'description': data['description'] ?? 'No description',
          'timestamp': timestamp,
        };
      }).toList();
    } catch (e) {
      logger.w('Could not fetch recent activities: $e');
      recentActivities = [];
    }
  }

  Future<void> _loadSystemHealth() async {
    // Simulated system health data
    systemHealth = {
      'overtimeRate': 85,
      'approvalRate': 92,
      'teamActive': onlineMembers,
      'performance': 95,
    };
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _initializeData();
    await _logSystemActivity('refresh', 'Dashboard direfresh');
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => isRefreshing = false);
      _showSuccessSnackbar('Dashboard diperbarui');
    }
  }

  Future<void> _logSystemActivity(String type, String description) async {
    try {
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': _auth.currentUser?.email,
        'target_user': _auth.currentUser?.uid,
        'session_id': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return const Color(0xFFFF6B35); // Orange
      case 'pengawas':
        return const Color(0xFF4CAF50); // Green
      case 'mitra':
        return const Color(0xFF2196F3); // Blue
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'baru saja';

    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return 'baru saja';
    }

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} bln';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hr';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} mnt';
    } else {
      return 'br saja';
    }
  }

  // ==================== SNACKBARS ====================

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== NAVIGATION TO MENUS ====================

  void _openApprovalMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprovalLemburScreen(
          onApprovalComplete: _refreshData,
        ),
      ),
    );
  }

  void _openHistoryMenu() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => OvertimeHistoryScreen(
      ),
    ),
  );
}

  void _openAnalyticsMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsMenuScreen(
          projectStats: projectStats,
          teamMembers: teamMembers,
          totalHours: totalHoursThisMonth,
          overtimeThreshold: overtimeThreshold,
        ),
      ),
    );
  }

  void _openLocationMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationMenuScreen(
          teamMembers: teamMembers.where((m) => m['isOnline'] == true).toList(),
          locations: locations,
        ),
      ),
    );
  }

  void _openSettingsMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsMenuScreen(
          currentThreshold: overtimeThreshold,
          onSettingsChanged: _refreshData,
        ),
      ),
    );
  }

  void _openProfileMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileMenuScreen(userData: userData),
      ),
    );
  }

  // ==================== DIALOGS & ACTIONS ====================

  void _showDetailDialog(Map<String, dynamic> lembur) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lembur['alasan'] ?? 'Detail Lembur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Pengawas', lembur['pengawas_nama'] ?? '-'),
              _buildDetailRow('Tanggal', lembur['tanggal'] != null ? DateFormat('dd/MM/yyyy').format((lembur['tanggal'] as Timestamp).toDate()) : '-'),
              _buildDetailRow('Jam', '${lembur['jam_mulai']} - ${lembur['jam_selesai']}'),
              _buildDetailRow('Durasi', '${_toDouble(lembur['total_jam_desimal']).toStringAsFixed(1)} jam'),
              _buildDetailRow('Alasan', lembur['alasan'] ?? '-'),
              if (lembur['rejection_reason'] != null)
                _buildDetailRow('Alasan Ditolak', lembur['rejection_reason'], color: Colors.red),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          if (lembur['status'] == 'pending') ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showApproveDialog(lembur);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Setujui'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRejectDialog(lembur);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Tolak'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> lembur) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Lembur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Anda akan menyetujui pengajuan ini'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Komentar (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processApproval(lembur, true, controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> lembur) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Lembur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berikan alasan penolakan:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Alasan *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan harus diisi')),
                );
                return;
              }
              Navigator.pop(context);
              _processApproval(lembur, false, controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _processApproval(Map<String, dynamic> lembur, bool isApprove, String komentar) async {
    try {
      final status = isApprove ? 'approved' : 'rejected';
      final field = isApprove ? 'approved_at' : 'rejected_at';
      
      await _firestore.collection('lembur').doc(lembur['id']).update({
        'status': status,
        isApprove ? 'approved_by' : 'rejected_by': _auth.currentUser?.email,
        field: FieldValue.serverTimestamp(),
        isApprove ? 'approval_comment' : 'rejection_reason': komentar,
      });

      await _logSystemActivity(
        isApprove ? 'approve_lembur' : 'reject_lembur',
        'Lembur ${isApprove ? 'disetujui' : 'ditolak'}: ${lembur['alasan']}'
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isApprove ? '✅ Disetujui' : '❌ Ditolak')),
        );
        _refreshData();
      }
    } catch (e) {
      logger.e('Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showLocationDetail(BuildContext context, Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (location['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: location['color'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              location['address'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (location['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          location['status'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: location['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildLocationDetailRow('Koordinat',
                            '${location['lat'].toStringAsFixed(4)}, ${location['lng'].toStringAsFixed(4)}'),
                        _buildLocationDetailRow('Last Update', _getTimeAgo(location['lastUpdate'])),
                        const Divider(height: 24),
                        _buildLocationDetailRow('Jumlah Pekerja', '${location['workers']} orang'),
                        _buildLocationDetailRow('CCTV Terpasang', '${location['cctv']} unit'),
                        _buildLocationDetailRow('Battery', '${location['battery']}%'),
                        _buildLocationDetailRow('Sinyal', location['signal']),
                        if (location['anomaly'] != null) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['anomaly'],
                                    style: GoogleFonts.poppins(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (location['warning'] != null) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['warning'],
                                    style: GoogleFonts.poppins(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchMaps(location['lat'], location['lng']),
                          icon: const Icon(Icons.map),
                          label: Text('Buka Maps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: location['color'],
                            side: BorderSide(color: location['color']),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: location['color'],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Tidak dapat membuka maps');
    }
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifikasi',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadNotifications > 9 ? '9+' : '$unreadNotifications Baru',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.done_all),
                            onPressed: _markAllAsRead,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('notifications')
                          .where('userId', isEqualTo: _auth.currentUser?.uid)
                          .orderBy('createdAt', descending: true)
                          .limit(30)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final notifications = snapshot.data!.docs;

                        if (notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada notifikasi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index].data() as Map<String, dynamic>;
                            final isRead = notif['isRead'] ?? false;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.transparent
                                    : Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.grey[200]!
                                      : Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getNotifColor(notif['type']).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getNotifIcon(notif['type']),
                                      color: _getNotifColor(notif['type']),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif['title'] ?? 'Notifikasi',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: isRead
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          notif['body'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _getTimeAgo(notif['createdAt']),
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case 'lembur_approved':
      case 'approval':
        return Colors.green;
      case 'lembur_rejected':
      case 'rejection':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'lembur_approved':
      case 'approval':
        return Icons.check_circle;
      case 'lembur_rejected':
      case 'rejection':
        return Icons.cancel;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      setState(() {
        unreadNotifications = 0;
      });
      _showSuccessSnackbar('Semua notifikasi telah dibaca');
    } catch (e) {
      _showErrorSnackbar('Gagal menandai notifikasi');
    }
  }

  void _showDrawerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(Icons.pending_actions, 'Persetujuan Lembur', Colors.orange, _openApprovalMenu),
              _buildMenuItem(Icons.history, 'Riwayat Lembur', Colors.blue, _openHistoryMenu),
              _buildMenuItem(Icons.analytics, 'Analisis Produktivitas', Colors.green, _openAnalyticsMenu),
              _buildMenuItem(Icons.location_on, 'Monitoring Lokasi', Colors.purple, _openLocationMenu),
              _buildMenuItem(Icons.settings, 'Pengaturan', Colors.grey, _openSettingsMenu),
              _buildMenuItem(Icons.person, 'Profil', Colors.teal, _openProfileMenu),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: GoogleFonts.poppins()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showSearchDialog(BuildContext context) {
    showSearch(
      context: context,
      delegate: ManagerSearchDelegate(),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bantuan & Dukungan', style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent, color: Colors.blue),
                title: Text('Hubungi Manager', style: GoogleFonts.poppins()),
                subtitle: Text('manager@company.com'),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse('mailto:manager@company.com'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner, color: Colors.green),
                title: Text('Panduan Manager', style: GoogleFonts.poppins()),
                subtitle: Text('Cara menggunakan fitur manager'),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessSnackbar('Membuka panduan...');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center, color: Colors.orange),
                title: Text('FAQ', style: GoogleFonts.poppins()),
                subtitle: Text('Pertanyaan yang sering diajukan'),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessSnackbar('Membuka FAQ...');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  void _showQuickActionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Menu Cepat',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickMenuTile(
                Icons.pending_actions,
                'Persetujuan Lembur',
                Colors.orange,
                () {
                  Navigator.pop(context);
                  _openApprovalMenu();
                },
              ),
              _buildQuickMenuTile(
                Icons.analytics,
                'Lihat Analisis',
                Colors.green,
                () {
                  Navigator.pop(context);
                  _openAnalyticsMenu();
                },
              ),
              _buildQuickMenuTile(
                Icons.location_on,
                'Monitoring Lokasi',
                Colors.purple,
                () {
                  Navigator.pop(context);
                  _openLocationMenu();
                },
              ),
              _buildQuickMenuTile(
                Icons.download,
                'Export Laporan',
                Colors.teal,
                () {
                  Navigator.pop(context);
                  _exportData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickMenuTile(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.poppins()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _exportData() async {
    try {
      _generateSessionId();
      await _logSystemActivity('export', 'Export data dimulai');
      _showSuccessSnackbar('Fitur export sedang dalam pengembangan');
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await _showConfirmDialog();
    if (confirm == true) {
      try {
        // Tampilkan loading dialog
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        _generateSessionId();
        await _logSystemActivity('logout', 'User logged out');
        await _auth.signOut();

        if (mounted) {
          Navigator.pop(context); // loading
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showErrorSnackbar('Error: $e');
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC),
      extendBody: true,
      floatingActionButton: totalPending > 0
          ? FloatingActionButton.extended(
              onPressed: _openApprovalMenu,
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.pending_actions),
              label: Text('Approval Lembur ($totalPending)'),
            )
          : FloatingActionButton(
              onPressed: _showQuickActionsMenu,
              backgroundColor: const Color(0xFFFF6B35),
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshData,
              color: const Color(0xFFFF6B35),
              backgroundColor: Colors.white,
              strokeWidth: 2,
              displacement: 40,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _buildSliverAppBar(user),
                  
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Welcome Card
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _buildWelcomeCard(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Quick Stats Grid
                        _buildQuickStatsGrid(),
                        const SizedBox(height: 16),
                        
                        // Key Metrics
                        _buildKeyMetrics(),
                        const SizedBox(height: 16),
                        
                        // Menu Grid (6 menu utama)
                        _buildMenuGrid(),
                        const SizedBox(height: 16),
                        
                        // Analytics Chart
                        _buildAnalyticsSection(),
                        const SizedBox(height: 16),
                        
                        // Pending Summary & Project Stats
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isTablet ? 5 : 6,
                              child: _buildPendingSummary(),
                            ),
                            const SizedBox(width: 12),
                            if (size.width > 400)
                              Expanded(
                                flex: isTablet ? 5 : 4,
                                child: _buildProjectSummary(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Team Summary & Location Monitoring
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildTeamSummary(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _buildLocationMonitoring(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Calendar & Overtime Stats
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildCalendarCard(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _buildOvertimeSummary(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Recent Activities
                        _buildRecentActivities(),
                        const SizedBox(height: 16),
                        
                        // System Health
                        _buildSystemHealth(),
                        const SizedBox(height: 16),
                        
                        // Quick Actions
                        _buildQuickActions(),
                        const SizedBox(height: 16),
                        
                        // Logout Button
                        _buildLogoutButton(),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFFF6B35),
            Color(0xFFFF8C5A),
            Color(0xFFFF6B35),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.elasticOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.manage_accounts,
                      size: 60,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Loading Text
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.white70],
              ).createShader(bounds),
              child: Text(
                'MANAGER DASHBOARD',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            
            // Loading Messages
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: 3),
              duration: const Duration(seconds: 3),
              builder: (context, int value, child) {
                final messages = [
                  'Memuat data tim...',
                  'Menganalisis lembur...',
                  'Menyiapkan dashboard...',
                  'Hampir selesai...',
                ];
                return Text(
                  messages[value],
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(User? user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      snap: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
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
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => _showDrawerMenu(context),
      ),
      actions: [
        // Search Button
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSearchDialog(context),
        ),
        
        // Notifications Button with Badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => _showNotifications(context),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        
        // Profile Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          offset: const Offset(0, 50),
          onSelected: (value) {
            if (value == 'profile') {
              _openProfileMenu();
            } else if (value == 'settings') {
              _openSettingsMenu();
            } else if (value == 'theme') {
              setState(() => isDarkMode = !isDarkMode);
            } else if (value == 'help') {
              _showHelp(context);
            } else if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 18, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Text('Profil Saya', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings, size: 18, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Text('Pengaturan', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'theme',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDarkMode ? 'Light Mode' : 'Dark Mode',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help, size: 18, color: Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  Text('Bantuan', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout, size: 18, color: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  Text('Logout', style: GoogleFonts.poppins(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;

    if (hour < 12) {
      greeting = 'Selamat Pagi';
      emoji = '🌅';
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
      emoji = '☀️';
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
      emoji = '🌆';
    } else {
      greeting = 'Selamat Malam';
      emoji = '🌙';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with animation
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFFF6B35)],
              ),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              backgroundImage: _auth.currentUser?.photoURL != null
                  ? NetworkImage(_auth.currentUser!.photoURL!)
                  : null,
              child: _auth.currentUser?.photoURL == null
                  ? Text(
                      userData['nama_lengkap']?[0]?.toUpperCase() ?? 
                      _auth.currentUser?.email?[0].toUpperCase() ?? 'M',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF6B35),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting + emoji,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userData['nama_lengkap'] ?? 'Manager',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userData['fungsi'] ?? userData['unit'] ?? 'Operation',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('dd/MM/yyyy').format(DateTime.now()),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final stats = [
      {
        'title': 'Tim',
        'value': totalTeamMembers.toString(),
        'icon': Icons.people,
        'color1': const Color(0xFF2196F3),
        'color2': const Color(0xFF64B5F6),
        'subtitle': '$onlineMembers online',
        'trend': '+$onlineMembers',
        'trendUp': true,
      },
      {
        'title': 'Menunggu',
        'value': totalPending.toString(),
        'icon': Icons.pending_actions,
        'color1': const Color(0xFFFF9800),
        'color2': const Color(0xFFFFB74D),
        'subtitle': 'Perlu disetujui',
        'trend': totalPending > 0 ? totalPending.toString() : '0',
        'trendUp': totalPending > 0,
      },
      {
        'title': 'Lembur',
        'value': totalLemburMonth.toString(),
        'icon': Icons.work_history,
        'color1': const Color(0xFF4CAF50),
        'color2': const Color(0xFF81C784),
        'subtitle': '${totalHoursThisMonth.toStringAsFixed(1)} jam',
        'trend': '+$totalLemburMonth',
        'trendUp': true,
      },
      {
        'title': 'Proyek',
        'value': activeProjects.toString(),
        'icon': Icons.assignment,
        'color1': const Color(0xFF9C27B0),
        'color2': const Color(0xFFBA68C8),
        'subtitle': 'Aktif',
        'trend': '+$activeProjects',
        'trendUp': true,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: 0.9 + (value * 0.1),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [stat['color1'] as Color, stat['color2'] as Color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (stat['color1'] as Color).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(stat['icon'] as IconData, color: Colors.white, size: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            stat['trendUp'] as bool
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            stat['trend'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['value'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat['subtitle'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyMetrics() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Key Metrics',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedTimeRange,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  items: const [
                    DropdownMenuItem(value: 'day', child: Text('Hari Ini')),
                    DropdownMenuItem(value: 'week', child: Text('Minggu Ini')),
                    DropdownMenuItem(value: 'month', child: Text('Bulan Ini')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedTimeRange = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricChip(
                  'Jam Lembur',
                  '${totalHoursThisMonth.toStringAsFixed(1)} jam',
                  Icons.access_time,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Batas Lembur',
                  '$overtimeThreshold jam',
                  Icons.timer,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Pengajuan',
                  '${totalApproved + totalRejected + totalPending}',
                  Icons.description,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Disetujui',
                  totalApproved.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Ditolak',
                  totalRejected.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final menus = [
      {'icon': Icons.pending_actions, 'label': 'Persetujuan', 'color': Colors.orange, 'count': totalPending, 'onTap': _openApprovalMenu},
      {'icon': Icons.history, 'label': 'Riwayat', 'color': Colors.blue, 'count': totalApproved, 'onTap': _openHistoryMenu},
      {'icon': Icons.analytics, 'label': 'Analisis', 'color': Colors.green, 'count': activeProjects, 'onTap': _openAnalyticsMenu},
      {'icon': Icons.location_on, 'label': 'Monitoring Lokasi', 'color': Colors.purple, 'count': onlineMembers, 'onTap': _openLocationMenu},
      {'icon': Icons.settings, 'label': 'Pengaturan', 'color': Colors.grey, 'count': 0, 'onTap': _openSettingsMenu},
      {'icon': Icons.person, 'label': 'Profile', 'color': Colors.teal, 'count': 0, 'onTap': _openProfileMenu},
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
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        final color = menu['color'] as Color;
        
        return GestureDetector(
          onTap: menu['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.9),
                  color,
                ],
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
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        menu['icon'] as IconData,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        menu['label'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((menu['count'] as int) > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${menu['count']}',
                        style: GoogleFonts.poppins(
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

  Widget _buildAnalyticsSection() {
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
              Icon(Icons.trending_up, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Tren Lembur 7 Hari Terakhir',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chart
          SizedBox(
            height: 200,
            child: _buildOvertimeChart(),
          ),
          
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Lembur', const Color(0xFFFF6B35)),
              const SizedBox(width: 16),
              _buildLegendItem('Batas', const Color(0xFF4CAF50)),
              const SizedBox(width: 16),
              _buildLegendItem('Rata-rata', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (overtimeThreshold * 1.2).toDouble(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()} jam',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = [
                  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'
                ];
                if (value >= 0 && value < 7) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(7, (index) {
          final overtime = 5 + (math.Random().nextDouble() * 15);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: overtime,
                color: selectedChartIndex == index
                    ? const Color(0xFFFFA500)
                    : const Color(0xFFFF6B35),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: overtimeThreshold.toDouble(),
                color: Colors.grey.withValues(alpha: 0.3),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
            showingTooltipIndicators: selectedChartIndex == index ? [0] : [],
          );
        }),
      ),
    );
  }

  Widget _buildPendingSummary() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pending_actions, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Menunggu Persetujuan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalPending pengajuan',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingLembur.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 40, color: Colors.green[200]),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada pengajuan pending',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...pendingLembur.take(3).map((lembur) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lembur['pengawas_nama'] ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lembur['alasan'] ?? '-',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_toDouble(lembur['total_jam_desimal']).toStringAsFixed(1)} jam',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showDetailDialog(lembur),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Detail'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showApproveDialog(lembur),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Setujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 36),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(lembur),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(80, 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          if (pendingLembur.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: _openApprovalMenu,
                  child: Text('Lihat ${pendingLembur.length - 3} lainnya...'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectSummary() {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Statistik Proyek',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...projectStats.isEmpty
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Belum ada data proyek',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ]
              : projectStats.take(3).map((project) {
                  final totalJam = _toDouble(project['totalJam']);
                  final percentage = totalHoursThisMonth > 0 ? (totalJam / totalHoursThisMonth * 100) : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                project['nama'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${totalJam.toStringAsFixed(1)} jam',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            minHeight: 8,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
          if (projectStats.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: _openAnalyticsMenu,
                  child: const Text('Lihat Detail Analisis'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamSummary() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tim ($totalTeamMembers Anggota)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$onlineMembers Online',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...teamMembers.isEmpty
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Belum ada anggota tim',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ]
              : teamMembers.take(4).map((member) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: member['isOnline'] == true ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['nama'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(member['role']).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  member['role'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: _getRoleColor(member['role']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_toDouble(member['totalLembur']).toStringAsFixed(1)} jam',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (member['isOnline'] == true)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              )),
          if (teamMembers.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: _openLocationMenu,
                  child: const Text('Lihat Semua Tim'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationMonitoring() {
    final anomalyCount = locations.where((l) => l['status'] != 'Normal').length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monitoring Lokasi',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: anomalyCount > 0 ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: anomalyCount > 0 ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${locations.length} Site · $anomalyCount Anomali',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: anomalyCount > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Map
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(-6.2088, 106.8456),
                initialZoom: 10,
                maxZoom: 18,
                minZoom: 3,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (tapPosition, point) {
                  _showLocationInfo(context,
                      'Koordinat: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}');
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: locations.map((location) {
                    return Marker(
                      point: LatLng(location['lat'], location['lng']),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showLocationDetail(context, location),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (location['status'] == 'Anomali')
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.5, end: 1.5),
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeInOut,
                                builder: (context, double scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: location['color'],
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: (location['color'] as Color).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                location['status'] == 'Anomali'
                                    ? Icons.warning
                                    : Icons.location_on,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Location List
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return GestureDetector(
                  onTap: () => _showLocationDetail(context, location),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (location['color'] as Color).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (location['color'] as Color).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: location['color'],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildCalendarCard() {
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
              Icon(Icons.calendar_month, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Kalender',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.now().add(const Duration(days: 3650)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFFF6B35),
                shape: BoxShape.circle,
              ),
              weekendTextStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              defaultTextStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeSummary() {
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
              Icon(Icons.work_history, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOvertimeStatItem(
            'Total Lembur',
            totalLemburMonth.toString(),
            '${totalHoursThisMonth.toStringAsFixed(1)} jam',
            Icons.work_history,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildOvertimeStatItem(
            'Pending',
            totalPending.toString(),
            'Perlu persetujuan',
            Icons.pending,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildOvertimeStatItem(
            'Disetujui',
            totalApproved.toString(),
            '${((totalApproved / (totalLemburMonth + totalRejected + 1)) * 100).toStringAsFixed(1)}% approval rate',
            Icons.check_circle,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildOvertimeStatItem(
            'Ditolak',
            totalRejected.toString(),
            '${((totalRejected / (totalLemburMonth + totalRejected + 1)) * 100).toStringAsFixed(1)}% rejection rate',
            Icons.cancel,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeStatItem(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: const Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Aktivitas Terbaru',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${recentActivities.length} baru',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentActivities.isEmpty
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 50, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ada aktivitas terbaru',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              : recentActivities.take(5).map((activity) {
                  return _buildActivityItem(activity);
                }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] ?? 'info';
    final color = _getActivityColor(type);
    final icon = _getActivityIcon(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['description'] ?? 'No description',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getTimeAgo(activity['timestamp']),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'approve_lembur':
        return Colors.green;
      case 'reject_lembur':
        return Colors.red;
      case 'login':
        return Colors.blue;
      case 'logout':
        return Colors.grey;
      case 'dashboard_view':
      case 'refresh':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'approve_lembur':
        return Icons.check_circle;
      case 'reject_lembur':
        return Icons.cancel;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'dashboard_view':
        return Icons.dashboard;
      case 'refresh':
        return Icons.refresh;
      default:
        return Icons.info;
    }
  }

  Widget _buildSystemHealth() {
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
              Icon(Icons.health_and_safety, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Kesehatan Sistem',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHealthIndicator('Lembur', systemHealth['overtimeRate'] ?? 85, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('Approval', systemHealth['approvalRate'] ?? 92, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('Tim', totalTeamMembers > 0 ? (onlineMembers / totalTeamMembers * 100).round() : 0, Colors.orange),
              const SizedBox(width: 12),
              _buildHealthIndicator('Kinerja', systemHealth['performance'] ?? 95, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '$value%',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
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
              Icon(Icons.flash_on, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(
                'Aksi Cepat',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionItem(Icons.picture_as_pdf, 'PDF', Colors.red, _exportData),
              _buildQuickActionItem(Icons.table_chart, 'Excel', Colors.green, _exportData),
              _buildQuickActionItem(Icons.print, 'Cetak', Colors.blue, _exportData),
              _buildQuickActionItem(Icons.share, 'Bagikan', Colors.orange, _exportData),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf12711), Color(0xFFf5af19)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf12711).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Search Delegate
class ManagerSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = [
      'Approval Lembur',
      'Riwayat Lembur',
      'Analisis Produktivitas',
      'Monitoring Lokasi',
      'Pengaturan',
      'Profil Saya',
      'Tim Saya',
      'Statistik Proyek',
      'Bantuan',
    ].where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Cari menu atau fitur',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 16, color: Color(0xFFFF6B35)),
          ),
          title: Text(
            results[index],
            style: GoogleFonts.poppins(),
          ),
          trailing: const Icon(Icons.arrow_forward, size: 16),
          onTap: () {
            close(context, results[index]);
          },
        );
      },
    );
  }
}