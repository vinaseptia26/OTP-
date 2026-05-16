// lib/widgets/approval/manager/approval_list_builder.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

class ApprovalListBuilder extends StatelessWidget {
  final String status;
  final String userRole;
  final String? userFungsi;
  final String? fungsiFilter;
  final String searchQuery;
  final bool isDarkMode;
  final Function(String groupId) onTap;

  const ApprovalListBuilder({
    super.key,
    required this.status,
    required this.userRole,
    this.userFungsi,
    this.fungsiFilter,
    required this.searchQuery,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final approvalService = OvertimeApprovalService();
    final rateService = OvertimeRateService();

    Stream<List<Map<String, dynamic>>> stream;

    if (userRole == 'superadmin') {
      stream = approvalService.getApprovalListForSuperadmin(
        status: status,
        fungsiFilter: fungsiFilter,
      );
    } else {
      stream = approvalService.getApprovalListForManager(
        status: status,
        fungsiManager: userFungsi ?? '',
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
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
                Text(
                  'Gagal memuat data',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data ?? [];

        // Filter search
        final filteredDocs = docs.where((data) {
          if (searchQuery.isEmpty) return true;
          final nama = (data['nama_pengawas'] ?? '').toString().toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
          return nama.contains(searchQuery) ||
              groupId.contains(searchQuery) ||
              fungsi.contains(searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada data',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500]),
                ),
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

  Widget _buildCard(Map<String, dynamic> data, OvertimeRateService rateService) {
    final isUrgent = data['urgensi'] == 'kritis';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';

    final lokasiData = data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final groupId = data['group_id'] ?? '';
    final totalBiaya = (data['estimasi_biaya_total'] ?? 0).toDouble();

    // Nama mitra dari detail_mitra
    final detailMitra = data['detail_mitra'] as List?;
    final mitraNames = detailMitra?.map((m) => m['nama'] ?? '?').toList() ?? [];

    return GestureDetector(
      onTap: () => onTap(groupId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUrgent
              ? Border.all(color: Colors.red, width: 2)
              : isOverride
                  ? Border.all(color: Colors.orange, width: 1.5)
                  : isOutside
                      ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
                      : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
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
                      // Nama + Badge Urgent
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
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'URGENT',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Chips
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
                // Arrow
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
      case 'pending':
        return Colors.orange;
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'disetujui':
        return Icons.check_circle;
      case 'ditolak':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
      case 'operation':
        return 'Operation';
      case 'lab':
        return 'Lab';
      case 'maintenance':
        return 'MTC';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'BS';
      default:
        return f ?? '?';
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