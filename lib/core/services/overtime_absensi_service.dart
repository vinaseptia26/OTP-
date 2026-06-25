// lib/core/services/overtime_absensi_service.dart

export '/core/services/overtime_history_service.dart' 
    show OvertimeHistory, HSSEViewMode;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '/core/services/overtime_history_service.dart';

// ============================================================================
// EXTENSION: OvertimeHistoryAbsensi
// ============================================================================

extension OvertimeHistoryAbsensi on OvertimeHistory {
  String get absensiStatus => 'belum_absen';
  DateTime? get absensiWaktu => null;
  String? get absensiFotoUrl => null;
  String? get absensiOleh => null;
  String? get absensiNama => null;

  String get absensiStatusLabel {
    switch (absensiStatus) {
      case 'belum_absen':       return 'Belum Absen';
      case 'sudah_absen':       return 'Sudah Absen';
      case 'check_in':          return 'Check In';
      case 'check_out':         return 'Check Out';
      case 'selesai':           return 'Selesai';
      case 'selesai_terlambat': return 'Absen Terlambat';
      case 'tidak_lembur':      return 'Tidak Lembur';
      case 'expired':           return 'Kadaluarsa';
      default:                  return '$absensiStatus';
    }
  }
}

// ============================================================================
// MODEL: OvertimeAbsensi
// ============================================================================

class OvertimeAbsensi {
  final String id;
  final String lemburId;
  final String userId;
  final String userName;
  final String fotoUrl;
  final DateTime waktu;
  final DateTime createdAt;

  OvertimeAbsensi({
    required this.id,
    required this.lemburId,
    required this.userId,
    required this.userName,
    required this.fotoUrl,
    required this.waktu,
    required this.createdAt,
  });

  factory OvertimeAbsensi.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return OvertimeAbsensi(
      id: doc.id,
      lemburId: data['lembur_id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      userName: data['user_name'] as String? ?? '',
      fotoUrl: data['foto_url'] as String? ?? '',
      waktu: (data['waktu'] as Timestamp).toDate(),
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'lembur_id': lemburId,
    'user_id': userId,
    'user_name': userName,
    'foto_url': fotoUrl,
    'waktu': Timestamp.fromDate(waktu),
    'created_at': Timestamp.fromDate(createdAt),
  };

  @override
  String toString() => 'OvertimeAbsensi(id: $id, user: $userName, waktu: $waktu)';
}

// ============================================================================
// MODEL: TenggatInfo
// ============================================================================

class TenggatInfo {
  final String label;
  final String labelSingkat;
  final String status;
  final Duration sisaWaktu;
  final DateTime batasMulai;
  final DateTime batasNormal;
  final DateTime batasExpired;
  final bool isNormal;
  final bool isLate;
  final bool isExpired;
  final bool canConfirm;
  final bool canAbsenNormal;
  final double progressPercent;
  final String jamMulai;
  final String jamSelesai;
  final String tanggalLembur;

  const TenggatInfo({
    required this.label,
    required this.labelSingkat,
    required this.status,
    required this.sisaWaktu,
    required this.batasMulai,
    required this.batasNormal,
    required this.batasExpired,
    required this.isNormal,
    required this.isLate,
    required this.isExpired,
    required this.canConfirm,
    required this.canAbsenNormal,
    required this.progressPercent,
    required this.jamMulai,
    required this.jamSelesai,
    required this.tanggalLembur,
  });

  // Formatted strings

  String get sisaWaktuFormatted {
    if (isExpired || sisaWaktu.isNegative) return 'Kadaluarsa';

    final hari = sisaWaktu.inDays;
    final jam = sisaWaktu.inHours.remainder(24);
    final menit = sisaWaktu.inMinutes.remainder(60);
    final detik = sisaWaktu.inSeconds.remainder(60);

    final parts = <String>[];
    if (hari > 0) parts.add('$hari hari');
    if (jam > 0) parts.add('$jam jam');
    if (menit > 0) parts.add('$menit mnt');
    if (hari == 0 && jam == 0 && menit == 0) parts.add('$detik dtk');
    
    return parts.join(' ');
  }

  String get sisaWaktuSingkat {
    if (isExpired || sisaWaktu.isNegative) return '0m';

    final hari = sisaWaktu.inDays;
    final jam = sisaWaktu.inHours.remainder(24);
    final menit = sisaWaktu.inMinutes.remainder(60);

    if (hari > 0) return '${hari}h ${jam}j';
    if (jam > 0) return '${jam}j ${menit}m';
    return '${menit}m';
  }

  String get sisaWaktuNumerik {
    if (isExpired || sisaWaktu.isNegative) return '00:00:00';

    final jam = sisaWaktu.inHours.remainder(24);
    final menit = sisaWaktu.inMinutes.remainder(60);
    final detik = sisaWaktu.inSeconds.remainder(60);

    return '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}:${detik.toString().padLeft(2, '0')}';
  }

  String get batasNormalFormatted => DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(batasNormal);
  String get batasExpiredFormatted => DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(batasExpired);
  String get batasNormalJam => DateFormat('HH:mm', 'id_ID').format(batasNormal);
  String get batasExpiredJam => DateFormat('HH:mm', 'id_ID').format(batasExpired);

  String get rentangWaktu => '$jamMulai - $jamSelesai';

  // Visual indicators

  Color get warnaIndikator {
    if (isExpired) return const Color(0xFFEF5350);
    if (sisaWaktu.inHours < 1) return const Color(0xFFFF5252);
    if (sisaWaktu.inHours < 2) return const Color(0xFFFF9800);
    if (sisaWaktu.inHours < 6) return const Color(0xFFFFC107);
    if (isLate) return const Color(0xFF42A5F5);
    return const Color(0xFF66BB6A);
  }

  Color get warnaBackground {
    if (isExpired) return const Color(0xFFFFF0F0);
    if (sisaWaktu.inHours < 1) return const Color(0xFFFFF5F5);
    if (sisaWaktu.inHours < 2) return const Color(0xFFFFF8F0);
    if (sisaWaktu.inHours < 6) return const Color(0xFFFFFBF0);
    if (isLate) return const Color(0xFFF0F8FF);
    return const Color(0xFFF0FFF0);
  }

  Color get warnaBorder {
    if (isExpired) return const Color(0xFFEF5350).withValues(alpha: 0.5);
    if (sisaWaktu.inHours < 2) return const Color(0xFFFF9800).withValues(alpha: 0.5);
    if (sisaWaktu.inHours < 6) return const Color(0xFFFFC107).withValues(alpha: 0.5);
    if (isLate) return const Color(0xFF42A5F5).withValues(alpha: 0.5);
    return const Color(0xFF66BB6A).withValues(alpha: 0.5);
  }

  Icon get iconStatus {
    if (isExpired) return const Icon(Icons.timer_off_rounded, color: Color(0xFFEF5350), size: 20);
    if (sisaWaktu.inHours < 1) return const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFFF5252), size: 20);
    if (sisaWaktu.inHours < 2) return const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFFF9800), size: 20);
    if (sisaWaktu.inHours < 6) return const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFC107), size: 20);
    if (isLate) return const Icon(Icons.warning_amber_rounded, color: Color(0xFF42A5F5), size: 20);
    return const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF66BB6A), size: 20);
  }

  String get emojiStatus {
    if (isExpired) return 'X';
    if (sisaWaktu.inHours < 1) return '!';
    if (sisaWaktu.inHours < 2) return '!!';
    if (sisaWaktu.inHours < 6) return '!';
    if (isLate) return '*';
    return 'V';
  }

  // Priority level

  String get levelPrioritas {
    if (isExpired) return 'EXPIRED';
    if (sisaWaktu.inHours < 1) return 'CRITICAL';
    if (sisaWaktu.inHours < 2) return 'HIGH';
    if (sisaWaktu.inHours < 6) return 'MEDIUM';
    if (isLate) return 'LOW';
    return 'NORMAL';
  }

  int get prioritas {
    if (isExpired) return 0;
    if (sisaWaktu.inHours < 1) return 1;
    if (sisaWaktu.inHours < 2) return 2;
    if (sisaWaktu.inHours < 6) return 3;
    if (isLate) return 4;
    return 5;
  }

  // Action labels

  String get aksiLabel {
    if (isExpired) return 'Sudah Kadaluarsa';
    if (isNormal && canAbsenNormal) return 'Absen Sekarang';
    if (canConfirm) return 'Konfirmasi Keterlambatan';
    return 'Menunggu';
  }

  bool get bisaDikonfirmasi => canConfirm && !isExpired;
  bool get butuhPerhatian => isLate || sisaWaktu.inHours < 6;
}

// ============================================================================
// SERVICE: OvertimeAbsensiService
// ============================================================================

class OvertimeAbsensiService {
  static final OvertimeAbsensiService _instance = OvertimeAbsensiService._internal();
  factory OvertimeAbsensiService() => _instance;
  OvertimeAbsensiService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cLembur = 'lembur_mitra';
  static const String _cPengajuan = 'pengajuan_lembur';
  static const String _cAbsensi = 'absensi';
  static const String _cNotif = 'notifications';
  static const String _cLog = 'activity_logs';

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findDoc(String id) async {
    var doc = await _firestore.collection(_cLembur).doc(id).get();
    if (doc.exists) return doc;
    doc = await _firestore.collection(_cPengajuan).doc(id).get();
    return doc.exists ? doc : null;
  }

  DateTime _parseTs(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return fallback ?? DateTime.now();
  }

  Future<void> _log(String action, String docId, String userId, [String? detail]) async {
    try {
      await _firestore.collection(_cLog).add({
        'action': action,
        'document_id': docId,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': detail,
        'module': 'absensi',
      });
    } catch (e) {
      debugPrint('OvertimeAbsensiService: Gagal log aktivitas: $e');
    }
  }

  Future<void> _syncGroup(String groupId, Map<String, dynamic> data, {String? excludeDocId}) async {
    if (groupId.isEmpty) return;
    try {
      final batch = _firestore.batch();
      final docs1 = await _firestore.collection(_cLembur).where('group_id', isEqualTo: groupId).get();
      final docs2 = await _firestore.collection(_cPengajuan).where('group_id', isEqualTo: groupId).get();
      for (var d in [...docs1.docs, ...docs2.docs]) {
        if (d.id != excludeDocId) batch.update(d.reference, data);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('OvertimeAbsensiService: Gagal sync group: $e');
    }
  }

  DateTime _parseJam(DateTime tanggal, String jamStr) {
    final parts = jamStr.split(':');
    final jam = int.tryParse(parts[0]) ?? 0;
    final menit = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(tanggal.year, tanggal.month, tanggal.day, jam, menit);
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'belum_absen': return 'Belum Absen';
      case 'sudah_absen': return 'Sudah Absen';
      case 'check_in': return 'Check In';
      case 'check_out': return 'Check Out';
      case 'selesai': return 'Selesai';
      case 'selesai_terlambat': return 'Absen Terlambat';
      case 'tidak_lembur': return 'Tidak Lembur';
      case 'expired': return 'Kadaluarsa';
      default: return status;
    }
  }

  // ==========================================================================
  // 1. SUBMIT ABSENSI NORMAL
  // ==========================================================================

  Future<Map<String, dynamic>> submitAbsensi({
    required String docId,
    required String fotoUrl,
    required String userId,
    required String userName,
  }) async {
    try {
      if (docId.isEmpty) return {'success': false, 'message': 'ID dokumen tidak valid'};
      if (fotoUrl.isEmpty) return {'success': false, 'message': 'URL foto tidak valid'};
      if (userId.isEmpty) return {'success': false, 'message': 'User ID tidak valid'};

      final doc = await _findDoc(docId);
      if (doc == null) {
        return {'success': false, 'message': 'Data lembur tidak ditemukan'};
      }

      final data = doc.data()!;
      final currentStatus = data['status'] as String? ?? '';
      final currentAbsensi = data['absensi_status'] as String? ?? 'belum_absen';

      final tenggat = await getTenggatInfo(docId);
      if (tenggat != null && tenggat.isExpired) {
        return {'success': false, 'message': 'Lembur sudah kadaluarsa, tidak bisa absen'};
      }
      if (tenggat != null && tenggat.isLate && !tenggat.canConfirm) {
        return {'success': false, 'message': 'Sudah melewati batas, gunakan konfirmasi keterlambatan'};
      }

      const resolvedStatuses = ['selesai', 'expired', 'selesai_terlambat', 'tidak_lembur'];
      if (resolvedStatuses.contains(currentAbsensi)) {
        return {'success': false, 'message': 'Absensi sudah diproses sebelumnya (status: $currentAbsensi)'};
      }

      final String newAbsensiStatus;
      final String newStatus;
      
      if (currentStatus == 'disetujui') {
        newAbsensiStatus = 'selesai';
        newStatus = 'selesai';
      } else {
        newAbsensiStatus = 'sudah_absen';
        newStatus = currentStatus;
      }

      final updateData = <String, dynamic>{
        'absensi_status': newAbsensiStatus,
        'absensi_foto_url': fotoUrl,
        'absensi_waktu': FieldValue.serverTimestamp(),
        'absensi_oleh': userId,
        'absensi_nama': userName,
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'selesai') {
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }

      final batch = _firestore.batch();
      batch.update(doc.reference, updateData);

      final absensiRef = _firestore.collection(_cAbsensi).doc();
      batch.set(absensiRef, {
        'lembur_id': docId,
        'user_id': userId,
        'user_name': userName,
        'foto_url': fotoUrl,
        'status_lembur': newStatus,
        'absensi_status': newAbsensiStatus,
        'waktu': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final groupId = data['group_id'] as String? ?? '';
      await _syncGroup(groupId, updateData, excludeDocId: docId);
      await _log('submit_absensi', docId, userId, 'Absensi normal: $newAbsensiStatus');

      return {
        'success': true,
        'message': 'Absensi berhasil disubmit',
        'absensiId': absensiRef.id,
        'absensiStatus': newAbsensiStatus,
        'lemburStatus': newStatus,
      };
    } catch (e) {
      debugPrint('OvertimeAbsensiService: submitAbsensi error');
      debugPrint('   Error: $e');
      return {'success': false, 'message': 'Gagal submit absensi: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // 2. KONFIRMASI KETERLAMBATAN
  // ==========================================================================

  Future<Map<String, dynamic>> konfirmasiKeterlambatan({
    required String lemburId,
    required String userId,
    required String userName,
    required bool melakukanLembur,
    required String alasan,
    String? buktiFotoUrl,
  }) async {
    try {
      if (lemburId.isEmpty) return {'success': false, 'message': 'ID lembur tidak valid'};
      if (userId.isEmpty) return {'success': false, 'message': 'User ID tidak valid'};
      
      final alasanBersih = alasan.trim();
      if (alasanBersih.isEmpty) {
        return {'success': false, 'message': 'Alasan wajib diisi'};
      }
      if (alasanBersih.length < 10) {
        return {'success': false, 'message': 'Alasan terlalu singkat (minimal 10 karakter)'};
      }

      if (melakukanLembur) {
        if (buktiFotoUrl == null || buktiFotoUrl.isEmpty) {
          return {'success': false, 'message': 'Foto bukti wajib diupload jika menyatakan tetap melakukan lembur'};
        }
      }

      final doc = await _findDoc(lemburId);
      if (doc == null) return {'success': false, 'message': 'Data lembur tidak ditemukan'};

      final data = doc.data()!;
      final currentAbsensi = data['absensi_status'] as String? ?? 'belum_absen';

      const resolvedStatuses = ['selesai', 'selesai_terlambat', 'tidak_lembur', 'expired'];
      if (resolvedStatuses.contains(currentAbsensi)) {
        return {'success': false, 'message': 'Absensi sudah diproses sebelumnya (status: $currentAbsensi)'};
      }

      final tenggat = await getTenggatInfo(lemburId);
      if (tenggat != null && tenggat.isExpired) {
        return {'success': false, 'message': 'Lembur sudah kadaluarsa, tidak bisa konfirmasi'};
      }

      final now = DateTime.now();
      final tanggal = _parseTs(data['tanggal']);
      final selesaiTime = _parseJam(tanggal, data['jam_selesai'] as String? ?? '00:00');
      final batasNormal = selesaiTime.add(const Duration(hours: 2));
      final batasExpired = selesaiTime.add(const Duration(days: 1));

      if (!now.isAfter(batasNormal)) {
        return {
          'success': false,
          'message': 'Anda masih bisa melakukan absensi normal sampai ${DateFormat('HH:mm', 'id_ID').format(batasNormal)} WIB.',
          'bisaAbsenNormal': true,
          'batasNormal': DateFormat('HH:mm', 'id_ID').format(batasNormal),
          'sisaWaktuNormal': batasNormal.difference(now).inMinutes,
        };
      }

      if (now.isAfter(batasExpired)) {
        return {'success': false, 'message': 'Lembur sudah kadaluarsa (lebih dari 1 hari).'};
      }

      final String newAbsensiStatus = melakukanLembur ? 'selesai_terlambat' : 'tidak_lembur';

      final updateData = <String, dynamic>{
        'absensi_status': newAbsensiStatus,
        'absensi_waktu': FieldValue.serverTimestamp(),
        'absensi_oleh': userId,
        'absensi_nama': userName,
        'absensi_keterlambatan': {
          'melakukan_lembur': melakukanLembur,
          'alasan': alasanBersih,
          'bukti_foto_url': buktiFotoUrl,
          'dikonfirmasi_pada': FieldValue.serverTimestamp(),
        },
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (buktiFotoUrl != null && buktiFotoUrl.isNotEmpty) {
        updateData['absensi_foto_url'] = buktiFotoUrl;
      }

      await doc.reference.update(updateData);

      final groupId = data['group_id'] as String? ?? '';
      await _syncGroup(groupId, updateData, excludeDocId: lemburId);
      await _log('konfirmasi_keterlambatan', lemburId, userId, '${melakukanLembur ? "Tetap Lembur" : "Tidak Lembur"}');

      final String message = melakukanLembur
          ? 'Konfirmasi berhasil: Anda dinyatakan tetap melakukan lembur.'
          : 'Konfirmasi berhasil: Anda dinyatakan tidak melakukan lembur.';

      return {'success': true, 'message': message, 'absensiStatus': newAbsensiStatus, 'lemburStatus': 'selesai'};
    } catch (e) {
      debugPrint('OvertimeAbsensiService: konfirmasiKeterlambatan error: $e');
      return {'success': false, 'message': 'Gagal menyimpan konfirmasi: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // 3. CEK STATUS KETERLAMBATAN
  // ==========================================================================

  Future<Map<String, dynamic>> cekStatusKeterlambatan(String lemburId) async {
    try {
      if (lemburId.isEmpty) return {'isLate': false, 'canConfirm': false, 'message': 'ID lembur tidak valid'};

      final doc = await _findDoc(lemburId);
      if (doc == null) return {'isLate': false, 'canConfirm': false, 'message': 'Data lembur tidak ditemukan'};

      final data = doc.data()!;
      final absensiStatus = data['absensi_status'] as String? ?? 'belum_absen';

      const resolved = ['selesai', 'selesai_terlambat', 'tidak_lembur', 'expired'];
      if (resolved.contains(absensiStatus)) {
        return {
          'isLate': false, 'canConfirm': false, 'isAlreadyResolved': true,
          'currentStatus': absensiStatus, 'statusLabel': _getStatusLabel(absensiStatus),
          'message': 'Absensi sudah diproses (status: ${_getStatusLabel(absensiStatus)})',
        };
      }

      final now = DateTime.now();
      final tanggal = _parseTs(data['tanggal']);
      final mulaiTime = _parseJam(tanggal, data['jam_mulai'] as String? ?? '00:00');
      var selesaiTime = _parseJam(tanggal, data['jam_selesai'] as String? ?? '00:00');
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));

      final batasNormal = selesaiTime.add(const Duration(hours: 2));
      final batasExpired = selesaiTime.add(const Duration(days: 1));

      final isInRange = now.isAfter(mulaiTime.subtract(const Duration(minutes: 30))) && now.isBefore(batasNormal);
      final isLate = now.isAfter(batasNormal);
      final canConfirm = isLate && !now.isAfter(batasExpired);

      return {
        'isLate': isLate, 'isInRange': isInRange, 'canConfirm': canConfirm, 'isAlreadyResolved': false,
        'mulaiTime': DateFormat('HH:mm', 'id_ID').format(mulaiTime),
        'selesaiTime': DateFormat('HH:mm', 'id_ID').format(selesaiTime),
        'batasNormal': DateFormat('HH:mm', 'id_ID').format(batasNormal),
        'batasExpired': DateFormat('dd MMM HH:mm', 'id_ID').format(batasExpired),
        'sisaWaktu': batasExpired.difference(now).inMinutes,
        'message': isLate
            ? 'Sudah melewati batas absensi normal.'
            : 'Masih dalam masa absensi normal.',
      };
    } catch (e) {
      return {'isLate': false, 'canConfirm': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // 4. UPDATE STATUS ABSENSI (MANUAL)
  // ==========================================================================

  Future<bool> updateAbsensiStatus({
    required String lemburId,
    required String absensiStatus,
    String? fotoUrl,
    String? absensiOleh,
    String? absensiNama,
    DateTime? absensiWaktu,
  }) async {
    try {
      final doc = await _findDoc(lemburId);
      if (doc == null) return false;

      final updateData = <String, dynamic>{
        'absensi_status': absensiStatus,
        'updated_at': FieldValue.serverTimestamp(),
        if (fotoUrl != null) 'absensi_foto_url': fotoUrl,
        if (absensiOleh != null) 'absensi_oleh': absensiOleh,
        if (absensiNama != null) 'absensi_nama': absensiNama,
        'absensi_waktu': absensiWaktu != null ? Timestamp.fromDate(absensiWaktu) : FieldValue.serverTimestamp(),
      };

      if (absensiStatus == 'selesai' && (doc.data()?['status'] == 'disetujui')) {
        updateData['status'] = 'selesai';
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }

      await doc.reference.update(updateData);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // 5. GET TODAY OVERTIME
  // ==========================================================================

  Future<OvertimeHistory?> getTodayOvertimeForAbsensi(String userId) async {
    try {
      final now = DateTime.now();
      
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final mitraSnapshot = await _firestore
          .collection(_cLembur)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      if (mitraSnapshot.docs.isNotEmpty) {
        const validStatuses = ['disetujui', 'selesai'];
        const unresolvedAbsensi = ['belum_absen', 'sudah_absen', null, ''];
        
        final canAbsen = mitraSnapshot.docs.where((doc) {
          final d = doc.data();
          final status = d['status'] as String? ?? '';
          final absensiStatus = d['absensi_status'] as String? ?? '';
          return validStatuses.contains(status) && unresolvedAbsensi.contains(absensiStatus);
        }).toList();
        
        if (canAbsen.isNotEmpty) {
          return OvertimeHistory.fromFirestore(canAbsen.first);
        }
        
        return OvertimeHistory.fromFirestore(mitraSnapshot.docs.first);
      }
      
      final pengajuanSnapshot = await _firestore
          .collection(_cPengajuan)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      if (pengajuanSnapshot.docs.isNotEmpty) {
        const validStatuses = ['disetujui', 'selesai'];
        final canAbsen = pengajuanSnapshot.docs.where((doc) {
          final status = doc.data()['status'] as String? ?? '';
          return validStatuses.contains(status);
        }).toList();
        
        if (canAbsen.isNotEmpty) {
          return OvertimeHistory.fromFirestore(canAbsen.first);
        }
      }
      
      final multiSnapshot = await _firestore
          .collection(_cLembur)
          .where('mitra_ids', arrayContains: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      if (multiSnapshot.docs.isNotEmpty) {
        return OvertimeHistory.fromFirestore(multiSnapshot.docs.first);
      }
      
      return null;
      
    } catch (e) {
      debugPrint('[AbsensiService] getTodayOvertimeForAbsensi ERROR: $e');
      return null;
    }
  }

  // ==========================================================================
  // 6. GET LEMBUR NEED ABSENSI
  // ==========================================================================

  Future<List<OvertimeHistory>> getLemburNeedAbsensi({
    required String userId,
    String userRole = 'mitra',
    String? bulan,
  }) async {
    try {
      var query = _firestore
          .collection(_cLembur)
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', whereIn: ['belum_absen', 'sudah_absen']);

      if (userRole == 'mitra') query = query.where('mitra_id', isEqualTo: userId);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.orderBy('tanggal', descending: true).get();
      return snapshot.docs.map((d) => OvertimeHistory.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('getLemburNeedAbsensi error: $e');
      return [];
    }
  }

  Future<OvertimeHistory?> getLemburDetail(String docId) async {
    try {
      final doc = await _findDoc(docId);
      return (doc != null && doc.exists) ? OvertimeHistory.fromFirestore(doc) : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<OvertimeHistory>> getAbsensiHistory({
    required String mitraId,
    String? bulan,
  }) async {
    try {
      var query = _firestore
          .collection(_cLembur)
          .where('mitra_id', isEqualTo: mitraId)
          .where('absensi_status', whereIn: ['selesai', 'sudah_absen', 'selesai_terlambat', 'tidak_lembur'])
          .orderBy('absensi_waktu', descending: true);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((d) => OvertimeHistory.fromFirestore(d)).toList();
    } catch (e) {
      return [];
    }
  }

  Stream<List<OvertimeHistory>> getLemburNeedAbsensiStream({
    required String userId,
    String userRole = 'mitra',
    String? bulan,
  }) {
    var query = _firestore
        .collection(_cLembur)
        .where('status', isEqualTo: 'disetujui')
        .where('absensi_status', whereIn: ['belum_absen', 'sudah_absen']);

    if (userRole == 'mitra') query = query.where('mitra_id', isEqualTo: userId);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    return query.orderBy('tanggal', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => OvertimeHistory.fromFirestore(d)).toList(),
    );
  }

  Stream<List<OvertimeAbsensi>> getAbsensiStream({
    String? lemburId,
    String? userId,
    int limit = 50,
  }) {
    var query = _firestore.collection(_cAbsensi).orderBy('waktu', descending: true).limit(limit);
    if (lemburId != null && lemburId.isNotEmpty) query = query.where('lembur_id', isEqualTo: lemburId);
    if (userId != null && userId.isNotEmpty) query = query.where('user_id', isEqualTo: userId);
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => OvertimeAbsensi.fromFirestore(d)).toList(),
    );
  }

  Future<Map<String, dynamic>> sendReminder({
    required String docId,
    required String groupId,
    required String pengawasId,
    required String pengawasName,
  }) async {
    try {
      final doc = await _findDoc(docId);
      if (doc == null) return {'success': false, 'message': 'Data lembur tidak ditemukan'};

      final lembur = OvertimeHistory.fromFirestore(doc);
      final mitraIds = <String>[];
      if (lembur.mitraId?.isNotEmpty == true) mitraIds.add(lembur.mitraId!);
      if (lembur.mitraIds != null) {
        for (var id in lembur.mitraIds!) {
          if (!mitraIds.contains(id)) mitraIds.add(id);
        }
      }

      if (mitraIds.isEmpty) return {'success': false, 'message': 'Tidak ada mitra'};

      final batch = _firestore.batch();
      for (var mid in mitraIds) {
        batch.set(_firestore.collection(_cNotif).doc(), {
          'userId': mid,
          'title': 'Pengingat Absensi Lembur',
          'body': 'Pengawas $pengawasName mengingatkan untuk segera melakukan absensi.',
          'type': 'absensi_reminder',
          'data': {'lembur_id': docId, 'group_id': groupId},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      return {
        'success': true,
        'message': 'Reminder berhasil dikirim ke ${mitraIds.length} mitra',
        'sentCount': mitraIds.length,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // TENGGAT FEATURES
  // ==========================================================================

  Future<TenggatInfo?> getTenggatInfo(String lemburId) async {
    try {
      final doc = await _findDoc(lemburId);
      if (doc == null) return null;

      final data = doc.data()!;
      final absensiStatus = data['absensi_status'] as String? ?? 'belum_absen';

      final tanggal = _parseTs(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));

      final batasNormal = selesaiTime.add(const Duration(hours: 2));
      final batasExpired = selesaiTime.add(const Duration(days: 1));

      const resolved = ['selesai', 'selesai_terlambat', 'tidak_lembur', 'expired'];
      if (resolved.contains(absensiStatus)) {
        final isExpired = absensiStatus == 'expired';
        return TenggatInfo(
          label: isExpired ? 'Kadaluarsa' : _getStatusLabel(absensiStatus),
          labelSingkat: isExpired ? 'EXPIRED' : _getStatusLabel(absensiStatus).toUpperCase(),
          status: absensiStatus,
          sisaWaktu: Duration.zero,
          batasMulai: mulaiTime,
          batasNormal: batasNormal,
          batasExpired: batasExpired,
          isNormal: false,
          isLate: false,
          isExpired: isExpired,
          canConfirm: false,
          canAbsenNormal: false,
          progressPercent: 1.0,
          jamMulai: jamMulai,
          jamSelesai: jamSelesai,
          tanggalLembur: DateFormat('dd MMM yyyy', 'id_ID').format(tanggal),
        );
      }

      final now = DateTime.now();
      final isExpired = now.isAfter(batasExpired);
      final isLate = !isExpired && now.isAfter(batasNormal);
      final isNormal = !isLate && !isExpired;
      final canConfirm = isLate && !isExpired;
      final canAbsenNormal = isNormal;

      final Duration sisaWaktu;
      if (isExpired) {
        sisaWaktu = Duration.zero;
      } else if (isNormal) {
        sisaWaktu = batasNormal.difference(now);
      } else {
        sisaWaktu = batasExpired.difference(now);
      }

      final totalWindow = batasExpired.difference(selesaiTime);
      final elapsed = now.difference(selesaiTime);
      final progressPercent = totalWindow.inMilliseconds > 0
          ? (elapsed.inMilliseconds / totalWindow.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      String label;
      String labelSingkat;
      
      if (isExpired) {
        label = 'Kadaluarsa';
        labelSingkat = 'EXPIRED';
      } else if (isNormal) {
        label = 'Absen sampai ${DateFormat('HH:mm', 'id_ID').format(batasNormal)}';
        labelSingkat = '${sisaWaktu.inHours}j ${sisaWaktu.inMinutes.remainder(60)}m';
      } else {
        final sisa = sisaWaktu;
        final sisaJam = sisa.inHours;
        final sisaMenit = sisa.inMinutes.remainder(60);
        label = 'Konfirmasi sebelum ${DateFormat('dd MMM HH:mm', 'id_ID').format(batasExpired)} (sisa $sisaJam jam $sisaMenit mnt)';
        labelSingkat = 'TERLAMBAT';
      }

      return TenggatInfo(
        label: label,
        labelSingkat: labelSingkat,
        status: absensiStatus,
        sisaWaktu: sisaWaktu,
        batasMulai: mulaiTime,
        batasNormal: batasNormal,
        batasExpired: batasExpired,
        isNormal: isNormal,
        isLate: isLate,
        isExpired: isExpired,
        canConfirm: canConfirm,
        canAbsenNormal: canAbsenNormal,
        progressPercent: progressPercent,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        tanggalLembur: DateFormat('dd MMM yyyy', 'id_ID').format(tanggal),
      );
    } catch (e) {
      debugPrint('getTenggatInfo error: $e');
      return null;
    }
  }

  Future<Map<String, TenggatInfo>> getBatchTenggatInfo(List<String> lemburIds) async {
    final result = <String, TenggatInfo>{};
    final futures = lemburIds.map((id) => getTenggatInfo(id));
    final infos = await Future.wait(futures);
    for (var i = 0; i < lemburIds.length; i++) {
      if (infos[i] != null) {
        result[lemburIds[i]] = infos[i]!;
      }
    }
    return result;
  }

  Stream<TenggatInfo?> getTenggatCountdown(String lemburId) {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getTenggatInfo(lemburId);
    }).asyncMap((future) => future);
  }

  Future<Map<String, dynamic>> getExpirySummary({
    required String userId,
    String? bulan,
  }) async {
    try {
      final now = DateTime.now();
      var query = _firestore
          .collection(_cLembur)
          .where('mitra_id', isEqualTo: userId)
          .where('status', whereIn: ['disetujui', 'selesai'])
          .where('absensi_status', whereIn: ['belum_absen', 'sudah_absen']);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final docs = await query.get();

      int akanExpired = 0;
      int kritis = 0;
      int warning = 0;
      int perhatian = 0;
      int aman = 0;
      int sudahLewatNormal = 0;
      
      final detailList = <Map<String, dynamic>>[];

      for (var d in docs.docs) {
        final data = d.data();
        final tanggal = _parseTs(data['tanggal']);
        final jamMulai = data['jam_mulai'] as String? ?? '00:00';
        final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
        final selesaiTime = _parseJam(tanggal, jamSelesai);
        final batasNormal = selesaiTime.add(const Duration(hours: 2));
        final batasExpired = selesaiTime.add(const Duration(days: 1));

        if (now.isAfter(batasExpired)) {
          sudahLewatNormal++;
          detailList.add({
            'id': d.id,
            'status': 'expired_pending',
            'jam': '$jamMulai-$jamSelesai',
            'sisaJam': 0,
          });
        } else if (now.isAfter(batasNormal)) {
          final sisa = batasExpired.difference(now);
          if (sisa.inHours < 1) {
            akanExpired++;
          } else if (sisa.inHours < 2) {
            kritis++;
          } else if (sisa.inHours < 6) {
            warning++;
          } else {
            perhatian++;
          }
          detailList.add({
            'id': d.id,
            'status': 'late',
            'jam': '$jamMulai-$jamSelesai',
            'sisaJam': sisa.inHours,
            'sisaMenit': sisa.inMinutes.remainder(60),
          });
        } else {
          final sisa = batasNormal.difference(now);
          if (sisa.inHours < 1) {
            akanExpired++;
          } else if (sisa.inHours < 2) {
            kritis++;
          } else if (sisa.inHours < 6) {
            warning++;
          } else {
            aman++;
          }
          detailList.add({
            'id': d.id,
            'status': 'normal',
            'jam': '$jamMulai-$jamSelesai',
            'sisaJam': sisa.inHours,
            'sisaMenit': sisa.inMinutes.remainder(60),
          });
        }
      }

      return {
        'totalPending': docs.docs.length,
        'akanExpired': akanExpired,
        'kritis': kritis,
        'warning': warning,
        'perhatian': perhatian,
        'aman': aman,
        'sudahLewatNormal': sudahLewatNormal,
        'detail': detailList,
      };
    } catch (e) {
      debugPrint('getExpirySummary error: $e');
      return {
        'totalPending': 0,
        'akanExpired': 0,
        'kritis': 0,
        'warning': 0,
        'perhatian': 0,
        'aman': 0,
        'sudahLewatNormal': 0,
        'detail': [],
      };
    }
  }

  Future<Map<String, dynamic>> autoUpdateExpired({String? userId}) async {
    try {
      final result = await checkExpired(userId: userId);
      
      if (result['success'] == true && result['expiredCount'] > 0) {
        final expiredIds = result['expiredIds'] as List<String>;
        final batch = _firestore.batch();
        
        for (var id in expiredIds) {
          final doc = await _findDoc(id);
          if (doc == null) continue;
          
          final data = doc.data()!;
          final mitraId = data['mitra_id'] as String?;
          final mitraIds = (data['mitra_ids'] as List?)?.cast<String>() ?? [];
          
          final allMitraIds = <String>{};
          if (mitraId != null) allMitraIds.add(mitraId);
          allMitraIds.addAll(mitraIds);
          
          for (var mid in allMitraIds) {
            batch.set(_firestore.collection(_cNotif).doc(), {
              'userId': mid,
              'title': 'Lembur Kadaluarsa',
              'body': 'Waktu absensi lembur telah kadaluarsa karena melebihi batas 1x24 jam.',
              'type': 'absensi_expired',
              'data': {'lembur_id': id},
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        
        await batch.commit();
        debugPrint('autoUpdateExpired: ${expiredIds.length} lembur expired, notifikasi terkirim');
      }
      
      return result;
    } catch (e) {
      debugPrint('autoUpdateExpired error: $e');
      return {'success': false, 'expiredCount': 0, 'expiredIds': []};
    }
  }

  Stream<Map<String, TenggatInfo>> getRealtimeTenggatStream({
    required String userId,
    String? bulan,
  }) {
    return Stream.periodic(const Duration(minutes: 5), (_) async {
      final docs = await _firestore
          .collection(_cLembur)
          .where('mitra_id', isEqualTo: userId)
          .where('status', whereIn: ['disetujui', 'selesai'])
          .where('absensi_status', whereIn: ['belum_absen', 'sudah_absen'])
          .get();

      final ids = docs.docs.map((d) => d.id).toList();
      return await getBatchTenggatInfo(ids);
    }).asyncMap((future) => future);
  }

  Future<Map<String, dynamic>> checkExpired({String? userId, String? userRole}) async {
    try {
      final now = DateTime.now();
      var query = _firestore
          .collection(_cLembur)
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', whereIn: ['belum_absen', 'sudah_absen']);

      if (userRole == 'mitra' && userId != null) {
        query = query.where('mitra_id', isEqualTo: userId);
      }

      final docs = await query.get();
      final batch = _firestore.batch();
      int count = 0;
      final ids = <String>[];

      for (var d in docs.docs) {
        final data = d.data();
        final tanggal = _parseTs(data['tanggal']);
        final selesaiTime = _parseJam(tanggal, data['jam_selesai'] as String? ?? '00:00');

        if (now.isAfter(selesaiTime.add(const Duration(days: 1)))) {
          batch.update(d.reference, {
            'status': 'kadaluarsa',
            'absensi_status': 'expired',
            'expired_at': FieldValue.serverTimestamp(),
            'expired_reason': 'Tidak melakukan absensi hingga batas waktu (1x24 jam)',
            'updated_at': FieldValue.serverTimestamp(),
          });
          count++;
          ids.add(d.id);
        }
      }

      if (count > 0) await batch.commit();

      return {
        'success': true,
        'expiredCount': count,
        'expiredIds': ids,
      };
    } catch (e) {
      return {'success': false, 'expiredCount': 0, 'expiredIds': []};
    }
  }

  Future<List<OvertimeHistory>> getLemburSortedByUrgency({
    required String userId,
    String? bulan,
  }) async {
    try {
      final list = await getLemburNeedAbsensi(userId: userId, bulan: bulan);
      if (list.isEmpty) return [];

      final ids = list.map((l) => l.id).toList();
      final tenggatMap = await getBatchTenggatInfo(ids);

      list.sort((a, b) {
        final ta = tenggatMap[a.id];
        final tb = tenggatMap[b.id];
        final pa = ta?.prioritas ?? 99;
        final pb = tb?.prioritas ?? 99;
        return pa.compareTo(pb);
      });

      return list;
    } catch (e) {
      debugPrint('getLemburSortedByUrgency error: $e');
      return [];
    }
  }

  // ==========================================================================
  // OTHER METHODS
  // ==========================================================================

  Future<bool> isAlreadyAbsen({required String mitraId, required DateTime tanggal}) async {
    try {
      final start = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final end = start.add(const Duration(days: 1));
      final snap = await _firestore
          .collection(_cAbsensi)
          .where('user_id', isEqualTo: mitraId)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('waktu', isLessThan: Timestamp.fromDate(end))
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAbsensiStats({
    required String userId,
    String? bulan,
  }) async {
    try {
      var query = _firestore.collection(_cLembur).where('mitra_id', isEqualTo: userId);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final docs = await query.get();
      int total = 0, sudah = 0, belum = 0, exp = 0;

      for (var d in docs.docs) {
        final s = d.data()['status'] as String? ?? '';
        final a = d.data()['absensi_status'] as String? ?? '';
        if (s == 'disetujui' || s == 'selesai' || s == 'kadaluarsa') {
          total++;
          if (a == 'selesai' || a == 'sudah_absen' || a == 'selesai_terlambat') {
            sudah++;
          } else if (a == 'belum_absen') {
            belum++;
          } else if (a == 'expired') {
            exp++;
          }
        }
      }

      return {
        'total': total,
        'sudahAbsen': sudah,
        'belumAbsen': belum,
        'expired': exp,
        'persentase': total > 0 ? (sudah / total * 100) : 0,
      };
    } catch (e) {
      return {'total': 0, 'sudahAbsen': 0, 'belumAbsen': 0, 'expired': 0, 'persentase': 0};
    }
  }
}