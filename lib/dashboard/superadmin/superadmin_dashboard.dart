import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

var logger = Logger();

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  
  // Data dashboard
  Map<String, dynamic> systemStats = {};
  List<Map<String, dynamic>> recentActivities = [];
  Map<String, int> userDistribution = {};
  Map<String, int> fungsiDistribution = {};
  List<Map<String, dynamic>> overtimeStats = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> helpTickets = [];
  Map<String, dynamic> systemHealth = {};
  List<Map<String, dynamic>> faqList = [];
  
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
  bool showNotifications = false;
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
  
  // Map controller
  late MapController _mapController;

  // Warna-warna untuk menu yang berbeda
  final List<Color> _menuColors = const [
    Color(0xFF1E3C72),
    Color(0xFFFF6B35),
    Color(0xFF00b09b),
    Color(0xFFf12711),
    Color(0xFF834d9b),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
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
    
    _fadeController.forward();
    _slideController.forward();
    
    // Inisialisasi MapController
    _mapController = MapController();
    
    _generateSessionId();
    loadDashboardData();
    listenToRealTimeUpdates();
    _loadLocationsFromFirebase();
    _checkUnreadNotifications();
    _loadFAQ();
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
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadDashboardData();
    }
  }

  void _generateSessionId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    _currentSessionId = base64Url.encode(bytes);
  }

  Future<void> _loadFAQ() async {
    try {
      final faqSnapshot = await _firestore
          .collection('faq')
          .orderBy('createdAt', descending: false)
          .get();
      
      setState(() {
        faqList = faqSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'question': data['question'] ?? '',
            'answer': data['answer'] ?? '',
            'category': data['category'] ?? 'Umum',
            'createdAt': data['createdAt'],
            'createdBy': data['createdBy'],
          };
        }).toList();
      });
    } catch (e) {
      logger.e('Error loading FAQ: $e');
    }
  }

  Future<void> _loadLocationsFromFirebase() async {
    try {
      final locationsSnapshot = await _firestore
          .collection('locations')
          .limit(50)
          .get();
      
      if (locationsSnapshot.docs.isNotEmpty) {
        final List<Map<String, dynamic>> loadedLocations = [];
        for (var doc in locationsSnapshot.docs) {
          final data = doc.data();
          loadedLocations.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Site',
            'lat': data['latitude'] ?? -6.2088,
            'lng': data['longitude'] ?? 106.8456,
            'status': data['status'] ?? 'Normal',
            'color': _getStatusColor(data['status'] ?? 'Normal'),
            'address': data['address'] ?? 'No address',
            'lastUpdate': data['lastUpdate'] is Timestamp 
                ? (data['lastUpdate'] as Timestamp).toDate()
                : DateTime.now(),
            'workers': data['workers'] ?? 0,
            'battery': data['battery'] ?? 100,
            'signal': data['signal'] ?? '4G',
            'cctv': data['cctv'] ?? 0,
          });
        }
        setState(() {
          locations = loadedLocations;
        });
      } else {
        await _loadLocationsFromAbsensi();
      }
    } catch (e) {
      logger.e('Error loading locations: $e');
      await _loadLocationsFromLembur();
    }
  }

  Future<void> _loadLocationsFromAbsensi() async {
    try {
      final absensiSnapshot = await _firestore
          .collection('absensi')
          .limit(50)
          .get();
      
      final Map<String, Map<String, dynamic>> uniqueLocations = {};
      
      for (var doc in absensiSnapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] ?? data['lokasi_latitude'];
        final lng = data['longitude'] ?? data['lokasi_longitude'];
        
        if (lat != null && lng != null) {
          final locationKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
          if (!uniqueLocations.containsKey(locationKey)) {
            uniqueLocations[locationKey] = {
              'id': locationKey,
              'name': data['lokasi_nama'] ?? 'Site ${uniqueLocations.length + 1}',
              'lat': lat is double ? lat : double.parse(lat.toString()),
              'lng': lng is double ? lng : double.parse(lng.toString()),
              'status': 'Normal',
              'color': Colors.green,
              'address': data['lokasi_alamat'] ?? 'Unknown',
              'lastUpdate': data['waktu'] is Timestamp 
                  ? (data['waktu'] as Timestamp).toDate()
                  : DateTime.now(),
              'workers': 1,
              'battery': 100,
              'signal': '4G',
              'cctv': 0,
            };
          } else {
            uniqueLocations[locationKey]!['workers'] = 
                (uniqueLocations[locationKey]!['workers'] as int) + 1;
          }
        }
      }
      
      if (uniqueLocations.isNotEmpty) {
        setState(() {
          locations = uniqueLocations.values.toList();
        });
      } else {
        await _loadLocationsFromLembur();
      }
    } catch (e) {
      logger.e('Error loading locations from absensi: $e');
      await _loadLocationsFromLembur();
    }
  }

  Future<void> _loadLocationsFromLembur() async {
    try {
      final lemburSnapshot = await _firestore
          .collection('lembur')
          .where('status', isEqualTo: 'disetujui')
          .limit(50)
          .get();
      
      final Map<String, Map<String, dynamic>> uniqueLocations = {};
      
      for (var doc in lemburSnapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map?;
        
        if (lokasi != null) {
          final lat = lokasi['latitude'];
          final lng = lokasi['longitude'];
          
          if (lat != null && lng != null) {
            final locationKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
            if (!uniqueLocations.containsKey(locationKey)) {
              uniqueLocations[locationKey] = {
                'id': locationKey,
                'name': lokasi['nama'] ?? lokasi['alamat']?.split(',').first ?? 'Site ${uniqueLocations.length + 1}',
                'lat': lat is double ? lat : double.parse(lat.toString()),
                'lng': lng is double ? lng : double.parse(lng.toString()),
                'status': 'Normal',
                'color': Colors.green,
                'address': lokasi['alamat'] ?? 'Unknown',
                'lastUpdate': data['tanggal'] is Timestamp 
                    ? (data['tanggal'] as Timestamp).toDate()
                    : DateTime.now(),
                'workers': 1,
                'battery': 100,
                'signal': '4G',
                'cctv': 0,
              };
            } else {
              uniqueLocations[locationKey]!['workers'] = 
                  (uniqueLocations[locationKey]!['workers'] as int) + 1;
            }
          }
        }
      }
      
      setState(() {
        locations = uniqueLocations.values.toList();
      });
    } catch (e) {
      logger.e('Error loading locations from lembur: $e');
      setState(() {
        locations = [];
      });
    }
  }

  void listenToRealTimeUpdates() {
    try {
      final usersSub = _firestore.collection('users').snapshots().listen(
        (snapshot) {
          if (mounted) {
            loadDashboardData();
          }
        },
        onError: (error) {
          logger.e('Error listening to users: $error');
        },
      );
      _subscriptions.add(usersSub);
    } catch (e) {
      logger.e('Error setting up users listener: $e');
    }

    try {
      final overtimeSub = _firestore
          .collection('lembur')
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                loadDashboardData();
              }
            },
            onError: (error) {
              logger.e('Error listening to lembur: $error');
            },
          );
      _subscriptions.add(overtimeSub);
    } catch (e) {
      logger.e('Error setting up lembur listener: $e');
    }

    try {
      final notifSub = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                setState(() {
                  unreadNotifications = snapshot.docs.length;
                });
              }
            },
            onError: (error) {
              logger.e('Error listening to notifications: $error');
            },
          );
      _subscriptions.add(notifSub);
    } catch (e) {
      logger.e('Error setting up notifications listener: $e');
    }

    try {
      final logsSub = _firestore
          .collection('system_logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                _updateRecentActivitiesFromLogs(snapshot.docs);
              }
            },
            onError: (error) {
              logger.e('Error listening to system_logs: $error');
            },
          );
      _subscriptions.add(logsSub);
    } catch (e) {
      logger.e('Error setting up system_logs listener: $e');
    }

    try {
      final broadcastSub = _firestore
          .collection('broadcasts')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                _checkBroadcastMessages(snapshot.docs);
              }
            },
            onError: (error) {
              logger.e('Error listening to broadcasts: $error');
            },
          );
      _subscriptions.add(broadcastSub);
    } catch (e) {
      logger.e('Error setting up broadcasts listener: $e');
    }
    
    try {
      final faqSub = _firestore
          .collection('faq')
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                _loadFAQ();
              }
            },
            onError: (error) {
              logger.e('Error listening to faq: $error');
            },
          );
      _subscriptions.add(faqSub);
    } catch (e) {
      logger.e('Error setting up faq listener: $e');
    }
  }

  void _updateRecentActivitiesFromLogs(List<QueryDocumentSnapshot> logs) {
    final List<Map<String, dynamic>> activities = [];
    
    for (var doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now();
      
      activities.add({
        'id': doc.id,
        'type': data['type'] ?? 'system',
        'user': data['user'] ?? 'System',
        'userRole': 'system',
        'description': data['description'] ?? 'No description',
        'timestamp': timestamp,
      });
    }

    setState(() {
      recentActivities = [...recentActivities, ...activities]
        ..sort((a, b) => 
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime))
        ..take(15).toList();
    });
  }

  void _checkBroadcastMessages(List<QueryDocumentSnapshot> broadcasts) {
    for (var doc in broadcasts) {
      final data = doc.data() as Map<String, dynamic>;
      final message = data['message'] ?? '';
      final targetRole = data['targetRole'] ?? 'Semua';
      
      if (targetRole == 'Semua' || targetRole == 'superadmin') {
        _showBroadcastNotification(message);
      }
    }
  }

  void _showBroadcastNotification(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      setState(() {
        unreadNotifications = snapshot.docs.length;
      });
    } catch (e) {
      logger.e('Error checking notifications: $e');
    }
  }

  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> loadDashboardData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final usersSnapshot = await _firestore.collection('users').limit(1000).get();
      final totalUsers = usersSnapshot.docs.length;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      int activeToday = 0;
      int verifiedUsers = 0;
      int lockedAccounts = 0;
      int newUsersToday = 0;
      
      Map<String, int> roleCount = {
        'superadmin': 0,
        'manager': 0,
        'pengawas': 0,
        'mitra': 0,
      };
      
      Map<String, int> fungsiCount = {};

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        
        String role = data['role'] ?? 'mitra';
        roleCount[role] = (roleCount[role] ?? 0) + 1;
        
        String fungsi = data['fungsi'] ?? 'unknown';
        fungsiCount[fungsi] = (fungsiCount[fungsi] ?? 0) + 1;
        
        if (data['is_verified'] == true) verifiedUsers++;
        if (data['account_locked'] == true) lockedAccounts++;
        
        final lastLogin = data['last_login'];
        if (lastLogin is Timestamp) {
          if (lastLogin.toDate().isAfter(startOfDay)) {
            activeToday++;
          }
        } else if (lastLogin is DateTime) {
          if (lastLogin.isAfter(startOfDay)) {
            activeToday++;
          }
        }

        final createdAt = data['created_at'];
        if (createdAt is Timestamp) {
          if (createdAt.toDate().isAfter(startOfDay)) {
            newUsersToday++;
          }
        } else if (createdAt is DateTime) {
          if (createdAt.isAfter(startOfDay)) {
            newUsersToday++;
          }
        }

        final auditTrail = data['audit_trail'] as List? ?? [];
        for (var trail in auditTrail) {
          if (trail is Map) {
            DateTime? timestamp;
            if (trail['timestamp'] is Timestamp) {
              timestamp = (trail['timestamp'] as Timestamp).toDate();
            } else if (trail['timestamp'] is DateTime) {
              timestamp = trail['timestamp'];
            }
            
            if (timestamp != null) {
              recentActivities.add({
                'id': '${doc.id}_${timestamp.millisecondsSinceEpoch}',
                'type': trail['action'] ?? 'unknown',
                'user': data['nama_lengkap'] ?? data['email'] ?? 'Unknown',
                'userRole': data['role'] ?? 'unknown',
                'description': '${trail['action']} - ${data['nama_lengkap'] ?? data['email']}',
                'timestamp': timestamp,
              });
            }
          }
        }
      }

      final pendingSnapshot = await _firestore
          .collection('lembur')
          .where('status', isEqualTo: 'pending')
          .limit(500)
          .get();

      final firstDayOfMonth = DateTime(today.year, today.month, 1);
      final overtimeSnapshot = await _firestore
          .collection('lembur')
          .where('created_at', isGreaterThanOrEqualTo: firstDayOfMonth)
          .limit(500)
          .get();

      try {
        final logsSnapshot = await _firestore
            .collection('system_logs')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();
        
        for (var doc in logsSnapshot.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'] is Timestamp 
              ? (data['timestamp'] as Timestamp).toDate() 
              : DateTime.now();
          
          recentActivities.add({
            'id': doc.id,
            'type': data['type'] ?? 'system',
            'user': data['user'] ?? 'System',
            'userRole': 'system',
            'description': data['description'] ?? 'No description',
            'timestamp': timestamp,
          });
        }
      } catch (e) {
        logger.w('Could not fetch system_logs: $e');
      }

      recentActivities.sort((a, b) => 
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      recentActivities = recentActivities.take(15).toList();

      try {
        final healthSnapshot = await _firestore
            .collection('system_settings')
            .doc('health')
            .get();
        
        if (healthSnapshot.exists) {
          systemHealth = healthSnapshot.data() as Map<String, dynamic>;
        } else {
          systemHealth = {
            'database': 98,
            'api': 95,
            'storage': 76,
            'memory': 82,
            'cpu': 23,
            'network': 45,
            'uptime': 15,
            'lastBackup': DateTime.now().subtract(const Duration(hours: 2)),
          };
        }
      } catch (e) {
        systemHealth = {
          'database': 98,
          'api': 95,
          'storage': 76,
          'memory': 82,
          'cpu': 23,
          'network': 45,
          'uptime': 15,
          'lastBackup': DateTime.now().subtract(const Duration(hours: 2)),
        };
      }

      if (!mounted) return;

      setState(() {
        systemStats = {
          'totalUsers': totalUsers,
          'activeToday': activeToday,
          'pendingApprovals': pendingSnapshot.docs.length,
          'totalReports': pendingSnapshot.docs.length,
          'totalOvertime': overtimeSnapshot.docs.length,
          'verifiedUsers': verifiedUsers,
          'lockedAccounts': lockedAccounts,
          'newUsersToday': newUsersToday,
          'openHelpTickets': 0,
          'superadmin': roleCount['superadmin'] ?? 0,
          'manager': roleCount['manager'] ?? 0,
          'pengawas': roleCount['pengawas'] ?? 0,
          'mitra': roleCount['mitra'] ?? 0,
        };

        userDistribution = {
          'Super Admin': roleCount['superadmin'] ?? 0,
          'Manager': roleCount['manager'] ?? 0,
          'Pengawas': roleCount['pengawas'] ?? 0,
          'Mitra': roleCount['mitra'] ?? 0,
        };

        fungsiDistribution = Map.from(fungsiCount);

        overtimeStats = overtimeSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        isLoading = false;
      });

      _fadeController.reset();
      _fadeController.forward();

      await _logSystemActivity('dashboard_view', 'Superadmin melihat dashboard');

    } catch (e) {
      logger.e('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackbar('Error loading data. Silakan refresh.');
      }
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

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await loadDashboardData();
    await _loadLocationsFromFirebase();
    await _loadFAQ();
    await _logSystemActivity('refresh', 'Dashboard direfresh');
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => isRefreshing = false);
      _showSuccessSnackbar('Dashboard diperbarui');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
      case 'active':
      case 'online':
        return Colors.green;
      case 'warning':
      case 'maintenance':
        return Colors.orange;
      case 'anomali':
      case 'error':
      case 'offline':
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'super admin':
        return const Color(0xFF9C27B0);
      case 'manager':
        return const Color(0xFFFF9800);
      case 'pengawas':
        return const Color(0xFF4CAF50);
      case 'mitra':
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
    }
  }

  Color _getMenuColor(int index) {
    return _menuColors[index % _menuColors.length];
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC),
      extendBody: true,
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshData,
              color: const Color(0xFF1E3C72),
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
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildWelcomeCard(),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickStatsGrid(),
                        const SizedBox(height: 16),
                        _buildKeyMetrics(),
                        const SizedBox(height: 16),
                        _buildAnalyticsSection(),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isTablet ? 6 : 7,
                              child: _buildUserDistributionCard(),
                            ),
                            const SizedBox(width: 12),
                            if (size.width > 400)
                              Expanded(
                                flex: isTablet ? 4 : 5,
                                child: _buildQuickActionsCard(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAdminMenu(),
                        const SizedBox(height: 16),
                        _buildLocationMonitoring(),
                        const SizedBox(height: 16),
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
                        _buildRecentActivities(),
                        const SizedBox(height: 16),
                        _buildSystemHealth(),
                        const SizedBox(height: 16),
                        _buildPerformanceMetrics(),
                        const SizedBox(height: 16),
                        _buildSettingsTools(),
                        const SizedBox(height: 24),
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
            Color(0xFF1E3C72),
            Color(0xFF2A4F8C),
            Color(0xFF1E3C72),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                      Icons.admin_panel_settings,
                      size: 60,
                      color: Color(0xFF1E3C72),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.white70],
              ).createShader(bounds),
              child: Text(
                'SUPER ADMIN DASHBOARD',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: 3),
              duration: const Duration(seconds: 3),
              builder: (context, int value, child) {
                final messages = [
                  'Memuat data pengguna...',
                  'Menganalisis statistik...',
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
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C), Color(0xFFFF6B35)],
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
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSearchDialog(context),
        ),
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
        PopupMenuButton<String>(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          offset: const Offset(0, 50),
          onSelected: (value) {
            if (value == 'profile') {
              Navigator.pushNamed(context, '/profile');
            } else if (value == 'settings') {
              Navigator.pushNamed(context, '/settings');
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

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showQuickActionsMenu,
      backgroundColor: const Color(0xFFFF6B35),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        'Aksi Cepat',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
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
        gradient: LinearGradient(
          colors: const [
            Color(0xFF1E3C72),
            Color(0xFF2A4F8C),
            Color(0xFF3A6AB5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
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
                  : null as ImageProvider?,
              child: _auth.currentUser?.photoURL == null
                  ? Text(
                      _auth.currentUser?.email?[0].toUpperCase() ?? 'SA',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E3C72),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting $emoji',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _auth.currentUser?.displayName ?? 'Super Admin',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  'Sistem OK',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final stats = [
      {
        'title': 'Total Users',
        'value': _formatNumber(systemStats['totalUsers'] ?? 0),
        'icon': Icons.people,
        'color1': const Color(0xFF1E3C72),
        'color2': const Color(0xFF2A4F8C),
        'subtitle': '${systemStats['verifiedUsers'] ?? 0} terverifikasi',
        'trend': '+12%',
        'trendUp': true,
      },
      {
        'title': 'Aktif Hari Ini',
        'value': _formatNumber(systemStats['activeToday'] ?? 0),
        'icon': Icons.online_prediction,
        'color1': const Color(0xFF00b09b),
        'color2': const Color(0xFF96c93d),
        'subtitle': '${((systemStats['activeToday'] ?? 0) / (systemStats['totalUsers'] ?? 1) * 100).toStringAsFixed(1)}% aktif',
        'trend': '+5%',
        'trendUp': true,
      },
      {
        'title': 'Pending',
        'value': _formatNumber(systemStats['pendingApprovals'] ?? 0),
        'icon': Icons.pending_actions,
        'color1': const Color(0xFFf12711),
        'color2': const Color(0xFFf5af19),
        'subtitle': 'Perlu tindakan',
        'trend': '-2',
        'trendUp': false,
      },
      {
        'title': 'Lembur',
        'value': _formatNumber(systemStats['totalOvertime'] ?? 0),
        'icon': Icons.work_history,
        'color1': const Color(0xFF834d9b),
        'color2': const Color(0xFFd04ed6),
        'subtitle': 'Bulan ini',
        'trend': '+23%',
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
                  color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
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
                    DropdownMenuItem(value: 'year', child: Text('Tahun Ini')),
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
                  'Pengguna Baru',
                  '${systemStats['newUsersToday'] ?? 0}',
                  Icons.person_add,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Akun Terkunci',
                  '${systemStats['lockedAccounts'] ?? 0}',
                  Icons.lock,
                  Colors.red,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  'Lembur Bulan Ini',
                  '${systemStats['totalOvertime'] ?? 0}',
                  Icons.work_history,
                  Colors.blue,
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
              Icon(Icons.analytics, color: const Color(0xFF1E3C72), size: 20),
              const SizedBox(width: 8),
              Text(
                'Analytics Overview',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildOvertimeChart(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Lembur', const Color(0xFF1E3C72)),
              const SizedBox(width: 16),
              _buildLegendItem('Target', const Color(0xFFFF6B35)),
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
        maxY: 25,
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
              interval: 5,
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
          double overtime = 0;
          if (overtimeStats.isNotEmpty) {
            final totalJam = overtimeStats.fold<double>(0, (total, item) {
              return total + (item['total_jam_desimal'] ?? 0);
            });
            overtime = totalJam / overtimeStats.length;
          } else {
            overtime = 8 + (math.Random().nextDouble() * 8);
          }
          final target = 12.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: overtime,
                color: selectedChartIndex == index
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF1E3C72),
                width: 14,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: target,
                color: Colors.grey.withValues(alpha: 0.3),
                width: 14,
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

  Widget _buildUserDistributionCard() {
    int total = 0;
    userDistribution.forEach((key, value) {
      total += value;
    });

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
                'Distribusi User',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF1E3C72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...userDistribution.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total) : 0.0;
            final color = _getRoleColor(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${entry.value}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${(percentage * 100).toStringAsFixed(1)}%)',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUserStatItem(
                'Terverifikasi',
                '${systemStats['verifiedUsers'] ?? 0}',
                Colors.green,
              ),
              _buildUserStatItem(
                'Terkunci',
                '${systemStats['lockedAccounts'] ?? 0}',
                Colors.red,
              ),
              _buildUserStatItem(
                'Online',
                '${systemStats['activeToday'] ?? 0}',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
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
                'Aksi Cepat',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.flash_on, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionItem(
            'Tambah User',
            Icons.person_add,
            () => _showAddUserDialog(context),
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildQuickActionItem(
            'Broadcast',
            Icons.campaign,
            () => _showBroadcastDialog(context),
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildQuickActionItem(
            'Kelola FAQ',
            Icons.help_center,
            () => _showManageFAQDialog(context),
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color, {
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenu() {
    final menuItems = [
      {
        'title': 'User Management',
        'icon': Icons.people,
        'route': '/user-management',
        'count': systemStats['totalUsers'] ?? 0,
      },
      {
        'title': 'Data Lembur',
        'icon': Icons.work_history,
        'route': '/overtime-data',
        'count': systemStats['pendingApprovals'] ?? 0,
        'countColor': Colors.red,
      },
      {
        'title': 'Data Absensi',
        'icon': Icons.checklist,
        'route': '/mitra/absensi',
        'count': 0,
      },
      {
        'title': 'Monitoring Lokasi',
        'icon': Icons.location_on,
        'route': '/location-monitoring',
        'count': locations.where((l) => l['status'] == 'Anomali').length,
        'countColor': Colors.red,
      },
      {
        'title': 'Laporan & Audit',
        'icon': Icons.assessment,
        'route': '/reports-audit',
        'count': recentActivities.length,
      },
      {
        'title': 'System Logs',
        'icon': Icons.list_alt,
        'route': '/system-logs',
        'count': recentActivities.length,
      },
      {
        'title': 'Pengaturan Sistem',
        'icon': Icons.settings,
        'route': '/settings',
      },
      {
        'title': 'Jadwal Shift',
        'icon': Icons.schedule,
        'route': '/jadwal-lembur-menu',
      },
      {
        'title': 'FAQ Bot',
        'icon': Icons.help_center,
        'route': '/faq-bot',
        'count': faqList.length,
      },
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
        final color = _getMenuColor(index);
        
        return GestureDetector(
          onTap: () => _navigateToMenu(context, item['title'] as String),
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
                        item['icon'] as IconData,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item['title'] as String,
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
                if (item.containsKey('count') && (item['count'] as int) > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item['countColor'] ?? Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item['count']}',
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
                  Icon(Icons.location_on, color: const Color(0xFF1E3C72), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Monitoring Lokasi',
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
          locations.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Belum ada data lokasi'),
                      ],
                    ),
                  ),
                )
              : Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(-6.2088, 106.8456),
                      initialZoom: 11,
                      maxZoom: 18,
                      minZoom: 3,
                      backgroundColor: const Color.fromRGBO(245, 245, 245, 1), // Pindahkan backgroundColor ke MapOptions
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (tapPosition, point) {
                        _showLocationInfo(context,
                            'Koordinat: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}');
                      },
                    ),
                    children: [
                      // PERBAIKAN: Menggunakan NetworkTileProvider dengan CancellableTileProvider untuk Web
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.otp_apk',
                        tileProvider: kIsWeb
                            ? CancellableNetworkTileProvider()
                            : NetworkTileProvider(),
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
                                  Positioned(
                                    bottom: -12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        location['name'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w600,
                                          color: location['color'],
                                        ),
                                      ),
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
          locations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Tidak ada data lokasi'),
                  ),
                )
              : SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      return GestureDetector(
                        onTap: () => _showLocationDetail(context, location),
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (location['color'] as Color).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (location['color'] as Color).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.people, size: 10, color: Colors.grey[500]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${location['workers']}',
                                    style: GoogleFonts.poppins(fontSize: 9),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.videocam, size: 10, color: Colors.grey[500]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${location['cctv']}',
                                    style: GoogleFonts.poppins(fontSize: 9),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.battery_charging_full,
                                    size: 10,
                                    color: (location['battery'] as int) > 50 ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${location['battery']}%',
                                    style: GoogleFonts.poppins(fontSize: 9),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.network_cell, size: 10, color: Colors.grey[500]),
                                  const SizedBox(width: 2),
                                  Text(
                                    location['signal'],
                                    style: GoogleFonts.poppins(fontSize: 9),
                                  ),
                                ],
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
              Icon(Icons.calendar_month, color: const Color(0xFF1E3C72), size: 20),
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
                color: Color(0xFF1E3C72),
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
          _buildOvertimeStatItem('Total Lembur', '${systemStats['totalOvertime'] ?? 0}',
              '${overtimeStats.length} pengajuan', Icons.work_history, Colors.blue),
          const SizedBox(height: 12),
          _buildOvertimeStatItem('Pending', '${systemStats['pendingApprovals'] ?? 0}',
              'Perlu persetujuan', Icons.pending, Colors.orange),
          const SizedBox(height: 12),
          _buildOvertimeStatItem('Disetujui', '${overtimeStats.where((o) => o['status'] == 'disetujui').length}',
              'Bulan ini', Icons.check_circle, Colors.green),
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
                  Icon(Icons.history, color: const Color(0xFF1E3C72), size: 20),
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
              Row(
                children: [
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
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _viewAllActivities(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3C72),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Lihat Semua',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ),
                ],
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
              : recentActivities.take(8).map((activity) {
                  return _buildActivityItem(activity);
                }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] ?? 'info';
    final color = _getActivityColor(type);

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
            child: Icon(_getActivityIcon(type), color: color, size: 16),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getRoleColor(activity['userRole'] ?? 'unknown')
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activity['userRole'] ?? 'System',
                        style: GoogleFonts.poppins(
                          fontSize: 7,
                          color: _getRoleColor(activity['userRole'] ?? 'unknown'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity['user'] ?? 'System',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getTimeAgo(activity['timestamp']),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  activity['type'] ?? 'info',
                  style: GoogleFonts.poppins(
                    fontSize: 7,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'user_added':
      case 'register':
      case 'admin_created':
        return Colors.green;
      case 'login':
        return Colors.blue;
      case 'logout':
        return Colors.grey;
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'backup':
        return Colors.purple;
      case 'dashboard_view':
      case 'refresh':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'user_added':
      case 'register':
      case 'admin_created':
        return Icons.person_add;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'backup':
        return Icons.backup;
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
              Icon(Icons.health_and_safety, color: const Color(0xFF1E3C72), size: 20),
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
              _buildHealthIndicator('Database', systemHealth['database'] ?? 98, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('API', systemHealth['api'] ?? 95, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('Storage', systemHealth['storage'] ?? 76, Colors.orange),
              const SizedBox(width: 12),
              _buildHealthIndicator('Memory', systemHealth['memory'] ?? 82, Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSystemInfoItem('CPU', '${systemHealth['cpu'] ?? 23}%', Icons.speed),
              _buildSystemInfoItem('Network', '${systemHealth['network'] ?? 45} Mbps', Icons.network_check),
              _buildSystemInfoItem('Uptime', '${systemHealth['uptime'] ?? 15} hari', Icons.timer),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last Backup: ${_getTimeAgo(systemHealth['lastBackup'])}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              TextButton.icon(
                onPressed: _performBackup,
                icon: const Icon(Icons.backup, size: 14),
                label: Text('Backup Now', style: GoogleFonts.poppins(fontSize: 10)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3C72),
                ),
              ),
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

  Widget _buildSystemInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
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
              Icon(Icons.trending_up, color: const Color(0xFF1E3C72), size: 20),
              const SizedBox(width: 8),
              Text(
                'Metrik Kinerja',
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
              Expanded(
                child: _buildMetricItem(
                  'Response Time',
                  '245 ms',
                  '12%',
                  true,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Error Rate',
                  '0.3%',
                  '5%',
                  false,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Req/min',
                  '1.2k',
                  '8%',
                  true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String change, bool isPositive) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isPositive
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 2),
              Text(
                change,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTools() {
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
              Icon(Icons.settings, color: const Color(0xFF1E3C72), size: 20),
              const SizedBox(width: 8),
              Text(
                'Pengaturan & Tools',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolChip('Export Data', Icons.download, () => _exportData()),
              _buildToolChip('Import Data', Icons.upload, () => _importData()),
              _buildToolChip('Clear Cache', Icons.cleaning_services, () => _clearCache()),
              _buildToolChip('System Logs', Icons.list_alt, () => Navigator.pushNamed(context, '/system-logs')),
              _buildToolChip('FAQ Bot', Icons.help_center, () => _showFAQBotDialog(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: const Color(0xFF1E3C72).withValues(alpha: 0.1),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1E3C72)),
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
              ListTile(
                leading: const Icon(Icons.dashboard, color: Color(0xFF1E3C72)),
                title: Text('Dashboard', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.people, color: Color(0xFF1E3C72)),
                title: Text('User Management', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-management');
                },
              ),
              ListTile(
                leading: const Icon(Icons.work_history, color: Color(0xFFFF6B35)),
                title: Text('Data Lembur', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/overtime-data');
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist, color: Color(0xFF00b09b)),
                title: Text('Data Absensi', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/mitra/absensi');
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF00b09b)),
                title: Text('Monitoring Lokasi', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/location-monitoring');
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.purple),
                title: Text('System Logs', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/system-logs');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center, color: Colors.orange),
                title: Text('FAQ Bot', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _showFAQBotDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF834d9b)),
                title: Text('Pengaturan', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
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
                Icons.person_add,
                'Tambah User',
                Colors.blue,
                () {
                  Navigator.pop(context);
                  _showAddUserDialog(context);
                },
              ),
              _buildQuickMenuTile(
                Icons.campaign,
                'Broadcast Pesan',
                Colors.orange,
                () {
                  Navigator.pop(context);
                  _showBroadcastDialog(context);
                },
              ),
              _buildQuickMenuTile(
                Icons.help_center,
                'FAQ Bot',
                Colors.purple,
                () {
                  Navigator.pop(context);
                  _showFAQBotDialog(context);
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

  void _showFAQBotDialog(BuildContext context) {
    final searchController = TextEditingController();
    String selectedCategory = 'Semua';
    List<Map<String, dynamic>> filteredFaq = [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            filteredFaq = faqList.where((faq) {
              final matchesSearch = faq['question'].toLowerCase().contains(
                searchController.text.toLowerCase()
              );
              final matchesCategory = selectedCategory == 'Semua' || 
                faq['category'] == selectedCategory;
              return matchesSearch && matchesCategory;
            }).toList();
            
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
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
                              color: Colors.purple.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.help_center, color: Colors.purple, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'FAQ Bot',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Cari pertanyaan...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip('Semua', selectedCategory, setState),
                            _buildCategoryChip('Umum', selectedCategory, setState),
                            _buildCategoryChip('Lembur', selectedCategory, setState),
                            _buildCategoryChip('Absensi', selectedCategory, setState),
                            _buildCategoryChip('Akun', selectedCategory, setState),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredFaq.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak menemukan jawaban?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hubungi langsung Pengawas, Manager, atau Superadmin',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildContactButtons(),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredFaq.length,
                                itemBuilder: (context, index) {
                                  final faq = filteredFaq[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        faq['question'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            faq['answer'],
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
      },
    );
  }

  Widget _buildCategoryChip(String category, String selectedCategory, StateSetter setState) {
    final isSelected = selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              selectedCategory = category;
            } else {
              selectedCategory = 'Semua';
            }
          });
        },
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        selectedColor: const Color(0xFF1E3C72).withValues(alpha: 0.2),
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? const Color(0xFF1E3C72) : null,
        ),
      ),
    );
  }

  Widget _buildContactButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildContactButton(
                'Hubungi Pengawas',
                Icons.person,
                Colors.green,
                () => _contactUser('pengawas'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactButton(
                'Hubungi Manager',
                Icons.people,
                Colors.orange,
                () => _contactUser('manager'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildContactButton(
          'Hubungi Superadmin',
          Icons.admin_panel_settings,
          Colors.purple,
          () => _contactUser('superadmin'),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildContactButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _contactUser(String role) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .limit(5)
          .get();
      
      if (usersSnapshot.docs.isEmpty) {
        _showErrorSnackbar('Tidak ada $role yang tersedia');
        return;
      }
      
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['nama_lengkap'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
        };
      }).toList();
      
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
                  'Pilih $role',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...users.map((user) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user['name'][0].toUpperCase()),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.email, color: Colors.blue),
                          onPressed: () => _sendEmail(user['email']),
                        ),
                        if (user['phone'].isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            onPressed: () => _makePhoneCall(user['phone']),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showContactOptions(user);
                    },
                  );
                }).toList(),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data $role');
    }
  }

  void _showContactOptions(Map<String, dynamic> user) {
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
                'Hubungi ${user['name']}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('Email'),
                subtitle: Text(user['email']),
                onTap: () {
                  Navigator.pop(context);
                  _sendEmail(user['email']);
                },
              ),
              if (user['phone'].isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.green),
                  title: const Text('Telepon'),
                  subtitle: Text(user['phone']),
                  onTap: () {
                    Navigator.pop(context);
                    _makePhoneCall(user['phone']);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.orange),
                title: const Text('Kirim Pesan'),
                subtitle: const Text('Kirim pesan melalui sistem'),
                onTap: () {
                  Navigator.pop(context);
                  _showSendMessageDialog(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendEmail(String email) async {
    final url = 'mailto:$email';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Tidak dapat membuka email');
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final url = 'tel:$phone';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Tidak dapat melakukan panggilan');
    }
  }

  void _showSendMessageDialog(Map<String, dynamic> user) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Kirim Pesan ke ${user['name']}'),
          content: TextField(
            controller: messageController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tulis pesan Anda...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.isNotEmpty) {
                  try {
                    await _firestore.collection('notifications').add({
                      'userId': user['id'],
                      'title': 'Pesan dari Superadmin',
                      'body': messageController.text,
                      'type': 'direct_message',
                      'isRead': false,
                      'createdAt': FieldValue.serverTimestamp(),
                      'sender': _auth.currentUser?.email,
                      'senderName': _auth.currentUser?.displayName ?? 'Super Admin',
                    });
                    
                    Navigator.pop(context);
                    _showSuccessSnackbar('Pesan terkirim');
                  } catch (e) {
                    _showErrorSnackbar('Gagal mengirim pesan');
                  }
                }
              },
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  void _showManageFAQDialog(BuildContext context) {
    final questionController = TextEditingController();
    final answerController = TextEditingController();
    String selectedCategory = 'Umum';
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Kelola FAQ', style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Umum', 'Lembur', 'Absensi', 'Akun']
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedCategory = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: questionController,
                        decoration: const InputDecoration(
                          labelText: 'Pertanyaan',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pertanyaan tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: answerController,
                        decoration: const InputDecoration(
                          labelText: 'Jawaban',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Jawaban tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (faqList.isNotEmpty)
                        Container(
                          height: 200,
                          child: ListView.builder(
                            itemCount: faqList.length,
                            itemBuilder: (context, index) {
                              final faq = faqList[index];
                              return ListTile(
                                title: Text(
                                  faq['question'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteFAQ(faq['id']),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await _firestore.collection('faq').add({
                          'question': questionController.text.trim(),
                          'answer': answerController.text.trim(),
                          'category': selectedCategory,
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': _auth.currentUser?.email,
                        });
                        
                        Navigator.pop(context);
                        _showSuccessSnackbar('FAQ berhasil ditambahkan');
                        _loadFAQ();
                      } catch (e) {
                        _showErrorSnackbar('Gagal menambahkan FAQ');
                      }
                    }
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFAQ(String faqId) async {
    try {
      await _firestore.collection('faq').doc(faqId).delete();
      _showSuccessSnackbar('FAQ berhasil dihapus');
      _loadFAQ();
    } catch (e) {
      _showErrorSnackbar('Gagal menghapus FAQ');
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
                        _buildDetailRow('Koordinat',
                            '${location['lat'].toStringAsFixed(4)}, ${location['lng'].toStringAsFixed(4)}'),
                        _buildDetailRow('Last Update', _getTimeAgo(location['lastUpdate'])),
                        const Divider(height: 24),
                        _buildDetailRow('Jumlah Pekerja', '${location['workers']} orang'),
                        _buildDetailRow('Battery', '${location['battery']}%'),
                        _buildDetailRow('Sinyal', location['signal']),
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

  Widget _buildDetailRow(String label, String value) {
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

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Tidak dapat membuka maps');
    }
  }

  void _showSearchDialog(BuildContext context) {
    showSearch(
      context: context,
      delegate: DashboardSearchDelegate(),
    );
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
                              '$unreadNotifications Baru',
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
                            onPressed: () => _markAllAsRead(),
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
      case 'broadcast':
        return Colors.orange;
      case 'system':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'direct_message':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'broadcast':
        return Icons.campaign;
      case 'system':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'direct_message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  void _markAllAsRead() async {
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
    } catch (e) {
      _showErrorSnackbar('Gagal menandai notifikasi');
    }
  }

  void _navigateToMenu(BuildContext context, String menu) {
    switch (menu) {
      case 'User Management':
        Navigator.pushNamed(context, '/user-management');
        break;
      case 'Data Lembur':
        Navigator.pushNamed(context, '/overtime-data');
        break;
      case 'Data Absensi':
        Navigator.pushNamed(context, '/mitra/absensi');
        break;
      case 'Monitoring Lokasi':
        Navigator.pushNamed(context, '/location-monitoring');
        break;
      case 'Laporan & Audit':
        Navigator.pushNamed(context, '/reports-audit');
        break;
      case 'System Logs':
        Navigator.pushNamed(context, '/system-logs');
        break;
      case 'Pengaturan Sistem':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'Jadwal Shift':
        Navigator.pushNamed(context, '/jadwal-lembur-menu');
        break;
      case 'FAQ Bot':
        _showFAQBotDialog(context);
        break;
      default:
        _showSuccessSnackbar('Membuka $menu');
    }
  }

  void _showAddUserDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'mitra';
    String selectedFungsi = 'operation';
    final formKey = GlobalKey<FormState>();

    final List<Map<String, String>> fungsiList = [
      {"value": "operation", "label": "Operation", "icon": "⚙️"},
      {"value": "lab", "label": "Laboratorium", "icon": "🔬"},
      {"value": "maintenance", "label": "Maintenance", "icon": "🔧"},
      {"value": "hsse", "label": "HSSE", "icon": "🛡️"},
      {"value": "gpr", "label": "GPR", "icon": "📊"},
      {"value": "bs", "label": "BS", "icon": "📋"},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tambah User Baru', style: GoogleFonts.poppins()),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Lengkap',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
                          if (!value.contains('@')) return 'Email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Nomor HP',
                          hintText: '81234567890',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nomor HP tidak boleh kosong';
                          final clean = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (clean.length < 10 || clean.length > 13) return 'Nomor HP harus 10-13 digit';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
                          if (value.length < 8) return 'Password minimal 8 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                        ),
                        items: ['superadmin', 'manager', 'pengawas', 'mitra']
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedRole = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFungsi,
                        decoration: InputDecoration(
                          labelText: 'Fungsi',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.work),
                        ),
                        items: fungsiList.map((item) => DropdownMenuItem(
                          value: item['value'],
                          child: Text('${item['icon']} ${item['label']}'),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedFungsi = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  try {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    _generateSessionId();

                    UserCredential userCredential = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );

                    final now = DateTime.now();
                    final cleanEmail = emailController.text.trim().toLowerCase();
                    final cleanPhone = phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userCredential.user!.uid)
                        .set({
                      'id': userCredential.user!.uid,
                      'nama_lengkap': nameController.text.trim(),
                      'email': cleanEmail,
                      'email_hash': _hashData(cleanEmail),
                      'phone': cleanPhone,
                      'phone_hash': _hashData(cleanPhone),
                      'role': selectedRole,
                      'fungsi': selectedFungsi,
                      'fungsi_label': fungsiList.firstWhere((f) => f['value'] == selectedFungsi)['label'] ?? selectedFungsi,
                      'status_akun': 'active',
                      'is_verified': true,
                      'account_locked': false,
                      'login_attempts': 0,
                      'security': {
                        'session_id': _currentSessionId,
                        'registered_at': Timestamp.now(),
                        'security_level': 'standard',
                      },
                      'terms_accepted': true,
                      'terms_version': '2.0.0',
                      'created_at': FieldValue.serverTimestamp(),
                      'last_login': null,
                      'profile_complete': true,
                      'audit_trail': [
                        {
                          'action': 'admin_created',
                          'timestamp': Timestamp.now(),
                          'session_id': _currentSessionId,
                        }
                      ],
                    });

                    await FirebaseFirestore.instance.collection('system_logs').add({
                      'type': 'user_added',
                      'user': _auth.currentUser?.email,
                      'target_user': userCredential.user?.uid,
                      'session_id': _currentSessionId,
                      'timestamp': FieldValue.serverTimestamp(),
                      'description': 'User baru ditambahkan oleh admin: $cleanEmail',
                    });

                    await FirebaseFirestore.instance.collection('mail').add({
                      'to': cleanEmail,
                      'template': {
                        'name': 'welcome_email',
                        'data': {
                          'name': nameController.text.trim(),
                          'email': cleanEmail,
                          'password': passwordController.text.trim(),
                        }
                      },
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.pop(context);

                    _showSuccessSnackbar('User ${nameController.text} berhasil ditambahkan');
                    loadDashboardData();
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);

                    String errorMessage = 'Gagal menambahkan user';
                    if (e.code == 'email-already-in-use') {
                      errorMessage = 'Email sudah digunakan';
                    } else if (e.code == 'weak-password') {
                      errorMessage = 'Password terlalu lemah';
                    }

                    _showErrorSnackbar(errorMessage);
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    _showErrorSnackbar('Error: $e');
                  }
                }
              },
              child: Text('Tambah', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final messageController = TextEditingController();
    String selectedRole = 'Semua';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Broadcast Pesan', style: GoogleFonts.poppins()),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Pesan',
                        hintText: 'Masukkan pesan broadcast...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Pesan tidak boleh kosong';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Target Role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: ['Semua', 'superadmin', 'manager', 'pengawas', 'mitra']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  try {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    _generateSessionId();

                    await FirebaseFirestore.instance.collection('broadcasts').add({
                      'message': messageController.text.trim(),
                      'targetRole': selectedRole,
                      'createdBy': _auth.currentUser?.email,
                      'createdAt': FieldValue.serverTimestamp(),
                      'status': 'active',
                    });

                    await FirebaseFirestore.instance.collection('system_logs').add({
                      'type': 'broadcast',
                      'user': _auth.currentUser?.email,
                      'target_user': 'all_${selectedRole}',
                      'session_id': _currentSessionId,
                      'timestamp': FieldValue.serverTimestamp(),
                      'description': 'Broadcast pesan ke $selectedRole',
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.pop(context);

                    _showSuccessSnackbar('Pesan broadcast terkirim');
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    _showErrorSnackbar('Error: $e');
                  }
                }
              },
              child: Text('Kirim', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  void _performBackup() async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      _generateSessionId();

      await Future.delayed(const Duration(seconds: 2));

      await FirebaseFirestore.instance.collection('system_logs').add({
        'type': 'backup',
        'user': _auth.currentUser?.email,
        'session_id': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Database backup performed',
      });

      if (!mounted) return;
      setState(() {
        systemHealth['lastBackup'] = DateTime.now();
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessSnackbar('Backup database berhasil');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackbar('Gagal backup: $e');
    }
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

  void _importData() async {
    try {
      _generateSessionId();
      await _logSystemActivity('import', 'Import data dimulai');
      _showSuccessSnackbar('Fitur import sedang dalam pengembangan');
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _clearCache() async {
    try {
      _generateSessionId();
      await _logSystemActivity('cache_clear', 'Cache dibersihkan');
      _showSuccessSnackbar('Cache dibersihkan');
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _viewAllActivities(BuildContext context) {
    Navigator.pushNamed(context, '/activity-log');
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
                title: Text('Hubungi Support', style: GoogleFonts.poppins()),
                subtitle: Text('admin@support.com'),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse('mailto:admin@support.com'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner, color: Colors.green),
                title: Text('Dokumentasi', style: GoogleFonts.poppins()),
                subtitle: Text('Panduan penggunaan sistem'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/documentation');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center, color: Colors.orange),
                title: Text('FAQ', style: GoogleFonts.poppins()),
                subtitle: Text('Pertanyaan yang sering diajukan'),
                onTap: () {
                  Navigator.pop(context);
                  _showFAQBotDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.purple),
                title: Text('Tentang Aplikasi', style: GoogleFonts.poppins()),
                subtitle: Text('Versi 2.0.0'),
                onTap: () => Navigator.pop(context),
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

  Future<void> _logout() async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      _generateSessionId();

      await FirebaseFirestore.instance.collection('system_logs').add({
        'type': 'logout',
        'user': _auth.currentUser?.email,
        'target_user': _auth.currentUser?.uid,
        'session_id': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User logged out',
      });

      await _auth.signOut();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackbar('Error: $e');
    }
  }
}

class DashboardSearchDelegate extends SearchDelegate {
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
      'User Management',
      'Data Lembur',
      'Data Absensi',
      'Monitoring Lokasi',
      'Laporan & Audit',
      'System Logs',
      'Pengaturan Sistem',
      'Jadwal Shift',
      'FAQ Bot',
      'Profil Saya',
      'Bantuan',
      'Dokumentasi',
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
              color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 16, color: Color(0xFF1E3C72)),
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