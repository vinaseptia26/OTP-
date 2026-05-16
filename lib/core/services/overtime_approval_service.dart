import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/core/services/spkl_generator_service.dart';
import '/core/services/notification_service.dart';

class OvertimeApprovalService {
  static final OvertimeApprovalService _instance =
      OvertimeApprovalService._internal();
  factory OvertimeApprovalService() => _instance;
  OvertimeApprovalService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final SpklGeneratorService _spklGenerator = SpklGeneratorService();
  final NotificationService _notificationService = NotificationService();

  // ============================================================================
  // KONSTANTA NAMA COLLECTION (STRUKTUR BARU)
  // ============================================================================
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';

  // ============================================================================
  // APPROVAL LIST (MANAGER)
  // ============================================================================
  Stream<List<Map<String, dynamic>>> getApprovalListForManager({
    required String status,
    required String fungsiManager,
  }) {
    return _firestore
        .collection(collectionPengajuan)
        .where('status', isEqualTo: status)
        .where('pengawas_fungsi', isEqualTo: fungsiManager)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'docId': doc.id,
                ...data,
                'tanggal': data['tanggal_lembur'], // mapping untuk UI
                'is_group_leader': true,
              };
            }).toList());
  }

  // ============================================================================
  // APPROVAL LIST (SUPERADMIN)
  // ============================================================================
  Stream<List<Map<String, dynamic>>> getApprovalListForSuperadmin({
    required String status,
    String? fungsiFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionPengajuan)
        .where('status', isEqualTo: status);

    if (fungsiFilter != null &&
        fungsiFilter.isNotEmpty &&
        fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }

    return query.orderBy('created_at', descending: true).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'docId': doc.id,
                ...data,
                'tanggal': data['tanggal_lembur'],
                'is_group_leader': true,
              };
            }).toList());
  }

  // ============================================================================
  // STATISTICS (MANAGER)
  // ============================================================================
  Future<Map<String, dynamic>> getStatisticsForManager(
      String fungsiManager) async {
    try {
      final pendingSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'pending')
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();

      final approvedSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'disetujui')
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();

      final rejectedSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'ditolak')
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final biayaSnapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'disetujui')
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .where('tanggal_lembur',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      double totalBiaya = 0;
      double totalJam = 0;
      for (final doc in biayaSnapshot.docs) {
        final data = doc.data();
        totalBiaya +=
            ((data['estimasi_biaya_total'] as num?) ?? 0).toDouble();
        totalJam += ((data['total_jam_desimal'] as num?) ?? 0).toDouble();
      }

      return {
        'totalPending': pendingSnapshot.docs.length,
        'totalApproved': approvedSnapshot.docs.length,
        'totalRejected': rejectedSnapshot.docs.length,
        'totalEstimasiBiaya': totalBiaya,
        'totalJamBulanIni': totalJam,
      };
    } catch (e) {
      debugPrint('❌ Statistics error: $e');
      return {
        'totalPending': 0,
        'totalApproved': 0,
        'totalRejected': 0,
        'totalEstimasiBiaya': 0.0,
        'totalJamBulanIni': 0.0,
      };
    }
  }

  // ============================================================================
  // STATISTICS (SUPERADMIN)
  // ============================================================================
  Future<Map<String, dynamic>> getStatisticsForSuperadmin({
    String? fungsiFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> baseQuery(String status) {
        Query<Map<String, dynamic>> query = _firestore
            .collection(collectionPengajuan)
            .where('status', isEqualTo: status);
        if (fungsiFilter != null &&
            fungsiFilter.isNotEmpty &&
            fungsiFilter != 'semua') {
          query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
        }
        return query;
      }

      final pendingSnapshot = await baseQuery('pending').get();
      final approvedSnapshot = await baseQuery('disetujui').get();
      final rejectedSnapshot = await baseQuery('ditolak').get();

      double totalBiaya = 0;
      double totalJam = 0;
      for (final doc in approvedSnapshot.docs) {
        final data = doc.data();
        totalBiaya +=
            ((data['estimasi_biaya_total'] as num?) ?? 0).toDouble();
        totalJam += ((data['total_jam_desimal'] as num?) ?? 0).toDouble();
      }

      Map<String, int> perFungsi = {};
      for (final doc in pendingSnapshot.docs) {
        final fungsi =
            (doc.data()['pengawas_fungsi'] ?? 'unknown').toString();
        perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
      }

      return {
        'totalPending': pendingSnapshot.docs.length,
        'totalApproved': approvedSnapshot.docs.length,
        'totalRejected': rejectedSnapshot.docs.length,
        'totalEstimasiBiaya': totalBiaya,
        'totalJamBulanIni': totalJam,
        'perFungsi': perFungsi,
      };
    } catch (e) {
      debugPrint('❌ Superadmin statistics error: $e');
      return {
        'totalPending': 0,
        'totalApproved': 0,
        'totalRejected': 0,
        'totalEstimasiBiaya': 0.0,
        'totalJamBulanIni': 0.0,
        'perFungsi': {},
      };
    }
  }

  // ============================================================================
  // DETAIL PENGAJUAN (STRUKTUR BARU)
  // ============================================================================
  Future<Map<String, dynamic>?> getDetailPengajuan(String groupId) async {
    try {
      final pengajuanDoc =
          await _firestore.collection(collectionPengajuan).doc(groupId).get();
      if (!pengajuanDoc.exists) return null;

      final pengajuanData = pengajuanDoc.data()!;

      // Ambil data mitra dari lembur_mitra
      final mitraSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();

      final mitraList = mitraSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'docId': doc.id,
          ...data,
          'is_group_leader': false,
        };
      }).toList();

      return {
        'id': pengajuanDoc.id,
        'docId': pengajuanDoc.id,
        ...pengajuanData,
        'is_group_leader': true,
        'tanggal': pengajuanData['tanggal_lembur'],
        'mitra_list': mitraList,
      };
    } catch (e) {
      debugPrint('❌ Detail error: $e');
      return null;
    }
  }

  // ============================================================================
  // PROCESS APPROVAL
  // ============================================================================
  Future<ApprovalResult> processApproval({
    required String groupId,
    required bool isApprove,
    required String notes,
    required String userRole,
    String? userFungsi,
    String? approverName,
    String? approverEmail,
    String? approverId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      if (userRole != 'manager' && userRole != 'superadmin') {
        throw Exception('Hanya manager/superadmin yang bisa approval');
      }

      // Ambil data pengajuan
      final pengajuanDoc =
          await _firestore.collection(collectionPengajuan).doc(groupId).get();
      if (!pengajuanDoc.exists) {
        throw Exception('Data pengajuan tidak ditemukan');
      }

      final pengajuanData = pengajuanDoc.data()!;
      final groupLeader = {
        'docId': pengajuanDoc.id,
        'id': pengajuanDoc.id,
        ...pengajuanData,
        'is_group_leader': true,
        'tanggal': pengajuanData['tanggal_lembur'],
      };

      if (groupLeader['status'] != 'pending') {
        throw Exception('Pengajuan sudah diproses');
      }

      if (userRole == 'manager' &&
          userFungsi != null &&
          userFungsi.isNotEmpty &&
          userFungsi != groupLeader['pengawas_fungsi']) {
        throw Exception('Manager tidak memiliki akses fungsi ini');
      }

      final effectiveApproverId = approverId ?? user.uid;
      final effectiveApproverEmail = approverEmail ?? user.email ?? 'Unknown';
      String effectiveApproverName =
          approverName ?? user.displayName ?? 'Unknown';

      // Update pengajuan_lembur & lembur_mitra
      final batch = _firestore.batch();

      Map<String, dynamic> updateData = {
        'updated_at': FieldValue.serverTimestamp(),
        if (isApprove) ...{
          'status': 'disetujui',
          'approved_by': effectiveApproverEmail,
          'approved_by_id': effectiveApproverId,
          'approved_by_name': effectiveApproverName,
          'approved_at': FieldValue.serverTimestamp(),
          'approval_note': notes,
        } else ...{
          'status': 'ditolak',
          'rejected_by': effectiveApproverEmail,
          'rejected_by_id': effectiveApproverId,
          'rejected_by_name': effectiveApproverName,
          'rejected_at': FieldValue.serverTimestamp(),
          'rejected_reason': notes,
        }
      };

      batch.update(
        _firestore.collection(collectionPengajuan).doc(groupId),
        updateData,
      );

      final mitraSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();

      for (final doc in mitraSnapshot.docs) {
        batch.update(
          _firestore.collection(collectionLemburMitra).doc(doc.id),
          updateData,
        );
      }

      await batch.commit();

      // Siapkan data mitra
      final mitraList = mitraSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'docId': doc.id,
          'id': doc.id,
          ...data,
          'is_group_leader': false,
        };
      }).toList();

      // Generate SPKL jika approved
      String? spklNomor;
      String? spklPdfPath;
      if (isApprove) {
        try {
          final result = await _generateSpklWithPdf(
            groupLeader: groupLeader,
            mitraList: mitraList,
            approvedByName: effectiveApproverName,
          );
          spklNomor = result['nomor'];
          spklPdfPath = result['pdfPath'];
        } catch (e) {
          debugPrint('❌ SPKL generation error: $e');
        }
      }

      // Notifikasi ke pengawas
      await _sendNotificationToPengawas(
        groupLeader: groupLeader,
        isApprove: isApprove,
        notes: notes,
        approverName: effectiveApproverName,
        approverRole: userRole,
        spklNomor: spklNomor,
      );

      // Notifikasi ke mitra jika approved
      if (isApprove) {
        await _sendNotificationToMitra(
          mitraList: mitraList,
          groupLeader: groupLeader,
          approverName: effectiveApproverName,
          spklNomor: spklNomor,
        );
      }

      // Log approval
      await _firestore.collection('approval_logs').add({
        'group_id': groupId,
        'action': isApprove ? 'approved' : 'rejected',
        'by_name': effectiveApproverName,
        'by_role': userRole,
        'by_email': effectiveApproverEmail,
        'by_id': effectiveApproverId,
        'notes': notes,
        'spkl_nomor': spklNomor,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return ApprovalResult(
        success: true,
        successCount: 1 + mitraList.length,
        failCount: 0,
        spklNomor: spklNomor,
        spklPdfPath: spklPdfPath,
        message: isApprove
            ? '✅ Pengajuan disetujui, SPKL telah digenerate & notifikasi terkirim'
            : '❌ Pengajuan ditolak, notifikasi terkirim',
      );
    } catch (e) {
      debugPrint('❌ Process approval error: $e');
      return ApprovalResult(
        success: false,
        successCount: 0,
        failCount: 1,
        message: e.toString(),
      );
    }
  }

  // ============================================================================
  // GENERATE SPKL
  // ============================================================================
  Future<Map<String, String>> _generateSpklWithPdf({
    required Map<String, dynamic> groupLeader,
    required List<Map<String, dynamic>> mitraList,
    required String approvedByName,
  }) async {
    final groupId = (groupLeader['group_id'] ?? '').toString();
    final now = DateTime.now();
    final shortId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;
    final nomorSpkl =
        'SPKL/${DateFormat('yyyyMMdd').format(now)}/$shortId';

    final formattedMitraList = mitraList.map((mitra) {
      return {
        'nama_mitra': mitra['nama_mitra'] ?? 'Unknown',
        'fungsi_mitra': mitra['fungsi_mitra'] ?? 'Unknown',
      };
    }).toList();

    final spklData = {
      'nomor_spkl': nomorSpkl,
      'group_id': groupId,
      'approved_by_name': approvedByName,
      'approved_at': Timestamp.fromDate(now),
      'tanggal_lembur': groupLeader['tanggal'],
      'jam_mulai': groupLeader['jam_mulai'] ?? '',
      'jam_selesai': groupLeader['jam_selesai'] ?? '',
      'total_jam': ((groupLeader['total_jam_desimal'] as num?) ?? 0).toDouble(),
      'estimasi_biaya_total':
          ((groupLeader['estimasi_biaya_total'] as num?) ?? 0).toDouble(),
      'pengawas_nama': groupLeader['nama_pengawas'] ?? '',
      'pengawas_fungsi': groupLeader['pengawas_fungsi'] ?? '',
      'mitra_list': formattedMitraList,
      'total_mitra': formattedMitraList.length,
      'jenis_lembur': groupLeader['jenis_lembur'] ?? 'hari_kerja',
      'alasan': groupLeader['alasan'] ?? '-',
      'lokasi': groupLeader['lokasi'] ?? {'alamat': 'Area PGE'},
      'urgensi': groupLeader['urgensi'] ?? 'normal',
      'created_at': FieldValue.serverTimestamp(),
      'status': 'active',
    };

    await _firestore.collection('spkl').doc(groupId).set(spklData);

    String pdfPath = '';
    try {
      pdfPath = await _spklGenerator.generateSpklPdf(spklData);
    } catch (e) {
      debugPrint('❌ Generate PDF error: $e');
    }

    // Update pengajuan & lembur_mitra dengan info SPKL
    final batch = _firestore.batch();
    final spklUpdate = {
      'spkl_generated': true,
      'spkl_nomor': nomorSpkl,
      'spkl_generated_at': FieldValue.serverTimestamp(),
      'spkl_status': 'active',
      if (pdfPath.isNotEmpty) 'spkl_pdf_path': pdfPath,
    };

    batch.update(
        _firestore.collection(collectionPengajuan).doc(groupId), spklUpdate);

    final mitraSnapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('group_id', isEqualTo: groupId)
        .get();
    for (final doc in mitraSnapshot.docs) {
      batch.update(_firestore.collection(collectionLemburMitra).doc(doc.id), {
        'spkl_generated': true,
        'spkl_nomor': nomorSpkl,
      });
    }
    await batch.commit();

    return {'nomor': nomorSpkl, 'pdfPath': pdfPath};
  }

  // ============================================================================
  // NOTIFIKASI KE PENGAWAS
  // ============================================================================
  Future<void> _sendNotificationToPengawas({
    required Map<String, dynamic> groupLeader,
    required bool isApprove,
    required String notes,
    required String approverName,
    required String approverRole,
    String? spklNomor,
  }) async {
    try {
      final groupId = (groupLeader['group_id'] ?? '').toString();
      final pengawasId = groupLeader['pengawas_id']?.toString();
      final pengawasNama = groupLeader['nama_pengawas'] ?? 'Unknown';
      final pengawasFungsi = groupLeader['pengawas_fungsi'] ?? 'Unknown';
      final tanggal = _formatDate(groupLeader['tanggal']);
      final waktu =
          '${groupLeader['jam_mulai']} - ${groupLeader['jam_selesai']}';

      if (pengawasId == null || pengawasId.isEmpty) return;

      String pengawasEmail = '';
      String pengawasNoHp = '';
      try {
        final doc =
            await _firestore.collection('users').doc(pengawasId).get();
        if (doc.exists) {
          pengawasEmail = doc.data()?['email'] ?? '';
          pengawasNoHp = doc.data()?['no_hp'] ?? '';
        }
      } catch (_) {}

      await _notificationService.sendApprovalResultNotification(
        pengawasId: pengawasId,
        pengawasNama: pengawasNama,
        pengawasEmail: pengawasEmail,
        pengawasNoHp: pengawasNoHp,
        isApproved: isApprove,
        approverName: approverName,
        approverRole: approverRole,
        spklNomor: spklNomor,
        groupId: groupId,
        notes: notes,
        tanggal: tanggal,
        waktu: waktu,
        fungsi: pengawasFungsi,
      );
    } catch (e) {
      debugPrint('❌ Notif pengawas error: $e');
    }
  }

  // ============================================================================
  // NOTIFIKASI KE MITRA
  // ============================================================================
  Future<void> _sendNotificationToMitra({
    required List<Map<String, dynamic>> mitraList,
    required Map<String, dynamic> groupLeader,
    required String approverName,
    String? spklNomor,
  }) async {
    try {
      final groupId = (groupLeader['group_id'] ?? '').toString();
      final tanggal = _formatDate(groupLeader['tanggal']);
      final waktu =
          '${groupLeader['jam_mulai']} - ${groupLeader['jam_selesai']}';
      final lokasi = groupLeader['lokasi']?['alamat'] ??
          groupLeader['lokasi']?.toString() ??
          'Area PGE Kamojang';
      final pengawasNama = groupLeader['nama_pengawas'] ?? 'Unknown';
      final fungsi = groupLeader['pengawas_fungsi'] ?? 'Unknown';

      for (final mitra in mitraList) {
        final mitraId =
            (mitra['mitra_id'] ?? mitra['user_id'] ?? '').toString();
        final mitraNama = mitra['nama_mitra'] ?? 'Mitra';
        if (mitraId.isEmpty) continue;

        String mitraEmail = '';
        String mitraNoHp = '';
        try {
          final doc =
              await _firestore.collection('users').doc(mitraId).get();
          if (doc.exists) {
            mitraEmail = doc.data()?['email'] ?? '';
            mitraNoHp = doc.data()?['no_hp'] ?? '';
          }
        } catch (_) {}

        await _notificationService.sendMitraAssignmentNotification(
          mitraId: mitraId,
          mitraNama: mitraNama,
          mitraEmail: mitraEmail,
          mitraNoHp: mitraNoHp,
          spklNomor: spklNomor,
          groupId: groupId,
          pengawasNama: pengawasNama,
          tanggal: tanggal,
          waktu: waktu,
          lokasi: lokasi,
          fungsi: fungsi,
        );
      }
    } catch (e) {
      debugPrint('❌ Notif mitra error: $e');
    }
  }

  // ============================================================================
  // BULK APPROVAL
  // ============================================================================
  Future<Map<String, dynamic>> bulkApproval({
    required List<String> groupIds,
    required bool isApprove,
    required String notes,
    required String approverName,
    required String approverEmail,
    required String approverId,
  }) async {
    int totalSuccess = 0;
    int totalFail = 0;
    List<String> failedGroups = [];
    List<String> successGroups = [];

    for (final groupId in groupIds) {
      try {
        final result = await processApproval(
          groupId: groupId,
          isApprove: isApprove,
          notes: notes,
          userRole: 'superadmin',
          approverName: approverName,
          approverEmail: approverEmail,
          approverId: approverId,
        );
        if (result.success) {
          totalSuccess++;
          successGroups.add(groupId);
        } else {
          totalFail++;
          failedGroups.add(groupId);
        }
      } catch (e) {
        totalFail++;
        failedGroups.add(groupId);
      }
    }

    return {
      'totalSuccess': totalSuccess,
      'totalFail': totalFail,
      'successGroups': successGroups,
      'failedGroups': failedGroups,
    };
  }

  // ============================================================================
  // SPKL
  // ============================================================================
  Future<Map<String, dynamic>?> getSpkl(String groupId) async {
    try {
      final doc = await _firestore.collection('spkl').doc(groupId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('❌ Get SPKL error: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> getSpklStream(String groupId) {
    return _firestore
        .collection('spkl')
        .doc(groupId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<String?> previewSpkl(String groupId) async {
    final data = await getSpkl(groupId);
    if (data == null) return null;
    return await _spklGenerator.generateSpklPdf(data);
  }

  Future<String?> downloadSpkl(String groupId) async {
    return await previewSpkl(groupId);
  }

  // ============================================================================
  // LOGS
  // ============================================================================
  Stream<List<Map<String, dynamic>>> getApprovalLogs({
    String? fungsiFilter,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('approval_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (fungsiFilter != null &&
        fungsiFilter.isNotEmpty &&
        fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // ============================================================================
  // HELPER
  // ============================================================================
  String _formatDate(dynamic tanggal) {
    if (tanggal == null) return '-';
    try {
      if (tanggal is Timestamp) {
        return DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal.toDate());
      }
      return DateFormat('dd MMMM yyyy', 'id_ID')
          .format(DateTime.parse(tanggal.toString()));
    } catch (e) {
      return tanggal.toString();
    }
  }
}

// ============================================================================
// RESULT MODEL
// ============================================================================
class ApprovalResult {
  final bool success;
  final int successCount;
  final int failCount;
  final List<String> failedDocs;
  final String? spklNomor;
  final String? spklPdfPath;
  final String message;

  ApprovalResult({
    required this.success,
    this.successCount = 0,
    this.failCount = 0,
    this.failedDocs = const [],
    this.spklNomor,
    this.spklPdfPath,
    this.message = '',
  });
}