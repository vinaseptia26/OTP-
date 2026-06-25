// lib/widgets/overtime_history/overtime_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/overtime_history/overtime_detail_sheet.dart';
import '/widgets/overtime_history/overtime_helpers.dart';

class OvertimeCard extends StatelessWidget {
  final OvertimeHistory item;
  final OvertimeRateService rateService;
  final String? userId;
  final String? userName;
  final String? userRole;
  
  // 🔥 Parameter untuk menampilkan info HSSE
  final bool showHSSEInfo;

  const OvertimeCard({
    super.key,
    required this.item,
    required this.rateService,
    this.userId,
    this.userName,
    this.userRole,
    this.showHSSEInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OvertimeHelpers.getStatusColor(item.status);
    final isUrgent = item.urgensi == 'kritis' || item.urgensi == 'tinggi';

    // ✅ Biaya ditampilkan sesuai tipe dokumen
    final biayaTampil = item.isMitraDocument
        ? item.estimasiBiayaPerMitra
        : item.estimasiBiayaTotal;

    // 🔥 Cek apakah konten card akan panjang
    final hasHSSEContent = showHSSEInfo && item.isRisky;
    final hasSpklContent = item.spklGenerated && item.status == 'disetujui';
    final hasExtraContent = hasHSSEContent || hasSpklContent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent ? Colors.red.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => OvertimeDetailSheet.show(
          context,
          item,
          rateService,
          userId,
          userName,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isUrgent
                ? LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.03),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          constraints: BoxConstraints(
            maxHeight: hasExtraContent ? 400 : 250,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  _buildHeader(context, statusColor),
                  const SizedBox(height: 12),
                  
                  // 🔥 HSSE INFO SECTION
                  if (hasHSSEContent) ...[
                    _buildHSSEInfoSection(),
                    const SizedBox(height: 12),
                  ],
                  
                  // INFO CHIPS
                  _buildInfoChips(isUrgent: isUrgent),
                  const SizedBox(height: 12),
                  
                  // DIVIDER
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 10),
                  
                  // COST ROW
                  _buildCostRow(biayaTampil),
                  
                  // SPKL INDICATOR
                  if (hasSpklContent) ...[
                    const SizedBox(height: 10),
                    _buildSpklIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 HSSE INFO SECTION
  // =========================================================================

  Widget _buildHSSEInfoSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.risikoLevelColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.risikoLevelColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header HSSE
          Row(
            children: [
              Icon(
                Icons.security,
                size: 14,
                color: item.risikoLevelColor,
              ),
              const SizedBox(width: 6),
              Text(
                'HSSE Assessment',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.risikoLevelColor,
                ),
              ),
              const Spacer(),
              // Risiko Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.risikoLevelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.risikoLevelIcon, size: 10, color: item.risikoLevelColor),
                    const SizedBox(width: 3),
                    Text(
                      item.risikoLevelLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: item.risikoLevelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Risiko Kategori
          if (item.risikoKategori != null) ...[
            _buildHSSEDetailRow(
              Icons.category_outlined,
              'Kategori',
              item.risikoKategori!,
            ),
            const SizedBox(height: 4),
          ],
          
          // Risiko Deskripsi (truncated)
          if (item.risikoDeskripsi != null && item.risikoDeskripsi!.isNotEmpty) ...[
            _buildHSSEDetailRow(
              Icons.description_outlined,
              'Deskripsi',
              item.risikoDeskripsi!.length > 80 
                  ? '${item.risikoDeskripsi!.substring(0, 80)}...' 
                  : item.risikoDeskripsi!,
            ),
            const SizedBox(height: 4),
          ],
          
          // Mitigasi (jika ada)
          if (item.risikoMitigasi != null && item.risikoMitigasi!.isNotEmpty) ...[
            _buildHSSEDetailRow(
              Icons.shield_outlined,
              'Mitigasi',
              '${item.risikoMitigasi!.length} langkah',
            ),
            const SizedBox(height: 4),
          ],
          
          // HSSE Status
          _buildHSSEDetailRow(
            Icons.track_changes,
            'Status HSSE',
            item.hsseStatusLabel,
            valueColor: item.hsseStatusColor,
          ),
          
          // HSSE Catatan (jika ada)
          if (item.hsseCatatan != null && item.hsseCatatan!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.hsseCatatan!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tombol Safety Briefing (jika diperlukan)
          if (item.hsseSafetyBriefing && !item.hsseSafetyBriefingDate.hasValue) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.safety_check, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Safety Briefing Diperlukan',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHSSEDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: valueColor ?? Colors.grey[800],
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================

  Widget _buildHeader(BuildContext context, Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        GestureDetector(
          onTap: item.pengawasId != null && item.pengawasId!.isNotEmpty
              ? () => context.push('/user-detail/${item.pengawasId}')
              : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OvertimeHelpers.getFungsiColor(item.pengawasFungsi).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isMultiple ? Icons.group : Icons.person,
              color: OvertimeHelpers.getFungsiColor(item.pengawasFungsi),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Title & Badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title + Badges
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _getCardTitle(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (item.spklGenerated && item.status == 'disetujui')
                    _buildMiniBadge('SPKL', Colors.blue),
                  // 🔥 HSSE Badge
                  if (showHSSEInfo && item.isRisky)
                    _buildMiniBadge('HSSE', item.risikoLevelColor),
                  const SizedBox(width: 4),
                  _buildStatusBadge(statusColor),
                ],
              ),
              const SizedBox(height: 4),
              
              // Row 2: Tanggal & Jam
              GestureDetector(
                onTap: () => context.push('/overtime-detail/${item.id}'),
                child: Text(
                  '${DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal)} • ${item.jamMulai} - ${item.jamSelesai}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCardTitle() {
    if (item.isMultiple) return 'Lembur Grup (${item.totalMitra} mitra)';
    if (item.namaMitra != null && item.namaMitra!.isNotEmpty) return item.namaMitra!;
    if (item.namaPengawas != null && item.namaPengawas!.isNotEmpty) return item.namaPengawas!;
    return 'Unknown';
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        OvertimeHelpers.getStatusText(item.status),
        style: GoogleFonts.poppins(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =========================================================================
  // INFO CHIPS
  // =========================================================================

  Widget _buildInfoChips({required bool isUrgent}) {
    final chips = <Widget>[];

    // Priority 1: Urgent
    if (isUrgent) {
      chips.add(_InfoChip(icon: Icons.warning_rounded, label: 'Urgent', color: Colors.red));
    }

    // Priority 2: Time & Type
    chips.add(_InfoChip(icon: Icons.access_time, label: '${item.totalJam.toStringAsFixed(1)} jam'));
    chips.add(_InfoChip(icon: Icons.work_outline, label: _getJenisLemburLabel()));

    // Priority 3: Location
    if (item.lokasi.isNotEmpty) {
      final lokasiStr = _getLokasiString();
      chips.add(_InfoChip(
        icon: Icons.location_on_outlined,
        label: lokasiStr,
        color: Colors.blue,
      ));
    }
    if (_isOutsideRadius()) {
      chips.add(_InfoChip(
        icon: Icons.warning_amber_rounded,
        label: 'Luar Radius',
        color: Colors.orange,
      ));
    }

    // 🔥 LIMIT: Max 6 chips visible
    const maxChips = 6;
    final displayChips = chips.take(maxChips).toList();
    
    if (chips.length > maxChips) {
      displayChips.add(
        _InfoChip(
          icon: Icons.more_horiz,
          label: '+${chips.length - maxChips}',
          color: Colors.grey,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: displayChips,
    );
  }

  String _getJenisLemburLabel() {
    switch (item.jenisLembur) {
      case 'hari_kerja': return 'Hari Kerja';
      case 'hari_libur': return 'Hari Libur';
      default: return item.jenisLembur;
    }
  }

  String _getLokasiString() {
    final lokasi = item.lokasi;
    String alamat = '';

    if (lokasi['nama_lokasi']?.toString().isNotEmpty == true) {
      alamat = lokasi['nama_lokasi'].toString();
    } else if (lokasi['alamat']?.toString().isNotEmpty == true) {
      alamat = lokasi['alamat'].toString();
    } else if (lokasi['latitude'] != null && lokasi['longitude'] != null) {
      return '📍 ${lokasi['latitude']}, ${lokasi['longitude']}';
    } else {
      return 'Tidak diketahui';
    }

    if (alamat.length > 25) {
      alamat = '${alamat.substring(0, 25)}...';
    }

    return alamat;
  }

  bool _isOutsideRadius() => item.lokasi['is_outside_radius'] == true;

  // =========================================================================
  // COST ROW
  // =========================================================================

  Widget _buildCostRow(double biaya) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          item.isMitraDocument ? 'Biaya' : 'Total Biaya',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          rateService.formatRupiahCompact(biaya),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SPKL INDICATOR
  // =========================================================================

  Widget _buildSpklIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, size: 14, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.spklNomor ?? 'SPKL Tersedia',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// INFO CHIP WIDGET
// =========================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF1976D2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: chipColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 Extension untuk nullable DateTime
extension DateTimeExtension on DateTime? {
  bool get hasValue => this != null;
}