import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OvertimeHistory {
  // Basic Info
  final String id;
  final String groupId;
  final String tipeDokumen;
  
  // Pengaju Info
  final String? pengawasId;
  final String? namaPengawas;
  final String? pengawasFungsi;
  final String? diajukanOlehId;
  final String? diajukanOlehNama;
  
  // Mitra Info
  final String? mitraId;
  final String? namaMitra;
  final String? fungsiMitra;
  final String? noHpMitra;
  final List<String>? mitraIds;
  final int totalMitra;
  final bool isMultiple;
  
  // Waktu & Durasi
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  
  // Detail Lembur
  final String jenisLembur;
  final Map<String, dynamic> lokasi;
  final String urgensi;
  final String alasan;
  final String catatanTambahan;
  
  // Biaya
  final double estimasiBiayaPerMitra;
  final double estimasiBiayaTotal;
  final bool isOverride;
  
  // Status Utama
  final String status;
  
  // Approval Umum
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  
  // SPKL
  final bool spklGenerated;
  final String? spklNomor;
  final String? spklPath;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Pembatalan
  final DateTime? dibatalkanPada;
  final String? dibatalkanOleh;
  
  // HSSE FIELDS
  final bool isRisky;
  final String? risikoLevel;
  final String? risikoKategori;
  final String? risikoDeskripsi;
  final List<String>? risikoMitigasi;
  final String hsseStatus;
  final String? hsseApprovedBy;
  final String? hsseApprovedByName;
  final DateTime? hsseApprovedAt;
  final String? hsseRejectedBy;
  final String? hsseRejectedByName;
  final DateTime? hsseRejectedAt;
  final String? hsseAlasanPenolakan;
  final String? hsseReviewBy;
  final String? hsseReviewByName;
  final DateTime? hsseReviewAt;
  final String? hsseCatatanRevisi;
  final List<String>? hsseItemsRevisi;
  final String? hsseCatatan;
  final String? hsseRekomendasi;
  final List<String>? hsseDokumenPendukung;
  final Map<String, dynamic>? hsseChecklist;
  final bool hsseNeedEscalation;
  final String? hsseEscalationTo;
  final String? hsseEscalationReason;
  final DateTime? hsseEscalationAt;
  final String? hsseEscalationBy;
  final String? hsseEscalationByName;
  final bool hsseSafetyBriefing;
  final DateTime? hsseSafetyBriefingDate;
  final String? hsseSafetyBriefingBy;
  final String? hsseSafetyBriefingByName;
  final String? hsseSafetyBriefingCatatan;
  final List<Map<String, dynamic>>? hsseApprovalHistory;
  final Map<String, dynamic>? approvalChain;
  final String approvalLevel;
  final int maxApprovalLevel;
  final String? lastModifiedBy;
  final String? lastModifiedByName;
  final DateTime? lastModifiedAt;
  final List<String>? tags;
  final Map<String, dynamic>? metadata;

  OvertimeHistory({
    required this.id,
    required this.groupId,
    this.tipeDokumen = 'lembur_mitra',
    this.pengawasId,
    this.namaPengawas,
    this.pengawasFungsi,
    this.diajukanOlehId,
    this.diajukanOlehNama,
    this.mitraId,
    this.namaMitra,
    this.fungsiMitra,
    this.noHpMitra,
    this.mitraIds,
    this.totalMitra = 1,
    this.isMultiple = false,
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
    this.isOverride = false,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.spklGenerated = false,
    this.spklNomor,
    this.spklPath,
    required this.createdAt,
    required this.updatedAt,
    this.dibatalkanPada,
    this.dibatalkanOleh,
    this.isRisky = false,
    this.risikoLevel,
    this.risikoKategori,
    this.risikoDeskripsi,
    this.risikoMitigasi,
    this.hsseStatus = 'pending',
    this.hsseApprovedBy,
    this.hsseApprovedByName,
    this.hsseApprovedAt,
    this.hsseRejectedBy,
    this.hsseRejectedByName,
    this.hsseRejectedAt,
    this.hsseAlasanPenolakan,
    this.hsseReviewBy,
    this.hsseReviewByName,
    this.hsseReviewAt,
    this.hsseCatatanRevisi,
    this.hsseItemsRevisi,
    this.hsseCatatan,
    this.hsseRekomendasi,
    this.hsseDokumenPendukung,
    this.hsseChecklist,
    this.hsseNeedEscalation = false,
    this.hsseEscalationTo,
    this.hsseEscalationReason,
    this.hsseEscalationAt,
    this.hsseEscalationBy,
    this.hsseEscalationByName,
    this.hsseSafetyBriefing = false,
    this.hsseSafetyBriefingDate,
    this.hsseSafetyBriefingBy,
    this.hsseSafetyBriefingByName,
    this.hsseSafetyBriefingCatatan,
    this.hsseApprovalHistory,
    this.approvalChain,
    this.approvalLevel = '',
    this.maxApprovalLevel = 1,
    this.lastModifiedBy,
    this.lastModifiedByName,
    this.lastModifiedAt,
    this.tags,
    this.metadata,
  });

  // ─────────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ─────────────────────────────────────────────────────────────────
  
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

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return List<String>.from(value);
    return null;
  }

  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // FROM/TO FIRESTORE
  // ─────────────────────────────────────────────────────────────────

  factory OvertimeHistory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final tanggalValue = data['tanggal'] ?? data['tanggal_lembur'];
    final DateTime tanggal = _parseTimestamp(tanggalValue);
    final createdAt = _parseTimestamp(data['created_at']);
    final updatedAt = _parseTimestamp(data['updated_at']);
    final estimasiBiayaPerMitra = (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0).toDouble();
    final estimasiBiayaTotal = (data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? 0).toDouble();

    return OvertimeHistory(
      id: doc.id,
      groupId: data['group_id'] ?? '',
      tipeDokumen: data['tipe_dokumen'] ?? 'lembur_mitra',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      diajukanOlehId: data['diajukan_oleh_id'] ?? data['pengawas_id'],
      diajukanOlehNama: data['diajukan_oleh_nama'] ?? data['nama_pengawas'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      mitraIds: _parseStringList(data['mitra_ids']),
      totalMitra: data['total_mitra'] ?? 1,
      isMultiple: data['is_multiple'] ?? false,
      tanggal: tanggal,
      jamMulai: data['jam_mulai'] ?? '',
      jamSelesai: data['jam_selesai'] ?? '',
      totalJam: (data['total_jam_desimal'] ?? 0).toDouble(),
      jenisLembur: data['jenis_lembur'] ?? 'hari_kerja',
      lokasi: data['lokasi'] ?? {},
      urgensi: data['urgensi'] ?? 'normal',
      alasan: data['alasan'] ?? '',
      catatanTambahan: data['catatan_tambahan'] ?? '',
      estimasiBiayaPerMitra: estimasiBiayaPerMitra,
      estimasiBiayaTotal: estimasiBiayaTotal > 0 ? estimasiBiayaTotal : estimasiBiayaPerMitra,
      isOverride: data['is_override'] ?? false,
      status: data['status'] ?? 'pending',
      approvedBy: data['approved_by'],
      approvedByName: data['approved_by_name'],
      approvedAt: _parseTimestampOrNull(data['approved_at']),
      spklGenerated: data['spkl_generated'] ?? false,
      spklNomor: data['spkl_nomor'],
      spklPath: data['spkl_path'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      dibatalkanPada: _parseTimestampOrNull(data['dibatalkan_pada']),
      dibatalkanOleh: data['dibatalkan_oleh'],
      isRisky: data['is_risky'] ?? false,
      risikoLevel: data['risiko_level'],
      risikoKategori: data['risiko_kategori'],
      risikoDeskripsi: data['risiko_deskripsi'],
      risikoMitigasi: _parseStringList(data['risiko_mitigasi']),
      hsseStatus: data['hsse_status'] ?? 'pending',
      hsseApprovedBy: data['hsse_approved_by'],
      hsseApprovedByName: data['hsse_approved_by_name'],
      hsseApprovedAt: _parseTimestampOrNull(data['hsse_approved_at']),
      hsseRejectedBy: data['hsse_rejected_by'],
      hsseRejectedByName: data['hsse_rejected_by_name'],
      hsseRejectedAt: _parseTimestampOrNull(data['hsse_rejected_at']),
      hsseAlasanPenolakan: data['hsse_alasan_penolakan'],
      hsseReviewBy: data['hsse_review_by'],
      hsseReviewByName: data['hsse_review_by_name'],
      hsseReviewAt: _parseTimestampOrNull(data['hsse_review_at']),
      hsseCatatanRevisi: data['hsse_catatan_revisi'],
      hsseItemsRevisi: _parseStringList(data['hsse_items_revisi']),
      hsseCatatan: data['hsse_catatan'],
      hsseRekomendasi: data['hsse_rekomendasi'],
      hsseDokumenPendukung: _parseStringList(data['hsse_dokumen_pendukung']),
      hsseChecklist: _parseMap(data['hsse_checklist']),
      hsseNeedEscalation: data['hsse_need_escalation'] ?? false,
      hsseEscalationTo: data['hsse_escalation_to'],
      hsseEscalationReason: data['hsse_escalation_reason'],
      hsseEscalationAt: _parseTimestampOrNull(data['hsse_escalation_at']),
      hsseEscalationBy: data['hsse_escalation_by'],
      hsseEscalationByName: data['hsse_escalation_by_name'],
      hsseSafetyBriefing: data['hsse_safety_briefing'] ?? false,
      hsseSafetyBriefingDate: _parseTimestampOrNull(data['hsse_safety_briefing_date']),
      hsseSafetyBriefingBy: data['hsse_safety_briefing_by'],
      hsseSafetyBriefingByName: data['hsse_safety_briefing_by_name'],
      hsseSafetyBriefingCatatan: data['hsse_safety_briefing_catatan'],
      hsseApprovalHistory: _parseMapList(data['hsse_approval_history']),
      approvalChain: _parseMap(data['approval_chain']),
      approvalLevel: data['approval_level']?.toString() ?? '0',  
      maxApprovalLevel: data['max_approval_level'] ?? 1,
      lastModifiedBy: data['last_modified_by'],
      lastModifiedByName: data['last_modified_by_name'],
      lastModifiedAt: _parseTimestampOrNull(data['last_modified_at']),
      tags: _parseStringList(data['tags']),
      metadata: _parseMap(data['metadata']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'group_id': groupId, 'tipe_dokumen': tipeDokumen,
      'pengawas_id': pengawasId, 'nama_pengawas': namaPengawas,
      'pengawas_fungsi': pengawasFungsi,
      'diajukan_oleh_id': diajukanOlehId, 'diajukan_oleh_nama': diajukanOlehNama,
      'mitra_id': mitraId, 'nama_mitra': namaMitra,
      'fungsi_mitra': fungsiMitra, 'no_hp_mitra': noHpMitra,
      'mitra_ids': mitraIds, 'total_mitra': totalMitra, 'is_multiple': isMultiple,
      'tanggal': Timestamp.fromDate(tanggal),
      'jam_mulai': jamMulai, 'jam_selesai': jamSelesai,
      'total_jam_desimal': totalJam, 'jenis_lembur': jenisLembur,
      'lokasi': lokasi, 'urgensi': urgensi, 'alasan': alasan,
      'catatan_tambahan': catatanTambahan,
      'estimasi_biaya_per_mitra': estimasiBiayaPerMitra,
      'estimasi_biaya_total': estimasiBiayaTotal, 'is_override': isOverride,
      'status': status,
      'approved_by': approvedBy, 'approved_by_name': approvedByName,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'spkl_generated': spklGenerated, 'spkl_nomor': spklNomor, 'spkl_path': spklPath,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'dibatalkan_pada': dibatalkanPada != null ? Timestamp.fromDate(dibatalkanPada!) : null,
      'dibatalkan_oleh': dibatalkanOleh,
      'is_risky': isRisky, 'risiko_level': risikoLevel,
      'risiko_kategori': risikoKategori, 'risiko_deskripsi': risikoDeskripsi,
      'risiko_mitigasi': risikoMitigasi, 'hsse_status': hsseStatus,
      'hsse_approved_by': hsseApprovedBy, 'hsse_approved_by_name': hsseApprovedByName,
      'hsse_approved_at': hsseApprovedAt != null ? Timestamp.fromDate(hsseApprovedAt!) : null,
      'hsse_rejected_by': hsseRejectedBy, 'hsse_rejected_by_name': hsseRejectedByName,
      'hsse_rejected_at': hsseRejectedAt != null ? Timestamp.fromDate(hsseRejectedAt!) : null,
      'hsse_alasan_penolakan': hsseAlasanPenolakan,
      'hsse_review_by': hsseReviewBy, 'hsse_review_by_name': hsseReviewByName,
      'hsse_review_at': hsseReviewAt != null ? Timestamp.fromDate(hsseReviewAt!) : null,
      'hsse_catatan_revisi': hsseCatatanRevisi, 'hsse_items_revisi': hsseItemsRevisi,
      'hsse_catatan': hsseCatatan, 'hsse_rekomendasi': hsseRekomendasi,
      'hsse_dokumen_pendukung': hsseDokumenPendukung, 'hsse_checklist': hsseChecklist,
      'hsse_need_escalation': hsseNeedEscalation,
      'hsse_escalation_to': hsseEscalationTo, 'hsse_escalation_reason': hsseEscalationReason,
      'hsse_escalation_at': hsseEscalationAt != null ? Timestamp.fromDate(hsseEscalationAt!) : null,
      'hsse_escalation_by': hsseEscalationBy, 'hsse_escalation_by_name': hsseEscalationByName,
      'hsse_safety_briefing': hsseSafetyBriefing,
      'hsse_safety_briefing_date': hsseSafetyBriefingDate != null ? Timestamp.fromDate(hsseSafetyBriefingDate!) : null,
      'hsse_safety_briefing_by': hsseSafetyBriefingBy,
      'hsse_safety_briefing_by_name': hsseSafetyBriefingByName,
      'hsse_safety_briefing_catatan': hsseSafetyBriefingCatatan,
      'hsse_approval_history': hsseApprovalHistory,
      'approval_chain': approvalChain,
      'approval_level': approvalLevel, 'max_approval_level': maxApprovalLevel,
      'last_modified_by': lastModifiedBy, 'last_modified_by_name': lastModifiedByName,
      'last_modified_at': lastModifiedAt != null ? Timestamp.fromDate(lastModifiedAt!) : null,
      'tags': tags, 'metadata': metadata,
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPER PROPERTIES
  // ─────────────────────────────────────────────────────────────────

  String get tahunBulan => DateFormat('yyyy-MM').format(tanggal);
  String get namaPengaju => diajukanOlehNama ?? namaPengawas ?? 'Tidak diketahui';
  bool get isMitraDocument => tipeDokumen == 'lembur_mitra';
  bool get isPengajuanDocument => tipeDokumen == 'pengajuan';
  
  bool get canBeCancelled {
    if (status != 'pending' && status != 'disetujui') return false;
    return DateTime.now().difference(createdAt).inDays > 3;
  }

  bool get needsHSSEApproval => isRisky && hsseStatus == 'pending';
  bool get isHSSEApproved => isRisky && hsseStatus == 'disetujui';
  bool get isHSSERejected => isRisky && hsseStatus == 'ditolak';
  bool get isHSSEReview => isRisky && hsseStatus == 'dalam_review';
  bool get needsHSSERevision => isRisky && hsseStatus == 'perlu_revisi';
  bool get isHSSEProcessed => hsseStatus == 'disetujui' || hsseStatus == 'ditolak';
  bool get isEscalated => hsseNeedEscalation;
  
  String get statusLabel {
    switch (status) {
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'selesai': return 'Selesai';
      case 'kadaluarsa': return 'Kadaluarsa';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }
  
  String get risikoLevelLabel {
    switch (risikoLevel) {
      case 'rendah': return 'Rendah';
      case 'sedang': return 'Sedang';
      case 'tinggi': return 'Tinggi';
      case 'kritis': return 'Kritis';
      default: return 'Tidak Diketahui';
    }
  }

  String get hsseStatusLabel {
    switch (hsseStatus) {
      case 'pending': return 'Menunggu HSSE';
      case 'disetujui': return 'Disetujui HSSE';
      case 'ditolak': return 'Ditolak HSSE';
      case 'perlu_revisi': return 'Perlu Revisi';
      case 'dalam_review': return 'Dalam Review';
      default: return hsseStatus;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'selesai': return Colors.blue;
      case 'kadaluarsa': return Colors.grey;
      case 'dibatalkan': return Colors.red[300]!;
      default: return Colors.grey;
    }
  }

  Color get risikoLevelColor {
    switch (risikoLevel) {
      case 'rendah': return Colors.green;
      case 'sedang': return Colors.orange;
      case 'tinggi': return Colors.deepOrange;
      case 'kritis': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color get hsseStatusColor {
    switch (hsseStatus) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'perlu_revisi': return Colors.amber;
      case 'dalam_review': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'disetujui': return Icons.check_circle_outline;
      case 'ditolak': return Icons.cancel_outlined;
      case 'selesai': return Icons.task_alt;
      case 'kadaluarsa': return Icons.timer_off;
      case 'dibatalkan': return Icons.remove_circle_outline;
      default: return Icons.help_outline;
    }
  }

  IconData get risikoLevelIcon {
    switch (risikoLevel) {
      case 'rendah': return Icons.check_circle_outline;
      case 'sedang': return Icons.warning_amber_outlined;
      case 'tinggi': return Icons.warning_rounded;
      case 'kritis': return Icons.dangerous_outlined;
      default: return Icons.help_outline;
    }
  }

  IconData get hsseStatusIcon {
    switch (hsseStatus) {
      case 'pending': return Icons.schedule;
      case 'disetujui': return Icons.verified;
      case 'ditolak': return Icons.cancel;
      case 'perlu_revisi': return Icons.edit_note;
      case 'dalam_review': return Icons.visibility;
      default: return Icons.help_outline;
    }
  }
}

/// ============================================================================
/// ENUM: HSSE View Mode
/// ============================================================================
enum HSSEViewMode {
  all,
  needApproval,
  myHistory,
}

/// ============================================================================
/// SERVICE: OvertimeHistoryService (CLEANED - No Absensi Operations)
/// ============================================================================
class OvertimeHistoryService {
  static final OvertimeHistoryService _instance = OvertimeHistoryService._internal();
  factory OvertimeHistoryService() => _instance;
  OvertimeHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionHSSELogs = 'hsse_activity_logs';
  static const String collectionSafetyBriefing = 'safety_briefings';
  static const String collectionActivityLogs = 'activity_logs';
  
  static const int batasWaktuPembatalan = 3;

  // =========================================================================
  // 🔥 KONSTANTA STATUS HSSE
  // =========================================================================
  static const List<String> hssePendingStatuses = [
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  static const List<String> hsseResolvedStatuses = [
    'disetujui',
    'ditolak',
  ];

  // =========================================================================
  // HELPERS
  // =========================================================================
  
  List<OvertimeHistory> _filterByBulan(List<OvertimeHistory> data, String? bulan) {
    if (bulan == null || bulan.isEmpty || bulan == 'semua') return data;
    return data.where((item) => item.tahunBulan == bulan).toList();
  }

  List<OvertimeHistory> _removeDuplicates(List<OvertimeHistory> data) {
    final seenIds = <String>{};
    return data.where((item) => seenIds.add(item.id)).toList();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findDocument(String documentId) async {
    var doc = await _firestore.collection(collectionLemburMitra).doc(documentId).get();
    if (doc.exists) return doc;
    doc = await _firestore.collection(collectionPengajuan).doc(documentId).get();
    if (doc.exists) return doc;
    return null;
  }

  // =========================================================================
  // STREAMS UTAMA
  // =========================================================================

  Stream<List<OvertimeHistory>> getOvertimeHistoryStream({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
    String? statusFilter,
  }) {
    if (userRole == 'manager' && userFungsi == 'hsse') {
      return _getHSSEManagerStream(bulan: bulan, statusFilter: statusFilter);
    }
    
    switch (userRole) {
      case 'mitra':
        return _getMitraHistoryStream(mitraId: userId!, bulan: bulan, statusFilter: statusFilter);
      case 'pengawas':
        return _getPengawasHistoryStream(pengawasId: userId!, bulan: bulan, statusFilter: statusFilter);
      case 'manager':
        return _getManagerHistoryStream(fungsi: userFungsi, bulan: bulan, statusFilter: statusFilter);
      case 'superadmin':
        return _getAllHistoryStream(bulan: bulan, statusFilter: statusFilter);
      default:
        return Stream.value([]);
    }
  }

  Stream<List<OvertimeHistory>> _getMitraHistoryStream({
    required String mitraId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('mitra_id', isEqualTo: mitraId);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snapshot) {
      var docs = snapshot.docs
          .map((doc) => OvertimeHistory.fromFirestore(doc))
          .where((item) => item.mitraId == mitraId && item.tipeDokumen == 'lembur_mitra')
          .toList();
      return _filterByBulan(docs, bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getPengawasHistoryStream({
    required String pengawasId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('diajukan_oleh_id', isEqualTo: pengawasId);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snapshot) {
      var docs = snapshot.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      return _filterByBulan(docs, bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getManagerHistoryStream({
    String? fungsi, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionPengajuan);
    if (fungsi != null && fungsi.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: fungsi);
    }
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('created_at', descending: true).snapshots().map((snapshot) {
      var docs = snapshot.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      return _filterByBulan(docs, bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getAllHistoryStream({String? bulan, String? statusFilter}) {
    final controller = StreamController<List<OvertimeHistory>>();
    StreamSubscription? pengajuanSub, mitraSub;
    List<OvertimeHistory> lastPengajuan = [], lastMitra = [];

    void emitMerged() {
      var allData = [...lastPengajuan, ...lastMitra];
      allData = _removeDuplicates(allData);
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        allData = allData.where((item) => item.status == statusFilter).toList();
      }
      allData = _filterByBulan(allData, bulan);
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      if (!controller.isClosed) controller.add(allData);
    }

    Query<Map<String, dynamic>> qp = _firestore.collection(collectionPengajuan);
    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qp = qp.where('tahun_bulan', isEqualTo: bulan);
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }

    pengajuanSub = qp.orderBy('created_at', descending: true).snapshots()
        .map((snap) => snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList())
        .listen((data) { lastPengajuan = data; emitMerged(); });
    mitraSub = qm.orderBy('tanggal', descending: true).snapshots()
        .map((snap) => snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList())
        .listen((data) { lastMitra = data; emitMerged(); });

    controller.onCancel = () { pengajuanSub?.cancel(); mitraSub?.cancel(); };
    return controller.stream;
  }

  // =========================================================================
  // HSSE STREAMS (Tetap ada, tidak terkait absensi)
  // =========================================================================

  Stream<List<OvertimeHistory>> _getHSSEManagerStream({
    String? bulan, String? statusFilter, String? hsseStatus,
    String? risikoLevel, String? risikoKategori,
  }) {
    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
        .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses]);
    
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      qm = qm.where('status', isEqualTo: statusFilter);
    }
    if (risikoLevel != null && risikoLevel.isNotEmpty && risikoLevel != 'semua') {
      qm = qm.where('risiko_level', isEqualTo: risikoLevel);
    }
    if (risikoKategori != null && risikoKategori.isNotEmpty && risikoKategori != 'semua') {
      qm = qm.where('risiko_kategori', isEqualTo: risikoKategori);
    }

    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      
      if (hsseStatus != null && hsseStatus.isNotEmpty && hsseStatus != 'semua') {
        allData = allData.where((item) => item.hsseStatus == hsseStatus).toList();
      }
      
      allData.sort((a, b) {
        if (a.hsseStatus == 'pending' && b.hsseStatus != 'pending') return -1;
        if (b.hsseStatus == 'pending' && a.hsseStatus != 'pending') return 1;
        final levelOrder = {'kritis': 0, 'tinggi': 1, 'sedang': 2, 'rendah': 3};
        final aLevel = levelOrder[a.risikoLevel] ?? 4;
        final bLevel = levelOrder[b.risikoLevel] ?? 4;
        if (aLevel != bLevel) return aLevel.compareTo(bLevel);
        return b.tanggal.compareTo(a.tanggal);
      });
      
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSEApprovedByMeStream({
    required String hsseUserId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
        .where('status', whereIn: hsseResolvedStatuses)
        .where('hsse_validated', isEqualTo: true);
    
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }

    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      
      allData = allData.where((item) {
        return item.hsseApprovedBy == hsseUserId ||
               item.hsseRejectedBy == hsseUserId ||
               item.hsseReviewBy == hsseUserId;
      }).toList();
      
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        allData = allData.where((item) => item.status == statusFilter).toList();
      }
      
      allData.sort((a, b) {
        final aDate = a.hsseApprovedAt ?? a.hsseRejectedAt ?? a.createdAt;
        final bDate = b.hsseApprovedAt ?? b.hsseRejectedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSERiskyOvertimeStream({
    String? bulan, String? statusFilter, String? risikoLevel,
    String? risikoKategori, String? hsseStatus, String? hsseUserId,
    HSSEViewMode? viewMode,
  }) {
    List<String> hsseStatusFilter;
    if (hsseStatus != null && hsseStatus.isNotEmpty) {
      hsseStatusFilter = [hsseStatus];
    } else {
      hsseStatusFilter = ['pending', 'disetujui', 'ditolak', 'perlu_revisi', 'dalam_review'];
    }

    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
        .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses])
        .where('hsse_status', whereIn: hsseStatusFilter);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      qm = qm.where('status', isEqualTo: statusFilter);
    }
    if (risikoLevel != null && risikoLevel.isNotEmpty) {
      qm = qm.where('risiko_level', isEqualTo: risikoLevel);
    }
    if (risikoKategori != null && risikoKategori.isNotEmpty) {
      qm = qm.where('risiko_kategori', isEqualTo: risikoKategori);
    }

    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      
      if (hsseUserId != null && hsseUserId.isNotEmpty) {
        allData = allData.where((item) {
          if (item.hsseStatus == 'pending') return true;
          if (item.hsseApprovedBy == hsseUserId) return true;
          if (item.hsseRejectedBy == hsseUserId) return true;
          if (item.hsseReviewBy == hsseUserId) return true;
          return false;
        }).toList();
      }
      
      allData.sort((a, b) {
        final levelOrder = {'kritis': 0, 'tinggi': 1, 'sedang': 2, 'rendah': 3};
        final aLevel = levelOrder[a.risikoLevel] ?? 4;
        final bLevel = levelOrder[b.risikoLevel] ?? 4;
        if (aLevel != bLevel) return aLevel.compareTo(bLevel);
        return b.tanggal.compareTo(a.tanggal);
      });
      
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSEApprovalHistoryStream({
    required String hsseUserId, String? bulan, String? hsseStatus,
  }) {
    List<String> statusFilter;
    if (hsseStatus != null && hsseStatus.isNotEmpty) {
      statusFilter = [hsseStatus];
    } else {
      statusFilter = ['disetujui', 'ditolak', 'perlu_revisi', 'dalam_review'];
    }

    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
        .where('status', whereIn: hsseResolvedStatuses)
        .where('hsse_status', whereIn: statusFilter);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }

    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      
      allData = allData.where((item) {
        return item.hsseApprovedBy == hsseUserId ||
               item.hsseRejectedBy == hsseUserId ||
               item.hsseReviewBy == hsseUserId ||
               item.hsseEscalationBy == hsseUserId;
      }).toList();
      
      allData.sort((a, b) {
        final aDate = a.hsseApprovedAt ?? a.hsseRejectedAt ?? a.createdAt;
        final bDate = b.hsseApprovedAt ?? b.hsseRejectedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSEEscalationStream({String? bulan}) {
    Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
        .where('hsse_need_escalation', isEqualTo: true);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      qm = qm.where('tahun_bulan', isEqualTo: bulan);
    }

    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSEManagerHistoryStream({
    String? bulan, String? statusFilter, String? hsseStatus,
    String? risikoLevel, String? risikoKategori,
  }) {
    return _getHSSEManagerStream(
      bulan: bulan, statusFilter: statusFilter,
      hsseStatus: hsseStatus, risikoLevel: risikoLevel, risikoKategori: risikoKategori,
    );
  }

  // =========================================================================
  // STATISTIK
  // =========================================================================
  
  Future<Map<String, dynamic>> getHSSEManagerStats({
    String? bulan, String? hsseStatus,
  }) async {
    try {
      Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
          .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses]);
          
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        qm = qm.where('tahun_bulan', isEqualTo: bulan);
      }
      if (hsseStatus != null && hsseStatus.isNotEmpty && hsseStatus != 'semua') {
        qm = qm.where('hsse_status', isEqualTo: hsseStatus);
      }
      
      final allDocs = (await qm.get()).docs;
      
      int total = allDocs.length;
      int pending = 0, approved = 0, rejected = 0, perluRevisi = 0, dalamReview = 0;
      int kritis = 0, tinggi = 0, sedang = 0, rendah = 0;
      Set<String> fungsiSet = {};
      double totalBiaya = 0;
      
      for (var doc in allDocs) {
        final overtime = OvertimeHistory.fromFirestore(doc);
        switch (overtime.hsseStatus) {
          case 'pending': pending++; break;
          case 'disetujui': approved++; break;
          case 'ditolak': rejected++; break;
          case 'perlu_revisi': perluRevisi++; break;
          case 'dalam_review': dalamReview++; break;
        }
        switch (overtime.risikoLevel) {
          case 'kritis': kritis++; break;
          case 'tinggi': tinggi++; break;
          case 'sedang': sedang++; break;
          case 'rendah': rendah++; break;
        }
        final fungsi = overtime.pengawasFungsi ?? overtime.fungsiMitra;
        if (fungsi != null) fungsiSet.add(fungsi);
        totalBiaya += overtime.estimasiBiayaTotal > 0 
            ? overtime.estimasiBiayaTotal 
            : overtime.estimasiBiayaPerMitra;
      }
      
      return {
        'total': total, 'pending': pending, 'approved': approved, 'rejected': rejected,
        'perluRevisi': perluRevisi, 'dalamReview': dalamReview,
        'kritis': kritis, 'tinggi': tinggi, 'sedang': sedang, 'rendah': rendah,
        'fungsiTerkait': fungsiSet.toList(), 'totalBiaya': totalBiaya,
        'approvalRate': total > 0 ? (approved / total * 100) : 0,
        'rejectionRate': total > 0 ? (rejected / total * 100) : 0,
      };
    } catch (e) {
      return {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0, 'perluRevisi': 0, 'dalamReview': 0, 'kritis': 0, 'tinggi': 0, 'sedang': 0, 'rendah': 0, 'fungsiTerkait': [], 'totalBiaya': 0, 'approvalRate': 0, 'rejectionRate': 0};
    }
  }

  Future<Map<String, dynamic>> getOvertimeStats({
    required String userRole, String? userFungsi, String? userId, String? bulan,
  }) async {
    try {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
      
      if (userRole == 'manager' && userFungsi == 'hsse') {
        Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
            .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses]);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
          qm = qm.where('tahun_bulan', isEqualTo: bulan);
        }
        allDocs = (await qm.get()).docs.toList();
      } else if (userRole == 'mitra') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
        if (userId != null && userId.isNotEmpty) query = query.where('mitra_id', isEqualTo: userId);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        allDocs = (await query.get()).docs.toList();
      } else if (userRole == 'pengawas') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
        if (userId != null && userId.isNotEmpty) query = query.where('diajukan_oleh_id', isEqualTo: userId);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        allDocs = (await query.get()).docs.toList();
      } else if (userRole == 'manager') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionPengajuan);
        if (userFungsi != null && userFungsi.isNotEmpty) query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
        allDocs = (await query.get()).docs.toList();
      } else {
        Query<Map<String, dynamic>> qp = _firestore.collection(collectionPengajuan);
        Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra);
        if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
          qp = qp.where('tahun_bulan', isEqualTo: bulan);
          qm = qm.where('tahun_bulan', isEqualTo: bulan);
        }
        final results = await Future.wait([qp.get(), qm.get()]);
        allDocs = [...results[0].docs, ...results[1].docs];
      }

      int total = allDocs.length, pending = 0, approved = 0, completed = 0,
          rejected = 0, expired = 0, cancelled = 0, riskyCount = 0;
      double totalJam = 0, totalBiaya = 0;

      for (var doc in allDocs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        switch (status) {
          case 'pending': pending++; break;
          case 'disetujui': approved++; break;
          case 'selesai': completed++; totalJam += (data['total_jam_desimal'] ?? 0).toDouble(); totalBiaya += (data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? 0).toDouble(); break;
          case 'ditolak': rejected++; break;
          case 'kadaluarsa': expired++; break;
          case 'dibatalkan': cancelled++; break;
        }
        if (hssePendingStatuses.contains(status) || data['requires_hsse_approval'] == true) riskyCount++;
      }

      return {
        'total': total, 'pending': pending, 'approved': approved, 'completed': completed,
        'rejected': rejected, 'expired': expired, 'cancelled': cancelled,
        'totalJam': totalJam, 'totalBiaya': totalBiaya, 'riskyCount': riskyCount,
      };
    } catch (e) {
      return {'total': 0, 'pending': 0, 'approved': 0, 'completed': 0, 'rejected': 0, 'expired': 0, 'cancelled': 0, 'totalJam': 0, 'totalBiaya': 0, 'riskyCount': 0};
    }
  }

  Future<Map<String, dynamic>> getHSSEStats({String? bulan, String? hsseUserId}) async {
    try {
      Query<Map<String, dynamic>> qm = _firestore.collection(collectionLemburMitra)
          .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses]);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        qm = qm.where('tahun_bulan', isEqualTo: bulan);
      }
      var allDocs = (await qm.get()).docs;

      if (hsseUserId != null && hsseUserId.isNotEmpty) {
        allDocs = allDocs.where((doc) {
          final data = doc.data();
          return data['hsse_status'] == 'pending' || data['hsse_approved_by'] == hsseUserId || data['hsse_rejected_by'] == hsseUserId;
        }).toList();
      }

      int totalRisky = allDocs.length, pendingHSSE = 0, approvedHSSE = 0, rejectedHSSE = 0,
          perluRevisi = 0, dalamReview = 0, escalated = 0;
      double totalBiaya = 0;
      Set<String> fungsiSet = {};

      for (var doc in allDocs) {
        final overtime = OvertimeHistory.fromFirestore(doc);
        switch (overtime.hsseStatus) {
          case 'pending': pendingHSSE++; break;
          case 'disetujui': approvedHSSE++; break;
          case 'ditolak': rejectedHSSE++; break;
          case 'perlu_revisi': perluRevisi++; break;
          case 'dalam_review': dalamReview++; break;
        }
        if (overtime.hsseNeedEscalation) escalated++;
        totalBiaya += overtime.estimasiBiayaTotal > 0 ? overtime.estimasiBiayaTotal : overtime.estimasiBiayaPerMitra;
        final fungsi = overtime.pengawasFungsi ?? overtime.fungsiMitra;
        if (fungsi != null) fungsiSet.add(fungsi);
      }

      return {
        'totalRisky': totalRisky, 'pendingHSSE': pendingHSSE, 'approvedHSSE': approvedHSSE,
        'rejectedHSSE': rejectedHSSE, 'perluRevisi': perluRevisi, 'dalamReview': dalamReview,
        'escalated': escalated, 'totalBiaya': totalBiaya, 'fungsiTerkait': fungsiSet.toList(),
        'approvalRate': totalRisky > 0 ? (approvedHSSE / totalRisky * 100) : 0,
        'rejectionRate': totalRisky > 0 ? (rejectedHSSE / totalRisky * 100) : 0,
      };
    } catch (e) {
      return {'totalRisky': 0, 'pendingHSSE': 0, 'approvedHSSE': 0, 'rejectedHSSE': 0, 'perluRevisi': 0, 'dalamReview': 0, 'escalated': 0, 'totalBiaya': 0, 'fungsiTerkait': [], 'approvalRate': 0, 'rejectionRate': 0};
    }
  }

  Future<Map<String, dynamic>> getHSSEQuickStats() async {
    try {
      final mitraSnapshot = await _firestore.collection(collectionLemburMitra)
          .where('status', whereIn: hssePendingStatuses)
          .where('hsse_status', isEqualTo: 'pending')
          .get();
      final pendingCount = mitraSnapshot.docs.length;
      int kritisCount = 0;
      for (var doc in mitraSnapshot.docs) {
        if (doc.data()['risiko_level'] == 'kritis') kritisCount++;
      }
      return {'pendingTotal': pendingCount, 'kritisCount': kritisCount, 'needsAttention': kritisCount > 0 || pendingCount > 5};
    } catch (e) {
      return {'pendingTotal': 0, 'kritisCount': 0, 'needsAttention': false};
    }
  }

  // =========================================================================
  // CRUD & PEMBATALAN
  // =========================================================================
  
  Future<Map<String, dynamic>> batalkanPengajuan({required String documentId, required String userId}) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return {'success': false, 'message': 'Data pengajuan tidak ditemukan'};
      
      final data = docSnapshot.data()!;
      final status = data['status'] as String?;
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      
      if (status != 'pending' && status != 'disetujui') {
        return {'success': false, 'message': 'Hanya pengajuan dengan status pending atau disetujui yang bisa dibatalkan'};
      }
      if (createdAt != null && DateTime.now().difference(createdAt).inDays < batasWaktuPembatalan) {
        return {'success': false, 'message': 'Pengajuan belum bisa dibatalkan (minimal $batasWaktuPembatalan hari)'};
      }
      
      final updateData = <String, dynamic>{
        'status': 'dibatalkan', 'dibatalkan_pada': FieldValue.serverTimestamp(),
        'dibatalkan_oleh': userId, 'updated_at': FieldValue.serverTimestamp(),
      };
      await docSnapshot.reference.update(updateData);
      
      final groupId = data['group_id'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        final otherCollection = docSnapshot.reference.parent.id == collectionLemburMitra ? collectionPengajuan : collectionLemburMitra;
        final otherDocs = await _firestore.collection(otherCollection).where('group_id', isEqualTo: groupId).get();
        for (var doc in otherDocs.docs) { await doc.reference.update(updateData); }
      }
      
      await _logActivity(action: 'batalkan_pengajuan', documentId: documentId, userId: userId, details: 'Membatalkan pengajuan lembur');
      return {'success': true, 'message': 'Pengajuan berhasil dibatalkan'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  Future<bool> canBatalkanPengajuan(String documentId) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return false;
      final data = docSnapshot.data()!;
      final status = data['status'] as String?;
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      if (status != 'pending' && status != 'disetujui') return false;
      if (createdAt != null) return DateTime.now().difference(createdAt).inDays >= batasWaktuPembatalan;
      return false;
    } catch (e) { return false; }
  }

  Future<Map<String, dynamic>> batalkanPengajuanByGroup({required String groupId, required String userId}) async {
    try {
      int cancelledCount = 0;
      final errors = <String>[];
      final pengajuanDocs = await _firestore.collection(collectionPengajuan).where('group_id', isEqualTo: groupId).get();
      final mitraDocs = await _firestore.collection(collectionLemburMitra).where('group_id', isEqualTo: groupId).get();
      for (var doc in [...pengajuanDocs.docs, ...mitraDocs.docs]) {
        final result = await batalkanPengajuan(documentId: doc.id, userId: userId);
        if (result['success'] == true) { cancelledCount++; } else { errors.add('${doc.id}: ${result['message']}'); }
      }
      return {
        'success': errors.isEmpty,
        'message': errors.isEmpty ? 'Berhasil membatalkan $cancelledCount pengajuan' : 'Berhasil membatalkan $cancelledCount pengajuan, gagal: ${errors.join(', ')}',
        'cancelledCount': cancelledCount, 'totalCount': pengajuanDocs.docs.length + mitraDocs.docs.length, 'errors': errors,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}', 'cancelledCount': 0, 'totalCount': 0, 'errors': [e.toString()]};
    }
  }

  Future<OvertimeHistory?> getOvertimeById(String id) async {
    try {
      final doc = await _findDocument(id);
      return doc != null ? OvertimeHistory.fromFirestore(doc) : null;
    } catch (e) { return null; }
  }

  Future<List<OvertimeHistory>> getOvertimeByGroupId(String groupId) async {
    try {
      final results = await Future.wait([
        _firestore.collection(collectionPengajuan).where('group_id', isEqualTo: groupId).get(),
        _firestore.collection(collectionLemburMitra).where('group_id', isEqualTo: groupId).get(),
      ]);
      return [...results[0].docs, ...results[1].docs].map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
    } catch (e) { return []; }
  }

  // =========================================================================
  // HSSE APPROVAL OPERATIONS
  // =========================================================================

  Future<Map<String, dynamic>> approveByHSSe({
    required String documentId, required String hssId, String? hssName,
    String? catatan, String? rekomendasi, Map<String, dynamic>? checklist,
    bool requireSafetyBriefing = false,
  }) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return {'success': false, 'message': 'Dokumen tidak ditemukan'};
      final data = docSnapshot.data()!;
      
      if (!hssePendingStatuses.contains(data['status'])) {
        return {'success': false, 'message': 'Dokumen ini bukan pengajuan yang menunggu validasi HSSE'};
      }

      List<Map<String, dynamic>> approvalHistory = data['hsse_approval_history'] != null
          ? List<Map<String, dynamic>>.from(data['hsse_approval_history']) : [];
      approvalHistory.add({'action': 'disetujui', 'by': hssId, 'name': hssName, 'at': FieldValue.serverTimestamp(), 'catatan': catatan, 'rekomendasi': rekomendasi});

      final updateData = <String, dynamic>{
        'hsse_status': 'disetujui', 'hsse_approved_by': hssId, 'hsse_approved_by_name': hssName,
        'hsse_approved_at': FieldValue.serverTimestamp(), 'hsse_catatan': catatan,
        'hsse_rekomendasi': rekomendasi, 'hsse_checklist': checklist,
        'hsse_safety_briefing': requireSafetyBriefing, 'hsse_approval_history': approvalHistory,
        'updated_at': FieldValue.serverTimestamp(), 'last_modified_by': hssId,
        'last_modified_by_name': hssName, 'last_modified_at': FieldValue.serverTimestamp(),
      };
      await docSnapshot.reference.update(updateData);

      final groupId = data['group_id'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        final otherCollection = docSnapshot.reference.parent.id == collectionLemburMitra ? collectionPengajuan : collectionLemburMitra;
        final otherDocs = await _firestore.collection(otherCollection).where('group_id', isEqualTo: groupId).get();
        for (var doc in otherDocs.docs) { await doc.reference.update(updateData); }
      }

      await _logHSSEActivity(action: 'approve', documentId: documentId, userId: hssId, userName: hssName, details: 'Menyetujui pengajuan lembur berisiko', catatan: catatan);
      if (requireSafetyBriefing) await _createSafetyBriefing(documentId: documentId, groupId: groupId, hssId: hssId, hssName: hssName);
      return {'success': true, 'message': 'Pengajuan berisiko berhasil disetujui oleh HSSE'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menyetujui pengajuan: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> rejectByHSSe({
    required String documentId, required String hssId, String? hssName, String? alasanPenolakan,
  }) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return {'success': false, 'message': 'Dokumen tidak ditemukan'};
      final data = docSnapshot.data()!;
      
      if (!hssePendingStatuses.contains(data['status'])) {
        return {'success': false, 'message': 'Dokumen ini bukan pengajuan yang menunggu validasi HSSE'};
      }

      List<Map<String, dynamic>> approvalHistory = data['hsse_approval_history'] != null
          ? List<Map<String, dynamic>>.from(data['hsse_approval_history']) : [];
      approvalHistory.add({'action': 'ditolak', 'by': hssId, 'name': hssName, 'at': FieldValue.serverTimestamp(), 'alasan': alasanPenolakan});

      final updateData = <String, dynamic>{
        'hsse_status': 'ditolak', 'status': 'ditolak', 'hsse_rejected_by': hssId,
        'hsse_rejected_by_name': hssName, 'hsse_rejected_at': FieldValue.serverTimestamp(),
        'hsse_alasan_penolakan': alasanPenolakan, 'hsse_approval_history': approvalHistory,
        'updated_at': FieldValue.serverTimestamp(), 'last_modified_by': hssId,
        'last_modified_by_name': hssName, 'last_modified_at': FieldValue.serverTimestamp(),
      };
      await docSnapshot.reference.update(updateData);

      final groupId = data['group_id'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        final otherCollection = docSnapshot.reference.parent.id == collectionLemburMitra ? collectionPengajuan : collectionLemburMitra;
        final otherDocs = await _firestore.collection(otherCollection).where('group_id', isEqualTo: groupId).get();
        for (var doc in otherDocs.docs) { await doc.reference.update(updateData); }
      }

      await _logHSSEActivity(action: 'reject', documentId: documentId, userId: hssId, userName: hssName, details: 'Menolak pengajuan lembur berisiko', catatan: alasanPenolakan);
      return {'success': true, 'message': 'Pengajuan berisiko berhasil ditolak oleh HSSE'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menolak pengajuan: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> requestRevisionByHSSe({
    required String documentId, required String hssId, String? hssName,
    String? catatanRevisi, List<String>? itemsToRevise,
  }) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return {'success': false, 'message': 'Dokumen tidak ditemukan'};

      final updateData = <String, dynamic>{
        'hsse_status': 'perlu_revisi', 'hsse_catatan_revisi': catatanRevisi,
        'hsse_items_revisi': itemsToRevise, 'hsse_review_by': hssId,
        'hsse_review_by_name': hssName, 'hsse_review_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(), 'last_modified_by': hssId,
        'last_modified_by_name': hssName, 'last_modified_at': FieldValue.serverTimestamp(),
      };
      await docSnapshot.reference.update(updateData);
      await _logHSSEActivity(action: 'request_revision', documentId: documentId, userId: hssId, userName: hssName, details: 'Meminta revisi pengajuan lembur berisiko', catatan: catatanRevisi);
      return {'success': true, 'message': 'Permintaan revisi berhasil dikirim'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal meminta revisi: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> escalateByHSSe({
    required String documentId, required String hssId, String? hssName,
    required String escalateTo, String? reason,
  }) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return {'success': false, 'message': 'Dokumen tidak ditemukan'};
      final updateData = <String, dynamic>{
        'hsse_need_escalation': true, 'hsse_escalation_to': escalateTo,
        'hsse_escalation_reason': reason, 'hsse_escalation_at': FieldValue.serverTimestamp(),
        'hsse_escalation_by': hssId, 'hsse_escalation_by_name': hssName,
        'updated_at': FieldValue.serverTimestamp(),
      };
      await docSnapshot.reference.update(updateData);
      final data = docSnapshot.data()!;
      final groupId = data['group_id'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        final otherCollection = docSnapshot.reference.parent.id == collectionLemburMitra ? collectionPengajuan : collectionLemburMitra;
        final otherDocs = await _firestore.collection(otherCollection).where('group_id', isEqualTo: groupId).get();
        for (var doc in otherDocs.docs) { await doc.reference.update(updateData); }
      }
      await _logHSSEActivity(action: 'escalate', documentId: documentId, userId: hssId, userName: hssName, details: 'Mengeskalasi pengajuan ke $escalateTo', catatan: reason);
      return {'success': true, 'message': 'Pengajuan berhasil dieskalasi ke $escalateTo'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengeskalasi: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> completeSafetyBriefing({
    required String documentId, required String hssId, String? hssName, String? catatan,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'hsse_safety_briefing': true, 'hsse_safety_briefing_date': FieldValue.serverTimestamp(),
        'hsse_safety_briefing_by': hssId, 'hsse_safety_briefing_by_name': hssName,
        'hsse_safety_briefing_catatan': catatan, 'updated_at': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(collectionPengajuan).doc(documentId).update(updateData);
      await _logHSSEActivity(action: 'complete_safety_briefing', documentId: documentId, userId: hssId, userName: hssName, details: 'Menyelesaikan safety briefing', catatan: catatan);
      return {'success': true, 'message': 'Safety briefing berhasil dicatat'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal mencatat safety briefing: ${e.toString()}'};
    }
  }

  // =========================================================================
  // EXPORT
  // =========================================================================
  
  Future<String> exportToCsv({
    required String userRole, String? userFungsi, String? userId,
    String? bulan, String? statusFilter, bool includeHSSE = false,
  }) async {
    try {
      List<OvertimeHistory> allData = [];
      if (userRole == 'mitra' && userId != null) {
        allData = (await _firestore.collection(collectionLemburMitra).where('mitra_id', isEqualTo: userId).get()).docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      } else if (userRole == 'pengawas' && userId != null) {
        allData = (await _firestore.collection(collectionLemburMitra).where('diajukan_oleh_id', isEqualTo: userId).get()).docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      } else if (userRole == 'manager') {
        Query<Map<String, dynamic>> query = _firestore.collection(collectionPengajuan);
        if (userFungsi != null && userFungsi.isNotEmpty) query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        allData = (await query.get()).docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      } else {
        final results = await Future.wait([_firestore.collection(collectionPengajuan).get(), _firestore.collection(collectionLemburMitra).get()]);
        allData = _removeDuplicates([...results[0].docs.map((doc) => OvertimeHistory.fromFirestore(doc)), ...results[1].docs.map((doc) => OvertimeHistory.fromFirestore(doc))]);
      }
      allData = _filterByBulan(allData, bulan);
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        allData = allData.where((item) => item.status == statusFilter).toList();
      }
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      final csvBuffer = StringBuffer();
      List<String> headers = ['No', 'Tanggal', 'Nama', 'Jam Mulai', 'Jam Selesai', 'Total Jam', 'Status', 'Biaya', 'Fungsi', 'Jenis Lembur', 'Urgensi'];
      if (includeHSSE) headers.addAll(['HSSE Status', 'Risiko Level', 'Risiko Kategori', 'HSSE Oleh', 'HSSE Catatan']);
      csvBuffer.writeln(headers.join(','));
      for (var i = 0; i < allData.length; i++) {
        final item = allData[i];
        csvBuffer.writeln([
          i + 1, DateFormat('dd/MM/yyyy').format(item.tanggal),
          '"${item.namaMitra ?? item.namaPengawas ?? '-'}"', item.jamMulai, item.jamSelesai,
          item.totalJam.toStringAsFixed(1), item.status.toUpperCase(),
          (item.estimasiBiayaTotal > 0 ? item.estimasiBiayaTotal : item.estimasiBiayaPerMitra).toStringAsFixed(0),
          item.pengawasFungsi ?? '-', item.jenisLembur, item.urgensi,
          if (includeHSSE) ...[item.hsseStatus.toUpperCase(), item.risikoLevel ?? '-', item.risikoKategori ?? '-', item.hsseApprovedByName ?? item.hsseRejectedByName ?? '-', '"${item.hsseCatatan ?? '-'}"'],
        ].join(','));
      }
      return csvBuffer.toString();
    } catch (e) { rethrow; }
  }

  Future<String> exportHSSEToCsv({String? bulan, String? hsseStatus}) async {
    try {
      final mitraDocs = await _firestore.collection(collectionLemburMitra)
          .where('status', whereIn: [...hssePendingStatuses, ...hsseResolvedStatuses])
          .get();
      var allData = mitraDocs.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _filterByBulan(allData, bulan);
      if (hsseStatus != null && hsseStatus.isNotEmpty) allData = allData.where((item) => item.hsseStatus == hsseStatus).toList();
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('No,Tanggal,Pengaju,Fungsi,Risiko Level,Kategori,Status,HSSE Status,Biaya,Disetujui Oleh,Tanggal Persetujuan,Catatan HSSE');
      for (var i = 0; i < allData.length; i++) {
        final item = allData[i];
        csvBuffer.writeln([i + 1, DateFormat('dd/MM/yyyy').format(item.tanggal), '"${item.namaPengaju}"', item.pengawasFungsi ?? '-', item.risikoLevelLabel, item.risikoKategori ?? '-', item.status.toUpperCase(), item.hsseStatus.toUpperCase(), item.estimasiBiayaTotal, item.hsseApprovedByName ?? '-', item.hsseApprovedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(item.hsseApprovedAt!) : '-', '"${item.hsseCatatan ?? '-'}"'].join(','));
      }
      return csvBuffer.toString();
    } catch (e) { rethrow; }
  }

  // =========================================================================
  // HSSE ACTIVITY LOGS STREAM
  // =========================================================================

  Stream<List<Map<String, dynamic>>> getHSSEActivityLogs({String? userId, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionHSSELogs).orderBy('timestamp', descending: true).limit(limit);
    if (userId != null && userId.isNotEmpty) query = query.where('user_id', isEqualTo: userId);
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, ...data, 'timestamp': (data['timestamp'] as Timestamp?)?.toDate()};
    }).toList());
  }

  // =========================================================================
  // LOGGING HELPERS
  // =========================================================================
  
  Future<void> _logActivity({required String action, required String documentId, required String userId, String? details}) async {
    try {
      await _firestore.collection(collectionActivityLogs).add({
        'action': action, 'document_id': documentId, 'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(), 'details': details,
      });
    } catch (e) { debugPrint('⚠️ Error logging activity: $e'); }
  }

  Future<void> _logHSSEActivity({required String action, required String documentId, required String userId, String? userName, String? details, String? catatan}) async {
    try {
      await _firestore.collection(collectionHSSELogs).add({
        'action': action, 'document_id': documentId, 'user_id': userId,
        'user_name': userName, 'timestamp': FieldValue.serverTimestamp(),
        'details': details, 'catatan': catatan,
      });
    } catch (e) { debugPrint('⚠️ Error logging HSSE activity: $e'); }
  }

  Future<void> _createSafetyBriefing({required String documentId, String? groupId, required String hssId, String? hssName}) async {
    try {
      await _firestore.collection(collectionSafetyBriefing).add({
        'document_id': documentId, 'group_id': groupId, 'created_by': hssId,
        'created_by_name': hssName, 'status': 'pending', 'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('⚠️ Error creating safety briefing: $e'); }
  }

  // =========================================================================
// 🔥 METHOD UNTUK REPORT PAGE - TAMBAHKAN INI!
// =========================================================================

/// Get status label untuk display
String getStatusText(String status) {
  switch (status) {
    case 'pending': return 'Pending';
    case 'disetujui': return 'Disetujui';
    case 'ditolak': return 'Ditolak';
    case 'selesai': return 'Selesai';
    case 'dibatalkan': return 'Dibatalkan';
    case 'kadaluarsa': return 'Kadaluarsa';
    default: return status;
  }
}

/// Get status color untuk UI
Color getStatusColor(String status) {
  switch (status) {
    case 'pending': return Colors.orange;
    case 'disetujui': return Colors.green;
    case 'selesai': return Colors.blue;
    case 'ditolak': return Colors.red;
    case 'dibatalkan': return Colors.grey;
    case 'kadaluarsa': return Colors.redAccent;
    default: return Colors.grey;
  }
}

/// Format Rupiah dengan aman
String formatRupiah(dynamic value) {
  final number = (value is num) ? value : 0;
  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return formatter.format(number);
}

/// Update status overtime (approve/reject)
Future<Map<String, dynamic>> updateOvertimeStatus({
  required String docId,
  required String status,
  String? note,
}) async {
  try {
    final doc = await _findDocument(docId);
    if (doc == null) {
      return {'success': false, 'message': 'Dokumen tidak ditemukan'};
    }

    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
      'last_modified_at': FieldValue.serverTimestamp(),
    };

    if (status == 'disetujui') {
      updateData['approved_at'] = FieldValue.serverTimestamp();
      updateData['approved_by'] = 'system';
      updateData['approved_by_name'] = 'System';
    } else if (status == 'ditolak' && note != null) {
      updateData['rejected_reason'] = note;
      updateData['rejected_at'] = FieldValue.serverTimestamp();
      updateData['rejected_by'] = 'system';
      updateData['rejected_by_name'] = 'System';
    }

    await doc.reference.update(updateData);

    // Sync ke group jika ada
    final data = doc.data()!;
    final groupId = data['group_id'] as String?;
    if (groupId != null && groupId.isNotEmpty) {
      final otherCollection = doc.reference.parent.id == collectionLemburMitra 
          ? collectionPengajuan 
          : collectionLemburMitra;
      final otherDocs = await _firestore
          .collection(otherCollection)
          .where('group_id', isEqualTo: groupId)
          .get();
      for (var d in otherDocs.docs) {
        await d.reference.update(updateData);
      }
    }

    await _logActivity(
      action: 'update_status',
      documentId: docId,
      userId: 'system',
      details: 'Status diubah menjadi $status${note != null ? ' - $note' : ''}',
    );

    return {'success': true, 'message': 'Status berhasil diupdate'};
  } catch (e) {
    return {'success': false, 'message': 'Gagal update status: ${e.toString()}'};
  }
}
}