// lib/core/services/live_location_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Model data lokasi terbaru
class LiveLocationData {
  final String userId;
  final String userName;
  final String? userRole;
  final String? userFungsi;
  final String? lemburId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final double? batteryLevel;
  final bool isActive;

  LiveLocationData({
    required this.userId,
    required this.userName,
    this.userRole,
    this.userFungsi,
    this.lemburId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.batteryLevel,
    this.isActive = true,
  });

  factory LiveLocationData.fromMap(Map<String, dynamic> map) {
    return LiveLocationData(
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Unknown',
      userRole: map['user_role'] as String?,
      userFungsi: map['user_fungsi'] as String?,
      lemburId: map['lembur_id'] as String?,
      latitude: (map['latitude'] ?? map['last_lat'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? map['last_lng'] ?? 0).toDouble(),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['last_update'] is Timestamp
              ? (map['last_update'] as Timestamp).toDate()
              : DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      batteryLevel: (map['battery_level'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'user_name': userName,
    'user_role': userRole,
    'user_fungsi': userFungsi,
    'lembur_id': lemburId,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': Timestamp.fromDate(timestamp),
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'battery_level': batteryLevel,
    'is_active': isActive,
  };
}

/// Service + Provider: mengirim & menerima data lokasi secara real‑time
class LiveLocationService extends ChangeNotifier {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;

  // STATE
  StreamSubscription<Position>? _positionSubscription;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;
  String? _currentUserFungsi;
  String? _currentOvertimeId;
  String? _currentLemburId;
  bool _isTracking = false;

  DateTime? _lastWriteTime;
  static const _minWriteInterval = Duration(seconds: 15);

  // Viewer state
  Map<String, LiveLocationData> _latestLocations = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;
  bool _isListening = false;

  // ⭐ FLAG UNTUK CEGAH NOTIFY SETELAH DISPOSE
  bool _isDisposed = false;

  // Getters
  bool get isTracking => _isTracking;
  bool get isListening => _isListening;
  Map<String, LiveLocationData> get latestLocations => _latestLocations;
  String? get currentOvertimeId => _currentOvertimeId;

  // ⭐ SAFE NOTIFY - CEK APAKAH MASIH ACTIVE
  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // START TRACKING - Dipanggil setelah absensi berhasil
  Future<void> startTracking({
    required String userId,
    required String userName,
    required String overtimeId,
    required String lemburId,
    String userRole = 'mitra',
    String? userFungsi,
  }) async {
    // Hentikan tracking sebelumnya
    await stopTracking();

    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserRole = userRole;
    _currentUserFungsi = userFungsi;
    _currentOvertimeId = overtimeId;
    _currentLemburId = lemburId;
    _isTracking = true;
    _safeNotify();

    debugPrint('🟢 Live tracking dimulai untuk $userName ($userId)');

    // Dapatkan posisi awal
    try {
      final pos = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _writeLocation(pos, forceWrite: true);
    } catch (e) {
      debugPrint('⚠️ Gagal ambil posisi awal: $e');
    }

    // Stream posisi
    _positionSubscription = _geolocator
        .getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        )
        .listen(
          _onPositionUpdate,
          onError: (error) {
            debugPrint('❌ Error stream posisi: $error');
          },
        );
  }

  void _onPositionUpdate(Position position) {
    final now = DateTime.now();
    if (_lastWriteTime != null &&
        now.difference(_lastWriteTime!) < _minWriteInterval) {
      return;
    }
    _writeLocation(position);
  }

  Future<void> _writeLocation(Position position, {bool forceWrite = false}) async {
    if (_currentUserId == null || _currentOvertimeId == null) return;
    if (!forceWrite && _lastWriteTime != null &&
        DateTime.now().difference(_lastWriteTime!) < _minWriteInterval) {
      return;
    }

    try {
      final batch = _firestore.batch();

      // Summary document (untuk query cepat)
      final summaryRef = _firestore
          .collection('live_locations')
          .doc(_currentOvertimeId);

      batch.set(summaryRef, {
        'user_id': _currentUserId,
        'user_name': _currentUserName,
        'user_role': _currentUserRole,
        'user_fungsi': _currentUserFungsi,
        'lembur_id': _currentLemburId,
        'overtime_id': _currentOvertimeId,
        'last_update': FieldValue.serverTimestamp(),
        'last_lat': position.latitude,
        'last_lng': position.longitude,
        'last_accuracy': position.accuracy,
        'last_altitude': position.altitude,
        'last_speed': position.speed,
        'last_heading': position.heading,
        'is_active': true,
        'battery_level': _getBatteryLevel(),
      }, SetOptions(merge: true));

      // History updates (untuk trail/jejak)
      final historyRef = summaryRef.collection('updates').doc();

      batch.set(historyRef, {
        'user_id': _currentUserId,
        'user_name': _currentUserName,
        'user_role': _currentUserRole,
        'user_fungsi': _currentUserFungsi,
        'lembur_id': _currentLemburId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'battery_level': _getBatteryLevel(),
      });

      await batch.commit();

      _lastWriteTime = DateTime.now();
      debugPrint('📍 Lokasi: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
    } catch (e) {
      debugPrint('❌ Gagal mengirim lokasi: $e');
    }
  }

  /// Placeholder untuk battery level (bisa integrasi dengan battery_plus package)
  double? _getBatteryLevel() {
    // TODO: Integrasi dengan battery_plus untuk data real
    return null;
  }

  // STOP TRACKING - Dipanggil saat lembur selesai
  Future<void> stopTracking() async {
    // ⭐ CEGAH EKSEKUSI JIKA SUDAH DISPOSED
    if (_isDisposed) return;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastWriteTime = null;

    if (_currentOvertimeId != null) {
      try {
        await _firestore
            .collection('live_locations')
            .doc(_currentOvertimeId)
            .update({
          'is_active': false,
          'stopped_at': FieldValue.serverTimestamp(),
        });
        debugPrint('🔴 Tracking dihentikan untuk $_currentOvertimeId');
      } catch (e) {
        debugPrint('⚠️ Gagal update status nonaktif: $e');
      }
    }

    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _currentUserFungsi = null;
    _currentOvertimeId = null;
    _currentLemburId = null;
    _isTracking = false;
    _safeNotify();
  }

  // VALIDASI LOKASI - Cek apakah mitra dalam radius lokasi lembur
  Future<Map<String, dynamic>> validateLocation({
    required double targetLat,
    required double targetLng,
    double radiusMeter = 500,
  }) async {
    try {
      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'valid': false,
            'message': '❌ Izin lokasi ditolak. Aktifkan GPS dan izin lokasi.',
            'distance': null,
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'valid': false,
          'message': '❌ Izin lokasi ditolak permanen. Buka pengaturan aplikasi.',
          'distance': null,
        };
      }

      // Cek GPS
      bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        return {
          'valid': false,
          'message': '❌ GPS tidak aktif. Harap nyalakan GPS.',
          'distance': null,
        };
      }

      // Dapatkan posisi saat ini
      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Hitung jarak
      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      final isValid = distanceInMeters <= radiusMeter;

      debugPrint('📍 Validasi Lokasi:');
      debugPrint('   Posisi: ${position.latitude}, ${position.longitude}');
      debugPrint('   Target: $targetLat, $targetLng');
      debugPrint('   Jarak: ${distanceInMeters.toStringAsFixed(1)} meter');
      debugPrint('   Valid: $isValid (radius: $radiusMeter meter)');

      return {
        'valid': isValid,
        'message': isValid
            ? '✅ Lokasi valid (${distanceInMeters.toStringAsFixed(0)} meter)'
            : '❌ Anda berada di luar area lembur (${distanceInMeters.toStringAsFixed(0)} meter dari lokasi)',
        'distance': distanceInMeters,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      debugPrint('❌ Error validasi lokasi: $e');
      return {
        'valid': false,
        'message': '❌ Gagal memvalidasi lokasi: ${e.toString()}',
        'distance': null,
      };
    }
  }

  // LISTENER UNTUK VIEWER (PENGAWAS/ADMIN)
  void listenToAllActiveLocations() {
    if (_isDisposed) return; // ⭐ CEK DISPOSED
    
    _stopListener();

    _listener = _firestore
        .collection('live_locations')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return; // ⭐ CEK DISPOSED DI DALAM CALLBACK
      
      _latestLocations.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('last_lat')) {
          final loc = LiveLocationData.fromMap(data);
          _latestLocations[doc.id] = loc;
        }
      }
      _isListening = true;
      _safeNotify();
    }, onError: (error) {
      if (_isDisposed) return;
      debugPrint('❌ Error stream lokasi: $error');
    });
  }

  void listenToOvertime(String overtimeId) {
    if (_isDisposed) return; // ⭐ CEK DISPOSED
    
    _stopListener();

    _listener = _firestore
        .collection('live_locations')
        .doc(overtimeId)
        .collection('updates')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return; // ⭐ CEK DISPOSED DI DALAM CALLBACK
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String?;
        if (userId == null) continue;

        final loc = LiveLocationData.fromMap(data);

        if (!_latestLocations.containsKey(userId) ||
            loc.timestamp.isAfter(_latestLocations[userId]!.timestamp)) {
          _latestLocations[userId] = loc;
        }
      }
      _isListening = true;
      _safeNotify();
    });
  }

  void _stopListener() {
    _listener?.cancel();
    _listener = null;
    _isListening = false;
  }

  void stopListening() {
    if (_isDisposed) return; // ⭐ CEK DISPOSED
    
    _stopListener();
    _latestLocations.clear();
    _safeNotify();
  }

  // GET LOCATION HISTORY
  Future<List<LiveLocationData>> getLocationHistory(
    String overtimeId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    if (_isDisposed) return []; // ⭐ CEK DISPOSED
    
    try {
      var query = _firestore
          .collection('live_locations')
          .doc(overtimeId)
          .collection('updates')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startTime != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
      }
      if (endTime != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => LiveLocationData.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('❌ Gagal ambil history lokasi: $e');
      return [];
    }
  }

  // AUTO STOP
  Timer? _autoStopTimer;

  void scheduleAutoStop(DateTime jamSelesai) {
    if (_isDisposed) return; // ⭐ CEK DISPOSED
    
    _autoStopTimer?.cancel();
    final delay = jamSelesai.difference(DateTime.now());
    if (delay.isNegative) {
      stopTracking();
      return;
    }

    _autoStopTimer = Timer(delay, () {
      if (_isDisposed) return; // ⭐ CEK DISPOSED DI DALAM TIMER
      debugPrint('⏰ Auto-stop tracking: jam selesai tercapai');
      stopTracking();
    });

    debugPrint('⏰ Auto-stop dijadwalkan dalam ${delay.inMinutes} menit');
  }

  // ⭐ DISPOSE - PRIORITAS UTAMA
  @override
  void dispose() {
    // 1. SET FLAG DISPOSED PALING PERTAMA
    _isDisposed = true;
    
    // 2. BATALKAN SEMUA SUBSCRIPTIONS
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _listener?.cancel();
    _listener = null;
    
    // 3. BERSIHKAN DATA
    _latestLocations.clear();
    _isTracking = false;
    _isListening = false;
    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _currentUserFungsi = null;
    _currentOvertimeId = null;
    _currentLemburId = null;
    _lastWriteTime = null;
    
    // 4. PANGGIL SUPER DISPOSE (TANPA NOTIFY)
    super.dispose();
  }
}