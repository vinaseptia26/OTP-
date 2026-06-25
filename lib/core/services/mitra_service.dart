// lib/core/services/mitra_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

class MitraService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();

  // 📦 KONSTANTA NAMA COLLECTION
  static const String collectionUsers = 'users';
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionAbsensi = 'absensi';
  static const String collectionSettings = 'settings';
  static const String collectionConfirmations = 'mitra_confirmations';
  static const String collectionOvertimeSchedules = 'overtime_schedules';
  static const String collectionOvertimeHistory = 'overtime_history';
  static const String collectionAttendance = 'attendance';

  // 🎨 HELPER METHODS
  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 365) return DateFormat('dd MMM yyyy').format(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln lalu';
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt lalu';
    return 'Baru saja';
  }

  Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return Colors.green;
      case 'selesai':
        return Colors.teal;
      case 'pending':
        return Colors.orange;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'check_in':
        return Colors.blue;
      case 'check_out':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const Color(0xFF9C27B0);
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

  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  // ==================== GREETING & PROFILE ====================
  Future<String> getGreetingWithNameAndEmoji() async {
    final user = _auth.currentUser;
    if (user == null) return '${getGreeting()}! 👋';
    final profile = await getUserProfile();
    final name = profile['nama_lengkap'] ?? user.displayName ?? user.email?.split('@')[0] ?? 'Mitra';
    return '${getGreeting()}, $name! 👋';
  }

  Future<String> getGreetingMotivation() async {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Semoga pekerjaanmu lancar hari ini! ☀️';
    if (hour < 15) return 'Tetap semangat bekerja! 💪';
    if (hour < 18) return 'Sore yang produktif, semoga cepat selesai. 🌆';
    return 'Jaga kesehatan, istirahat yang cukup. 🌙';
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection(collectionUsers).doc(user.uid).get();
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

  // ==================== NOTIFICATIONS (DELEGASI) ====================
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

  // 📊 LOAD DASHBOARD DATA (REFACTORED)
  Future<MitraDashboardData> loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    final userId = user.uid;
    final now = DateTime.now();
    final tahunBulan = DateFormat('yyyy-MM').format(now);

    final userData = await _getUserData(userId);
    final lemburData = await _getLemburMitraData(userId, now, tahunBulan);
    final absensiData = await _getAbsensiToday(userId, now);
    final pendingData = await _getPendingRequests(userId, now);
    final additionalData = await _getAdditionalData(userId);
    final schedules = _buildSchedules(lemburData.allLembur, now);
    final stats = _calculateStats(lemburData);

    return MitraDashboardData(
      userData: userData,
      userName: userData['nama_lengkap']?.toString() ?? user.email?.split('@')[0] ?? 'Mitra',
      fungsi: userData['fungsi']?.toString() ?? 'operation',
      todayOvertime: lemburData.todayOvertime,
      todayAbsensi: absensiData.doc,
      isCheckedIn: absensiData.isCheckedIn,
      isCheckedOut: absensiData.isCheckedOut,
      lastCheckIn: absensiData.checkInTime,
      lastCheckOut: absensiData.checkOutTime,
      workDuration: absensiData.workDuration,
      allLembur: lemburData.allLembur,
      schedules: schedules,
      pendingRequests: pendingData,
      stats: stats,
      overtimeSettings: additionalData.settings,
      unreadNotifications: additionalData.unreadCount,
    );
  }

  // 🔍 PRIVATE GETTER METHODS
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection(collectionUsers).doc(userId).get();
      if (!doc.exists) throw Exception('Data user tidak ditemukan');
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      logger.e('Gagal ambil data user: $e');
      throw Exception('Gagal memuat data user');
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return _getUserData(user.uid);
  }

  // ==================== ✅ METHOD-METHOD BARU ====================
  
  /// Mendapatkan jadwal lembur yang akan datang (minggu ini)
  Future<List<Map<String, dynamic>>> getUpcomingSchedules() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: user.uid)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .orderBy('tanggal', descending: false)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final date = (data['tanggal'] as Timestamp).toDate();
        return {
          'id': doc.id,
          'date': DateFormat('dd MMM yyyy', 'id_ID').format(date),
          'jam_mulai': data['jam_mulai']?.toString() ?? '--:--',
          'jam_selesai': data['jam_selesai']?.toString() ?? '--:--',
          'description': data['alasan']?.toString() ?? data['keterangan']?.toString() ?? 'Lembur Rutin',
          'status': data['status']?.toString() ?? 'scheduled',
          'location': data['lokasi'] is Map ? data['lokasi']['pilihan']?.toString() ?? 'kantor' : 'kantor',
        };
      }).toList();
    } catch (e) {
      logger.e('Error getting upcoming schedules: $e');
      return [];
    }
  }

  /// Mendapatkan riwayat lembur terbaru
  Future<List<Map<String, dynamic>>> getRecentOvertimeHistory({int limit = 5}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: user.uid)
          .orderBy('tanggal', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final date = (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
        return {
          'id': doc.id,
          'date': DateFormat('dd MMM yyyy', 'id_ID').format(date),
          'jam_mulai': data['jam_mulai']?.toString() ?? '--:--',
          'jam_selesai': data['jam_selesai']?.toString() ?? '--:--',
          'income': (data['income_amount'] ?? data['actual_income'] ?? 0).toDouble(),
          'status': data['status']?.toString() ?? 'pending',
          'description': data['alasan']?.toString() ?? data['keterangan']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      logger.e('Error getting recent overtime history: $e');
      return [];
    }
  }

  /// Mendapatkan status kehadiran hari ini
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final snapshot = await _firestore
          .collection(collectionAbsensi)
          .where('user_id', isEqualTo: user.uid)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('waktu', isLessThan: Timestamp.fromDate(todayEnd))
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'is_checked_in': false,
          'check_in_time': '--:--',
          'working_hours': '0',
          'status': 'Belum Absen',
        };
      }
      
      final data = snapshot.docs.first.data();
      final checkInTime = (data['waktu'] as Timestamp?)?.toDate();
      final checkOutTime = (data['waktu_checkout'] as Timestamp?)?.toDate();
      
      double workingHours = 0;
      if (checkInTime != null) {
        final endTime = checkOutTime ?? DateTime.now();
        workingHours = endTime.difference(checkInTime).inMinutes / 60.0;
      }
      
      return {
        'is_checked_in': checkInTime != null,
        'check_in_time': checkInTime != null 
            ? DateFormat('HH:mm').format(checkInTime) 
            : '--:--',
        'working_hours': workingHours.toStringAsFixed(1),
        'status': checkOutTime != null ? 'Selesai' : (checkInTime != null ? 'Sedang Bekerja' : 'Belum Absen'),
      };
    } catch (e) {
      logger.e('Error getting today attendance: $e');
      return null;
    }
  }

  /// Mendapatkan data performa untuk grafik
  Future<List<Map<String, dynamic>>> getPerformanceData({int months = 6}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months + 1, 1);
      
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'selesai')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      
      // Group by month
      final Map<String, double> monthlyData = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['tanggal'] as Timestamp).toDate();
        final monthKey = DateFormat('yyyy-MM').format(date);
        final hours = (data['actual_total_jam'] ?? 0).toDouble();
        
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + hours;
      }
      
      // Fill all months in range
      final result = <Map<String, dynamic>>[];
      for (int i = months - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthKey = DateFormat('yyyy-MM').format(date);
        result.add({
          'month': DateFormat('MMM', 'id_ID').format(date),
          'year': date.year,
          'hours': (monthlyData[monthKey] ?? 0.0).toDouble(),
        });
      }
      
      return result;
    } catch (e) {
      logger.e('Error getting performance data: $e');
      return [];
    }
  }

  Future<_LemburMitraResult> _getLemburMitraData(
    String userId,
    DateTime now,
    String tahunBulan,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: userId)
          .orderBy('tanggal', descending: true)
          .limit(50)
          .get();

      final allLembur = <Map<String, dynamic>>[];
      Map<String, dynamic>? todayOvertime;
      int pending = 0, approved = 0, rejected = 0, selesai = 0;
      double totalJam = 0, totalIncome = 0;

      for (var doc in snapshot.docs) {
        final d = _normalizeLemburData(doc);
        allLembur.add(d);

        final status = (d['status'] as String? ?? 'pending').toLowerCase();
        final tanggal = d['tanggal_date'] as DateTime?;

        switch (status) {
          case 'pending': pending++; break;
          case 'disetujui':
          case 'approved': approved++; break;
          case 'ditolak':
          case 'rejected': rejected++; break;
          case 'selesai': selesai++; break;
        }

        if (tanggal != null &&
            DateUtils.isSameDay(tanggal, now) &&
            (status == 'disetujui' || status == 'approved')) {
          todayOvertime = d;
        }

        if (status == 'selesai' && d['tahun_bulan'] == tahunBulan) {
          totalJam += (d['actual_total_jam'] as num?)?.toDouble() ?? 0;
          totalIncome += (d['income_amount'] as num?)?.toDouble() ?? 0;
        }
      }

      return _LemburMitraResult(
        allLembur: allLembur,
        todayOvertime: todayOvertime,
        pending: pending,
        approved: approved,
        rejected: rejected,
        selesai: selesai,
        totalJam: totalJam,
        totalIncome: totalIncome,
      );
    } catch (e) {
      logger.e('Gagal ambil data lembur: $e');
      return _LemburMitraResult(
        allLembur: [],
        todayOvertime: null,
        pending: 0,
        approved: 0,
        rejected: 0,
        selesai: 0,
        totalJam: 0,
        totalIncome: 0,
      );
    }
  }

  Map<String, dynamic> _normalizeLemburData(QueryDocumentSnapshot doc) {
    final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

    if (raw['tanggal'] is Timestamp) {
      raw['tanggal_date'] = (raw['tanggal'] as Timestamp).toDate();
    }
    if (raw['created_at'] is Timestamp) {
      raw['created_at_date'] = (raw['created_at'] as Timestamp).toDate();
    }
    if (raw['updated_at'] is Timestamp) {
      raw['updated_at_date'] = (raw['updated_at'] as Timestamp).toDate();
    }

    return {
      'id': doc.id,
      'status': raw['status']?.toString().toLowerCase() ?? 'pending',
      'tanggal': raw['tanggal'],
      'tanggal_date': raw['tanggal_date'],
      'jam_mulai': raw['jam_mulai']?.toString() ?? '19:00',
      'jam_selesai': raw['jam_selesai']?.toString() ?? '22:00',
      'alasan': raw['alasan']?.toString() ?? raw['keterangan']?.toString() ?? 'Lembur',
      'jenis_lembur': raw['jenis_lembur']?.toString() ?? 'hari_kerja',
      'lokasi': raw['lokasi'] is Map ? raw['lokasi']['pilihan']?.toString() ?? 'kantor' : 'kantor',
      'nama_pengawas': raw['nama_pengawas']?.toString() ?? raw['pengawas_nama']?.toString() ?? 'Pengawas',
      'pengawas_id': raw['pengawas_id']?.toString() ?? raw['diajukan_oleh_id']?.toString(),
      'pengawas_fungsi': raw['pengawas_fungsi']?.toString(),
      'total_jam_desimal': (raw['total_jam_desimal'] ?? raw['total_jam'] ?? raw['actual_total_jam'] ?? 0).toDouble(),
      'actual_total_jam': (raw['actual_total_jam'] as num?)?.toDouble(),
      'tahun_bulan': raw['tahun_bulan']?.toString(),
      'absensi_status': raw['absensi_status']?.toString(),
      'absensi_waktu': raw['absensi_waktu'],
      'absensi_checkout_waktu': raw['absensi_checkout_waktu'],
      'absensi_oleh': raw['absensi_oleh']?.toString(),
      'absensi_nama': raw['absensi_nama']?.toString(),
      'income_amount': (raw['income_amount'] ?? raw['actual_income'] ?? 0).toDouble(),
      'is_income_calculated': raw['is_income_calculated'] == true,
      'group_id': raw['group_id']?.toString(),
      'mitra_id': raw['mitra_id']?.toString(),
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'created_at_date': raw['created_at_date'],
      'updated_at_date': raw['updated_at_date'],
    };
  }

  Future<_AbsensiResult> _getAbsensiToday(String userId, DateTime now) async {
    try {
      final startOfDay = DateTime(now.year, now.month, now.day);
      final snapshot = await _firestore
          .collection(collectionAbsensi)
          .where('user_id', isEqualTo: userId)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return _AbsensiResult(
          doc: null,
          isCheckedIn: false,
          isCheckedOut: false,
          checkInTime: null,
          checkOutTime: null,
          workDuration: null,
        );
      }

      final data = snapshot.docs.first.data() as Map<String, dynamic>? ?? {};
      DateTime? checkInTime;
      DateTime? checkOutTime;

      if (data['waktu'] is Timestamp) {
        checkInTime = (data['waktu'] as Timestamp).toDate();
      }
      if (data['waktu_checkout'] is Timestamp) {
        checkOutTime = (data['waktu_checkout'] as Timestamp).toDate();
      }

      return _AbsensiResult(
        doc: data,
        isCheckedIn: checkInTime != null,
        isCheckedOut: checkOutTime != null,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        workDuration: checkInTime != null
            ? (checkOutTime ?? DateTime.now()).difference(checkInTime)
            : null,
      );
    } catch (e) {
      logger.e('Gagal ambil data absensi: $e');
      return _AbsensiResult(
        doc: null,
        isCheckedIn: false,
        isCheckedOut: false,
        checkInTime: null,
        checkOutTime: null,
        workDuration: null,
      );
    }
  }

  // ✅ PERBAIKAN: query dengan mitra_ids array-contains
  Future<List<Map<String, dynamic>>> _getPendingRequests(String userId, DateTime now) async {
    try {
      final snapshot = await _firestore
          .collection(collectionPengajuan)
          .where('mitra_ids', arrayContains: userId)
          .where('status', isEqualTo: 'pending')
          .where('tanggal_lembur',
              isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 1))))
          .orderBy('tanggal_lembur', descending: false)
          .get();

      final confDoc = await _firestore
          .collection(collectionConfirmations)
          .doc(userId)
          .get();

      final confirmedIds = <String>{};
      if (confDoc.exists && confDoc.data() != null) {
        final data = confDoc.data() as Map<String, dynamic>;
        if (data['confirmed_overtime_ids'] is List) {
          confirmedIds.addAll(List<String>.from(data['confirmed_overtime_ids']));
        }
      }

      final requests = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final d = doc.data() as Map<String, dynamic>? ?? {};
        if (!confirmedIds.contains(doc.id)) {
          requests.add({
            'id': doc.id,
            'tanggal': d['tanggal_lembur'] ?? d['tanggal'],
            'jam_mulai': d['jam_mulai']?.toString() ?? '19:00',
            'jam_selesai': d['jam_selesai']?.toString() ?? '22:00',
            'total_jam': (d['total_jam_desimal'] as num?)?.toDouble() ?? 3.0,
            'alasan': d['alasan']?.toString() ?? 'Lembur',
            'pengawas_nama': d['nama_pengawas']?.toString() ?? 'Pengawas',
            'pengawas_id': d['pengawas_id']?.toString(),
            'pengawas_fungsi': d['pengawas_fungsi']?.toString() ?? '',
            'urgensi': d['urgensi']?.toString() ?? 'normal',
            'jenis_lembur': d['jenis_lembur']?.toString() ?? 'hari_kerja',
            'lokasi': d['lokasi'] is Map ? d['lokasi']['pilihan']?.toString() ?? 'kantor' : 'kantor',
            'estimasi_biaya': (d['estimasi_biaya_per_mitra'] ?? d['estimasi_biaya_total'] ?? 0).toDouble(),
          });
        }
      }
      return requests;
    } catch (e) {
      logger.e('Gagal ambil pending requests: $e');
      return [];
    }
  }

  Future<_AdditionalData> _getAdditionalData(String userId) async {
    final results = await Future.wait([
      _notifService.getUnreadCount(userId).catchError((e) {
        logger.e('Gagal ambil notifikasi: $e');
        return 0;
      }),
      _firestore
          .collection(collectionSettings)
          .doc('overtime_rates')
          .get()
          .then((doc) {
            if (doc.exists && doc.data() != null) {
              return doc.data() as Map<String, dynamic>;
            }
            return <String, dynamic>{};
          })
          .catchError((e) {
            logger.e('Gagal ambil settings: $e');
            return <String, dynamic>{};
          }),
    ]);

    return _AdditionalData(
      unreadCount: results[0] as int,
      settings: results[1] as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _buildSchedules(List<Map<String, dynamic>> allLembur, DateTime now) {
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return allLembur.where((d) {
      final status = (d['status'] as String? ?? '').toLowerCase();
      final tanggal = d['tanggal_date'] as DateTime?;
      return (status == 'disetujui' || status == 'approved') &&
          tanggal != null &&
          tanggal.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          tanggal.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, dynamic> _calculateStats(_LemburMitraResult data) {
    const maxKuota = 60;
    return {
      'totalLembur': data.approved + data.selesai,
      'totalJamLembur': data.totalJam.toInt(),
      'sisaKuota': (maxKuota - data.totalJam).toInt().clamp(0, maxKuota),
      'pending': data.pending,
      'disetujui': data.approved,
      'ditolak': data.rejected,
      'selesai': data.selesai,
      'totalIncome': data.totalIncome,
    };
  }

  // ✅ CHECK-IN LEMBUR
  Future<void> checkInLembur(String lemburId, String userName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    try {
      final lemburDoc = await _firestore.collection(collectionLemburMitra).doc(lemburId).get();
      if (!lemburDoc.exists) throw Exception('Data lembur tidak ditemukan');

      final lemburData = lemburDoc.data() ?? {};
      if (lemburData['mitra_id'] != user.uid) throw Exception('Bukan lembur milik Anda');

      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection(collectionLemburMitra).doc(lemburId), {
        'absensi_status': 'check_in',
        'absensi_waktu': now,
        'absensi_oleh': user.uid,
        'absensi_nama': userName,
        'updated_at': now,
      });

      batch.set(_firestore.collection(collectionAbsensi).doc(), {
        'lembur_id': lemburId,
        'user_id': user.uid,
        'user_name': userName,
        'waktu': now,
        'tanggal_lembur': lemburData['tanggal'],
        'pengawas_id': lemburData['diajukan_oleh_id'] ?? lemburData['pengawas_id'],
        'created_at': now,
      });

      await batch.commit();

      final pengawasId = lemburData['diajukan_oleh_id']?.toString() ??
          lemburData['pengawas_id']?.toString();
      if (pengawasId != null && pengawasId.isNotEmpty) {
        _notifService.sendMitraCheckInNotification(
          mitraName: userName,
          lemburId: lemburId,
          pengawasId: pengawasId,
        );
      }

      logger.i('Check-in berhasil: $userName -> $lemburId');
    } catch (e) {
      logger.e('Gagal check-in: $e');
      rethrow;
    }
  }

  // ✅ CHECK-OUT LEMBUR
  Future<double> checkOutLembur(
    String lemburId,
    String userName,
    Map<String, dynamic> overtimeSettings,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    try {
      final lemburDoc = await _firestore.collection(collectionLemburMitra).doc(lemburId).get();
      if (!lemburDoc.exists) throw Exception('Data lembur tidak ditemukan');

      final lemburData = lemburDoc.data() ?? {};
      if (lemburData['mitra_id'] != user.uid) throw Exception('Bukan lembur milik Anda');

      final checkInTimestamp = lemburData['absensi_waktu'];
      if (checkInTimestamp == null || checkInTimestamp is! Timestamp) {
        throw Exception('Belum check-in, tidak bisa check-out');
      }

      final checkInTime = checkInTimestamp.toDate();
      final checkOutTime = DateTime.now();
      if (checkOutTime.difference(checkInTime).inMinutes < 1) {
        throw Exception('Durasi lembur terlalu singkat');
      }

      final actualHours = checkOutTime.difference(checkInTime).inMinutes / 60.0;
      final income = _calculateIncome(actualHours, overtimeSettings);
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection(collectionLemburMitra).doc(lemburId), {
        'absensi_status': 'selesai',
        'absensi_checkout_waktu': now,
        'status': 'selesai',
        'completed_at': now,
        'actual_total_jam': actualHours,
        'actual_income': income,
        'income_amount': income,
        'is_income_calculated': true,
        'updated_at': now,
      });

      final absensiQuery = await _firestore
          .collection(collectionAbsensi)
          .where('lembur_id', isEqualTo: lemburId)
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (absensiQuery.docs.isNotEmpty) {
        batch.update(_firestore.collection(collectionAbsensi).doc(absensiQuery.docs.first.id), {
          'waktu_checkout': now,
          'actual_duration': (actualHours * 60).toInt(),
          'updated_at': now,
        });
      }

      await batch.commit();

      final pengawasId = lemburData['diajukan_oleh_id']?.toString() ??
          lemburData['pengawas_id']?.toString();
      if (pengawasId != null && pengawasId.isNotEmpty) {
        _notifService.sendMitraCheckOutNotification(
          mitraName: userName,
          lemburId: lemburId,
          pengawasId: pengawasId,
          actualHours: actualHours,
          income: income,
        );
      }

      logger.i('Check-out berhasil: $userName -> $lemburId, income: $income');
      return income;
    } catch (e) {
      logger.e('Gagal check-out: $e');
      rethrow;
    }
  }

  // 💰 KALKULASI INCOME
  double _calculateIncome(double hours, Map<String, dynamic> settings) {
    const defaultRate = 17341.04;
    const defaultM1 = 2.0;
    const defaultM2 = 3.0;
    const defaultM3 = 4.0;

    final rate = (settings['rate_per_hour'] as num?)?.toDouble() ?? defaultRate;
    final m1 = (settings['first_8_hours_multiplier'] as num?)?.toDouble() ?? defaultM1;
    final m2 = (settings['ninth_hour_multiplier'] as num?)?.toDouble() ?? defaultM2;
    final m3 = (settings['tenth_plus_multiplier'] as num?)?.toDouble() ?? defaultM3;

    if (hours <= 0) return 0;
    if (hours <= 8) return hours * rate * m1;
    if (hours <= 9) return (8 * rate * m1) + ((hours - 8) * rate * m2);
    return (8 * rate * m1) + (1 * rate * m2) + ((hours - 9) * rate * m3);
  }

  Future<void> confirmOvertime(String overtimeId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');
    try {
      await _firestore.collection(collectionConfirmations).doc(user.uid).set({
        'confirmed_overtime_ids': FieldValue.arrayUnion([overtimeId]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      logger.i('Konfirmasi berhasil: $overtimeId');
    } catch (e) {
      logger.e('Gagal konfirmasi: $e');
      rethrow;
    }
  }

  Future<void> rejectOvertime(String overtimeId, String? reason) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');
    try {
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(collectionConfirmations).doc(user.uid),
        {
          'confirmed_overtime_ids': FieldValue.arrayUnion([overtimeId]),
          'rejected_overtime_ids': FieldValue.arrayUnion([overtimeId]),
          'rejection_reasons': {overtimeId: reason ?? 'Tidak ada alasan'},
          'updated_at': now,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      _notifService.sendMitraRejectionNotification(
        mitraId: user.uid,
        overtimeId: overtimeId,
        reason: reason,
      );

      logger.i('Reject berhasil: $overtimeId, alasan: $reason');
    } catch (e) {
      logger.e('Gagal reject: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      logger.i('Logout berhasil');
    } catch (e) {
      logger.e('Gagal logout: $e');
      rethrow;
    }
  }
}

// =================== DATA CLASSES ===================
class MitraDashboardData {
  final Map<String, dynamic> userData;
  final String userName;
  final String fungsi;
  final Map<String, dynamic>? todayOvertime;
  final Map<String, dynamic>? todayAbsensi;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final Duration? workDuration;
  final List<Map<String, dynamic>> allLembur;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> pendingRequests;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> overtimeSettings;
  final int unreadNotifications;

  const MitraDashboardData({
    required this.userData,
    required this.userName,
    required this.fungsi,
    this.todayOvertime,
    this.todayAbsensi,
    required this.isCheckedIn,
    required this.isCheckedOut,
    this.lastCheckIn,
    this.lastCheckOut,
    this.workDuration,
    required this.allLembur,
    required this.schedules,
    required this.pendingRequests,
    required this.stats,
    required this.overtimeSettings,
    required this.unreadNotifications,
  });

  bool get hasTodayOvertime => todayOvertime != null;
  bool get isLemburCheckedIn => todayOvertime?['absensi_status'] == 'check_in';
  bool get isLemburCheckedOut =>
      todayOvertime?['absensi_status'] == 'check_out' ||
      todayOvertime?['absensi_status'] == 'selesai';

  int get totalLemburStat => (stats['totalLembur'] as int?) ?? 0;
  int get totalJamStat => (stats['totalJamLembur'] as int?) ?? 0;
  int get sisaKuotaStat => (stats['sisaKuota'] as int?) ?? 60;
  int get pendingStat => (stats['pending'] as int?) ?? 0;
  int get disetujuiStat => (stats['disetujui'] as int?) ?? 0;
  int get ditolakStat => (stats['ditolak'] as int?) ?? 0;
  int get selesaiStat => (stats['selesai'] as int?) ?? 0;
  double get totalIncomeStat => (stats['totalIncome'] as double?) ?? 0.0;

  String get workDurationFormatted {
    if (workDuration == null) return '-';
    final hours = workDuration!.inHours;
    final minutes = workDuration!.inMinutes.remainder(60);
    if (hours > 0) return '$hours jam $minutes mnt';
    return '$minutes mnt';
  }
}

class _LemburMitraResult {
  final List<Map<String, dynamic>> allLembur;
  final Map<String, dynamic>? todayOvertime;
  final int pending;
  final int approved;
  final int rejected;
  final int selesai;
  final double totalJam;
  final double totalIncome;

  const _LemburMitraResult({
    required this.allLembur,
    this.todayOvertime,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.selesai,
    required this.totalJam,
    required this.totalIncome,
  });
}

class _AbsensiResult {
  final Map<String, dynamic>? doc;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration? workDuration;

  const _AbsensiResult({
    this.doc,
    required this.isCheckedIn,
    required this.isCheckedOut,
    this.checkInTime,
    this.checkOutTime,
    this.workDuration,
  });
}

class _AdditionalData {
  final int unreadCount;
  final Map<String, dynamic> settings;

  const _AdditionalData({
    required this.unreadCount,
    required this.settings,
  });
}