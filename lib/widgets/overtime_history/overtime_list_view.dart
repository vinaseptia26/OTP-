// lib/widgets/overtime_history/overtime_list_view.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import 'overtime_card.dart';

class OvertimeListView extends StatelessWidget {
  final OvertimeHistoryService historyService;
  final OvertimeRateService rateService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String? userName;
  final String selectedBulan;
  final String selectedStatus;
  final Function(String)? onBatalkanPengajuan;

  // 🔥 HSSE Support
  final bool showRiskyOnly;
  final List<OvertimeHistory>? hssData;
  final bool showHSSEStatus;
  final bool showApprovalActions;

  // 🔥 Filter HSSE untuk Manager
  final String? selectedHSSEStatus;
  final String? selectedRisikoLevel;

  const OvertimeListView({
    super.key,
    required this.historyService,
    required this.rateService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    this.userName,
    required this.selectedBulan,
    required this.selectedStatus,
    this.onBatalkanPengajuan,
    this.showRiskyOnly = false,
    this.hssData,
    this.showHSSEStatus = false,
    this.showApprovalActions = true,
    this.selectedHSSEStatus,
    this.selectedRisikoLevel,
  });

  // =========================================================================
  // 🔥 HELPER: Deteksi status HSSE yang sebenarnya
  // Karena field `hsse_status` mungkin belum di-set oleh service approval,
  // kita fallback ke field lain yang udah pasti ada.
  // =========================================================================
  String _getActualHSSEStatus(OvertimeHistory item) {
    // 1. Cek hsse_status dulu (kalau udah di-set)
    if (item.hsseStatus == 'disetujui' ||
        item.hsseStatus == 'ditolak' ||
        item.hsseStatus == 'perlu_revisi' ||
        item.hsseStatus == 'dalam_review') {
      return item.hsseStatus;
    }

    // 2. Fallback: cek hsse_approved_by + hsse_approved_at
    if (item.hsseApprovedBy != null && item.hsseApprovedAt != null) {
      return 'disetujui';
    }

    // 3. Fallback: cek hsse_rejected_by + hsse_rejected_at
    if (item.hsseRejectedBy != null && item.hsseRejectedAt != null) {
      return 'ditolak';
    }

    // 4. Fallback: cek hsse_review_by
    if (item.hsseReviewBy != null) {
      return 'dalam_review';
    }

    // 5. Fallback: cek status utama dokumen
    if (item.status == 'disetujui') return 'disetujui';
    if (item.status == 'ditolak') return 'ditolak';

    // 6. Default: pending
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final isHSSE = userFungsi == 'hsse';
    final isHSSEManager = userRole == 'manager' && isHSSE;

    // ── 🔥 KHUSUS HSSE MANAGER ──
    if (isHSSEManager) {
      return StreamBuilder<List<OvertimeHistory>>(
        stream: historyService.getHSSEManagerHistoryStream(
          bulan: selectedBulan.isNotEmpty ? selectedBulan : null,
          statusFilter: selectedStatus != 'semua' ? selectedStatus : null,
          hsseStatus: selectedHSSEStatus,
          risikoLevel: selectedRisikoLevel,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorWidget(context, snapshot.error.toString());
          }
          final items = snapshot.data ?? [];
          return _buildListView(context, items, isHSSE: true);
        },
      );
    }

    // ── 🔥 HSSE mode risky only dengan pre-filtered data ──
    if (showRiskyOnly && hssData != null) {
      return _buildListView(context, hssData!, isHSSE: true);
    }

    // ── 🔥 HSSE mode risky only tanpa pre-filtered data ──
    if (showRiskyOnly && isHSSE) {
      return StreamBuilder<List<OvertimeHistory>>(
        stream: historyService.getHSSERiskyOvertimeStream(
          bulan: selectedBulan.isNotEmpty ? selectedBulan : null,
          statusFilter: selectedStatus != 'semua' ? selectedStatus : null,
          hsseStatus: selectedHSSEStatus,
          risikoLevel: selectedRisikoLevel,
          hsseUserId: userId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorWidget(context, snapshot.error.toString());
          }
          final items = snapshot.data ?? [];
          return _buildListView(context, items, isHSSE: true);
        },
      );
    }

    // ── Mode normal ──
    return StreamBuilder<List<OvertimeHistory>>(
      stream: historyService.getOvertimeHistoryStream(
        userRole: userRole,
        userFungsi: userFungsi,
        userId: userId,
        bulan: selectedBulan.isNotEmpty ? selectedBulan : null,
        statusFilter: selectedStatus != 'semua' ? selectedStatus : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorWidget(context, snapshot.error.toString());
        }
        final items = snapshot.data ?? [];
        return _buildListView(context, items);
      },
    );
  }

  // 🔥 Widget error
  Widget _buildErrorWidget(BuildContext context, String error) {
    String displayMessage = error;
    if (error.contains('failed-precondition') || error.contains('index')) {
      displayMessage = 'Memerlukan konfigurasi database.\nSilakan hubungi admin.';
    } else if (error.length > 150) {
      displayMessage = '${error.substring(0, 150)}...';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Gagal Memuat Data', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(displayMessage, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => (context as Element).markNeedsBuild(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Build list view utama
  Widget _buildListView(BuildContext context, List<OvertimeHistory> items, {bool isHSSE = false}) {
    if (items.isEmpty) return _buildEmptyState(context, isHSSE);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (isHSSE) {
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildHSSECard(context, item));
        }
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildNormalCard(context, item));
      },
    );
  }

  // 🔥 Empty state
  Widget _buildEmptyState(BuildContext context, bool isHSSE) {
    final isHSSEManager = userRole == 'manager' && userFungsi == 'hsse';
    final screenHeight = MediaQuery.of(context).size.height;
    String title, subtitle;
    IconData icon;

    if (isHSSEManager) {
      if (selectedHSSEStatus == 'pending') {
        title = 'Tidak Ada Pengajuan\nMenunggu Validasi';
        subtitle = 'Semua pengajuan berisiko telah divalidasi';
        icon = Icons.check_circle_outline;
      } else {
        title = 'Tidak Ada Pengajuan HSSE';
        subtitle = 'Semua pengajuan telah diproses';
        icon = Icons.verified_user;
      }
    } else if (isHSSE) {
      title = 'Tidak Ada Pengajuan Berisiko';
      subtitle = 'Semua pengajuan aman dan terkendali';
      icon = Icons.verified_user;
    } else {
      title = 'Belum Ada Pengajuan';
      subtitle = 'Silakan ajukan lembur jika diperlukan';
      icon = Icons.inbox_outlined;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: screenHeight * 0.08, color: Colors.grey.shade300),
            SizedBox(height: screenHeight * 0.02),
            Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400, height: 1.4), textAlign: TextAlign.center),
            if (userRole == 'pengawas' && !isHSSE) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ajukan-lembur'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajukan Lembur'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 Build card normal
  Widget _buildNormalCard(BuildContext context, OvertimeHistory item) {
    final canCancel = _canCancelPengajuan(item);
    final isExpired = _isExpired(item.createdAt, item.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OvertimeCard(item: item, rateService: rateService, userId: userId, userName: userName, userRole: userRole, showHSSEInfo: showHSSEStatus),
        if (canCancel && (userRole == 'pengawas' || userRole == 'mitra')) _buildCancelButton(context, item, isExpired),
      ],
    );
  }

  // 🔥 Build card HSSE
  Widget _buildHSSECard(BuildContext context, OvertimeHistory item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRisikoBadge(item),
        OvertimeCard(item: item, rateService: rateService, userId: userId, userName: userName, userRole: userRole, showHSSEInfo: true),
        _buildHSSEInfoFooter(item),
      ],
    );
  }

  // 🔥 Badge risiko — DIPERBAIKI dengan fallback status
  Widget _buildRisikoBadge(OvertimeHistory item) {
    final actualStatus = _getActualHSSEStatus(item);
    final shouldShow = item.isRisky || userFungsi == 'hsse' || showHSSEStatus;
    if (!shouldShow) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.isRisky ? item.risikoLevelColor.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: item.isRisky ? item.risikoLevelColor.withValues(alpha: 0.3) : Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        children: [
          if (item.isRisky) ...[
            Icon(item.risikoLevelIcon, size: 14, color: item.risikoLevelColor),
            const SizedBox(width: 4),
            Flexible(child: Text(item.risikoLevelLabel.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: item.risikoLevelColor), overflow: TextOverflow.ellipsis)),
            if (item.risikoKategori != null) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: item.risikoLevelColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(item.risikoKategori!, style: GoogleFonts.poppins(fontSize: 10, color: item.risikoLevelColor, fontWeight: FontWeight.w500))),
            ],
          ] else if (actualStatus == 'pending') ...[
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('PERLU VALIDASI HSSE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          ],
          const Spacer(),
          _buildHSSEStatusBadge(item),
        ],
      ),
    );
  }

  // 🔥 Badge status HSSE — DIPERBAIKI dengan fallback status
  Widget _buildHSSEStatusBadge(OvertimeHistory item) {
    final actualStatus = _getActualHSSEStatus(item);
    String label; Color color; IconData icon;

    switch (actualStatus) {
      case 'pending': label = 'PENDING'; color = Colors.orange; icon = Icons.schedule; break;
      case 'disetujui': label = 'APPROVED'; color = Colors.green; icon = Icons.check_circle; break;
      case 'ditolak': label = 'REJECTED'; color = Colors.red; icon = Icons.cancel; break;
      case 'perlu_revisi': label = 'REVISI'; color = Colors.amber.shade700; icon = Icons.edit_note; break;
      case 'dalam_review': label = 'REVIEW'; color = Colors.blue; icon = Icons.visibility; break;
      default: return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color), const SizedBox(width: 3),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
      ]),
    );
  }

  // 🔥 Footer info HSSE — DIPERBAIKI dengan fallback status
  Widget _buildHSSEInfoFooter(OvertimeHistory item) {
    final actualStatus = _getActualHSSEStatus(item);

    if (actualStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: Colors.orange.shade200, width: 0.5)),
        child: Row(children: [
          Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700), const SizedBox(width: 6),
          Expanded(child: Text('⏳ Menunggu validasi oleh Manager HSSE', style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    if (actualStatus == 'disetujui') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: Colors.green.shade200, width: 0.5)),
        child: Row(children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700), const SizedBox(width: 6),
          Expanded(child: Text('✅ Disetujui HSSE${item.hsseApprovedByName != null ? ' oleh: ${item.hsseApprovedByName}' : ''}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    if (actualStatus == 'ditolak') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: Colors.red.shade200, width: 0.5)),
        child: Row(children: [
          Icon(Icons.cancel, size: 14, color: Colors.red.shade700), const SizedBox(width: 6),
          Expanded(child: Text('❌ Ditolak HSSE${item.hsseRejectedByName != null ? ' oleh: ${item.hsseRejectedByName}' : ''}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade800, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    if (actualStatus == 'perlu_revisi') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: Colors.amber.shade200, width: 0.5)),
        child: Row(children: [
          Icon(Icons.edit_note, size: 14, color: Colors.amber.shade700), const SizedBox(width: 6),
          Expanded(child: Text('📝 ${item.hsseCatatanRevisi ?? 'Perlu revisi dari HSSE'}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    if (actualStatus == 'dalam_review') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: Colors.blue.shade200, width: 0.5)),
        child: Row(children: [
          Icon(Icons.visibility, size: 14, color: Colors.blue.shade700), const SizedBox(width: 6),
          Expanded(child: Text('🔍 Sedang dalam review oleh HSSE', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    return const SizedBox(height: 2);
  }

  // 🔥 Tombol batalkan
  Widget _buildCancelButton(BuildContext context, OvertimeHistory item, bool isExpired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isExpired ? Colors.red.shade50 : Colors.orange.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border.all(color: isExpired ? Colors.red.shade200 : Colors.orange.shade200, width: 0.5)),
      child: Row(children: [
        Icon(isExpired ? Icons.warning_amber_rounded : Icons.info_outline, size: 16, color: isExpired ? Colors.red.shade700 : Colors.orange.shade700),
        const SizedBox(width: 6),
        Expanded(child: Text(isExpired ? 'Pengajuan kedaluwarsa' : 'Dapat dibatalkan', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: isExpired ? Colors.red.shade700 : Colors.orange.shade700))),
        const SizedBox(width: 6),
        SizedBox(height: 28, child: ElevatedButton.icon(
          onPressed: () => onBatalkanPengajuan?.call(item.id),
          icon: const Icon(Icons.cancel_outlined, size: 14),
          label: Text('Batal', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(backgroundColor: isExpired ? Colors.red.shade600 : Colors.orange.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
        )),
      ]),
    );
  }

  bool _canCancelPengajuan(OvertimeHistory item) {
    if (userRole != 'mitra' && userRole != 'pengawas') return false;
    return item.canBeCancelled;
  }

  bool _isExpired(DateTime? createdAt, String status) {
    if (createdAt == null) return false;
    if (status != 'pending' && status != 'disetujui') return false;
    return DateTime.now().difference(createdAt).inDays > OvertimeHistoryService.batasWaktuPembatalan;
  }
}