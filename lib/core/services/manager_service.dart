// lib/core/services/manager_service.dart
// ⚡ SUPER CLEAN: TIDAK ADA KOLEKSI 'lembur', FULL pakai 'pengajuan_lembur' & 'lembur_mitra'
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'notification_service.dart';

var logger = Logger();

class ManagerService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();

  
  // ⚡ NAMA KOLEKSI (KONSTAN)
  
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // ==================== HELPERS ====================
  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal': case 'active': case 'online': return Colors.green;
      case 'warning': case 'maintenance': return Colors.orange;
      case 'anomali': case 'error': case 'offline': case 'critical': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return const Color(0xFF9C27B0);
      case 'manager': return const Color(0xFFFF9800);
      case 'pengawas': return const Color(0xFF4CAF50);
      case 'mitra': return const Color(0xFF2196F3);
      default: return Colors.grey;
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // ==================== USER DATA ====================
  Future<Map<String, dynamic>> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User data not found');
    final data = doc.data()!;
    data['uid'] = user.uid;
    return data;
  }

  // ==================== TEAM DATA ====================
  Future<TeamDataResult> getTeamData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');
    final userData = userDoc.data()!;
    final fungsi = userData['fungsi'] ?? 'operation';

    final result = await _getTeamByFungsi(fungsi);
    final onlineMembers = result.members.where((m) => m['isOnline'] == true).length;
    return TeamDataResult(
      teamMembers: result.members,
      teamIds: result.ids,
      totalMembers: result.members.length,
      onlineMembers: onlineMembers,
      fungsi: fungsi,
    );
  }

  Future<_TeamQueryResult> _getTeamByFungsi(String fungsi) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['pengawas', 'mitra'])
          .where('fungsi', isEqualTo: fungsi)
          .get();
      final members = <Map<String, dynamic>>[];
      final ids = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        members.add(_formatMemberData(doc.id, data));
        ids.add(doc.id);
      }
      members.sort((a, b) {
        if (a['role'] == 'pengawas' && b['role'] == 'mitra') return -1;
        if (a['role'] == 'mitra' && b['role'] == 'pengawas') return 1;
        return 0;
      });
      return _TeamQueryResult(members: members, ids: ids);
    } catch (e) {
      logger.e('Error getting team by fungsi: $e');
      return _TeamQueryResult(members: [], ids: []);
    }
  }

  Map<String, dynamic> _formatMemberData(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'nama': data['nama_lengkap'] ?? data['name'] ?? data['email'] ?? 'Unknown',
      'email': data['email'] ?? '',
      'role': data['role'] ?? 'mitra',
      'fungsi': data['fungsi'] ?? '-',
      'isOnline': data['isOnline'] ?? false,
      'phone': data['phone'] ?? data['no_hp'] ?? '-',
      'totalLembur': _toDouble(data['totalLemburBulanIni'] ?? data['total_lembur'] ?? 0),
      'lastActive': data['last_login'] ?? data['last_active'],
      'avatar': data['avatar'] ?? '',
      'pengawas_id': data['pengawas_id'] ?? '',
      'created_at': data['created_at'],
    };
  }

  // ==================== DASHBOARD DATA ====================
  Future<ManagerDashboardData> loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');
    final userData = userDoc.data()!;
    final fungsi = userData['fungsi'] ?? 'operation';
    userData['uid'] = user.uid;

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Team members
    final teamResult = await _getTeamByFungsi(fungsi);
    final teamMembers = teamResult.members;
    final teamUserIds = teamResult.ids;
    teamUserIds.add(user.uid);
    final onlineMembers = teamMembers.where((m) => m['isOnline'] == true).length;

    // ⚡ HANYA QUERY KE pengajuan_lembur
    final lemburSnapshot = await _firestore
        .collection(collectionPengajuan)
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .orderBy('created_at', descending: true)
        .limit(100)
        .get();

    int pending = 0, approved = 0, rejected = 0;
    int totalLemburMonthCount = 0; // ✅ dihitung hanya untuk bulan ini
    double totalHours = 0;
    List<Map<String, dynamic>> pendingList = [];
    List<Map<String, dynamic>> activityList = [];
    Map<String, Map<String, dynamic>> projectMap = {};
    List<double> chartData = List.filled(7, 0.0);

    for (var doc in lemburSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['tanggal'] = data['tanggal_lembur'] ?? data['tanggal'];

      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final jam = _toDouble(data['total_jam_desimal']);
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();

      switch (status) {
        case 'pending':
          pending++;
          pendingList.add(data);
          break;
        case 'approved':
        case 'disetujui':
          approved++;
          // ✅ Cek tanggal untuk memastikan dalam bulan ini
          final tgl = (data['tanggal'] as Timestamp?)?.toDate();
          if (tgl != null && !tgl.isBefore(firstDayOfMonth)) {
            totalHours += jam;
            totalLemburMonthCount++; // ✅ tambah hitungan hanya jika dalam bulan ini
          }
          String proyek = (data['alasan']?.toString().split(' ').take(3).join(' ') ?? 'Proyek Umum');
          projectMap.putIfAbsent(proyek, () => {'nama': proyek, 'totalJam': 0.0, 'totalPengajuan': 0});
          projectMap[proyek]!['totalJam'] += jam;
          projectMap[proyek]!['totalPengajuan']++;
          if (createdAt != null) {
            final dayDiff = now.difference(createdAt).inDays;
            if (dayDiff >= 0 && dayDiff < 7) chartData[6 - dayDiff] += jam;
          }
          break;
        case 'rejected':
        case 'ditolak':
          rejected++;
          break;
      }

      activityList.add({
        'type': status == 'pending'
            ? 'pending'
            : (status == 'disetujui' ? 'approved' : 'rejected'),
        'description':
            '${data['nama_pengawas'] ?? data['pengawas_nama'] ?? 'Unknown'} - ${jam.toStringAsFixed(1)} jam',
        'timestamp': createdAt ?? DateTime.now(),
        'user': data['nama_pengawas'] ?? data['pengawas_nama'] ?? 'Unknown',
        'userRole': 'pengawas',
        'userId': data['pengawas_id'],
        'source': 'pengajuan',
      });
    }

    // Overtime threshold
    int overtimeThreshold = 60;
    try {
      final settingsDoc = await _firestore.collection('system_settings').doc('lembur_config').get();
      if (settingsDoc.exists) {
        overtimeThreshold = settingsDoc.data()?['max_jam_per_bulan'] ?? 60;
      }
    } catch (_) {}

    // System logs dari tim
    if (teamUserIds.isNotEmpty) {
      final systemLogs = await _fetchSystemLogsBatch(teamUserIds, fungsi);
      activityList.addAll(systemLogs);
    }

    // Activity logs global (dengan filter unit)
    try {
      final activitySnapshot = await _firestore
          .collection('activity_logs')
          .where('role', whereIn: ['manager', 'pengawas', 'mitra'])
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();
      for (var doc in activitySnapshot.docs) {
        final d = doc.data();
        final logRole = d['role'] ?? 'system';
        final userEmail = d['user'] ?? '';
        final isFromSameUnit = await _isUserFromSameUnit(userEmail, fungsi);
        if (logRole == 'superadmin') continue;
        if (logRole != 'manager' && !isFromSameUnit) continue;
        activityList.add({
          'type': d['action'] ?? 'activity',
          'description': d['description'] ?? 'No description',
          'timestamp': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'user': d['user'] ?? 'System',
          'userRole': logRole,
          'userId': d['user_id'],
          'source': 'activity_logs',
        });
      }
    } catch (e) {
      logger.d('Error loading activity_logs: $e');
    }

    // Team activities
    if (teamUserIds.isNotEmpty) {
      final teamActivities = await _fetchTeamActivitiesBatch(teamUserIds);
      activityList.addAll(teamActivities);
    }

    // Sort & unique
    activityList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    final uniqueActivities = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    for (var activity in activityList) {
      final key =
          '${activity['type']}_${activity['user']}_${activity['description']}_${activity['timestamp'].toString()}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueActivities.add(activity);
      }
    }
    activityList = uniqueActivities.take(20).toList();

    // ⚡ Unread notifications via NotificationService
    final int unreadNotifications = await _notifService.getUnreadCount(user.uid);

    // Locations
    List<Map<String, dynamic>> locations = await loadLocations();

    // System health
    Map<String, dynamic> systemHealth = await loadSystemHealth();

    return ManagerDashboardData(
      userData: userData,
      fungsi: fungsi,
      totalTeamMembers: teamMembers.length,
      onlineMembers: onlineMembers,
      teamMembers: teamMembers,
      totalPending: pending,
      totalApproved: approved,
      totalRejected: rejected,
      totalHoursThisMonth: totalHours,
      totalLemburMonth: totalLemburMonthCount, // ✅ sekarang akurat: hanya bulan ini
      activeProjects: projectMap.length,
      projectStats: projectMap.values.toList(),
      pendingList: pendingList,
      overtimeThreshold: overtimeThreshold,
      recentActivities: activityList,
      chartData: chartData,
      locations: locations,
      systemHealth: systemHealth,
      unreadNotifications: unreadNotifications,
    );
  }

  // ==================== APPROVE / REJECT ====================
  Future<void> approveLembur(String lemburId, bool approve, {String? note}) async {
    final sessionId = generateSessionId();
    final user = _auth.currentUser;
    final userData = await getUserData();

    final updateData = <String, dynamic>{
      'status': approve ? 'disetujui' : 'ditolak',
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (approve) {
      updateData['approved_by'] = user?.email;
      updateData['approved_by_name'] = userData['nama_lengkap'];
      updateData['approved_at'] = FieldValue.serverTimestamp();
      updateData['approval_comment'] = note ?? '';
    } else {
      updateData['rejected_by'] = user?.email;
      updateData['rejected_by_name'] = userData['nama_lengkap'];
      updateData['rejected_at'] = FieldValue.serverTimestamp();
      updateData['rejection_reason'] = note ?? '';
    }

    final batch = _firestore.batch();

    // Update di pengajuan_lembur
    batch.update(_firestore.collection(collectionPengajuan).doc(lemburId), updateData);

    // Update di lembur_mitra untuk semua mitra dalam group
    final mitraSnapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('group_id', isEqualTo: lemburId)
        .get();
    for (var doc in mitraSnapshot.docs) {
      batch.update(_firestore.collection(collectionLemburMitra).doc(doc.id), updateData);
    }

    await batch.commit();

    // Logging
    await _firestore.collection('system_logs').add({
      'type': approve ? 'approve_lembur' : 'reject_lembur',
      'user': user?.email,
      'user_role': 'manager',
      'target_user': user?.uid,
      'session_id': sessionId,
      'timestamp': FieldValue.serverTimestamp(),
      'description': '${approve ? "Menyetujui" : "Menolak"} lembur $lemburId - ${note ?? ""}',
    });

    await _firestore.collection('activity_logs').add({
      'action': approve ? 'approve_lembur' : 'reject_lembur',
      'user': user?.email,
      'role': 'manager',
      'description': '${approve ? "Menyetujui" : "Menolak"} lembur $lemburId',
      'timestamp': FieldValue.serverTimestamp(),
      'session_id': sessionId,
      'user_id': user?.uid,
    });
  }

  // ==================== KEY METRICS ====================
  Future<ManagerKeyMetrics> getManagerKeyMetrics() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');
    final fungsi = userDoc.data()!['fungsi'] ?? 'operation';
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Team
    final teamSnapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['pengawas', 'mitra'])
        .where('fungsi', isEqualTo: fungsi)
        .get();
    final totalTeamMembers = teamSnapshot.docs.length;
    final onlineMembers = teamSnapshot.docs.where((doc) => doc.data()['isOnline'] == true).length;

    // ⚡ Query ke pengajuan_lembur
    final lemburSnapshot = await _firestore
        .collection(collectionPengajuan)
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .get();

    int pendingApprovals = 0;
    double totalHoursThisMonth = 0;
    for (var doc in lemburSnapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'pending') pendingApprovals++;
      if (status == 'disetujui' || status == 'approved') {
        final tanggal = data['tanggal_lembur'] ?? data['tanggal'];
        if (tanggal is Timestamp) {
          if (tanggal.toDate().isAfter(firstDayOfMonth)) {
            totalHoursThisMonth += _toDouble(data['total_jam_desimal']);
          }
        }
      }
    }

    int overtimeThreshold = 60;
    try {
      final settingsDoc = await _firestore.collection('system_settings').doc('lembur_config').get();
      if (settingsDoc.exists) overtimeThreshold = settingsDoc.data()?['max_jam_per_bulan'] ?? 60;
    } catch (_) {}

    return ManagerKeyMetrics(
      totalTeamMembers: totalTeamMembers,
      onlineMembers: onlineMembers,
      pendingApprovals: pendingApprovals,
      totalHoursThisMonth: totalHoursThisMonth,
      overtimeThreshold: overtimeThreshold,
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
    await _notifService.markAllAsRead(user.uid);
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'last_active': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ==================== LOCATIONS ====================
  Future<List<Map<String, dynamic>>> loadLocations() async {
    try {
      final snapshot = await _firestore.collection('locations').limit(50).get();
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
          'lastUpdate': (d['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'workers': d['workers'] ?? 0,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '4G',
          'cctv': d['cctv'] ?? 0,
        };
      }).toList();
    } catch (e) {
      logger.e('Error loading locations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> loadSystemHealth() async {
    try {
      final doc = await _firestore.collection('health_check').doc('current').get();
      if (doc.exists) return doc.data()!;
    } catch (_) {}
    return {'database': 98, 'api': 95, 'storage': 76, 'memory': 82};
  }

  // ==================== INTERNAL HELPERS ====================
  Future<List<Map<String, dynamic>>> _fetchSystemLogsBatch(List<String> teamUserIds, String fungsi) async {
    final List<Map<String, dynamic>> logs = [];
    for (int i = 0; i < teamUserIds.length; i += 10) {
      final chunk = teamUserIds.skip(i).take(10).toList();
      try {
        final snapshot = await _firestore
            .collection('system_logs')
            .where('target_user', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
        for (var doc in snapshot.docs) {
          final d = doc.data();
          final logUserRole = d['user_role'] ?? d['role'] ?? 'system';
          if (logUserRole == 'superadmin') continue;
          logs.add({
            'type': d['type'] ?? 'system',
            'description': d['description'] ?? 'No description',
            'timestamp': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'user': d['user'] ?? 'System',
            'userRole': logUserRole,
            'userId': d['target_user'],
            'source': 'system_logs',
          });
        }
      } catch (e) {
        logger.d('Error loading system_logs chunk $i: $e');
      }
    }
    return logs;
  }

  Future<List<Map<String, dynamic>>> _fetchTeamActivitiesBatch(List<String> teamUserIds) async {
    final List<Map<String, dynamic>> activities = [];
    for (int i = 0; i < teamUserIds.length; i += 10) {
      final chunk = teamUserIds.skip(i).take(10).toList();
      try {
        final snapshot = await _firestore
            .collection('activity_logs')
            .where('user_id', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
        for (var doc in snapshot.docs) {
          final d = doc.data();
          final logRole = d['role'] ?? 'team';
          if (logRole == 'superadmin') continue;
          activities.add({
            'type': d['action'] ?? 'team_activity',
            'description': d['description'] ?? 'Team activity',
            'timestamp': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'user': d['user'] ?? 'Team Member',
            'userRole': logRole,
            'userId': d['user_id'],
            'source': 'team_activities',
          });
        }
      } catch (e) {
        logger.d('Error loading team activities chunk $i: $e');
      }
    }
    return activities;
  }

  Future<bool> _isUserFromSameUnit(String userEmail, String fungsi) async {
    if (userEmail.isEmpty) return false;
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        return userData['fungsi'] == fungsi;
      }
    } catch (_) {}
    return false;
  }
}

// ==================== DATA CLASSES ====================
class ManagerDashboardData {
  final Map<String, dynamic> userData;
  final String fungsi;
  final int totalTeamMembers;
  final int onlineMembers;
  final List<Map<String, dynamic>> teamMembers;
  final int totalPending;
  final int totalApproved;
  final int totalRejected;
  final double totalHoursThisMonth;
  final int totalLemburMonth; // ✅ jumlah lembur disetujui bulan ini
  final int activeProjects;
  final List<Map<String, dynamic>> projectStats;
  final List<Map<String, dynamic>> pendingList;
  final int overtimeThreshold;
  final List<Map<String, dynamic>> recentActivities;
  final List<double> chartData;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic> systemHealth;
  final int unreadNotifications;

  ManagerDashboardData({
    required this.userData,
    required this.fungsi,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.teamMembers,
    required this.totalPending,
    required this.totalApproved,
    required this.totalRejected,
    required this.totalHoursThisMonth,
    required this.totalLemburMonth,
    required this.activeProjects,
    required this.projectStats,
    required this.pendingList,
    required this.overtimeThreshold,
    required this.recentActivities,
    this.chartData = const [],
    this.locations = const [],
    this.systemHealth = const {},
    this.unreadNotifications = 0,
  });
}

class ManagerKeyMetrics {
  final int totalTeamMembers;
  final int onlineMembers;
  final int pendingApprovals;
  final double totalHoursThisMonth;
  final int overtimeThreshold;

  ManagerKeyMetrics({
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.pendingApprovals,
    required this.totalHoursThisMonth,
    required this.overtimeThreshold,
  });

  double get utilization {
    if (overtimeThreshold == 0) return 0.0;
    return totalHoursThisMonth / overtimeThreshold;
  }

  String get utilizationPercent => '${(utilization * 100).toStringAsFixed(0)}%';

  Color get utilizationColor {
    if (utilization > 0.8) return Colors.red;
    if (utilization > 0.6) return Colors.orange;
    return Colors.purple;
  }

  String get formattedTotalHours {
    if (totalHoursThisMonth >= 100) return '${totalHoursThisMonth.toStringAsFixed(0)} jam';
    if (totalHoursThisMonth >= 10) return '${totalHoursThisMonth.toStringAsFixed(1)} jam';
    return '${totalHoursThisMonth.toStringAsFixed(1)} jam';
  }
}

class TeamDataResult {
  final List<Map<String, dynamic>> teamMembers;
  final List<String> teamIds;
  final int totalMembers;
  final int onlineMembers;
  final String fungsi;

  TeamDataResult({
    required this.teamMembers,
    required this.teamIds,
    required this.totalMembers,
    required this.onlineMembers,
    required this.fungsi,
  });
}

class _TeamQueryResult {
  final List<Map<String, dynamic>> members;
  final List<String> ids;
  _TeamQueryResult({required this.members, required this.ids});
}