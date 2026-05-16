// lib/core/services/overtime_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODEL OvertimeHistory ====================
class OvertimeHistory {
  final String id;
  final String groupId;
  final String? pengawasId;
  final String? namaPengawas;
  final String? pengawasFungsi;
  final String? mitraId;
  final String? namaMitra;
  final String? fungsiMitra;
  final String? noHpMitra;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final String jenisLembur;
  final Map<String, dynamic> lokasi;
  final String urgensi;
  final String alasan;
  final String catatanTambahan;
  final double estimasiBiayaPerMitra;
  final double estimasiBiayaTotal;
  final int totalMitra;
  final bool isMultiple;
  final bool isOverride;
  final String status;
  final String absensiStatus;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  OvertimeHistory({
    required this.id,
    required this.groupId,
    this.pengawasId,
    this.namaPengawas,
    this.pengawasFungsi,
    this.mitraId,
    this.namaMitra,
    this.fungsiMitra,
    this.noHpMitra,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.jenisLembur,
    required this.lokasi,
    required this.urgensi,
    required this.alasan,
    required this.catatanTambahan,
    required this.estimasiBiayaPerMitra,
    required this.estimasiBiayaTotal,
    required this.totalMitra,
    required this.isMultiple,
    required this.isOverride,
    required this.status,
    required this.absensiStatus,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor untuk parsing dari Firestore (mendukung dokumen `lembur_mitra` dan `pengajuan_lembur`)
  factory OvertimeHistory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Baca field yang bisa berbeda antara dua koleksi
    return OvertimeHistory(
      id: doc.id,
      groupId: data['group_id'] ?? data['pengajuan_id'] ?? '',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      tanggal: (data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : (data['tanggal_lembur'] as Timestamp).toDate()),
      jamMulai: data['jam_mulai'] ?? '',
      jamSelesai: data['jam_selesai'] ?? '',
      totalJam: (data['total_jam_desimal'] ?? 0).toDouble(),
      jenisLembur: data['jenis_lembur'] ?? 'hari_kerja',
      lokasi: data['lokasi'] ?? {},
      urgensi: data['urgensi'] ?? 'normal',
      alasan: data['alasan'] ?? '',
      catatanTambahan: data['catatan_tambahan'] ?? '',
      estimasiBiayaPerMitra: (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0).toDouble(),
      estimasiBiayaTotal: (data['estimasi_biaya_total'] ?? 0).toDouble(),
      totalMitra: data['total_mitra'] ?? 1,
      isMultiple: data['is_multiple'] ?? false,
      isOverride: data['is_override'] ?? false,
      status: data['status'] ?? 'pending',
      absensiStatus: data['absensi_status'] ?? 'belum_absen',
      approvedBy: data['approved_by'],
      approvedByName: data['approved_by_name'],
      approvedAt: data['approved_at'] != null 
          ? (data['approved_at'] as Timestamp).toDate() 
          : null,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'pengawas_id': pengawasId,
      'nama_pengawas': namaPengawas,
      'pengawas_fungsi': pengawasFungsi,
      'mitra_id': mitraId,
      'nama_mitra': namaMitra,
      'fungsi_mitra': fungsiMitra,
      
      'no_hp_mitra': noHpMitra,
      'tanggal': Timestamp.fromDate(tanggal),
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'total_jam_desimal': totalJam,
      'jenis_lembur': jenisLembur,
      'lokasi': lokasi,
      'urgensi': urgensi,
      'alasan': alasan,
      'catatan_tambahan': catatanTambahan,
      'estimasi_biaya_per_mitra': estimasiBiayaPerMitra,
      'estimasi_biaya_total': estimasiBiayaTotal,
      'total_mitra': totalMitra,
      'is_multiple': isMultiple,
      'is_override': isOverride,
      'status': status,
      'absensi_status': absensiStatus,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}

// ==================== OVERTIME SERVICE ====================
class OvertimeService {
  static final OvertimeService _instance = OvertimeService._internal();
  factory OvertimeService() => _instance;
  OvertimeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ==================== KONSTANTA KOLEKSI ====================
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionPengajuan = 'pengajuan_lembur';

  // ==================== TARIF LEMBUR ====================
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const double jamKerjaPerBulan = 173;

  Future<Map<String, dynamic>> loadOvertimeRates({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedRates != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedRates!;
    }

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .get();

      if (doc.exists) {
        _cachedRates = doc.data();
        _lastFetch = DateTime.now();
        return _cachedRates!;
      }
    } catch (e) {
      debugPrint('Error loading overtime rates: $e');
    }

    return _getDefaultRates();
  }

  Map<String, dynamic> _getDefaultRates() {
    const defaultGaji = 3000000.0;
    final upahPerJam = defaultGaji / jamKerjaPerBulan;
    
    return {
      'base_salary': defaultGaji,
      'rate_per_hour': upahPerJam,
      'last_updated': null,
      'updated_by': 'system',
      'weekday_rate': {
        'first_hour_multiplier': 1.5,
        'next_hours_multiplier': 2.0,
        'is_active': true,
      },
      'holiday_rate': {
        'first_8_hours_multiplier': 2.0,
        'ninth_hour_multiplier': 3.0,
        'tenth_plus_multiplier': 4.0,
        'is_active': true,
      },
    };
  }

  double calculateOvertimeCost({
    required double totalHours,
    required bool isHoliday,
    required Map<String, dynamic> rates,
  }) {
    final ratePerHour = (rates['rate_per_hour'] as num?)?.toDouble() ?? 0;
    if (ratePerHour <= 0 || totalHours <= 0) return 0;

    if (isHoliday) {
      return _calculateHolidayOvertime(totalHours, ratePerHour, rates);
    } else {
      return _calculateWeekdayOvertime(totalHours, ratePerHour, rates);
    }
  }

  double _calculateWeekdayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>;
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;

    if (roundedHours <= 1) {
      totalCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      totalCost += ratePerHour * firstHourMultiplier;
      final remainingHours = roundedHours - 1;
      totalCost += remainingHours * ratePerHour * nextHoursMultiplier;
    }

    return totalCost;
  }

  double _calculateHolidayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>;
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;
    
    final first8Hours = roundedHours < 8 ? roundedHours : 8;
    totalCost += first8Hours * ratePerHour * first8Multiplier;
    
    if (roundedHours > 8) {
      final ninthHour = roundedHours < 9 ? roundedHours - 8 : 1;
      totalCost += ninthHour * ratePerHour * ninthMultiplier;
    }
    
    if (roundedHours > 9) {
      final remainingHours = roundedHours - 9;
      totalCost += remainingHours * ratePerHour * tenthMultiplier;
    }
    
    return totalCost;
  }

  String formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  String formatRupiahCompact(double value) {
    if (value >= 1000000) {
      final juta = value / 1000000;
      return 'Rp ${juta.toStringAsFixed(1)} Jt';
    } else if (value >= 1000) {
      final ribu = value / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    } else {
      return 'Rp ${value.toStringAsFixed(0)}';
    }
  }

  void clearCache() {
    _cachedRates = null;
    _lastFetch = null;
  }

  // ==================== RIWAYAT LEMBUR (STREAM) ====================
  
  /// Mendapatkan stream riwayat lembur berdasarkan role user.
  /// Data diambil dari koleksi `lembur_mitra`.
  Stream<List<OvertimeHistory>> getOvertimeHistoryStream({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);

    // Filter berdasarkan role
    if (userRole == 'superadmin') {
      // Tidak ada filter tambahan
    } else if (userRole == 'manager') {
      // Manager melihat berdasarkan fungsi pengawas yang mengajukan
      if (userFungsi != null && userFungsi.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
      }
    } else if (userRole == 'pengawas') {
      // Pengawas melihat pengajuan yang dia buat sendiri
      query = query.where('pengawas_id', isEqualTo: userId);
    } else if (userRole == 'mitra') {
      // Mitra melihat lembur yang melibatkan dirinya (pakai field user_id atau mitra_id)
      query = query.where('user_id', isEqualTo: userId);
    }

    // Filter bulan (format yyyy-MM)
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    // Filter status (kecuali 'need_absensi' akan difilter setelah query)
    if (statusFilter != null && statusFilter != 'semua' && statusFilter != 'need_absensi') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs
              .map((doc) => OvertimeHistory.fromFirestore(doc))
              .toList();

          // Filter need_absensi: status disetujui dan absensi belum selesai
          if (statusFilter == 'need_absensi') {
            docs = docs.where((item) =>
                item.status == 'disetujui' &&
                item.absensiStatus != 'selesai'
            ).toList();
          }

          return docs;
        });
  }

  // ==================== STATISTIK ====================

  Future<Map<String, dynamic>> getOvertimeStats({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);

      if (userRole == 'superadmin') {
        // all
      } else if (userRole == 'manager') {
        if (userFungsi != null && userFungsi.isNotEmpty) {
          query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        }
      } else if (userRole == 'pengawas') {
        query = query.where('pengawas_id', isEqualTo: userId);
      } else if (userRole == 'mitra') {
        query = query.where('user_id', isEqualTo: userId);
      }

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      int total = docs.length;
      int pending = docs.where((d) => d.data()['status'] == 'pending').length;
      int approved = docs.where((d) => d.data()['status'] == 'disetujui').length;
      int completed = docs.where((d) => d.data()['status'] == 'selesai').length;
      int rejected = docs.where((d) => d.data()['status'] == 'ditolak').length;
      int expired = docs.where((d) => d.data()['status'] == 'kadaluarsa').length;
      int needAbsensi = docs.where((d) =>
          d.data()['status'] == 'disetujui' &&
          d.data()['absensi_status'] != 'selesai'
      ).length;

      double totalJam = 0;
      double totalBiaya = 0;

      for (var doc in docs) {
        final data = doc.data();
        if (data['status'] == 'selesai') {
          totalJam += (data['total_jam_desimal'] ?? 0).toDouble();
          totalBiaya += (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0).toDouble();
        }
      }

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'rejected': rejected,
        'expired': expired,
        'needAbsensi': needAbsensi,
        'totalJam': totalJam,
        'totalBiaya': totalBiaya,
        'totalMitra': total, // karena satu dokumen = satu mitra
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'expired': 0,
        'needAbsensi': 0,
        'totalJam': 0,
        'totalBiaya': 0,
        'totalMitra': 0,
      };
    }
  }

  // ==================== SINGLE DOCUMENT ====================

  /// Mendapatkan satu dokumen lembur_mitra berdasarkan ID
  Future<OvertimeHistory?> getOvertimeById(String id) async {
    try {
      final doc = await _firestore.collection(collectionLemburMitra).doc(id).get();
      if (!doc.exists) return null;
      return OvertimeHistory.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting overtime by id: $e');
      return null;
    }
  }

  /// Mendapatkan data pengajuan (induk) berdasarkan groupId
  Future<OvertimeHistory?> getPengajuanById(String groupId) async {
    try {
      final doc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      if (!doc.exists) return null;
      return OvertimeHistory.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting pengajuan: $e');
      return null;
    }
  }

  /// Mendapatkan semua dokumen lembur_mitra dalam satu group
  Future<List<OvertimeHistory>> getLemburMitraByGroup(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      return snapshot.docs
          .map((doc) => OvertimeHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting lembur mitra by group: $e');
      return [];
    }
  }

  // ==================== APPROVAL / STATUS UPDATE ====================

  /// Update status dokumen lembur_mitra (approve/reject)
  Future<void> updateOvertimeStatus({
    required String docId,
    required String status,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
    
    await _firestore.collection(collectionLemburMitra).doc(docId).update({
      'status': status,
      if (note != null) 'approval_note': note,
      'approved_by': user.uid,
      'approved_by_name': userName,
      'approved_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    // Kirim notifikasi ke pengawas terkait
    final lembur = await getOvertimeById(docId);
    if (lembur != null && lembur.pengawasId != null) {
      await _firestore.collection('notifications').add({
        'userId': lembur.pengawasId,
        'title': status == 'disetujui' ? '✅ Lembur Disetujui' : '❌ Lembur Ditolak',
        'body': 'Pengajuan lembur tanggal ${formatTanggalShort(lembur.tanggal)} ${status == 'disetujui' ? 'disetujui' : 'ditolak'}${note != null ? '\nAlasan: $note' : ''}',
        'type': 'overtime_${status == 'disetujui' ? 'approved' : 'rejected'}',
        'data': {
          'lembur_id': docId,
          'group_id': lembur.groupId,
          if (note != null) 'reason': note,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Batch approve/reject untuk semua mitra dalam satu group
  Future<void> batchUpdateStatusByGroup({
    required String groupId,
    required String status,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
    
    final snapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('group_id', isEqualTo: groupId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': status,
        if (note != null) 'approval_note': note,
        'approved_by': user.uid,
        'approved_by_name': userName,
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    
    // Notifikasi ke pengawas (ambil dari dokumen pertama)
    if (snapshot.docs.isNotEmpty) {
      final first = OvertimeHistory.fromFirestore(snapshot.docs.first);
      if (first.pengawasId != null) {
        await _firestore.collection('notifications').add({
          'userId': first.pengawasId,
          'title': status == 'disetujui' ? '✅ Lembur Disetujui' : '❌ Lembur Ditolak',
          'body': 'Pengajuan lembur group $groupId ${status == 'disetujui' ? 'disetujui' : 'ditolak'}${note != null ? '\nAlasan: $note' : ''}',
          'type': 'overtime_batch_${status == 'disetujui' ? 'approved' : 'rejected'}',
          'data': {
            'group_id': groupId,
            if (note != null) 'reason': note,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ==================== ABSENSI ====================

  /// Submit absensi untuk satu mitra
  Future<void> submitAbsensi({
    required String docId,
    required String fotoUrl,
    required String userId,
    required String userName,
  }) async {
    final batch = _firestore.batch();
    
    // Update dokumen lembur_mitra
    final lemburRef = _firestore.collection(collectionLemburMitra).doc(docId);
    batch.update(lemburRef, {
      'absensi_status': 'selesai',
      'absensi_foto_url': fotoUrl,
      'absensi_waktu': FieldValue.serverTimestamp(),
      'absensi_oleh': userId,
      'absensi_nama': userName,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Tambahkan ke koleksi absensi (opsional, untuk tracking)
    final absensiRef = _firestore.collection('absensi').doc();
    batch.set(absensiRef, {
      'lembur_id': docId,
      'user_id': userId,
      'user_name': userName,
      'foto_url': fotoUrl,
      'waktu': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    
    // Cek apakah bisa langsung selesai
    final lembur = await getOvertimeById(docId);
    if (lembur != null && lembur.status == 'disetujui') {
      await _firestore.collection(collectionLemburMitra).doc(docId).update({
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== REMINDER ====================

  /// Kirim reminder absensi ke mitra tertentu
  Future<void> sendAbsensiReminder(String docId, String groupId, String pengawasName) async {
    final lembur = await getOvertimeById(docId);
    if (lembur == null || lembur.mitraId == null) return;
    
    await _firestore.collection('notifications').add({
      'userId': lembur.mitraId,
      'title': '📸 Pengingat Absensi Lembur',
      'body': 'Pengawas $pengawasName mengingatkan untuk segera melakukan absensi lembur tanggal ${formatTanggalShort(lembur.tanggal)}.',
      'type': 'absensi_reminder',
      'data': {
        'lembur_id': docId,
        'group_id': groupId,
        'pengawas_name': pengawasName,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kirim reminder ke semua mitra dalam satu group
  Future<void> sendAbsensiReminderToGroup(String groupId, String pengawasName) async {
    final mitraList = await getLemburMitraByGroup(groupId);
    for (final mitra in mitraList) {
      if (mitra.mitraId != null && mitra.absensiStatus != 'selesai') {
        await _firestore.collection('notifications').add({
          'userId': mitra.mitraId,
          'title': '📸 Pengingat Absensi Lembur',
          'body': 'Pengawas $pengawasName mengingatkan untuk segera melakukan absensi lembur tanggal ${formatTanggalShort(mitra.tanggal)}.',
          'type': 'absensi_reminder',
          'data': {
            'lembur_id': mitra.id,
            'group_id': groupId,
            'pengawas_name': pengawasName,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ==================== EXPIRED CHECKER ====================

  /// Cek dan update lembur yang kadaluarsa (belum absen > 1 hari setelah jam selesai)
  Future<void> checkAndUpdateExpiredOvertime(String userId, String userRole) async {
    try {
      final now = DateTime.now();
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
      
      if (userRole == 'mitra') {
        query = query.where('user_id', isEqualTo: userId);
      } else if (userRole == 'pengawas') {
        query = query.where('pengawas_id', isEqualTo: userId);
      }
      
      final snapshot = await query
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', isNotEqualTo: 'selesai')
          .get();
      
      final batch = _firestore.batch();
      bool hasExpired = false;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tanggalLembur = (data['tanggal'] as Timestamp).toDate();
        final jamSelesai = data['jam_selesai'] ?? '00:00';
        
        final parts = jamSelesai.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        
        final waktuSelesai = DateTime(
          tanggalLembur.year,
          tanggalLembur.month,
          tanggalLembur.day,
          hour,
          minute,
        );
        
        final batasWaktu = waktuSelesai.add(const Duration(days: 1));
        
        if (now.isAfter(batasWaktu)) {
          batch.update(doc.reference, {
            'status': 'kadaluarsa',
            'absensi_status': 'expired',
            'expired_at': FieldValue.serverTimestamp(),
            'expired_reason': 'Tidak melakukan absensi hingga batas waktu',
            'updated_at': FieldValue.serverTimestamp(),
          });
          hasExpired = true;
        }
      }
      
      if (hasExpired) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error checking expired overtime: $e');
    }
  }

  // ==================== HELPER METHODS ====================
  
  String formatTanggal(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }
  
  String formatTanggalShort(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }
  
  String formatWaktu(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  String getStatusText(String status) {
    switch (status) {
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'pending': return 'Pending';
      case 'selesai': return 'Selesai';
      case 'kadaluarsa': return 'Kadaluarsa';
      default: return status;
    }
  }
  
  Color getStatusColor(String status) {
    switch (status) {
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'pending': return Colors.orange;
      case 'selesai': return Colors.blue;
      case 'kadaluarsa': return Colors.grey;
      default: return Colors.grey;
    }
  }
  
  String getJenisLemburLabel(String jenis) {
    switch (jenis) {
      case 'hari_kerja': return 'Hari Kerja';
      case 'hari_libur': return 'Hari Libur';
      default: return jenis;
    }
  }
  
  String getUrgensiLabel(String? urgensi) {
    switch (urgensi) {
      case 'rendah': return 'Rendah';
      case 'normal': return 'Normal';
      case 'tinggi': return 'Tinggi';
      case 'kritis': return 'Kritis';
      default: return urgensi ?? 'Normal';
    }
  }
  
  Color getUrgensiColor(String? urgensi) {
    switch (urgensi) {
      case 'rendah': return Colors.green;
      case 'normal': return Colors.blue;
      case 'tinggi': return Colors.orange;
      case 'kritis': return Colors.red;
      default: return Colors.blue;
    }
  }
  
  String getFungsiLabel(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi ?? 'Unknown';
    }
  }
  
  Color getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF1E3C72);
    }
  }
  
  String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
  
  /// Mendapatkan alamat lengkap dari field lokasi (gabungan alamat + RT/RW jika ada)
  String getAlamatLengkap(Map<String, dynamic>? lokasi) {
    if (lokasi == null) return '-';
    String alamat = lokasi['alamat'] ?? '-';
    final rt = lokasi['rt'];
    final rw = lokasi['rw'];
    if (rt != null && rt.toString().isNotEmpty) alamat += ' RT $rt';
    if (rw != null && rw.toString().isNotEmpty) alamat += ' RW $rw';
    return alamat;
  }
}