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
  
  // 🔥🔥🔥 TAMBAHAN: Flag untuk HSSE Tab (approved/rejected by HSSE K3)
  final bool isHSSETab;

  const ApprovalListBuilder({
    super.key,
    required this.status,
    required this.userRole,
    this.userFungsi,
    this.fungsiFilter,
    required this.searchQuery,
    required this.isDarkMode,
    required this.onTap,
    this.isHSSETab = false, // 🔥 DEFAULT FALSE
  });

  @override
  Widget build(BuildContext context) {
    final approvalService = OvertimeApprovalService();
    final rateService = OvertimeRateService();

    Stream<List<Map<String, dynamic>>> stream;

    // ================================================================
    // 🔥 HSSE TAB: Gunakan method khusus HSSE
    //    - getApprovedListForHSSE() untuk 'disetujui' (hsse_validated=true)
    //    - getRejectedListForHSSE() untuk 'ditolak' (hsse_validated=true)
    //    Query ini LINTAS FUNGSI, filter hsse_validated = true
    // ================================================================
    if (isHSSETab) {
      debugPrint('🟣 HSSE Tab: Query $status (HSSE validated only)');
      if (status == 'disetujui') {
        stream = approvalService.getApprovedListForHSSE(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
          fungsiFilter: fungsiFilter,
        );
      } else if (status == 'ditolak') {
        stream = approvalService.getRejectedListForHSSE(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
          fungsiFilter: fungsiFilter,
        );
      } else {
        // Fallback untuk status lain (seharusnya tidak terjadi)
        stream = approvalService.getApprovalListForManager(
          status: status,
          fungsiManager: userFungsi ?? '',
        );
      }
    }
    // ================================================================
    // SUPERADMIN
    // ================================================================
    else if (userRole == 'superadmin') {
      stream = approvalService.getApprovalListForSuperadmin(
        status: status,
        fungsiFilter: fungsiFilter,
      );
    }
    // ================================================================
    // MANAGER BIASA
    // ================================================================
    else {
      stream = approvalService.getApprovalListForManager(
        status: status,
        fungsiManager: userFungsi ?? '',
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        // Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        // Error State
        if (snapshot.hasError) {
          debugPrint('❌ ApprovalListBuilder error: ${snapshot.error}');
          return _buildErrorState();
        }

        final docs = snapshot.data ?? [];

        // Filter search
        final filteredDocs = docs.where((data) {
          if (searchQuery.isEmpty) return true;
          final query = searchQuery.toLowerCase();
          final nama = (data['nama_pengawas'] ?? '').toString().toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
          final email = (data['pengawas_email'] ?? '').toString().toLowerCase();
          return nama.contains(query) ||
              groupId.contains(query) ||
              fungsi.contains(query) ||
              email.contains(query);
        }).toList();

        // Empty State
        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        // 🔥 FIX: Gunakan LayoutBuilder + SingleChildScrollView untuk menghindari overflow
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔥 HSSE Info Header
                    if (isHSSETab) _buildHSSEInfoHeader(filteredDocs.length),
                    // Cards
                    ...filteredDocs.map((data) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildApprovalCard(data, rateService),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================================================================
  // 🔥 HSSE INFO HEADER
  // ================================================================
  Widget _buildHSSEInfoHeader(int count) {
    final isApproved = status == 'disetujui';
    final Color headerColor = isApproved ? Colors.green : Colors.red;
    final String title = isApproved 
        ? 'Validasi K3 Disetujui • $count pengajuan' 
        : 'Validasi K3 Ditolak • $count pengajuan';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerColor.withValues(alpha: 0.08),
            headerColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isApproved ? Icons.health_and_safety : Icons.cancel,
              color: headerColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: headerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== LOADING STATE ==============
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHSSETab ? const Color(0xFF9C27B0) : const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isHSSETab ? 'Memuat data validasi K3...' : 'Memuat data...',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============== ERROR STATE ==============
  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
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
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal Memuat Data',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isHSSETab 
                    ? 'Gagal mengambil data validasi K3.\nSilakan coba lagi atau refresh halaman.'
                    : 'Silakan coba lagi atau refresh halaman',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Trigger rebuild
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHSSETab ? const Color(0xFF9C27B0) : const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============== EMPTY STATE ==============
  Widget _buildEmptyState() {
    final isApproved = status == 'disetujui';
    final Color emptyColor = isApproved ? Colors.green : Colors.red;
    final IconData emptyIcon = isApproved ? Icons.check_circle_outline : Icons.cancel_outlined;
    
    final String title;
    final String subtitle;
    
    if (isHSSETab) {
      title = isApproved ? 'Tidak Ada Validasi K3 Disetujui' : 'Tidak Ada Validasi K3 Ditolak';
      subtitle = isApproved
          ? 'Belum ada pengajuan berisiko yang divalidasi K3.\nData akan muncul setelah validasi dilakukan.'
          : 'Belum ada pengajuan berisiko yang ditolak K3.\nData akan muncul setelah penolakan dilakukan.';
    } else {
      title = 'Tidak Ada Data';
      subtitle = searchQuery.isNotEmpty
          ? 'Tidak ada hasil untuk "$searchQuery"'
          : 'Semua pengajuan telah diproses';
    }

    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF1E293B) 
                      : (isHSSETab ? emptyColor.withValues(alpha: 0.06) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isHSSETab ? emptyIcon : Icons.inbox_outlined,
                  size: 36,
                  color: isHSSETab ? emptyColor.withValues(alpha: 0.4) : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (searchQuery.isNotEmpty && !isHSSETab) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    // Clear search handled by parent
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Hapus Pencarian'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============== APPROVAL CARD ==============
  Widget _buildApprovalCard(Map<String, dynamic> data, OvertimeRateService rateService) {
    final isUrgent = data['urgensi'] == 'kritis';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';

    final lokasiData = data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final groupId = data['group_id'] ?? '';
    final totalBiaya = (data['estimasi_biaya_total'] ?? 0).toDouble();
    final totalMitra = data['total_mitra'] ?? 0;

    // Nama mitra dari detail_mitra
    final detailMitra = data['detail_mitra'] as List?;
    final mitraNames = detailMitra?.map((m) => m['nama'] ?? '?').toList() ?? [];

    // Tanggal
    String tanggalStr = '-';
    if (data['tanggal'] != null) {
      try {
        if (data['tanggal'] is Timestamp) {
          tanggalStr = DateFormat('dd MMM yyyy').format((data['tanggal'] as Timestamp).toDate());
        }
      } catch (_) {}
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(groupId),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isUrgent
                ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5)
                : isOverride
                    ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1)
                    : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getFungsiColor(data['pengawas_fungsi']),
                          _getFungsiColor(data['pengawas_fungsi']).withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        (data['nama_pengawas'] ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                data['nama_pengawas'] ?? '-',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUrgent)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'URGENT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _getFungsiLabel(data['pengawas_fungsi']),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // INFO GRID
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInfoItem(
                          Icons.calendar_today_rounded,
                          tanggalStr,
                          isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoItem(
                          Icons.access_time_rounded,
                          '${data['jam_mulai']} - ${data['jam_selesai']}',
                          isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInfoItem(
                          Icons.account_balance_wallet_rounded,
                          rateService.formatRupiahCompact(totalBiaya),
                          const Color(0xFF10B981),
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoItem(
                          Icons.people_outline_rounded,
                          '$totalMitra mitra • ${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                          isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // TAGS
              if (isWeekend || isOverride || isOutside || lokasiString.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isWeekend)
                      _buildTag('Hari Libur', Colors.purple, Icons.event_busy),
                    if (isOverride)
                      _buildTag('Override', Colors.orange, Icons.warning_amber_rounded),
                    if (isOutside)
                      _buildTag('Luar Radius', Colors.deepOrange, Icons.location_off_rounded),
                    if (lokasiString.isNotEmpty && !isOutside)
                      _buildTag(lokasiString, Colors.blue, Icons.location_on_rounded),
                  ],
                ),
              ],
              // MITRA NAMES
              if (mitraNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mitraNames.take(2).join(', ') +
                            (mitraNames.length > 2 ? ' +${mitraNames.length - 2}' : ''),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
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
      ),
    );
  }

  // ============== INFO ITEM ==============
  Widget _buildInfoItem(IconData icon, String text, Color color, {bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============== TAG ==============
  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER METHODS ==============
  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'disetujui':
        return const Color(0xFF10B981);
      case 'ditolak':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_bottom_rounded;
      case 'disetujui':
        return Icons.check_circle_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
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
        return f ?? 'Unknown';
    }
  }

  Color _getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
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
        return const Color(0xFF6366F1);
    }
  }

  String _getLokasiSingkat(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return '';

    if (lokasi['nama_lokasi'] != null && lokasi['nama_lokasi'].toString().isNotEmpty) {
      final nama = lokasi['nama_lokasi'].toString();
      return nama.length > 12 ? '${nama.substring(0, 12)}...' : nama;
    }
    if (lokasi['alamat'] != null && lokasi['alamat'].toString().isNotEmpty) {
      final alamat = lokasi['alamat'].toString();
      return alamat.length > 12 ? '${alamat.substring(0, 12)}...' : alamat;
    }
    if (lokasi['nama'] != null && lokasi['nama'].toString().isNotEmpty) {
      final nama = lokasi['nama'].toString();
      return nama.length > 12 ? '${nama.substring(0, 12)}...' : nama;
    }

    return '';
  }
}