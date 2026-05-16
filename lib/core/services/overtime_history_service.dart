// lib/core/services/overtime_history_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model OvertimeHistory — mendukung data dari pengajuan_lembur & lembur_mitra
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
  final bool spklGenerated;
  final String? spklNomor;
  final String? spklPath;
  final List<String>? mitraIds;
  final DateTime? absensiWaktu;
  final String? absensiFotoUrl;
  final String? absensiOleh;
  final String? absensiNama;
  final String tipeDokumen;
  final String? diajukanOlehId;
  final String? diajukanOlehNama;

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
    this.spklGenerated = false,
    this.spklNomor,
    this.spklPath,
    this.mitraIds,
    this.absensiWaktu,
    this.absensiFotoUrl,
    this.absensiOleh,
    this.absensiNama,
    this.tipeDokumen = 'lembur_mitra',
    this.diajukanOlehId,
    this.diajukanOlehNama,
  });

  static DateTime _parseTimestamp(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseTimestampOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory OvertimeHistory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    List<String>? parsedMitraIds;
    if (data['mitra_ids'] != null && data['mitra_ids'] is List) {
      parsedMitraIds = List<String>.from(data['mitra_ids']);
    }

    final tanggalValue = data['tanggal'] ?? data['tanggal_lembur'];
    final DateTime tanggal = _parseTimestamp(tanggalValue);

    return OvertimeHistory(
      id: doc.id,
      groupId: data['group_id'] ?? '',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      tanggal: tanggal,
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
      approvedAt: _parseTimestampOrNull(data['approved_at']),
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      spklGenerated: data['spkl_generated'] ?? false,
      spklNomor: data['spkl_nomor'],
      spklPath: data['spkl_path'],
      mitraIds: parsedMitraIds,
      absensiWaktu: _parseTimestampOrNull(data['absensi_waktu']),
      absensiFotoUrl: data['absensi_foto_url'],
      absensiOleh: data['absensi_oleh'],
      absensiNama: data['absensi_nama'],
      tipeDokumen: data['tipe_dokumen'] ?? 'lembur_mitra',
      diajukanOlehId: data['diajukan_oleh_id'] ?? data['pengawas_id'],
      diajukanOlehNama: data['diajukan_oleh_nama'] ?? data['nama_pengawas'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'group_id': groupId,
      'pengawas_id': pengawasId, 'nama_pengawas': namaPengawas,
      'pengawas_fungsi': pengawasFungsi, 'mitra_id': mitraId,
      'nama_mitra': namaMitra, 'fungsi_mitra': fungsiMitra,
      'tanggal': Timestamp.fromDate(tanggal),
      'jam_mulai': jamMulai, 'jam_selesai': jamSelesai,
      'total_jam_desimal': totalJam, 'jenis_lembur': jenisLembur,
      'lokasi': lokasi, 'urgensi': urgensi, 'alasan': alasan,
      'catatan_tambahan': catatanTambahan,
      'estimasi_biaya_per_mitra': estimasiBiayaPerMitra,
      'estimasi_biaya_total': estimasiBiayaTotal,
      'total_mitra': totalMitra, 'is_multiple': isMultiple,
      'is_override': isOverride, 'status': status,
      'absensi_status': absensiStatus,
      'approved_by': approvedBy, 'approved_by_name': approvedByName,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'spkl_generated': spklGenerated, 'spkl_nomor': spklNomor,
      'spkl_path': spklPath, 'mitra_ids': mitraIds,
      'absensi_waktu': absensiWaktu != null ? Timestamp.fromDate(absensiWaktu!) : null,
      'absensi_foto_url': absensiFotoUrl, 'absensi_oleh': absensiOleh,
      'absensi_nama': absensiNama, 'tipe_dokumen': tipeDokumen,
      'diajukan_oleh_id': diajukanOlehId, 'diajukan_oleh_nama': diajukanOlehNama,
    };
  }

  String get namaPengaju => diajukanOlehNama ?? namaPengawas ?? 'Tidak diketahui';
  bool get isMitraDocument => tipeDokumen == 'lembur_mitra';
  bool get isPengajuanDocument => tipeDokumen == 'pengajuan';
}

/// Service untuk riwayat lembur, statistik, dan operasi terkait
class OvertimeHistoryService {
  static final OvertimeHistoryService _instance = OvertimeHistoryService._internal();
  factory OvertimeHistoryService() => _instance;
  OvertimeHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';

  // =========================================================================
  // ⚡ METHOD UTAMA
  // =========================================================================
  Stream<List<OvertimeHistory>> getOvertimeHistoryStream({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
    String? statusFilter,
  }) {
    Stream<List<OvertimeHistory>> stream;

    if (userRole == 'mitra') {
      stream = _getMitraHistoryStream(
        mitraId: userId!,
        bulan: bulan,
        statusFilter: statusFilter,
      );
    } else if (userRole == 'pengawas') {
      stream = _getPengawasHistoryStream(
        pengawasId: userId!,
        bulan: bulan,
        statusFilter: statusFilter,
      );
    } else if (userRole == 'manager') {
      stream = _getManagerHistoryStream(
        fungsi: userFungsi,
        bulan: bulan,
        statusFilter: statusFilter,
      );
    } else {
      stream = _getAllHistoryStream(
        bulan: bulan,
        statusFilter: statusFilter,
      );
    }

    return stream.handleError((error, stackTrace) {
      debugPrint('❌ OvertimeHistoryStream ERROR: $error');
      return <OvertimeHistory>[];
    });
  }

  // =========================================================================
  // ⚡ STREAM MITRA (Dari lembur_mitra)
  // =========================================================================
  Stream<List<OvertimeHistory>> _getMitraHistoryStream({
    required String mitraId,
    String? bulan,
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('mitra_id', isEqualTo: mitraId);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'semua' &&
        statusFilter != 'need_absensi') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.orderBy('tanggal', descending: true).snapshots().map((snapshot) {
      try {
        var docs = snapshot.docs
            .map((doc) => OvertimeHistory.fromFirestore(doc))
            .toList();

        if (statusFilter == 'need_absensi') {
          docs = docs
              .where((item) =>
                  item.status == 'disetujui' && item.absensiStatus != 'selesai')
              .toList();
        }

        return docs;
      } catch (e) {
        debugPrint('❌ Mitra stream parse error: $e');
        return <OvertimeHistory>[];
      }
    });
  }

  // =========================================================================
  // ⚡ STREAM PENGAWAS — dari lembur_mitra, diffilter diajukan_oleh_id
  // =========================================================================
  Stream<List<OvertimeHistory>> _getPengawasHistoryStream({
    required String pengawasId,
    String? bulan,
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('diajukan_oleh_id', isEqualTo: pengawasId);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'semua' &&
        statusFilter != 'need_absensi') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.orderBy('tanggal', descending: true).snapshots().map((snapshot) {
      try {
        var docs = snapshot.docs
            .map((doc) => OvertimeHistory.fromFirestore(doc))
            .toList();

        if (statusFilter == 'need_absensi') {
          docs = docs
              .where((item) =>
                  item.status == 'disetujui' && item.absensiStatus != 'selesai')
              .toList();
        }

        debugPrint('📋 Pengawas history: ${docs.length} items dari lembur_mitra');
        return docs;
      } catch (e) {
        debugPrint('❌ Pengawas stream parse error: $e');
        return <OvertimeHistory>[];
      }
    });
  }

  // =========================================================================
  // ⚡ STREAM MANAGER (Dari pengajuan_lembur)
  // =========================================================================
  Stream<List<OvertimeHistory>> _getManagerHistoryStream({
    String? fungsi,
    String? bulan,
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection(collectionPengajuan);

    if (fungsi != null && fungsi.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: fungsi);
    }

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'semua' &&
        statusFilter != 'need_absensi') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.orderBy('created_at', descending: true).snapshots().map((snapshot) {
      try {
        var docs = snapshot.docs
            .map((doc) => OvertimeHistory.fromFirestore(doc))
            .toList();

        if (statusFilter == 'need_absensi') {
          docs = docs
              .where((item) =>
                  item.status == 'disetujui' && item.absensiStatus != 'selesai')
              .toList();
        }

        return docs;
      } catch (e) {
        debugPrint('❌ Manager stream parse error: $e');
        return <OvertimeHistory>[];
      }
    });
  }

  // =========================================================================
  // ⚡ STREAM SUPERADMIN (GABUNGAN PENGAJUAN + LEMBUR_MITRA)
  // =========================================================================
  Stream<List<OvertimeHistory>> _getAllHistoryStream({
    String? bulan,
    String? statusFilter,
  }) {
    final controller = StreamController<List<OvertimeHistory>>();
    StreamSubscription? pengajuanSub;
    StreamSubscription? mitraSub;

    List<OvertimeHistory> lastPengajuan = [];
    List<OvertimeHistory> lastMitra = [];

    void emitMerged() {
      var allData = [...lastPengajuan, ...lastMitra];

      // Dedup by id
      final seenIds = <String>{};
      allData = allData.where((item) {
        if (seenIds.contains(item.id)) return false;
        seenIds.add(item.id);
        return true;
      }).toList();

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        if (statusFilter == 'need_absensi') {
          allData = allData
              .where((item) => item.status == 'disetujui' && item.absensiStatus != 'selesai')
              .toList();
        } else {
          allData = allData.where((item) => item.status == statusFilter).toList();
        }
      }

      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      if (!controller.isClosed) controller.add(allData);
    }

    // Setup stream pengajuan
    Query<Map<String, dynamic>> queryPengajuan = _firestore.collection(collectionPengajuan);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      queryPengajuan = queryPengajuan.where('tahun_bulan', isEqualTo: bulan);
    }
    final pengajuanStream = queryPengajuan
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList());

    // Setup stream mitra
    Query<Map<String, dynamic>> queryMitra = _firestore.collection(collectionLemburMitra);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      queryMitra = queryMitra.where('tahun_bulan', isEqualTo: bulan);
    }
    final mitraStream = queryMitra
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList());

    pengajuanSub = pengajuanStream.listen((data) {
      lastPengajuan = data;
      emitMerged();
    });

    mitraSub = mitraStream.listen((data) {
      lastMitra = data;
      emitMerged();
    });

    controller.onCancel = () {
      pengajuanSub?.cancel();
      mitraSub?.cancel();
    };

    return controller.stream;
  }

  // =========================================================================
  // ⚡ STATISTIK
  // =========================================================================
  Future<Map<String, dynamic>> getOvertimeStats({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
  }) async {
    try {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

      if (userRole == 'mitra') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
        if (userId != null && userId.isNotEmpty) query = query.where('mitra_id', isEqualTo: userId);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        final snapshot = await query.get();
        allDocs = snapshot.docs.toList();
      } else if (userRole == 'pengawas') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
        if (userId != null && userId.isNotEmpty) query = query.where('diajukan_oleh_id', isEqualTo: userId);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        final snapshot = await query.get();
        allDocs = snapshot.docs.toList();
      } else if (userRole == 'manager') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionPengajuan);
        if (userFungsi != null && userFungsi.isNotEmpty) query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        final snapshot = await query.get();
        allDocs = snapshot.docs.toList();
      } else {
        Query<Map<String, dynamic>> queryPengajuan = _firestore.collection(collectionPengajuan);
        Query<Map<String, dynamic>> queryMitra = _firestore.collection(collectionLemburMitra);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
          queryPengajuan = queryPengajuan.where('tahun_bulan', isEqualTo: bulan);
          queryMitra = queryMitra.where('tahun_bulan', isEqualTo: bulan);
        }
        final results = await Future.wait([queryPengajuan.get(), queryMitra.get()]);
        allDocs = [...results[0].docs, ...results[1].docs];
      }

      int total = allDocs.length;
      int pending = 0, approved = 0, completed = 0, rejected = 0, expired = 0, needAbsensi = 0;
      double totalJam = 0, totalBiaya = 0;
      int totalMitra = 0;

      for (var doc in allDocs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        switch (status) {
          case 'pending': pending++; break;
          case 'disetujui': approved++; if (data['absensi_status'] != 'selesai') needAbsensi++; break;
          case 'selesai': completed++; totalJam += (data['total_jam_desimal'] ?? 0).toDouble(); totalBiaya += (data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? 0).toDouble(); break;
          case 'ditolak': rejected++; break;
          case 'kadaluarsa': expired++; break;
        }
        totalMitra += (data['total_mitra'] as int? ?? 1);
      }

      return {
        'total': total, 'pending': pending, 'approved': approved,
        'completed': completed, 'rejected': rejected, 'expired': expired,
        'needAbsensi': needAbsensi, 'totalJam': totalJam,
        'totalBiaya': totalBiaya, 'totalMitra': totalMitra,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'total': 0, 'pending': 0, 'approved': 0, 'completed': 0,
        'rejected': 0, 'expired': 0, 'needAbsensi': 0,
        'totalJam': 0, 'totalBiaya': 0, 'totalMitra': 0,
      };
    }
  }

  // =========================================================================
  // ⚡ GET BY ID
  // =========================================================================
  Future<OvertimeHistory?> getOvertimeById(String id) async {
    try {
      var doc = await _firestore.collection(collectionLemburMitra).doc(id).get();
      if (doc.exists) return OvertimeHistory.fromFirestore(doc);
      doc = await _firestore.collection(collectionPengajuan).doc(id).get();
      if (doc.exists) return OvertimeHistory.fromFirestore(doc);
      return null;
    } catch (e) {
      debugPrint('Error getting overtime by id: $e');
      return null;
    }
  }

  // =========================================================================
  // ⚡ GET BY GROUP ID
  // =========================================================================
  Future<List<Map<String, dynamic>>> getOvertimeByGroupId(String groupId) async {
    try {
      final pengajuanSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('group_id', isEqualTo: groupId)
          .get();
      final mitraSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();

      final results = <Map<String, dynamic>>[];
      for (var doc in pengajuanSnapshot.docs) {
        results.add({'docId': doc.id, ...doc.data()});
      }
      for (var doc in mitraSnapshot.docs) {
        results.add({'docId': doc.id, ...doc.data()});
      }
      return results;
    } catch (e) {
      debugPrint('Error getting overtime by group: $e');
      return [];
    }
  }

  /// Mendapatkan semua dokumen lembur_mitra dalam satu group (berguna untuk detail)
  Future<List<OvertimeHistory>> getMitraDocsByGroupId(String groupId) async {
    try {
      final snap = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      return snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting mitra by group: $e');
      return [];
    }
  }

  // =========================================================================
  // ⚡ UPDATE ABSENSI
  // =========================================================================
  Future<bool> updateAbsensiStatus({
    required String lemburId,
    required String absensiStatus,
    String? fotoUrl,
    String? absensiOleh,
    String? absensiNama,
    DateTime? absensiWaktu,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'absensi_status': absensiStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (fotoUrl != null) updateData['absensi_foto_url'] = fotoUrl;
      if (absensiOleh != null) updateData['absensi_oleh'] = absensiOleh;
      if (absensiNama != null) updateData['absensi_nama'] = absensiNama;
      if (absensiWaktu != null) {
        updateData['absensi_waktu'] = Timestamp.fromDate(absensiWaktu);
      } else {
        updateData['absensi_waktu'] = FieldValue.serverTimestamp();
      }

      final batch = _firestore.batch();
      batch.update(
        _firestore.collection(collectionLemburMitra).doc(lemburId),
        updateData,
      );

      final parts = lemburId.split('_');
      if (parts.length >= 2) {
        final groupId = parts[0];
        batch.update(
          _firestore.collection(collectionPengajuan).doc(groupId),
          {
            'absensi_status': absensiStatus,
            'updated_at': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error updating absensi: $e');
      return false;
    }
  }

  // =========================================================================
  // ⚡ CEK DUPLIKAT
  // =========================================================================
  Future<bool> isDuplicateOvertime({
    required String mitraId,
    required DateTime tanggal,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('status', whereIn: ['pending', 'disetujui'])
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final existingTanggal = (data['tanggal'] as Timestamp).toDate();
        if (existingTanggal.year == tanggal.year &&
            existingTanggal.month == tanggal.month &&
            existingTanggal.day == tanggal.day) {
          return true;
        }
      }

      final pengajuanSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('mitra_ids', arrayContains: mitraId)
          .where('status', whereIn: ['pending', 'disetujui'])
          .get();

      for (var doc in pengajuanSnapshot.docs) {
        final data = doc.data();
        final existingTanggal = (data['tanggal_lembur'] as Timestamp).toDate();
        if (existingTanggal.year == tanggal.year &&
            existingTanggal.month == tanggal.month &&
            existingTanggal.day == tanggal.day) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return false;
    }
  }

  // =========================================================================
  // ⚡ RIWAYAT ABSENSI MITRA
  // =========================================================================
  Future<List<OvertimeHistory>> getAbsensiHistory({
    required String mitraId,
    String? bulan,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('absensi_status', isEqualTo: 'selesai')
          .orderBy('absensi_waktu', descending: true);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting absensi history: $e');
      return [];
    }
  }
}