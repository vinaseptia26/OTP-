import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

// Import screen untuk ajukan lembur
import '../pengawas/ajukan_lembur.dart';

var logger = Logger();

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() => _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Data
  Map<String, dynamic> userData = {};
  List<Map<String, dynamic>> pendingLembur = [];
  List<Map<String, dynamic>> recentLembur = [];
  List<Map<String, dynamic>> ongoingLembur = [];
  List<Map<String, dynamic>> teamMembers = [];
  List<Map<String, dynamic>> locations = [];
  
  // Stats
  int totalLemburToday = 0;
  int totalLemburWeek = 0;
  int pendingApproval = 0;
  int activeTeam = 0;
  
  // Check-in/out
  bool _isCheckedIn = false;
  Map<String, dynamic>? _activeLembur;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  // UI State
  bool isLoading = true;
  bool isRefreshing = false;
  int unreadNotifications = 0;
  String? _currentSessionId;
  
  // Error handling
  List<Map<String, dynamic>> _recentErrors = [];
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  
  // Refresh indicator
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = 
      GlobalKey<RefreshIndicatorState>();
  
  // Calendar
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  
  // Map
  final MapController _mapController = MapController();
  
  // Stream subscriptions
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // ==================== DEFINISI WARNA ====================
  static const Color merahCerah = Color(0xFFFF5252);
  static const Color merahMuda = Color(0xFFFF4081);
  static const Color unguCerah = Color(0xFF7C4DFF);
  static const Color unguMuda = Color(0xFFB388FF);
  static const Color biruCerah = Color(0xFF448AFF);
  static const Color biruMuda = Color(0xFF83B9FF);
  static const Color cyanCerah = Color(0xFF18FFFF);
  static const Color cyanMuda = Color(0xFF84FFFF);
  static const Color hijauCerah = Color(0xFF69F0AE);
  static const Color hijauMuda = Color(0xFFB9F6CA);
  static const Color kuningCerah = Color(0xFFFFD740);
  static const Color kuningMuda = Color(0xFFFFE57F);
  static const Color orangeCerah = Color(0xFFFFAB40);
  static const Color orangeMuda = Color(0xFFFFD180);
  static const Color pinkCerah = Color(0xFFFF80AB);
  static const Color pinkMuda = Color(0xFFFFB2DD);
  
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color darkPurple = Color(0xFF4A148C);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color darkRed = Color(0xFFB71C1C);
  static const Color darkOrange = Color(0xFFE65100);
  static const Color darkGrey = Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _initializeControllers();
    _generateSessionId();
    _initializeData();
  }

  void _initializeControllers() {
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
  }

  void _initializeData() {
    _loadUserData();
    _loadTeamMembers();
    _checkActiveLembur();
    _listenToRealTimeUpdates();
    _initSampleLocations();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLemburData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== SESSION MANAGEMENT ====================
  void _generateSessionId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    _currentSessionId = base64Url.encode(bytes);
  }

  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ==================== ERROR HANDLING ====================
  Future<void> _handleError(String operation, dynamic error, {StackTrace? stackTrace}) async {
    final errorDetails = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'operation': operation,
      'error': error.toString(),
      'timestamp': DateTime.now(),
      'stackTrace': stackTrace?.toString() ?? '',
      'userId': _auth.currentUser?.uid,
      'sessionId': _currentSessionId,
    };
    
    setState(() {
      _recentErrors.insert(0, errorDetails);
      if (_recentErrors.length > 20) {
        _recentErrors.removeLast();
      }
    });
    
    // Log ke Firebase - TAPI HANYA JIKA MEMILIKI PERMISSION
    try {
      // Cek apakah user masih login dan memiliki permission
      if (_auth.currentUser != null) {
        await _firestore.collection('error_logs').add({
          ...errorDetails,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silent fail - jangan log error lagi karena bisa infinite loop
      logger.d('Failed to log error to Firebase: $e');
    }
    
    logger.e('Error in $operation: $error');
  }

  void _showErrorDialog(String operation, dynamic error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: merahCerah.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error, color: merahCerah),
            ),
            const SizedBox(width: 12),
            Text('Error Detail', style: GoogleFonts.poppins()),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: merahCerah.withAlpha(77)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: merahCerah.withAlpha(13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: merahCerah, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        operation,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: darkRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [biruCerah, unguCerah],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    if (_recentErrors.isEmpty) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: merahCerah.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: merahCerah.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: merahCerah),
              const SizedBox(width: 8),
              Text(
                'Terjadi ${_recentErrors.length} error',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: darkRed,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showErrorListDialog(),
                child: Text(
                  'Lihat Detail',
                  style: GoogleFonts.poppins(color: merahCerah),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showErrorListDialog() {
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: merahCerah.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error, color: merahCerah),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Daftar Error',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _recentErrors.length,
                      itemBuilder: (context, index) {
                        final error = _recentErrors[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: merahCerah.withAlpha(77)),
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: merahCerah.withAlpha(26),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.error, color: merahCerah, size: 16),
                            ),
                            title: Text(
                              error['operation'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: darkBlue,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy HH:mm:ss').format(error['timestamp'] as DateTime),
                              style: GoogleFonts.poppins(fontSize: 10),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  error['error'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: darkRed,
                                  ),
                                ),
                              ),
                              if (error['stackTrace'].isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    error['stackTrace'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.grey[300],
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
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userData = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        });
      }
    } catch (e, stack) {
      await _handleError('loadUserData', e, stackTrace: stack);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mitra')
          .limit(100)
          .get();

      final members = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        return {
          'id': doc.id,
          'nama': data['nama_lengkap'] ?? data['email'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'status': data['status_akun'] ?? 'active',
          'isOnline': data['isOnline'] ?? false,
          'lastLocation': data['lastLocation'] ?? null,
          'fungsi': data['fungsi'] ?? 'operation',
        };
      }).toList();

      setState(() {
        teamMembers = members;
        activeTeam = members.where((m) => m['isOnline'] == true).length;
      });
    } catch (e, stack) {
      await _handleError('loadTeamMembers', e, stackTrace: stack);
    }
  }

  Future<void> _loadLemburData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

      final lemburSnapshot = await _firestore
          .collection('lembur')
          .where('pengawas_id', isEqualTo: user.uid) // PERBAIKAN: created_by -> pengawas_id
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      _processLemburData(lemburSnapshot, startOfDay, startOfWeek);
    } catch (e, stack) {
      await _handleError('loadLemburData', e, stackTrace: stack);
      _loadLemburDataFallback(user.uid);
    }
  }

  void _processLemburData(QuerySnapshot snapshot, DateTime startOfDay, DateTime startOfWeek) {
    try {
      List<Map<String, dynamic>> pending = [];
      List<Map<String, dynamic>> recent = [];
      List<Map<String, dynamic>> ongoing = [];
      
      int todayCount = 0;
      int weekCount = 0;

      for (var doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        
        final lemburDate = (data['tanggal'] as Timestamp).toDate();
        
        if (lemburDate.isAfter(startOfDay) || 
            DateUtils.isSameDay(lemburDate, startOfDay)) {
          todayCount++;
        }
        if (lemburDate.isAfter(startOfWeek) || 
            DateUtils.isSameDay(lemburDate, startOfWeek)) {
          weekCount++;
        }

        final status = data['status']?.toString().toLowerCase() ?? 'pending';
        if (status == 'pending') {
          pending.add(data);
        } else if (status == 'disetujui' || status == 'approved') { // PERBAIKAN: sesuai rules
          if (data['check_in'] != null && data['check_out'] == null) {
            ongoing.add(data);
          }
          recent.add(data);
        } else {
          recent.add(data);
        }
      }

      setState(() {
        pendingLembur = pending;
        recentLembur = recent.take(10).toList();
        ongoingLembur = ongoing;
        totalLemburToday = todayCount;
        totalLemburWeek = weekCount;
        pendingApproval = pending.length;
      });
    } catch (e, stack) {
      _handleError('processLemburData', e, stackTrace: stack);
    }
  }

  Future<void> _loadLemburDataFallback(String userId) async {
    try {
      final fallbackSnapshot = await _firestore
          .collection('lembur')
          .where('pengawas_id', isEqualTo: userId) // PERBAIKAN: created_by -> pengawas_id
          .limit(50)
          .get();
          
      List<Map<String, dynamic>> pending = [];
      List<Map<String, dynamic>> recent = [];
      
      for (var doc in fallbackSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        
        if (data['status'] == 'pending') {
          pending.add(data);
        } else {
          recent.add(data);
        }
      }
      
      setState(() {
        pendingLembur = pending;
        recentLembur = recent;
        pendingApproval = pending.length;
      });
    } catch (e, stack) {
      await _handleError('loadLemburDataFallback', e, stackTrace: stack);
    }
  }

  Future<void> _checkActiveLembur() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('lembur')
          .where('pengawas_id', isEqualTo: user.uid) // PERBAIKAN: created_by -> pengawas_id
          .where('status', isEqualTo: 'disetujui') // PERBAIKAN: sesuai rules
          .where('check_out', isEqualTo: null)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(snapshot.docs.first.data() as Map<String, dynamic>);
        data['id'] = snapshot.docs.first.id;
        setState(() {
          _isCheckedIn = true;
          _activeLembur = data;
        });
        
        _startLocationTracking();
      }
    } catch (e, stack) {
      await _handleError('checkActiveLembur', e, stackTrace: stack);
    }
  }

  void _initSampleLocations() {
    try {
      locations = [
        {
          'id': 'loc1',
          'name': 'Site A - Jakarta',
          'lat': -6.2088,
          'lng': 106.8456,
          'status': 'active',
          'workers': 3,
          'address': 'Jl. Sudirman No. 1',
          'lastUpdate': DateTime.now(),
        },
        {
          'id': 'loc2',
          'name': 'Site B - Jakarta',
          'lat': -6.2188,
          'lng': 106.8556,
          'status': 'active',
          'workers': 2,
          'address': 'Jl. Thamrin No. 45',
          'lastUpdate': DateTime.now(),
        },
        {
          'id': 'loc3',
          'name': 'Site C - Jakarta',
          'lat': -6.2288,
          'lng': 106.8356,
          'status': 'inactive',
          'workers': 0,
          'address': 'Jl. Gatot Subroto',
          'lastUpdate': DateTime.now(),
        },
      ];
    } catch (e, stack) {
      _handleError('initSampleLocations', e, stackTrace: stack);
    }
  }

  // ==================== REAL-TIME UPDATES ====================
  void _listenToRealTimeUpdates() {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final lemburSub = _firestore
          .collection('lembur')
          .where('pengawas_id', isEqualTo: user.uid) // PERBAIKAN: created_by -> pengawas_id
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _loadLemburData();
        }
      }, onError: (error) {
        // Hanya log error jika bukan permission denied
        if (!error.toString().contains('permission-denied')) {
          _handleError('lemburStream', error);
        }
      });
      _subscriptions.add(lemburSub);
    } catch (e, stack) {
      _handleError('listenToLembur', e, stackTrace: stack);
    }

    try {
      final teamSub = _firestore
          .collection('users')
          .where('role', isEqualTo: 'mitra')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _loadTeamMembers();
        }
      }, onError: (error) {
        if (!error.toString().contains('permission-denied')) {
          _handleError('teamStream', error);
        }
      });
      _subscriptions.add(teamSub);
    } catch (e, stack) {
      _handleError('listenToTeam', e, stackTrace: stack);
    }

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
        if (!error.toString().contains('permission-denied')) {
          _handleError('notificationsStream', error);
        }
      });
      _subscriptions.add(notifSub);
    } catch (e, stack) {
      _handleError('listenToNotifications', e, stackTrace: stack);
    }
  }

  // ==================== GPS & LOCATION ====================
  Future<bool> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackbar('Lokasi tidak aktif. Silakan aktifkan GPS');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackbar('Izin lokasi diperlukan untuk check-in/out');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackbar('Izin lokasi ditolak permanen');
        return false;
      }

      return true;
    } catch (e, stack) {
      await _handleError('checkLocationPermission', e, stackTrace: stack);
      return false;
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      
      return position;
    } catch (e, stack) {
      await _handleError('getCurrentLocation', e, stackTrace: stack);
      return null;
    }
  }

  void _startLocationTracking() {
    try {
      _positionStream?.cancel();
      
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          
          _updateLocationInFirestore(position);
        }
      }, onError: (error) {
        _handleError('locationStream', error);
      });
    } catch (e, stack) {
      _handleError('startLocationTracking', e, stackTrace: stack);
    }
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null || _activeLembur == null) return;

      await _firestore
          .collection('lembur')
          .doc(_activeLembur!['id'])
          .update({
        'last_location': GeoPoint(position.latitude, position.longitude),
        'last_location_update': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastLocation': GeoPoint(position.latitude, position.longitude),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      await _handleError('updateLocationInFirestore', e, stackTrace: stack);
    }
  }

  // ==================== LEMBUR OPERATIONS ====================
  Future<void> _checkIn() async {
    try {
      if (_activeLembur == null) {
        _showErrorSnackbar('Tidak ada lembur aktif');
        return;
      }

      final position = await _getCurrentLocation();
      if (position == null) return;

      await _firestore.collection('lembur').doc(_activeLembur!['id']).update({
        'check_in': FieldValue.serverTimestamp(),
        'check_in_location': GeoPoint(position.latitude, position.longitude),
        'absensi_status': 'check_in', // PERBAIKAN: sesuai rules
      });

      setState(() {
        _activeLembur!['check_in'] = Timestamp.now();
      });

      await _logActivity('check_in', 'Check-in lembur: ${_activeLembur!['proyek']}');
      _showSuccessSnackbar('Check-in berhasil');

    } catch (e, stack) {
      await _handleError('checkIn', e, stackTrace: stack);
      _showErrorSnackbar('Gagal check-in: ${e.toString()}');
    }
  }

  Future<void> _checkOut() async {
    try {
      if (_activeLembur == null) {
        _showErrorSnackbar('Tidak ada lembur aktif');
        return;
      }

      final position = await _getCurrentLocation();
      if (position == null) return;

      final checkInTime = (_activeLembur!['check_in'] as Timestamp).toDate();
      final checkOutTime = DateTime.now();
      final totalJam = checkOutTime.difference(checkInTime).inHours;

      await _firestore.collection('lembur').doc(_activeLembur!['id']).update({
        'check_out': FieldValue.serverTimestamp(),
        'check_out_location': GeoPoint(position.latitude, position.longitude),
        'total_jam_real': totalJam,
        'absensi_status': 'check_out', // PERBAIKAN: sesuai rules
      });

      _positionStream?.cancel();
      
      await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
        'isOnline': false,
      });
      
      setState(() {
        _isCheckedIn = false;
        _activeLembur = null;
      });

      await _logActivity('check_out', 'Check-out lembur, total $totalJam jam');
      _showSuccessSnackbar('Check-out berhasil. Total jam: $totalJam jam');

    } catch (e, stack) {
      await _handleError('checkOut', e, stackTrace: stack);
      _showErrorSnackbar('Gagal check-out: ${e.toString()}');
    }
  }

  Future<void> _logActivity(String type, String description) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': user.email,
        'target_user': user.uid,
        'session_id': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });
    } catch (e, stack) {
      // Silent fail untuk permission denied
      if (!e.toString().contains('permission-denied')) {
        await _handleError('logActivity', e, stackTrace: stack);
      }
    }
  }

  // ==================== NAVIGASI KE AJUKAN LEMBUR ====================
  Future<void> _showAddLemburDialog() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AjukanLemburPage(),
        ),
      );

      // Jika berhasil submit, refresh data
      if (result == true) {
        _refreshData();
      }
    } catch (e, stack) {
      await _handleError('showAddLemburDialog', e, stackTrace: stack);
      _showErrorSnackbar('Gagal membuka form pengajuan');
    }
  }

  // ==================== UTILITIES ====================
  String _getTimeAgo(dynamic timestamp) {
    try {
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
    } catch (e) {
      return 'baru saja';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui': // PERBAIKAN: sesuai rules
      case 'approved':
      case 'check_in':
        return hijauCerah;
      case 'pending':
      case 'pending_approval':
        return orangeCerah;
      case 'ditolak': // PERBAIKAN: sesuai rules
      case 'rejected':
        return merahCerah;
      case 'check_out':
      case 'selesai': // PERBAIKAN: sesuai rules
        return biruCerah;
      default:
        return Colors.grey;
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
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
        backgroundColor: hijauCerah,
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
        backgroundColor: merahCerah,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== DETAIL LEMBUR ====================
  Future<void> _showDetailLembur(Map<String, dynamic> lembur) async {
    try {
      final status = lembur['status']?.toString() ?? 'pending';
      final statusColor = _getStatusColor(status);
      final isApproved = status == 'disetujui' || status == 'approved';

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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      statusColor.withAlpha(26),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [statusColor, statusColor.withAlpha(179)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isApproved ? Icons.check_circle : Icons.pending,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lembur['proyek'] ?? 'Lembur',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Status: ${status.toUpperCase()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cyanCerah, biruCerah],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${lembur['total_jam'] ?? 0} jam',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                          _buildDetailInfo(
                            Icons.calendar_today,
                            'Tanggal',
                            DateFormat('dd MMMM yyyy')
                                .format((lembur['tanggal'] as Timestamp).toDate()),
                            biruCerah,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailInfo(
                            Icons.access_time,
                            'Jam Lembur',
                            '${lembur['jam_mulai']} - ${lembur['jam_selesai']}',
                            hijauCerah,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailInfo(
                            Icons.description,
                            'Alasan',
                            lembur['alasan'] ?? '-',
                            orangeCerah,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailInfo(
                            Icons.people,
                            'Anggota Tim',
                            '${lembur['total_mitra'] ?? 0} orang',
                            unguCerah,
                          ),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cyanMuda.withAlpha(51), biruMuda.withAlpha(51)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cyanCerah.withAlpha(128)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Anggota:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: darkBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Catatan: anggota_details tidak ada di rules, ini dummy
                                ...List.generate(3, (i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: cyanCerah,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Anggota ${i + 1}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: darkBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          
                          if (isApproved) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [hijauMuda.withAlpha(77), cyanMuda.withAlpha(77)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: hijauCerah.withAlpha(128)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, color: hijauCerah),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Status Check-in/out',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: darkBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (lembur['check_in'] != null) ...[
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: hijauCerah,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.login,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Check-in: ${_getTimeAgo(lembur['check_in'])}',
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (lembur['check_out'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: merahCerah,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.logout,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Check-out: ${_getTimeAgo(lembur['check_out'])}',
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (lembur['total_jam_real'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: orangeCerah,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.timer,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Total jam: ${lembur['total_jam_real']} jam',
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e, stack) {
      await _handleError('showDetailLembur', e, stackTrace: stack);
      _showErrorSnackbar('Gagal menampilkan detail');
    }
  }

  Widget _buildDetailInfo(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withAlpha(179)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: darkBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== NAVIGATION ====================
  void _navigateTo(String page) {
    try {
      switch (page) {
        case 'history':
          Navigator.pushNamed(context, '/overtime-data');
          break;
        case 'monitoring':
          _showSuccessSnackbar('Membuka Monitoring Tim');
          break;
        case 'reports':
          _showSuccessSnackbar('Membuka Laporan');
          break;
        case 'profile':
          _showSuccessSnackbar('Membuka Profil');
          break;
        case 'settings':
          _showSuccessSnackbar('Membuka Pengaturan');
          break;
      }
    } catch (e, stack) {
      _handleError('navigateTo', e, stackTrace: stack);
    }
  }

  // ==================== HELP & SUPPORT (DIINTEGRASIKAN) ====================
  void _showHelpSupport() {
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    biruCerah.withAlpha(26),
                    unguCerah.withAlpha(13),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
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
                  
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [biruCerah, unguCerah],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pusat Bantuan',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // FAQ Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(26),
                                blurRadius: 10,
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
                                    decoration: BoxDecoration(
                                      color: orangeCerah.withAlpha(26),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.help, color: orangeCerah),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'FAQ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildFAQItem(
                                'Cara mengajukan lembur?',
                                'Klik tombol "Ajukan Lembur" di pojok kanan bawah, isi form dengan lengkap, lalu submit. Pengajuan akan diproses oleh Manager.',
                                orangeCerah,
                              ),
                              _buildFAQItem(
                                'Bagaimana cara check-in?',
                                'Setelah pengajuan disetujui, Anda akan melihat banner lembur aktif. Klik tombol "Check-in" untuk memulai lembur.',
                                hijauCerah,
                              ),
                              _buildFAQItem(
                                'Lupa check-out?',
                                'Hubungi Manager atau Super Admin untuk bantuan. Data lembur akan tetap tersimpan.',
                                merahCerah,
                              ),
                              _buildFAQItem(
                                'Maksimal jam lembur?',
                                'Maksimal 4 jam per hari sesuai regulasi perusahaan. Lebih dari itu memerlukan persetujuan khusus.',
                                biruCerah,
                              ),
                            ],
                          ),
                        ),
                        
                        // Contact Support
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(26),
                                blurRadius: 10,
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
                                    decoration: BoxDecoration(
                                      color: hijauCerah.withAlpha(26),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.headset_mic, color: hijauCerah),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hubungi Dukungan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildContactItem(
                                icon: Icons.email,
                                color: biruCerah,
                                label: 'Email',
                                value: 'support@aplikasi.com',
                                onTap: () => launchUrl(Uri.parse('mailto:support@aplikasi.com')),
                              ),
                              _buildContactItem(
                                icon: Icons.phone,
                                color: hijauCerah,
                                label: 'Telepon',
                                value: '0812-3456-7890',
                                onTap: () => launchUrl(Uri.parse('tel:081234567890')),
                              ),
                              _buildContactItem(
                                icon: Icons.chat,
                                color: orangeCerah,
                                label: 'WhatsApp',
                                value: '0812-3456-7890',
                                onTap: () => launchUrl(Uri.parse('https://wa.me/6281234567890')),
                              ),
                            ],
                          ),
                        ),
                        
                        // Quick Help
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.video_library, color: biruCerah),
                                ),
                                title: Text(
                                  'Video Tutorial',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: darkBlue,
                                  ),
                                ),
                                subtitle: Text(
                                  'Tonton video panduan penggunaan aplikasi',
                                  style: GoogleFonts.poppins(fontSize: 11),
                                ),
                                trailing: const Icon(Icons.play_circle_fill, color: biruCerah),
                                onTap: () => _showSuccessSnackbar('Membuka video tutorial'),
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.description, color: orangeCerah),
                                ),
                                title: Text(
                                  'Dokumentasi',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: darkBlue,
                                  ),
                                ),
                                subtitle: Text(
                                  'Baca panduan lengkap penggunaan',
                                  style: GoogleFonts.poppins(fontSize: 11),
                                ),
                                trailing: const Icon(Icons.arrow_forward, color: orangeCerah),
                                onTap: () => _showSuccessSnackbar('Membuka dokumentasi'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chat with AI Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [biruCerah, unguCerah],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: biruCerah.withAlpha(77),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showChatBot();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Chat dengan Asisten AI',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildFAQItem(String question, String answer, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          question,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: darkBlue,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(77)),
            ),
            child: Text(
              answer,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: darkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: darkBlue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _showChatBot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    biruCerah.withAlpha(26),
                    unguCerah.withAlpha(13),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [biruCerah, unguCerah],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asisten AI',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                            Text(
                              'Siap membantu Anda 24/7',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildBotMessage('Halo! Ada yang bisa saya bantu?'),
                          _buildBotMessage('Anda bisa bertanya tentang:'),
                          _buildBotMessage('• Cara mengajukan lembur\n• Status pengajuan\n• Cara check-in/out\n• Aturan lembur\n• Dan lain-lain'),
                          
                          const SizedBox(height: 16),
                          
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickQuestion('Cara lembur'),
                              _buildQuickQuestion('Status pengajuan'),
                              _buildQuickQuestion('Check-in'),
                              _buildQuickQuestion('Check-out'),
                              _buildQuickQuestion('Aturan jam'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Ketik pesan...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [biruCerah, unguCerah],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () => _showSuccessSnackbar('Pesan terkirim'),
                          ),
                        ),
                      ],
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

  Widget _buildBotMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, size: 16, color: biruCerah),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestion(String text) {
    return ActionChip(
      onPressed: () => _showSuccessSnackbar('Memproses pertanyaan: $text'),
      backgroundColor: biruCerah.withAlpha(26),
      label: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: biruCerah,
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================
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
              _buildMenuItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                color1: biruCerah,
                color2: unguCerah,
                onTap: () => Navigator.pop(context),
              ),
              _buildMenuItem(
                icon: Icons.add_alert,
                label: 'Ajukan Lembur',
                color1: orangeCerah,
                color2: pinkCerah,
                onTap: () {
                  Navigator.pop(context);
                  _showAddLemburDialog();
                },
              ),
              _buildMenuItem(
                icon: Icons.history,
                label: 'Riwayat Pengajuan',
                color1: hijauCerah,
                color2: cyanCerah,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo('history');
                },
              ),
              _buildMenuItem(
                icon: Icons.people,
                label: 'Monitoring Tim',
                color1: cyanCerah,
                color2: biruCerah,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo('monitoring');
                },
              ),
              _buildMenuItem(
                icon: Icons.assessment,
                label: 'Laporan',
                color1: unguCerah,
                color2: pinkCerah,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo('reports');
                },
              ),
              _buildMenuItem(
                icon: Icons.support_agent,
                label: 'Bantuan & Dukungan',
                color1: biruCerah,
                color2: unguCerah,
                onTap: () {
                  Navigator.pop(context);
                  _showHelpSupport();
                },
              ),
              _buildMenuItem(
                icon: Icons.person,
                label: 'Profil',
                color1: darkBlue,
                color2: darkPurple,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo('profile');
                },
              ),
              _buildMenuItem(
                icon: Icons.settings,
                label: 'Pengaturan',
                color1: darkGrey,
                color2: Colors.grey,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo('settings');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1.withAlpha(26), color2.withAlpha(13)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: darkBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: color1, size: 16),
        onTap: onTap,
      ),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [biruCerah, unguCerah],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Notifikasi',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.done_all, color: hijauCerah),
                          onPressed: _markAllAsRead,
                        ),
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
                          // Jangan tampilkan error untuk permission denied
                          if (snapshot.error.toString().contains('permission-denied')) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none, size: 60, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tidak dapat memuat notifikasi',
                                    style: GoogleFonts.poppins(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error, color: merahCerah),
                                const SizedBox(height: 8),
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: GoogleFonts.poppins(color: darkBlue),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final notifs = snapshot.data!.docs;

                        if (notifs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada notifikasi',
                                  style: GoogleFonts.poppins(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: notifs.length,
                          itemBuilder: (context, index) {
                            final notif = notifs[index].data() as Map<String, dynamic>;
                            final isRead = notif['isRead'] ?? false;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isRead 
                                      ? [Colors.white, Colors.grey[50]!]
                                      : [biruCerah.withAlpha(26), unguCerah.withAlpha(13)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead ? Colors.grey[200]! : biruCerah.withAlpha(77),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isRead 
                                            ? [Colors.grey, Colors.grey[400]!]
                                            : [biruCerah, unguCerah],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications,
                                      color: Colors.white,
                                      size: 16,
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
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                            color: darkBlue,
                                          ),
                                        ),
                                        Text(
                                          notif['body'] ?? '',
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [biruCerah, unguCerah],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
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

  void _showMemberLocation(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: member['isOnline'] == true
                        ? [hijauCerah, cyanCerah]
                        : [Colors.grey, Colors.grey[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                member['nama'] ?? 'Anggota',
                style: GoogleFonts.poppins(color: darkBlue),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Icon(Icons.phone, color: biruCerah),
                  title: Text(
                    member['phone'] ?? '-',
                    style: GoogleFonts.poppins(color: darkBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Icon(Icons.location_on, color: hijauCerah),
                  title: Text(
                    member['lastLocation'] != null
                        ? 'Lokasi: ${(member['lastLocation'] as GeoPoint).latitude.toStringAsFixed(4)}, ${(member['lastLocation'] as GeoPoint).longitude.toStringAsFixed(4)}'
                        : 'Lokasi tidak tersedia',
                    style: GoogleFonts.poppins(color: darkBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Icon(
                    member['isOnline'] == true ? Icons.circle : Icons.circle_outlined,
                    color: member['isOnline'] == true ? hijauCerah : Colors.grey,
                  ),
                  title: Text(
                    member['isOnline'] == true ? 'Online' : 'Offline',
                    style: GoogleFonts.poppins(color: darkBlue),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [biruCerah, unguCerah],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      setState(() {
        unreadNotifications = 0;
      });
      
      _showSuccessSnackbar('Semua notifikasi telah dibaca');
    } catch (e, stack) {
      // Silent fail untuk permission denied
      if (!e.toString().contains('permission-denied')) {
        await _handleError('markAllAsRead', e, stackTrace: stack);
        _showErrorSnackbar('Gagal menandai notifikasi');
      }
    }
  }

  // ==================== EXPORT REPORT ====================
  Future<void> _exportReport(String type) async {
    try {
      _generateSessionId();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      await _logActivity('export_report', 'Export laporan tipe: $type');

      if (!mounted) return;
      Navigator.pop(context);

      _showSuccessSnackbar('Laporan $type berhasil diexport');
    } catch (e, stack) {
      await _handleError('exportReport', e, stackTrace: stack);
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackbar('Gagal export: $e');
    }
  }

  // ==================== REFRESH ====================
  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    try {
      await Future.wait([
        _loadUserData(),
        _loadLemburData(),
        _loadTeamMembers(),
      ]);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => isRefreshing = false);
        _showSuccessSnackbar('Data diperbarui');
      }
    } catch (e, stack) {
      await _handleError('refreshData', e, stackTrace: stack);
      setState(() => isRefreshing = false);
    }
  }

  // ==================== LOGOUT (SESUAI RULES) ====================
  Future<void> _logout() async {
    try {
      _generateSessionId();
      
      final user = _auth.currentUser;
      
      if (user != null) {
        // Update status user menjadi offline
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': false,
            'lastActive': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Silent fail untuk permission denied saat logout
          logger.d('Gagal update status user saat logout: $e');
        }

        // Log aktivitas logout - coba dulu, tapi jangan gagalkan logout jika gagal
        try {
          await _firestore.collection('system_logs').add({
            'type': 'logout',
            'user': user.email,
            'target_user': user.uid,
            'session_id': _currentSessionId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Pengawas logout',
          });
        } catch (e) {
          logger.d('Gagal mencatat log logout: $e');
        }
      }

      // Hentikan tracking lokasi
      _positionStream?.cancel();
      
      // Batalkan semua subscription
      for (var sub in _subscriptions) {
        sub.cancel();
      }

      // Sign out dari Firebase Auth
      await _auth.signOut();
      
      if (mounted) {
        // Hapus semua snackbar yang mungkin masih tampil
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Navigasi ke halaman login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e, stack) {
      // Log error tapi tetap coba sign out
      logger.e('Error during logout: $e');
      
      // Coba sign out lagi
      try {
        await _auth.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (signOutError) {
        // Jika gagal juga, force navigate ke login
        logger.e('Gagal sign out: $signOutError');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  // ==================== BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: _isCheckedIn
          ? FloatingActionButton.extended(
              onPressed: _checkOut,
              backgroundColor: merahCerah,
              icon: const Icon(Icons.logout),
              label: Text('Check-out', style: GoogleFonts.poppins()),
            )
          : FloatingActionButton.extended(
              onPressed: _showAddLemburDialog,
              backgroundColor: orangeCerah,
              icon: const Icon(Icons.add),
              label: Text('Ajukan Lembur', style: GoogleFonts.poppins()),
            ),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshData,
              color: orangeCerah,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Error indicator
                        _buildErrorIndicator(),
                        
                        _buildWelcomeCard(),
                        const SizedBox(height: 16),

                        _buildQuickStats(),
                        const SizedBox(height: 16),

                        if (_isCheckedIn) _buildActiveLemburBanner(),
                        if (_isCheckedIn) const SizedBox(height: 16),

                        _buildPendingApprovals(),
                        const SizedBox(height: 16),

                        _buildMainActions(),
                        const SizedBox(height: 16),

                        _buildTodaySchedule(),
                        const SizedBox(height: 16),

                        _buildTeamMonitoring(),
                        const SizedBox(height: 16),

                        _buildRecentLembur(),
                        const SizedBox(height: 16),

                        _buildCalendarSection(),
                        const SizedBox(height: 16),

                        _buildReportsSection(),
                        const SizedBox(height: 16),

                        // Help & Support terintegrasi
                        _buildHelpSupportCard(),
                        const SizedBox(height: 16),

                        _buildLogoutButton(),
                        
                        // Spacer untuk menghindari bottom overflow
                        SizedBox(height: screenHeight * 0.05),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHelpSupportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: biruCerah.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: biruCerah.withAlpha(26),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [biruCerah, unguCerah],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white),
            ),
            title: Text(
              'Pusat Bantuan & Dukungan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            subtitle: Text(
              'FAQ, tutorial, dan chat dengan asisten AI',
              style: GoogleFonts.poppins(fontSize: 11),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: biruCerah.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: biruCerah),
            ),
            onTap: _showHelpSupport,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHelpQuickItem(
                icon: Icons.help,
                label: 'FAQ',
                color: orangeCerah,
                onTap: _showHelpSupport,
              ),
              _buildHelpQuickItem(
                icon: Icons.headset_mic,
                label: 'Support',
                color: hijauCerah,
                onTap: _showHelpSupport,
              ),
              _buildHelpQuickItem(
                icon: Icons.smart_toy,
                label: 'Chat AI',
                color: unguCerah,
                onTap: _showChatBot,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpQuickItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
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
          colors: [biruCerah, unguCerah, pinkCerah],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(77),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.supervisor_account,
                      size: 50,
                      color: orangeCerah,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'DASHBOARD PENGAWAS',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: 3),
              duration: const Duration(seconds: 3),
              builder: (context, value, child) {
                final messages = [
                  'Memuat data tim...',
                  'Mengecek pengajuan lembur...',
                  'Menyiapkan monitoring...',
                  'Hampir selesai...',
                ];
                return Text(
                  messages[value],
                  style: GoogleFonts.poppins(color: Colors.white70),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [biruCerah, unguCerah, pinkCerah],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withAlpha(51), Colors.white.withAlpha(102)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _showDrawerMenu(context),
        ),
      ),
      actions: [
        if (_isCheckedIn)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [hijauCerah, cyanCerah],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Check-in Aktif',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      
        Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withAlpha(51), Colors.white.withAlpha(102)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => _showNotifications(context),
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: merahCerah,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadNotifications',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withAlpha(51), Colors.white.withAlpha(102)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'profile') {
                _navigateTo('profile');
              } else if (value == 'settings') {
                _navigateTo('settings');
              } else if (value == 'help') {
                _showHelpSupport();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: biruCerah),
                      const SizedBox(width: 8),
                      Text('Profil', style: GoogleFonts.poppins(color: darkBlue)),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: hijauCerah),
                      const SizedBox(width: 8),
                      Text('Pengaturan', style: GoogleFonts.poppins(color: darkBlue)),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.help, color: orangeCerah),
                      const SizedBox(width: 8),
                      Text('Bantuan', style: GoogleFonts.poppins(color: darkBlue)),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [merahCerah.withAlpha(26), merahMuda.withAlpha(26)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: merahCerah),
                      const SizedBox(width: 8),
                      Text('Logout', style: GoogleFonts.poppins(color: darkBlue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [biruCerah, unguCerah, pinkCerah],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: biruCerah.withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha(77),
                  blurRadius: 10,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Text(
                userData['nama_lengkap']?[0]?.toUpperCase() ?? 'P',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  color: biruCerah,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang,',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  userData['nama_lengkap'] ?? 'Pengawas',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    userData['fungsi'] ?? 'operation',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [hijauCerah, cyanCerah],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: hijauCerah.withAlpha(77),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Hari Ini',
            '$totalLemburToday',
            Icons.today,
            biruCerah,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Minggu Ini',
            '$totalLemburWeek',
            Icons.date_range,
            hijauCerah,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '$pendingApproval',
            Icons.pending_actions,
            orangeCerah,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(26), color.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(179)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
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

  Widget _buildActiveLemburBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hijauCerah, cyanCerah],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: hijauCerah.withAlpha(77),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lembur Aktif',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _activeLembur?['proyek'] ?? 'Proyek',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (_currentPosition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lokasi: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white.withAlpha(179)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ElevatedButton(
              onPressed: _checkOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                'Check-out',
                style: GoogleFonts.poppins(color: hijauCerah),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals() {
    if (pendingLembur.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: orangeCerah.withAlpha(128), width: 1),
        boxShadow: [
          BoxShadow(
            color: orangeCerah.withAlpha(26),
            blurRadius: 10,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [orangeCerah, pinkCerah],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Menunggu Persetujuan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: orangeCerah,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingLembur.take(3).map((lembur) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.work, color: orangeCerah, size: 16),
                ),
                title: Text(
                  lembur['proyek'] ?? 'Proyek',
                  style: GoogleFonts.poppins(fontSize: 13, color: darkBlue),
                ),
                subtitle: Text(
                  '${lembur['total_mitra'] ?? 0} anggota',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTimeAgo(lembur['created_at']),
                    style: GoogleFonts.poppins(fontSize: 10, color: orangeCerah),
                  ),
                ),
                onTap: () => _showDetailLembur(lembur),
              ),
            );
          }),
          if (pendingLembur.length > 3)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Lihat ${pendingLembur.length - 3} lainnya...',
                    style: GoogleFonts.poppins(color: orangeCerah),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainActions() {
    final actions = [
      {
        'icon': Icons.add_alert,
        'label': 'Ajukan Lembur',
        'color1': orangeCerah,
        'color2': pinkCerah,
        'onTap': _showAddLemburDialog,
      },
      {
        'icon': Icons.history,
        'label': 'Riwayat',
        'color1': biruCerah,
        'color2': unguCerah,
        'onTap': () => _navigateTo('history'),
      },
      {
        'icon': Icons.people,
        'label': 'Monitoring Tim',
        'color1': hijauCerah,
        'color2': cyanCerah,
        'onTap': () => _navigateTo('monitoring'),
      },
      {
        'icon': Icons.assessment,
        'label': 'Laporan',
        'color1': unguCerah,
        'color2': pinkCerah,
        'onTap': () => _navigateTo('reports'),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: action['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [action['color1'] as Color, action['color2'] as Color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: (action['color1'] as Color).withAlpha(77),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodaySchedule() {
    final todayLembur = recentLembur.where((lembur) {
      final tanggal = (lembur['tanggal'] as Timestamp).toDate();
      return DateUtils.isSameDay(tanggal, DateTime.now());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: biruCerah.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: biruCerah.withAlpha(26),
            blurRadius: 10,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [biruCerah, unguCerah],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Jadwal Hari Ini',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (todayLembur.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada jadwal lembur hari ini',
                      style: GoogleFonts.poppins(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...todayLembur.take(3).map((lembur) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(26),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [biruCerah.withAlpha(26), unguCerah.withAlpha(26)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.work,
                        color: biruCerah,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lembur['proyek'] ?? 'Proyek',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: darkBlue,
                            ),
                          ),
                          Text(
                            '${lembur['total_mitra'] ?? 0} anggota',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(26),
                            _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(13),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lembur['status']?.toString() ?? 'pending',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: _getStatusColor(lembur['status']?.toString() ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTeamMonitoring() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hijauCerah.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: hijauCerah.withAlpha(26),
            blurRadius: 10,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [hijauCerah, cyanCerah],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monitoring Tim',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkBlue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeTeam/${teamMembers.length} Online',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: hijauCerah,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Map container dengan fixed height
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hijauCerah.withAlpha(128)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(-6.2088, 106.8456),
                  initialZoom: 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: teamMembers
                        .where((m) => m['lastLocation'] != null)
                        .map((member) {
                      final loc = member['lastLocation'] as GeoPoint;
                      return Marker(
                        point: LatLng(loc.latitude, loc.longitude),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            _showMemberLocation(member);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: member['isOnline'] == true
                                    ? [hijauCerah, cyanCerah]
                                    : [Colors.grey, Colors.grey[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (member['isOnline'] == true ? hijauCerah : Colors.grey).withAlpha(77),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Member list horizontal dengan fixed height
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: teamMembers.length,
              itemBuilder: (context, index) {
                final member = teamMembers[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: member['isOnline'] == true
                          ? [hijauCerah.withAlpha(26), cyanCerah.withAlpha(26)]
                          : [Colors.grey.withAlpha(26), Colors.grey.withAlpha(13)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: member['isOnline'] == true
                          ? hijauCerah
                          : Colors.grey,
                      width: 1,
                    ),
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
                              color: member['isOnline'] == true
                                  ? hijauCerah
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              member['nama'],
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: darkBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member['phone'] ?? '-',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey[500],
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
  }

  Widget _buildRecentLembur() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [unguCerah.withAlpha(26), pinkCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: unguCerah.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: unguCerah.withAlpha(26),
            blurRadius: 10,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [unguCerah, pinkCerah],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Lembur',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkBlue,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [unguCerah.withAlpha(26), pinkCerah.withAlpha(26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  onPressed: () => _navigateTo('history'),
                  child: Text(
                    'Lihat Semua',
                    style: GoogleFonts.poppins(color: unguCerah),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentLembur.take(5).map((lembur) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(26),
                        _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(13),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.work,
                    color: _getStatusColor(lembur['status']?.toString() ?? ''),
                    size: 16,
                  ),
                ),
                title: Text(
                  lembur['proyek'] ?? 'Proyek',
                  style: GoogleFonts.poppins(fontSize: 13, color: darkBlue),
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format((lembur['tanggal'] as Timestamp).toDate()),
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(26),
                        _getStatusColor(lembur['status']?.toString() ?? '').withAlpha(13),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lembur['status']?.toString() ?? 'pending',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _getStatusColor(lembur['status']?.toString() ?? ''),
                    ),
                  ),
                ),
                onTap: () => _showDetailLembur(lembur),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cyanCerah.withAlpha(26), biruCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cyanCerah.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: cyanCerah.withAlpha(26),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.now().add(const Duration(days: 365)),
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
                gradient: LinearGradient(
                  colors: [cyanCerah, biruCerah],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [biruCerah, unguCerah],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: darkBlue,
              ),
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orangeCerah.withAlpha(26), pinkCerah.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: orangeCerah.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: orangeCerah.withAlpha(26),
            blurRadius: 10,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [orangeCerah, pinkCerah],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assessment, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Laporan & Export',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildReportChip(
                'Mingguan',
                Icons.date_range,
                biruCerah,
                () => _exportReport('weekly'),
              ),
              _buildReportChip(
                'Bulanan',
                Icons.calendar_month,
                hijauCerah,
                () => _exportReport('monthly'),
              ),
              _buildReportChip(
                'Export PDF',
                Icons.picture_as_pdf,
                merahCerah,
                () => _exportReport('pdf'),
              ),
              _buildReportChip(
                'Export Excel',
                Icons.table_chart,
                unguCerah,
                () => _exportReport('excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.transparent,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(26), color.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(128)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [merahCerah, merahMuda],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: merahCerah.withAlpha(77),
            blurRadius: 10,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}