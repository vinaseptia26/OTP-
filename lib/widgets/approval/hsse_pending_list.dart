// lib/widgets/approval/hsse_pending_list.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/overtime_rate_service.dart';

class HSSEPendingList extends StatefulWidget {
  final String searchQuery;
  final String? fungsiFilter;
  final bool isDarkMode;
  final Function(String) onTap;
  final Function(String) onHSSEApprove;
  final Function(String) onHSSEReject;

  const HSSEPendingList({
    super.key,
    required this.searchQuery,
    this.fungsiFilter,
    required this.isDarkMode,
    required this.onTap,
    required this.onHSSEApprove,
    required this.onHSSEReject,
  });

  @override
  State<HSSEPendingList> createState() => _HSSEPendingListState();
}

class _HSSEPendingListState extends State<HSSEPendingList> {
  // ============ STATIC CACHE ============
  static final _rateService = OvertimeRateService();
  static final _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final Map<String, String> _fungsiLabelCache = {};
  static final Map<String, Color> _fungsiColorCache = {};

  // 🔥 ALL PENDING HSSE STATUSES
  static const List<String> _pendingHSSEStatuses = [
    'pending_hsse',
    'manager_approval_pending_hsse',
  ];

  // ============ FILTERED CACHE ============
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs = [];
  String _lastSearchQuery = '';
  String? _lastFungsiFilter;

  @override
  Widget build(BuildContext context) {
    // 🔥 FIX: Gunakan whereIn untuk menangkap semua variasi status
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('pengajuan_lembur')
        .where('status', whereIn: _pendingHSSEStatuses)
        .orderBy('created_at', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting &&
            _filteredDocs.isEmpty) {
          return _buildLoadingState();
        }

        // Error
        if (snapshot.hasError) {
          debugPrint('❌ HSSE Pending List Error: ${snapshot.error}');
          return _buildErrorState();
        }

        final docs = snapshot.data?.docs ?? [];

        debugPrint(
            '📊 HSSE Pending Stream: ${docs.length} documents found');

        // Empty
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        // 🔥 Filter cuma kalo search/filter berubah
        if (widget.searchQuery != _lastSearchQuery ||
            widget.fungsiFilter != _lastFungsiFilter) {
          _lastSearchQuery = widget.searchQuery;
          _lastFungsiFilter = widget.fungsiFilter;
          _filteredDocs = _applyFilter(docs);
          debugPrint(
              '🔍 Filtered: ${_filteredDocs.length}/${docs.length} documents');
        }

        if (_filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _filteredDocs.map((doc) {
                    final data = doc.data();
                    final groupId = doc.id;
                    data['group_id'] = groupId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHSSECard(data, groupId),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============ FILTER LOGIC ============
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      // 🔥 Filter HSSE-related hanya jika diperlukan
      if (!_isHSSERelated(data)) {
        return false;
      }

      // Search filter
      if (widget.searchQuery.isNotEmpty) {
        final query = widget.searchQuery.toLowerCase();
        final nama =
            (data['nama_pengawas'] ?? '').toString().toLowerCase();
        final groupId = doc.id.toLowerCase();
        final fungsi =
            (data['pengawas_fungsi'] ?? '').toString().toLowerCase();

        if (!nama.contains(query) &&
            !groupId.contains(query) &&
            !fungsi.contains(query)) {
          return false;
        }
      }

      // Fungsi filter
      if (widget.fungsiFilter != null &&
          widget.fungsiFilter!.isNotEmpty &&
          widget.fungsiFilter != 'semua') {
        final pengawasFungsi =
            (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
        if (pengawasFungsi != widget.fungsiFilter!.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // 🔥 Helper: Cek apakah data terkait HSSE
  bool _isHSSERelated(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';

    // Status mengandung pending_hsse
    if (_pendingHSSEStatuses.any((s) => status.contains(s))) {
      return true;
    }

    // Field requires_hsse_approval
    if (data['requires_hsse_approval'] == true) {
      return true;
    }

    // Field need_hsse_confirmation
    if (data['need_hsse_confirmation'] == true) {
      return true;
    }

    // Risk level high/critical
    final riskLevel =
        (data['risk_level'] ?? data['risk_assessment']?['kategori_risiko'])
            ?.toString()
            .toLowerCase() ??
        '';
    if (riskLevel == 'high' ||
        riskLevel == 'critical' ||
        riskLevel == 'tinggi') {
      return true;
    }

    return false;
  }

  // ============ HSSE CARD ============
  Widget _buildHSSECard(Map<String, dynamic> data, String groupId) {
    // 🔥 Ambil risk level dari berbagai sumber
    final riskAssessment =
        data['risk_assessment'] as Map<String, dynamic>? ?? {};
    final riskLevel = (data['risk_level'] ??
            riskAssessment['kategori_risiko'] ??
            'medium')
        .toString()
        .toLowerCase();

    final riskFactors =
        (data['risk_factors'] as List?)?.cast<String>() ?? [];

    final fungsiApproval =
        data['fungsi_approval'] as Map<String, dynamic>? ?? {};

    final totalBiaya = (data['estimasi_biaya_total'] ?? 0).toDouble();
    final totalMitra = data['total_mitra'] ?? 0;
    final totalJam = (data['total_jam_desimal'] ?? 0).toDouble();

    // 🔥 Format tanggal & waktu
    String tanggalStr = '-';
    String waktuStr = '-';
    if (data['tanggal_lembur'] is Timestamp) {
      try {
        final date = (data['tanggal_lembur'] as Timestamp).toDate();
        tanggalStr = _dateFormatter.format(date);
        waktuStr =
            '${data['jam_mulai'] ?? '-'} - ${data['jam_selesai'] ?? '-'}';
      } catch (_) {}
    } else if (data['tanggal'] is Timestamp) {
      try {
        final date = (data['tanggal'] as Timestamp).toDate();
        tanggalStr = _dateFormatter.format(date);
        waktuStr =
            '${data['jam_mulai'] ?? '-'} - ${data['jam_selesai'] ?? '-'}';
      } catch (_) {}
    }

    final riskColor = _getRiskColor(riskLevel);
    final riskEmoji = _getRiskEmoji(riskLevel);
    final riskLabel = _getRiskLabel(riskLevel);
    final fungsiColor = _getFungsiColorCached(data['pengawas_fungsi']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap(groupId),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.isDarkMode
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                riskColor.withValues(alpha: widget.isDarkMode ? 0.05 : 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: riskColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: riskColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 RISK LEVEL HEADER
              _buildRiskHeader(riskColor, riskEmoji, riskLabel, riskFactors),

              // 🔥 CONTENT
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pengawas Info
                    _buildPengawasRow(data, fungsiColor),
                    const SizedBox(height: 14),

                    // Info Grid
                    _buildInfoGrid(tanggalStr, waktuStr, totalJam),
                    const SizedBox(height: 10),

                    // Biaya & Approval Flow
                    _buildBiayaApprovalRow(
                        totalBiaya, fungsiApproval, data),
                    const SizedBox(height: 12),

                    // Action Buttons
                    _buildActionButtons(groupId, riskColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ RISK HEADER ============
  Widget _buildRiskHeader(
    Color riskColor,
    String riskEmoji,
    String riskLabel,
    List<String> riskFactors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            riskColor.withValues(alpha: 0.15),
            riskColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(
          bottom: BorderSide(
            color: riskColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Risk Emoji
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(riskEmoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          // Risk Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Validasi Risiko $riskLabel',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
                if (riskFactors.isNotEmpty)
                  Text(
                    riskFactors.take(2).join(' • '),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: riskColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Risk Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              riskLabel.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ PENGAWAS ROW ============
  Widget _buildPengawasRow(Map<String, dynamic> data, Color fungsiColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [fungsiColor, fungsiColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              (data['nama_pengawas'] ?? 'U')[0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Nama & Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['nama_pengawas'] ?? 'Unknown',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.business, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _getFungsiLabelCached(data['pengawas_fungsi']),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.people_outline,
                      size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${data['total_mitra'] ?? 0} mitra',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ INFO GRID ============
  Widget _buildInfoGrid(String tanggalStr, String waktuStr, double totalJam) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF0A0E21)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode
              ? Colors.grey[800]!
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoColumn(
                Icons.calendar_today_rounded, tanggalStr, 'Tanggal'),
          ),
          _buildDivider(),
          Expanded(
            child: _buildInfoColumn(
                Icons.access_time_rounded, waktuStr, 'Waktu'),
          ),
          _buildDivider(),
          Expanded(
            child: _buildInfoColumn(
                Icons.timer_outlined, '${totalJam.toStringAsFixed(1)} jam', 'Durasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? Colors.white70
                  : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  // ============ BIAYA & APPROVAL ROW ============
  Widget _buildBiayaApprovalRow(
    double totalBiaya,
    Map<String, dynamic> fungsiApproval,
    Map<String, dynamic> data,
  ) {
    return Row(
      children: [
        // Biaya Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                _rateService.formatRupiahCompact(totalBiaya),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Approval Flow Dots
        _buildApprovalDot(
          'Fungsi',
          fungsiApproval['status_fungsi'] == 'disetujui',
          fungsiApproval['fungsi_manager_name']
                  ?.toString()
                  .split(' ')
                  .first ??
              'Mgr',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child:
              Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey[400]),
        ),
        _buildApprovalDot('HSSE', false, 'Anda', isActive: true),
      ],
    );
  }

  Widget _buildApprovalDot(String label, bool isDone, String name,
      {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.green.withValues(alpha: 0.1)
                : isActive
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
            border: Border.all(
              color: isDone
                  ? Colors.green
                  : isActive
                      ? Colors.orange
                      : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.green)
                : isActive
                    ? const Icon(Icons.hourglass_top,
                        size: 14, color: Colors.orange)
                    : const Icon(Icons.circle_outlined,
                        size: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.orange : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 7,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // ============ ACTION BUTTONS ============
  Widget _buildActionButtons(String groupId, Color riskColor) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => widget.onHSSEReject(groupId),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.close_rounded, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Tolak',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () => widget.onHSSEApprove(groupId),
            style: ElevatedButton.styleFrom(
              backgroundColor: riskColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Validasi K3',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============ STATES ============
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data K3...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal Memuat Data K3',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Periksa koneksi dan pastikan data tersedia',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.health_and_safety,
                  size: 40,
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Semua Aman ✅',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isDarkMode
                      ? Colors.white70
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.searchQuery.isNotEmpty
                    ? 'Tidak ada hasil untuk "${widget.searchQuery}"'
                    : 'Tidak ada pengajuan yang memerlukan\nvalidasi risiko K3 saat ini',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Semua risiko telah tervalidasi',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ UTILITY (CACHED) ============
  String _getFungsiLabelCached(String? f) {
    final key = f?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation':
        return 'Operation';
      case 'lab':
        return 'Laboratorium';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'BS';
      default:
        return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }

  Color _getFungsiColorCached(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiColorCache[key] ??= _computeFungsiColor(key);
  }

  Color _computeFungsiColor(String fungsi) {
    switch (fungsi) {
      case 'operation':
        return const Color(0xFF1976D2);
      case 'lab':
        return const Color(0xFF4CAF50);
      case 'maintenance':
        return const Color(0xFFFF9800);
      case 'hsse':
        return const Color(0xFF9C27B0);
      case 'gpr':
        return const Color(0xFFEF4444);
      case 'bs':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF757575);
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
      case 'tinggi':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'sedang':
        return const Color(0xFFF59E0B);
      case 'low':
      case 'rendah':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getRiskEmoji(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return '🔴';
      case 'high':
      case 'tinggi':
        return '🟠';
      case 'medium':
      case 'sedang':
        return '🟡';
      case 'low':
      case 'rendah':
        return '🟢';
      default:
        return '⚪';
    }
  }

  String _getRiskLabel(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return 'Kritis';
      case 'high':
      case 'tinggi':
        return 'Tinggi';
      case 'medium':
      case 'sedang':
        return 'Sedang';
      case 'low':
      case 'rendah':
        return 'Rendah';
      default:
        return 'Normal';
    }
  }
}