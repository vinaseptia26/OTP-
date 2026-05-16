// lib/widgets/approval/admin/admin_approval_list_builder.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

class AdminApprovalListBuilder extends StatelessWidget {
  final String status;
  final String? fungsiFilter;
  final String searchQuery;
  final bool isDarkMode;

  // Bulk selection
  final bool isBulkMode;
  final Set<String> selectedIds;
  final bool isSelectAll;
  final Function(String groupId, bool isSelected)? onSelectionChanged;
  final Function(List<String> allIds, bool isSelectAll)? onSelectAllChanged;
  final Function(List<Map<String, dynamic>> data)? onAllDataLoaded;

  final Function(String groupId) onTap;

  const AdminApprovalListBuilder({
    super.key,
    required this.status,
    this.fungsiFilter,
    required this.searchQuery,
    required this.isDarkMode,
    this.isBulkMode = false,
    this.selectedIds = const {},
    this.isSelectAll = false,
    this.onSelectionChanged,
    this.onSelectAllChanged,
    this.onAllDataLoaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final approvalService = OvertimeApprovalService();
    final rateService = OvertimeRateService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: approvalService.getApprovalListForSuperadmin(
        status: status,
        fungsiFilter: fungsiFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[200]),
                const SizedBox(height: 16),
                Text('Gagal memuat data', style: GoogleFonts.poppins(color: Colors.red)),
              ],
            ),
          );
        }

        final docs = snapshot.data ?? [];

        final filteredDocs = docs.where((data) {
          if (searchQuery.isEmpty) return true;
          final nama = (data['nama_pengawas'] ?? '').toString().toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
          return nama.contains(searchQuery) ||
              groupId.contains(searchQuery) ||
              fungsi.contains(searchQuery);
        }).toList();

        // Callback data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onAllDataLoaded?.call(filteredDocs);
          if (isBulkMode && onSelectAllChanged != null) {
            final ids = filteredDocs
                .map((d) => (d['group_id'] ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList();
            onSelectAllChanged!(ids, isSelectAll);
          }
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Tidak ada data', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index];
            return _buildCard(data, rateService);
          },
        );
      },
    );
  }

  // ========== CARD (diperbarui) ==========
  Widget _buildCard(Map<String, dynamic> data, OvertimeRateService rateService) {
    final urgency = data['urgensi'] as String?; // bisa 'kritis', 'tinggi', 'sedang', 'rendah'
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';

    final lokasiData = data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final groupId = data['group_id'] ?? '';
    final totalBiaya = (data['estimasi_biaya_total'] ?? 0).toDouble();
    final isPending = status == 'pending';
    final isSelected = isSelectAll || selectedIds.contains(groupId);

    // Cek apakah perlu rekomendasi segera approve
    bool isUrgentNeedApprove = (urgency == 'kritis'); // urgensi kritis
    // Cek tanggal mepet (≤1 hari dari sekarang)
    bool isDateNear = false;
    if (data['tanggal'] != null) {
      final overtimeDate = (data['tanggal'] as Timestamp).toDate();
      final now = DateTime.now();
      // Jika lembur dimulai dalam 24 jam ke depan atau sudah lewat (mepet)
      isDateNear = overtimeDate.isBefore(now.add(const Duration(days: 1))) &&
                   overtimeDate.isAfter(now.subtract(const Duration(hours: 2))); // toleransi 2 jam
    }
    final showRecommendationBar = isUrgentNeedApprove || isDateNear;

    // Nama mitra
    final detailMitra = data['detail_mitra'] as List?;
    final mitraNames = detailMitra?.map((m) => m['nama'] ?? '?').toList() ?? [];

    return GestureDetector(
      onTap: () {
        if (isBulkMode && isPending) {
          onSelectionChanged?.call(groupId, !isSelected);
        } else {
          onTap(groupId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: urgency == 'kritis'
              ? Border.all(color: Colors.red, width: 2)
              : urgency == 'tinggi'
                  ? Border.all(color: Colors.orange, width: 1.5)
                  : isOverride
                      ? Border.all(color: Colors.orange, width: 1.5)
                      : isOutside
                          ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5)
                          : isSelected
                              ? Border.all(color: const Color(0xFF1E3C72), width: 2)
                              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== BAR REKOMENDASI SEGERA APPROVE ==========
            if (showRecommendationBar)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.yellow.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '⚠️ Harus segera ditinjau / di-approve',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Checkbox bulk
                if (isBulkMode && isPending)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF1E3C72),
                      onChanged: (_) => onSelectionChanged?.call(groupId, !isSelected),
                    ),
                  ),
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama + Badge Urgensi
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['nama_pengawas'] ?? '-',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          // Chip urgensi (warna beda per level)
                          if (urgency != null && urgency.isNotEmpty)
                            _buildUrgencyChip(urgency),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Chips lain
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _chip(_getFungsiLabel(data['pengawas_fungsi']), Colors.blue),
                          _chip('${data['total_mitra']} mitra', Colors.purple),
                          _chip(
                            '${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                            Colors.green,
                          ),
                          if (isWeekend) _chip('LIBUR', Colors.purple),
                          if (isOverride) _chip('OVERRIDE', Colors.orange),
                          if (isOutside) _chip('⚠️ LUAR RADIUS', Colors.orange),
                          if (lokasiMap.isNotEmpty && !isOutside)
                            _chip('📍 $lokasiString', Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tanggal & Jam
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            data['tanggal'] != null
                                ? DateFormat('dd/MM/yyyy').format(
                                    (data['tanggal'] as Timestamp).toDate())
                                : '-',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${data['jam_mulai']} - ${data['jam_selesai']}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Biaya
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            rateService.formatRupiahCompact(totalBiaya),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            groupId.length >= 8 ? '${groupId.substring(0, 8)}...' : groupId,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),

                      // Nama mitra
                      if (mitraNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.people, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mitraNames.take(3).join(', ') +
                                    (mitraNames.length > 3 ? ' +${mitraNames.length - 3} lainnya' : ''),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow (hilang saat bulk mode)
                if (!isBulkMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== Chip urgensi dengan warna per level ==========
  Widget _buildUrgencyChip(String level) {
    final color = _getUrgencyColor(level);
    final label = level.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ========== Warna per tingkat urgensi ==========
  Color _getUrgencyColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'kritis':
        return Colors.red;
      case 'tinggi':
        return Colors.orange;
      case 'sedang':
        return Colors.amber.shade700;
      case 'rendah':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 8, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s) {
      case 'pending': return Icons.hourglass_empty;
      case 'disetujui': return Icons.check_circle;
      case 'ditolak': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Lab';
      case 'maintenance': return 'MTC';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return f ?? '?';
    }
  }

  String _getLokasiSingkat(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return '';
    if (lokasi['nama_lokasi'] != null && lokasi['nama_lokasi'].toString().isNotEmpty) {
      final nama = lokasi['nama_lokasi'].toString();
      return nama.length > 15 ? '${nama.substring(0, 15)}...' : nama;
    }
    if (lokasi['alamat'] != null && lokasi['alamat'].toString().isNotEmpty) {
      final alamat = lokasi['alamat'].toString();
      return alamat.length > 15 ? '${alamat.substring(0, 15)}...' : alamat;
    }
    if (lokasi['nama'] != null && lokasi['nama'].toString().isNotEmpty) {
      return lokasi['nama'].toString();
    }
    return '';
  }
}