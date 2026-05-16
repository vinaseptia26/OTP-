// lib/core/services/pengawas_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'notification_service.dart';

var logger = Logger();

class PengawasService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // ==================== HELPERS ====================
  String formatNumber(int number) {
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'baru saja';
    DateTime time;
    if (timestamp is Timestamp) time = timestamp.toDate();
    else if (timestamp is DateTime) time = timestamp;
    else return 'baru saja';
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'br saja';
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return const Color(0xFFFF9800);
      case 'pengawas':
        return const Color(0xFF4CAF50);
      case 'mitra':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
      case 'check_in':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'check_out':
      case 'selesai':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 15) return '☀️';
    if (hour < 18) return '🌆';
    return '🌙';
  }

  // ==================== DASHBOARD DATA ====================
  Future<PengawasDashboardData> loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User not found');
    final userData = userDoc.data()!;
    userData['uid'] = user.uid;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(today.year, today.month, 1); // ✅ Tambahan

    // 🔥 LEMBUR DATA (dari koleksi lembur_mitra)
    final lemburSnapshot = await _firestore
        .collection('lembur_mitra')
        .where('diajukan_oleh_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();

    List<Map<String, dynamic>> pending = [];
    List<Map<String, dynamic>> recent = [];
    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0; // ✅ Tambahan
    Map<String, dynamic>? activeLembur;

    for (var doc in lemburSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;

      final tanggal =
          (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();

      // ✅ HANYA HITUNG JIKA STATUS DISETUJUI
      if (status == 'disetujui' || status == 'approved') {
        if (tanggal.isAfter(startOfDay) ||
            DateUtils.isSameDay(tanggal, startOfDay)) {
          todayCount++;
        }
        if (tanggal.isAfter(startOfWeek) ||
            DateUtils.isSameDay(tanggal, startOfWeek)) {
          weekCount++;
        }
        if (tanggal.isAfter(startOfMonth) ||
            DateUtils.isSameDay(tanggal, startOfMonth)) {
          monthCount++;
        }
      }

      // Pengelompokan pending / recent
      if (status == 'pending') {
        pending.add(data);
      } else {
        recent.add(data);
      }

      // Lembur aktif (disetujui & sedang check‑in)
      if ((status == 'disetujui' || status == 'approved') &&
          data['check_in'] != null &&
          data['check_out'] == null) {
        activeLembur = data;
      }
    }

    // 🔥 TEAM MEMBERS
    final fungsi = userData['fungsi'] ?? 'operation';
    final teamSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'mitra')
        .where('fungsi', isEqualTo: fungsi)
        .limit(50)
        .get();

    final teamMembers = teamSnapshot.docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'nama': d['nama_lengkap'] ?? d['email'] ?? 'Unknown',
        'email': d['email'] ?? '',
        'phone': d['phone'] ?? '-',
        'status': d['status_akun'] ?? 'active',
        'isOnline': d['isOnline'] ?? false,
        'lastLocation': d['lastLocation'] ?? null,
        'fungsi': d['fungsi'] ?? fungsi,
        'totalLembur': (d['totalLemburBulanIni'] ?? 0).toDouble(),
      };
    }).toList();

    final onlineMembers =
        teamMembers.where((m) => m['isOnline'] == true).length;

    // 🔥 UNREAD NOTIFICATIONS
    final int unreadNotifications =
        await _notifService.getUnreadCount(user.uid);

    // 🔥 RECENT ACTIVITIES (system_logs & activity_logs)
    List<Map<String, dynamic>> activities = [];
    try {
      final logSnapshot = await _firestore
          .collection('system_logs')
          .where('target_user', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      activities.addAll(logSnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'type': d['type'] ?? 'system',
          'description': d['description'] ?? '',
          'timestamp':
              (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'user': d['user'] ?? 'System',
          'userRole': 'system',
        };
      }).toList());
    } catch (_) {}

    try {
      final activitySnapshot = await _firestore
          .collection('activity_logs')
          .where('user', isEqualTo: user.email)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      activities.addAll(activitySnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'type': d['action'] ?? 'activity',
          'description': d['description'] ?? '',
          'timestamp':
              (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'user': d['user'] ?? 'System',
          'userRole': d['role'] ?? 'system',
        };
      }).toList());
    } catch (_) {}

    activities.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    activities = activities.take(15).toList();

    // 🔥 SYSTEM HEALTH
    Map<String, dynamic> systemHealth = {
      'database': 98,
      'api': 95,
      'storage': 76,
      'memory': 82,
    };
    try {
      final healthDoc =
          await _firestore.collection('health_check').doc('current').get();
      if (healthDoc.exists) {
        systemHealth = Map<String, dynamic>.from(healthDoc.data()!);
      }
    } catch (_) {}

    // 🔥 LOCATIONS
    List<Map<String, dynamic>> locations = [];
    try {
      final locSnapshot =
          await _firestore.collection('locations').limit(50).get();
      locations = locSnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': d['name'] ?? 'Unknown',
          'lat': (d['latitude'] ?? 0).toDouble(),
          'lng': (d['longitude'] ?? 0).toDouble(),
          'status': d['status'] ?? 'Normal',
          'color': getStatusColor(d['status'] ?? 'Normal'),
          'address': d['address'] ?? '',
          'workers': d['workers'] ?? 0,
          'lastUpdate':
              (d['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (_) {}

    return PengawasDashboardData(
      userData: userData,
      fungsi: fungsi,
      pendingList: pending,
      recentList: recent.take(10).toList(),
      activeLembur: activeLembur,
      totalLemburToday: todayCount,          // ✅ hanya disetujui
      totalLemburWeek: weekCount,            // ✅ hanya disetujui
      totalLemburMonth: monthCount,          // ✅ baru, hanya disetujui
      pendingApproval: pending.length,
      teamMembers: teamMembers,
      onlineMembers: onlineMembers,
      totalTeamMembers: teamMembers.length,
      unreadNotifications: unreadNotifications,
      recentActivities: activities,
      systemHealth: systemHealth,
      locations: locations,
    );
  }

  // ==================== NOTIFICATIONS ====================
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return _notifService.getNotificationsOnce(user.uid);
  }

  Future<void> markAllNotificationsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _notifService.markAllNotificationsAsReadFlat(user.uid);
  }

  Future<void> markNotificationRead(String notifId) async {
    await _notifService.markNotificationAsReadFlat(notifId);
  }

  // ==================== LEMBUR ACTIONS ====================
  Future<void> cancelLembur(String lemburId) async {
    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'status': 'dibatalkan',
      'updated_at': FieldValue.serverTimestamp(),
    });
    await logActivity('cancel_lembur', 'Membatalkan lembur $lemburId');
  }

  Future<void> checkIn(String lemburId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'check_in': FieldValue.serverTimestamp(),
      'absensi_status': 'check_in',
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await logActivity('check_in', 'Check-in lembur $lemburId');
  }

  Future<void> checkOut(String lemburId, double totalJam) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'check_out': FieldValue.serverTimestamp(),
      'total_jam_real': totalJam,
      'absensi_status': 'check_out',
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await logActivity(
        'check_out', 'Check-out lembur $lemburId, total $totalJam jam');
  }

  // ==================== ACTIVITY LOGGING ====================
  Future<void> logActivity(String type, String description) async {
    final sessionId = generateSessionId();
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': user.email,
        'target_user': user.uid,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });

      await _firestore.collection('activity_logs').add({
        'action': type,
        'user': user.email,
        'role': 'pengawas',
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'session_id': sessionId,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  // ==================== AUTH & PROFILE ====================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
        });
        await logActivity('logout', 'Pengawas logout');
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User not found');
    return doc.data()!;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await logActivity('update_profile', 'Update profil');
  }

  // ==================== LOCATIONS ====================
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final snapshot =
          await _firestore.collection('locations').limit(50).get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': d['name'] ?? 'Unknown',
          'lat': (d['latitude'] ?? 0).toDouble(),
          'lng': (d['longitude'] ?? 0).toDouble(),
          'status': d['status'] ?? 'Normal',
          'color': getStatusColor(d['status'] ?? 'Normal'),
          'address': d['address'] ?? '',
          'workers': d['workers'] ?? 0,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '4G',
          'cctv': d['cctv'] ?? 0,
          'lastUpdate':
              (d['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      logger.e('Error get locations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final doc =
          await _firestore.collection('health_check').doc('current').get();
      if (doc.exists) return doc.data()!;
    } catch (_) {}
    return {
      'database': 98,
      'api': 95,
      'storage': 76,
      'memory': 82,
      'cpu': 23,
      'network': 45,
      'uptime': 15,
    };
  }

  Future<List<Map<String, dynamic>>> getFAQ() async {
    try {
      final snapshot =
          await _firestore.collection('faq').orderBy('createdAt').limit(20).get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'question': d['question'] ?? '',
          'answer': d['answer'] ?? '',
          'category': d['category'] ?? 'Umum',
        };
      }).toList();
    } catch (e) {
      logger.e('Error get FAQ: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getOvertimeSettings() async {
    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('lembur_config')
          .get();
      if (doc.exists) return doc.data()!;
    } catch (_) {}
    return {'max_jam_per_bulan': 60};
  }

  // ==================== GREETING & PROFILE ====================
  Future<String> getGreetingWithNameAndEmoji() async {
    final user = _auth.currentUser;
    if (user == null) return '${getGreeting()}! 👋';
    final profile = await getUserProfile();
    final name = profile['nama_lengkap'] ??
        user.displayName ??
        user.email?.split('@')[0] ??
        'Pengawas';
    return '${getGreeting()}, $name! 👋';
  }

  Future<String> getGreetingMotivation() async {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Semoga aktivitas pengawasanmu lancar hari ini! ☀️';
    if (hour < 15) return 'Tetap semangat mengawasi tim, ya! 💪';
    if (hour < 18) return 'Sore yang produktif untuk memonitor lembur. 🌆';
    return 'Jaga kesehatan, awasi tim dengan bijak malam ini. 🌙';
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'nama_lengkap': data['nama_lengkap'],
          'role': data['role'],
          'photo_url': data['photo_url'],
          'email': data['email'],
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==================== KIRIM PESAN KE MANAGER ====================
  Future<void> sendMessageToManager(String message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getUserProfile();
    final fungsi = userData['fungsi'] ?? 'operation';

    final managerSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .where('fungsi', isEqualTo: fungsi)
        .where('status_akun', isEqualTo: 'active')
        .limit(1)
        .get();

    for (var doc in managerSnapshot.docs) {
      await _notifService.sendGeneralNotification(
        userId: doc.id,
        title: 'Pesan dari ${userData['nama_lengkap'] ?? 'Pengawas'}',
        message: message,
        data: {
          'sender_id': user.uid,
          'sender_name': userData['nama_lengkap'] ?? 'Pengawas',
          'sender_role': 'pengawas',
          'fungsi': fungsi,
        },
      );
    }
  }
}

// ==================== DATA CLASS ====================
class PengawasDashboardData {
  final Map<String, dynamic> userData;
  final String fungsi;
  final List<Map<String, dynamic>> pendingList;
  final List<Map<String, dynamic>> recentList;
  final Map<String, dynamic>? activeLembur;
  final int totalLemburToday;    // ✅ hanya disetujui
  final int totalLemburWeek;     // ✅ hanya disetujui
  final int totalLemburMonth;    // ✅ baru, hanya disetujui
  final int pendingApproval;
  final List<Map<String, dynamic>> teamMembers;
  final int onlineMembers;
  final int totalTeamMembers;
  final int unreadNotifications;
  final List<Map<String, dynamic>> recentActivities;
  final Map<String, dynamic> systemHealth;
  final List<Map<String, dynamic>> locations;

  PengawasDashboardData({
    required this.userData,
    required this.fungsi,
    required this.pendingList,
    required this.recentList,
    this.activeLembur,
    required this.totalLemburToday,
    required this.totalLemburWeek,
    required this.totalLemburMonth,  // ✅ wajib diisi
    required this.pendingApproval,
    required this.teamMembers,
    required this.onlineMembers,
    required this.totalTeamMembers,
    required this.unreadNotifications,
    required this.recentActivities,
    this.systemHealth = const {},
    this.locations = const [],
  });

  bool get isCheckedIn => activeLembur != null;
}