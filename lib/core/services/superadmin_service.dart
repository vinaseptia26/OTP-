// lib/core/services/dashboard_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';

var logger = Logger();

class DashboardService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardData? _cachedData;
  DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==================== REAL-TIME ONLINE USERS ====================
  Stream<List<OnlineUserData>> getOnlineUsersStream() {
    return _firestore
        .collection('online_users')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final users = <OnlineUserData>[];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            users.add(OnlineUserData(
              uid: doc.id,
              name: data['name'] ?? data['nama_lengkap'] ?? 'Unknown',
              email: data['email'] ?? '',
              role: data['role'] ?? 'mitra',
              isOnline: data['is_online'] ?? false,
              lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              deviceInfo: data['device_info'] ?? '',
              location: data['location'] ?? '',
              loginTime: (data['login_time'] as Timestamp?)?.toDate(),
            ));
          }
          users.sort((a, b) => a.name.compareTo(b.name));
          return users;
        });
  }

  Stream<int> getOnlineUsersCountStream() {
    return _firestore
        .collection('online_users')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> setUserOnline({String? deviceInfo, String? location}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final onlineData = {
        'name': userData['nama_lengkap'] ?? user.email ?? 'Unknown',
        'email': user.email,
        'role': userData['role'] ?? 'mitra',
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
        'device_info': deviceInfo ?? 'Unknown Device',
        'location': location ?? 'Unknown Location',
        'login_time': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('online_users')
          .doc(user.uid)
          .set(onlineData, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logActivity('online',
          'User ${user.email} is now online', generateSessionId());
    } catch (e) {
      logger.e('Error setting user online: $e');
    }
  }

  Future<void> setUserOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('online_users').doc(user.uid).set({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
        'logout_time': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logActivity('offline',
          'User ${user.email} is now offline', generateSessionId());
    } catch (e) {
      logger.e('Error setting user offline: $e');
    }
  }

  Future<void> updateHeartbeat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('online_users').doc(user.uid).set({
        'last_seen': FieldValue.serverTimestamp(),
        'is_online': true,
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'last_seen': FieldValue.serverTimestamp(),
        'is_online': true,
      }, SetOptions(merge: true));
    } catch (e) {
      logger.e('Error updating heartbeat: $e');
    }
  }

  Future<List<OnlineUserData>> getCurrentOnlineUsers() async {
    try {
      final snapshot = await _firestore
          .collection('online_users')
          .where('is_online', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineUserData(
          uid: doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          role: data['role'] ?? 'mitra',
          isOnline: true,
          lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          deviceInfo: data['device_info'] ?? '',
          location: data['location'] ?? '',
          loginTime: (data['login_time'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      logger.e('Error getting online users: $e');
      return [];
    }
  }

  Future<int?> getOnlineUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('online_users')
          .where('is_online', isEqualTo: true)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      logger.e('Error getting online count: $e');
      return 0;
    }
  }

  Future<List<OnlineUserData>> getOnlineUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection('online_users')
          .where('is_online', isEqualTo: true)
          .where('role', isEqualTo: role.toLowerCase())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineUserData(
          uid: doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          role: data['role'] ?? 'mitra',
          isOnline: true,
          lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          deviceInfo: data['device_info'] ?? '',
          location: data['location'] ?? '',
          loginTime: (data['login_time'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      logger.e('Error getting online users by role: $e');
      return [];
    }
  }

  // ==================== DASHBOARD DATA UTAMA (OPTIMIZED) ====================

  Future<DashboardData> loadDashboardData(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _lastCacheTime != null) {
      if (DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
        logger.i(
            '🎯 Using cached dashboard data (${DateTime.now().difference(_lastCacheTime!).inMilliseconds}ms old)');
        return _cachedData!;
      }
    }

    final stopwatch = Stopwatch()..start();
    logger.i('🚀 Starting dashboard data load...');

    try {
      final results = await Future.wait([
        _loadUsersData(),
        _loadLemburData(),
        _loadLogsData(),
      ]);

      final usersData = results[0] as Map<String, dynamic>;
      final lemburData = results[1] as Map<String, dynamic>;
      final logsData = results[2] as List<Map<String, dynamic>>;

      final dashboardData = DashboardData(
        totalUsers: usersData['totalUsers'],
        activeToday: usersData['activeToday'],
        pendingApprovals: lemburData['pendingApprovals'],
        totalOvertime: lemburData['totalOvertime'],
        approvedOvertime: lemburData['approvedOvertime'],
        verifiedUsers: usersData['verifiedUsers'],
        lockedAccounts: usersData['lockedAccounts'],
        newUsersToday: usersData['newUsersToday'],
        roleCount: usersData['roleCount'],
        fungsiCount: usersData['fungsiCount'],
        roleDistribution: usersData['roleDistribution'],
        recentActivities: logsData,
      );

      _cachedData = dashboardData;
      _lastCacheTime = DateTime.now();

      stopwatch.stop();
      logger.i(
          '✅ Dashboard data loaded in ${stopwatch.elapsedMilliseconds}ms');
      logger.i(
          '📊 Data summary: ${usersData['totalUsers']} users, ${lemburData['pendingApprovals']} pending, ${logsData.length} activities');

      return dashboardData;
    } catch (e) {
      logger.e('❌ Error loading dashboard data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadUsersData() async {
    final startTime = DateTime.now();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final totalUsersCount =
        await _firestore.collection('users').count().get();
    final totalUsers = totalUsersCount.count;
    logger.i(
        '📈 Total users count: $totalUsers (${DateTime.now().difference(startTime).inMilliseconds}ms)');

    final usersSnapshot = await _firestore
        .collection('users')
        .orderBy('last_login', descending: true)
        .limit(300)
        .get();

    logger.i(
        '👥 Users sample loaded: ${usersSnapshot.docs.length} docs (${DateTime.now().difference(startTime).inMilliseconds}ms)');

    int activeToday = 0;
    int verifiedUsers = 0;
    int lockedAccounts = 0;
    int newUsersToday = 0;
    Map<String, int> roleCount = {
      'superadmin': 0,
      'manager': 0,
      'pengawas': 0,
      'mitra': 0
    };
    Map<String, int> fungsiCount = {};

    for (var i = 0; i < usersSnapshot.docs.length; i++) {
      final data = usersSnapshot.docs[i].data();
      String role = data['role'] ?? 'mitra';
      roleCount[role] = (roleCount[role] ?? 0) + 1;

      String fungsi = data['fungsi'] ?? 'unknown';
      fungsiCount[fungsi] = (fungsiCount[fungsi] ?? 0) + 1;

      if (data['is_verified'] == true) verifiedUsers++;
      if (data['account_locked'] == true) lockedAccounts++;

      final lastLogin = data['last_login'];
      if (lastLogin is Timestamp &&
          lastLogin.toDate().isAfter(startOfDay)) activeToday++;
      if (lastLogin is DateTime && lastLogin.isAfter(startOfDay))
        activeToday++;

      final createdAt = data['created_at'];
      if (createdAt is Timestamp &&
          createdAt.toDate().isAfter(startOfDay)) newUsersToday++;
      if (createdAt is DateTime && createdAt.isAfter(startOfDay))
        newUsersToday++;
    }

    logger.i(
        '📊 Users processed in ${DateTime.now().difference(startTime).inMilliseconds}ms');

    return {
      'totalUsers': totalUsers,
      'activeToday': activeToday,
      'verifiedUsers': verifiedUsers,
      'lockedAccounts': lockedAccounts,
      'newUsersToday': newUsersToday,
      'roleCount': roleCount,
      'fungsiCount': fungsiCount,
      'roleDistribution': {
        'Super Admin': roleCount['superadmin'] ?? 0,
        'Manager': roleCount['manager'] ?? 0,
        'Pengawas': roleCount['pengawas'] ?? 0,
        'Mitra': roleCount['mitra'] ?? 0,
      },
    };
  }

  // ============================================================================
  // ⚡ PERBAIKAN: Query lembur dengan filter status & tanggal yang benar
  // ============================================================================
  Future<Map<String, dynamic>> _loadLemburData() async {
    final startTime = DateTime.now();
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(today.year, today.month, 1);

    // Parallel queries dengan filter yang tepat
    final results = await Future.wait([
      // Pending dari pengajuan_lembur (tetap)
      _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'pending')
          .limit(100)
          .get(),
      // ✅ Total lembur bulan ini dari lembur_mitra HANYA yang disetujui/approved/selesai
      _firestore
          .collection(collectionLemburMitra)
          .where('tanggal',
              isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('status', whereIn: ['disetujui', 'approved', 'selesai'])
          .limit(100)
          .get(),
      // Disetujui dari pengajuan_lembur (tetap ambil semua disetujui, lalu filter bulan)
      _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'disetujui')
          .limit(100)
          .get(),
    ]);

    final pendingSnapshot = results[0];
    final overtimeSnapshot = results[1];
    final approvedSnapshot = results[2];

    // Hitung approvedOvertime hanya yang tanggal lemburnya di bulan ini
    int approvedCount = 0;
    for (var i = 0; i < approvedSnapshot.docs.length; i++) {
      final data = approvedSnapshot.docs[i].data();
      // ✅ Gunakan tanggal_lembur (bukan created_at) untuk filter bulan
      final tanggalLembur = data['tanggal_lembur'] ?? data['tanggal'];
      if (tanggalLembur is Timestamp) {
        final date = tanggalLembur.toDate();
        if (!date.isBefore(firstDayOfMonth)) {
          approvedCount++;
        }
      }
    }

    logger.i(
        '📋 Lembur data loaded (new collections) in ${DateTime.now().difference(startTime).inMilliseconds}ms');

    return {
      'pendingApprovals': pendingSnapshot.docs.length,
      'totalOvertime': overtimeSnapshot.docs.length,   // ✅ hanya yang valid (disetujui/approved/selesai)
      'approvedOvertime': approvedCount,               // ✅ hanya bulan ini
    };
  }

  Future<List<Map<String, dynamic>>> _loadLogsData() async {
    final startTime = DateTime.now();
    final List<Map<String, dynamic>> activities = [];

    final results = await Future.wait([
      _firestore
          .collection('system_logs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get(),
      _firestore
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get(),
    ]);

    try {
      for (var doc in results[0].docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        activities.add({
          'user': data['user'] ?? 'System',
          'userRole': 'system',
          'description': data['description'] ?? 'No description',
          'type': data['type'] ?? 'system',
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      logger.w('Could not fetch system_logs: $e');
    }

    try {
      for (var doc in results[1].docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        activities.add({
          'user': data['user'] ?? 'System',
          'userRole': data['role'] ?? 'system',
          'description': data['description'] ??
              data['action'] ??
              'No description',
          'type': data['action'] ?? data['type'] ?? 'activity',
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      logger.w('Could not fetch activity_logs: $e');
    }

    activities.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    logger.i(
        '📝 Logs data loaded in ${DateTime.now().difference(startTime).inMilliseconds}ms');

    return activities.take(10).toList();
  }

  void clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
    logger.i('🗑️ Dashboard cache cleared');
  }

  // ==================== LOCATION MONITORING ====================
  Future<List<LocationData>> loadLocations() async {
    try {
      final locationsSnapshot =
          await _firestore.collection('locations').limit(50).get();

      if (locationsSnapshot.docs.isNotEmpty) {
        return locationsSnapshot.docs.map((doc) {
          final data = doc.data();
          return LocationData(
            id: doc.id,
            name: data['name'] ?? 'Unknown Site',
            lat: (data['latitude'] ?? -6.2088).toDouble(),
            lng: (data['longitude'] ?? 106.8456).toDouble(),
            status: data['status'] ?? 'Normal',
            color: getStatusColor(data['status'] ?? 'Normal'),
            address: data['address'] ?? 'No address',
            lastUpdate: data['lastUpdate'] is Timestamp
                ? (data['lastUpdate'] as Timestamp).toDate()
                : DateTime.now(),
            workers: data['workers'] ?? 0,
            battery: data['battery'] ?? 100,
            signal: data['signal'] ?? '4G',
            cctv: data['cctv'] ?? 0,
          );
        }).toList();
      }

      return await _loadLocationsFromAbsensi();
    } catch (e) {
      logger.e('Error loading locations: $e');
      return await _loadLocationsFromLembur();
    }
  }

  Future<List<LocationData>> _loadLocationsFromAbsensi() async {
    try {
      final absensiSnapshot =
          await _firestore.collection('absensi').limit(50).get();

      final Map<String, LocationData> uniqueLocations = {};

      for (var doc in absensiSnapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] ?? data['lokasi_latitude'];
        final lng = data['longitude'] ?? data['lokasi_longitude'];

        if (lat != null && lng != null) {
          final latD =
              lat is double ? lat : double.parse(lat.toString());
          final lngD =
              lng is double ? lng : double.parse(lng.toString());
          final locationKey =
              '${latD.toStringAsFixed(4)}_${lngD.toStringAsFixed(4)}';

          if (!uniqueLocations.containsKey(locationKey)) {
            uniqueLocations[locationKey] = LocationData(
              id: locationKey,
              name: data['lokasi_nama'] ??
                  'Site ${uniqueLocations.length + 1}',
              lat: latD,
              lng: lngD,
              status: 'Normal',
              color: Colors.green,
              address: data['lokasi_alamat'] ?? 'Unknown',
              lastUpdate: data['waktu'] is Timestamp
                  ? (data['waktu'] as Timestamp).toDate()
                  : DateTime.now(),
              workers: 1,
              battery: 100,
              signal: '4G',
              cctv: 0,
            );
          } else {
            uniqueLocations[locationKey] =
                uniqueLocations[locationKey]!.copyWith(
              workers: uniqueLocations[locationKey]!.workers + 1,
            );
          }
        }
      }

      if (uniqueLocations.isNotEmpty) {
        return uniqueLocations.values.toList();
      }
      return await _loadLocationsFromLembur();
    } catch (e) {
      logger.e('Error loading from absensi: $e');
      return await _loadLocationsFromLembur();
    }
  }

  Future<List<LocationData>> _loadLocationsFromLembur() async {
    try {
      final lemburSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', isEqualTo: 'disetujui')
          .limit(50)
          .get();

      final Map<String, LocationData> uniqueLocations = {};

      for (var doc in lemburSnapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map?;

        if (lokasi != null) {
          final lat = lokasi['latitude'];
          final lng = lokasi['longitude'];

          if (lat != null && lng != null) {
            final latD = lat is double
                ? lat
                : double.parse(lat.toString());
            final lngD = lng is double
                ? lng
                : double.parse(lng.toString());
            final locationKey =
                '${latD.toStringAsFixed(4)}_${lngD.toStringAsFixed(4)}';

            if (!uniqueLocations.containsKey(locationKey)) {
              uniqueLocations[locationKey] = LocationData(
                id: locationKey,
                name: lokasi['nama'] ??
                    'Site ${uniqueLocations.length + 1}',
                lat: latD,
                lng: lngD,
                status: 'Normal',
                color: Colors.green,
                address: lokasi['alamat'] ?? 'Unknown',
                lastUpdate: data['tanggal'] is Timestamp
                    ? (data['tanggal'] as Timestamp).toDate()
                    : DateTime.now(),
                workers: 1,
                battery: 100,
                signal: '4G',
                cctv: 0,
              );
            } else {
              uniqueLocations[locationKey] =
                  uniqueLocations[locationKey]!.copyWith(
                workers: uniqueLocations[locationKey]!.workers + 1,
              );
            }
          }
        }
      }

      return uniqueLocations.values.toList();
    } catch (e) {
      logger.e('Error loading from lembur: $e');
      return [];
    }
  }

  // ==================== LIVE STREAM UNTUK LOKASI AKTIF ====================

  /// Stream semua user yang sedang mengirim live location.
  Stream<List<LocationData>> streamLiveLocations() {
    return _firestore
        .collection('live_locations')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            double lat, lng;
            final geo = data['coordinates'];
            if (geo is GeoPoint) {
              lat = geo.latitude;
              lng = geo.longitude;
            } else if (data['latitude'] != null && data['longitude'] != null) {
              lat = (data['latitude'] as num).toDouble();
              lng = (data['longitude'] as num).toDouble();
            } else {
              // fallback
              lat = -6.2; lng = 106.8;
            }
            return LocationData(
              id: doc.id, // userId
              name: data['user_name'] ?? data['name'] ?? 'Unknown',
              lat: lat,
              lng: lng,
              status: data['status'] ?? 'Normal',
              color: getStatusColor(data['status'] ?? 'Normal'),
              address: data['address'] ?? '',
              lastUpdate: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              workers: 1,
              battery: data['battery'] ?? 100,
              signal: data['signal'] ?? '4G',
              cctv: 0,
            );
          }).toList();
        });
  }

  /// Hanya lokasi user yang sedang lembur disetujui & sudah check-in.
  Stream<List<LocationData>> streamActiveOvertimeLocations() {
    // Ambil set mitra_id yang memenuhi syarat
    final activeMitraStream = _firestore
        .collection(collectionLemburMitra)
        .where('status', isEqualTo: 'disetujui')
        .where('absensi_status', isEqualTo: 'check_in')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['mitra_id'] as String).toSet());

    return activeMitraStream.asyncExpand((activeIds) {
      return streamLiveLocations().map(
          (allLocs) => allLocs.where((loc) => activeIds.contains(loc.id)).toList());
    });
  }

  // ==================== SYSTEM HEALTH ====================
  Future<Map<String, dynamic>> loadSystemHealth() async {
    try {
      final doc = await _firestore
          .collection('health_check')
          .doc('current')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'database': data['database'] ?? 98,
          'api': data['api'] ?? 95,
          'storage': data['storage'] ?? 76,
          'memory': data['memory'] ?? 82,
          'cpu': data['cpu'] ?? 23,
          'network': data['network'] ?? 45,
          'uptime': data['uptime'] ?? 15,
          'lastBackup': data['last_backup'] is Timestamp
              ? (data['last_backup'] as Timestamp).toDate()
              : DateTime.now().subtract(const Duration(hours: 2)),
        };
      }

      final settingsDoc = await _firestore
          .collection('system_settings')
          .doc('health')
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        return {
          'database': data['database'] ?? 98,
          'api': data['api'] ?? 95,
          'storage': data['storage'] ?? 76,
          'memory': data['memory'] ?? 82,
          'cpu': data['cpu'] ?? 23,
          'network': data['network'] ?? 45,
          'uptime': data['uptime'] ?? 15,
          'lastBackup': data['lastBackup'] is Timestamp
              ? (data['lastBackup'] as Timestamp).toDate()
              : DateTime.now().subtract(const Duration(hours: 2)),
        };
      }
    } catch (e) {
      logger.e('Error loading system health: $e');
    }

    return {
      'database': 98,
      'api': 95,
      'storage': 76,
      'memory': 82,
      'cpu': 23,
      'network': 45,
      'uptime': 15,
      'lastBackup':
          DateTime.now().subtract(const Duration(hours: 2)),
    };
  }

  // ==================== DASHBOARD CONFIG ====================
  Future<Map<String, dynamic>> loadDashboardConfig() async {
    try {
      final doc = await _firestore
          .collection('dashboard_config')
          .doc('superadmin')
          .get();

      if (doc.exists) {
        return doc.data()!;
      }
    } catch (e) {
      logger.e('Error loading dashboard config: $e');
    }
    return {};
  }

  // ==================== FAQ ====================
  Future<List<Map<String, dynamic>>> loadFAQ() async {
    try {
      final snapshot = await _firestore
          .collection('faq')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] ?? '',
          'answer': data['answer'] ?? '',
          'category': data['category'] ?? 'Umum',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      logger.e('Error loading FAQ: $e');
      return [];
    }
  }

  Future<void> addFAQ({
    required String question,
    required String answer,
    required String category,
  }) async {
    await _firestore.collection('faq').add({
      'question': question,
      'answer': answer,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.email ?? 'unknown',
    });
  }

  Future<void> deleteFAQ(String faqId) async {
    await _firestore.collection('faq').doc(faqId).delete();
  }

  // ==================== BROADCAST ====================
  Future<void> sendBroadcast({
    required String message,
    required String targetRole,
  }) async {
    await _firestore.collection('broadcasts').add({
      'message': message,
      'targetRole': targetRole,
      'createdBy': _auth.currentUser?.email ?? 'unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  // ==================== LOGGING ====================
  Future<void> logActivity(
      String type, String description, String sessionId) async {
    try {
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': _auth.currentUser?.uid ?? 'unknown',
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });

      await _firestore.collection('activity_logs').add({
        'action': type,
        'user': _auth.currentUser?.email ?? 'unknown',
        'role': 'superadmin',
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'session_id': sessionId,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  // ==================== BACKUP ====================
  Future<void> performBackup(String sessionId) async {
    await logActivity(
        'backup', 'Database backup performed', sessionId);

    try {
      await _firestore
          .collection('health_check')
          .doc('current')
          .set({
        'last_backup': FieldValue.serverTimestamp(),
        'backup_by': _auth.currentUser?.email ?? 'unknown',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      logger.e('Error updating backup time: $e');
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout(String sessionId) async {
    await setUserOffline();
    await logActivity('logout', 'User logged out', sessionId);
    await _auth.signOut();
  }

  // ==================== USER PROFILE & GREETING ====================
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'uid': user.uid,
          'nama_lengkap': data['nama_lengkap'] ?? '',
          'email': user.email ?? '',
          'role': data['role'] ?? 'mitra',
          'fungsi': data['fungsi'] ?? '',
          'nip': data['nip'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'photo_url':
              data['photo_url'] ?? data['foto_profil'] ?? '',
          'is_verified': data['is_verified'] ?? false,
          'is_online': data['is_online'] ?? true,
          'last_login': data['last_login'],
          'created_at': data['created_at'],
          'account_locked': data['account_locked'] ?? false,
        };
      }

      return {
        'uid': user.uid,
        'nama_lengkap': user.displayName ?? '',
        'email': user.email ?? '',
        'role': 'mitra',
        'fungsi': '',
        'nip': '',
        'no_hp': user.phoneNumber ?? '',
        'photo_url': user.photoURL ?? '',
        'is_verified': user.emailVerified,
        'is_online': true,
        'last_login': user.metadata.lastSignInTime,
        'created_at': user.metadata.creationTime,
        'account_locked': false,
      };
    } catch (e) {
      logger.e('Error getting current user profile: $e');
      return null;
    }
  }

  Future<String> getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Pengguna';

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null &&
            data['nama_lengkap'] != null &&
            data['nama_lengkap'].toString().trim().isNotEmpty) {
          return data['nama_lengkap'].toString().trim();
        }
      }

      if (user.displayName != null &&
          user.displayName!.trim().isNotEmpty) {
        return user.displayName!.trim();
      }

      if (user.email != null && user.email!.isNotEmpty) {
        final emailName = user.email!.split('@')[0];
        return emailName
            .replaceAll('.', ' ')
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1)}'
                : '')
            .join(' ');
      }

      return 'Pengguna';
    } catch (e) {
      logger.e('Error getting user name: $e');
      return 'Pengguna';
    }
  }

  Future<String> getGreetingWithName() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;

    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour >= 12 && hour < 15) {
      greeting = 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }

    return '$greeting, $userName! 👋';
  }

  Future<String> getGreetingWithNameAndEmoji() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;

    String greeting;
    String emoji;
    if (hour >= 5 && hour < 12) {
      greeting = 'Selamat Pagi';
      emoji = '🌅';
    } else if (hour >= 12 && hour < 15) {
      greeting = 'Selamat Siang';
      emoji = '☀️';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore';
      emoji = '🌆';
    } else {
      greeting = 'Selamat Malam';
      emoji = '🌙';
    }

    return '$greeting, $userName! $emoji';
  }

  Future<String> getGreetingMotivation() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;

    List<String> motivations;

    if (dayOfWeek == 1) {
      motivations = [
        'Awali minggu dengan semangat baru',
        'Saatnya memulai pekan yang produktif',
        'Mari capai target minggu ini',
      ];
    } else if (dayOfWeek == 5) {
      motivations = [
        'Jumat berkah, tetap semangat',
        'Semoga hari ini penuh keberkahan',
        'Jangan lupa ibadah dan doa hari ini',
      ];
    } else if (dayOfWeek == 6 || dayOfWeek == 7) {
      motivations = [
        'Selamat berakhir pekan',
        'Tetap produktif di akhir pekan',
        'Waktunya istirahat dan refleksi',
      ];
    } else {
      motivations = [
        'Semangat bekerja hari ini',
        'Tetap fokus dan produktif',
        'Jadikan hari ini lebih baik dari kemarin',
        'Konsistensi adalah kunci kesuksesan',
      ];
    }

    final motivation = motivations[hour % motivations.length];
    return '$motivation, $userName! 💪';
  }

  // ==================== HELPER METHODS ====================
  String formatNumber(int number) {
    if (number >= 1000000)
      return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000)
      return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'baru saja';
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return 'baru saja';
    }

    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30)
      return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'br saja';
  }

  Color getStatusColor(String status) {
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

  Color getRoleColor(String role) {
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

  @Deprecated('Gunakan getGreetingWithName()')
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Selamat Pagi';
    if (hour >= 12 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @Deprecated('Gunakan getGreetingWithNameAndEmoji()')
  String getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '🌅';
    if (hour >= 12 && hour < 15) return '☀️';
    if (hour >= 15 && hour < 18) return '🌆';
    return '🌙';
  }
}

// ==================== DATA CLASSES ====================
class DashboardData {
  final int totalUsers;
  final int activeToday;
  final int pendingApprovals;
  final int totalOvertime;
  final int approvedOvertime;
  final int verifiedUsers;
  final int lockedAccounts;
  final int newUsersToday;
  final Map<String, int> roleCount;
  final Map<String, int> fungsiCount;
  final Map<String, int> roleDistribution;
  final List<Map<String, dynamic>> recentActivities;

  DashboardData({
    required this.totalUsers,
    required this.activeToday,
    required this.pendingApprovals,
    required this.totalOvertime,
    required this.approvedOvertime,
    required this.verifiedUsers,
    required this.lockedAccounts,
    required this.newUsersToday,
    required this.roleCount,
    required this.fungsiCount,
    required this.roleDistribution,
    required this.recentActivities,
  });
}

class LocationData {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String status;
  final Color color;
  final String address;
  final DateTime lastUpdate;
  final int workers;
  final int battery;
  final String signal;
  final int cctv;

  LocationData({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.status,
    required this.color,
    required this.address,
    required this.lastUpdate,
    required this.workers,
    required this.battery,
    required this.signal,
    required this.cctv,
  });

  LocationData copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    Color? color,
    String? address,
    DateTime? lastUpdate,
    int? workers,
    int? battery,
    String? signal,
    int? cctv,
  }) {
    return LocationData(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      status: status ?? this.status,
      color: color ?? this.color,
      address: address ?? this.address,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      workers: workers ?? this.workers,
      battery: battery ?? this.battery,
      signal: signal ?? this.signal,
      cctv: cctv ?? this.cctv,
    );
  }
}

class OnlineUserData {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isOnline;
  final DateTime lastSeen;
  final String deviceInfo;
  final String location;
  final DateTime? loginTime;

  OnlineUserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isOnline,
    required this.lastSeen,
    required this.deviceInfo,
    required this.location,
    this.loginTime,
  });
}