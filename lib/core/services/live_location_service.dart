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
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;

  LiveLocationData({
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
  });

  factory LiveLocationData.fromMap(Map<String, dynamic> map) {
    return LiveLocationData(
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Unknown',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
    );
  }
}

/// Service + Provider: mengirim & menerima data lokasi secara real‑time
class LiveLocationService extends ChangeNotifier {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;

  // ===================================================================
  // BAGIAN PENGIRIM (SERVICE)
  // ===================================================================
  StreamSubscription<Position>? _positionSubscription;
  String? _currentUserId;
  String? _currentOvertimeId;

  // Throttle: tulis ke Firestore maksimal setiap 15 detik
  DateTime? _lastWriteTime;
  static const _minWriteInterval = Duration(seconds: 15);

  /// Mulai tracking lokasi real‑time
  Future<void> startTracking({
    required String userId,
    required String overtimeId,
  }) async {
    // Hentikan tracking sebelumnya
    await stopTracking();

    _currentUserId = userId;
    _currentOvertimeId = overtimeId;

    // Dapatkan posisi awal segera (dengan timeout)
    try {
      final pos = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _writeLocation(pos);
    } catch (e) {
      debugPrint('Gagal ambil posisi awal: $e');
    }

    // Stream posisi dengan filter jarak (10 meter) & akurasi tinggi
    _positionSubscription = _geolocator
        .getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,   // kirim jika bergerak ≥10 meter
          ),
        )
        .listen(
          _onPositionUpdate,
          onError: (error) {
            debugPrint('Error stream posisi: $error');
          },
        );

    debugPrint('🟢 Live tracking dimulai untuk $userId');
  }

  void _onPositionUpdate(Position position) {
    // Throttle: tulis ke Firestore tidak lebih sering dari _minWriteInterval
    final now = DateTime.now();
    if (_lastWriteTime != null &&
        now.difference(_lastWriteTime!) < _minWriteInterval) {
      return; // abaikan jika belum 15 detik dari penulisan terakhir
    }
    _writeLocation(position);
  }

  Future<void> _writeLocation(Position position) async {
    if (_currentUserId == null || _currentOvertimeId == null) return;
    try {
      final user = _auth.currentUser;
      final userName = user?.displayName ?? user?.email ?? 'Unknown';
      final userRole = 'mitra'; // bisa disesuaikan

      final docRef = _firestore
          .collection('live_locations')
          .doc(_currentOvertimeId);

      // Gunakan batch untuk menulis ringkasan + riwayat
      final batch = _firestore.batch();
      batch.set(docRef, {
        'user_id': _currentUserId,
        'user_name': userName,
        'last_update': FieldValue.serverTimestamp(),
        'last_lat': position.latitude,
        'last_lng': position.longitude,
        'is_active': true,
      }, SetOptions(merge: true));
      batch.set(
        docRef.collection('updates').doc(),
        {
          'user_id': _currentUserId,
          'user_name': userName,
          'user_role': userRole,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'speed': position.speed,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();

      _lastWriteTime = DateTime.now();
      debugPrint('📍 Lokasi terkirim: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Gagal mengirim lokasi: $e');
    }
  }

  /// Hentikan tracking sepenuhnya
  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastWriteTime = null;

    // Tandai tidak aktif di Firestore
    if (_currentOvertimeId != null) {
      try {
        await _firestore
            .collection('live_locations')
            .doc(_currentOvertimeId)
            .update({'is_active': false});
      } catch (e) {
        debugPrint('Gagal update status nonaktif: $e');
      }
    }

    _currentUserId = null;
    _currentOvertimeId = null;
    debugPrint('🔴 Live tracking dihentikan');
  }

  // ===================================================================
  // BAGIAN PENERIMA (PROVIDER UNTUK VIEWER)
  // ===================================================================
  Map<String, LiveLocationData> _latestLocations = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;

  Map<String, LiveLocationData> get latestLocations => _latestLocations;

  /// Mulai mendengarkan lokasi real‑time untuk suatu overtimeId
  void listenToOvertime(String overtimeId) {
    _stopListener();

    _listener = _firestore
        .collection('live_locations')
        .doc(overtimeId)
        .collection('updates')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String;
        final loc = LiveLocationData.fromMap(data);

        // Simpan hanya yang terbaru per user
        if (!_latestLocations.containsKey(userId) ||
            loc.timestamp.isAfter(_latestLocations[userId]!.timestamp)) {
          _latestLocations[userId] = loc;
        }
      }
      notifyListeners(); // 🔄 Update UI viewer
    });
  }

  void _stopListener() {
    _listener?.cancel();
    _listener = null;
  }

  void stopListening() {
    _stopListener();
  }

  @override
  void dispose() {
    stopTracking();
    _stopListener();
    super.dispose();
  }
}