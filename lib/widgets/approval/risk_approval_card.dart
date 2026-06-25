// lib/widgets/approval/risk_approval_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RiskApprovalCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RiskApprovalCard({
    super.key,
    required this.data,
    required this.isDarkMode,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  // 🔥 Static cache
  static final _dateFormatter = DateFormat('dd MMM yyyy');
  static final _timeFormatter = DateFormat('dd/MM HH:mm');
  static final Map<String, Map<String, dynamic>> _riskCategoryCache = {};

  @override
  Widget build(BuildContext context) {
    final riskCategory = _getRiskCategoryCached(
      data['risk_assessment']?['kategori_risiko'] ?? 'rendah',
    );
    final fungsiApproval = data['fungsi_approval'] as Map<String, dynamic>? ?? {};
    final hsseStatus = data['hsse_approval_status']?.toString() ?? 'pending';

    DateTime? parsedTanggal;
    final tanggalData = data['tanggal'] ?? data['tanggal_lembur'];
    if (tanggalData is Timestamp) {
      parsedTanggal = tanggalData.toDate();
    }

    final Color riskColor = riskCategory['color'] as Color;
    final IconData riskIcon = riskCategory['icon'] as IconData;
    final String riskLabel = riskCategory['label'] as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: riskColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: riskColor.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // HEADER
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [riskColor, riskColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: riskColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(riskIcon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Risk Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['nama_pengawas'] ?? '-',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Risk Level Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: riskColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(riskIcon, color: riskColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  riskLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: riskColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Risk Info Detail
                      _buildRiskInfo(),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // APPROVAL HISTORY
            _buildApprovalHistory(fungsiApproval, hsseStatus),
            
            const SizedBox(height: 12),
            
            // BOTTOM BAR
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF131A2A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: riskColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // Date
                  _buildInfoItem(
                    Icons.calendar_today,
                    parsedTanggal != null
                        ? _dateFormatter.format(parsedTanggal)
                        : '-',
                    Colors.grey[600]!,
                  ),
                  const SizedBox(width: 12),
                  // Time
                  _buildInfoItem(
                    Icons.access_time,
                    '${data['jam_mulai'] ?? '-'} - ${data['jam_selesai'] ?? '-'}',
                    Colors.grey[600]!,
                  ),
                  const Spacer(),
                  // Action Buttons
                  if (hsseStatus == 'pending') ...[
                    _buildActionButton(
                      label: 'Tolak',
                      color: Colors.red,
                      onPressed: onReject,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      label: 'Approve',
                      color: Colors.green,
                      onPressed: onApprove,
                    ),
                  ] else ...[
                    // Status badge when not pending
                    _buildStatusBadge(hsseStatus),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== RISK INFO ==============
  Widget _buildRiskInfo() {
    final risk = data['risk_assessment'] as Map<String, dynamic>? ?? {};
    final lokasi = data['lokasi'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRiskRow(
            Icons.dangerous,
            'Kategori: ${risk['kategori_risiko'] ?? '-'}',
            Colors.red,
          ),
          const SizedBox(height: 6),
          _buildRiskRow(
            Icons.location_on,
            'Lokasi: ${lokasi['deskripsi_lokasi'] ?? lokasi['alamat'] ?? '-'}',
            Colors.grey[600]!,
          ),
          if (risk['keterangan_risiko'] != null && 
              risk['keterangan_risiko'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildRiskRow(
              Icons.description,
              risk['keterangan_risiko'].toString(),
              Colors.grey[600]!,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskRow(IconData icon, String text, Color color, {int maxLines = 2}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11, color: color),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============== APPROVAL HISTORY ==============
  Widget _buildApprovalHistory(
    Map<String, dynamic> fungsiApproval,
    String hsseStatus,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0A0E21) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Approval',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildApprovalStep(
                'Fungsi',
                fungsiApproval['status_fungsi'] == 'disetujui',
                fungsiApproval['fungsi_manager_name']?.toString() ?? '-',
                fungsiApproval['fungsi_approved_at'] is Timestamp
                    ? _timeFormatter.format(
                        (fungsiApproval['fungsi_approved_at'] as Timestamp).toDate(),
                      )
                    : null,
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              _buildApprovalStep(
                'HSSE',
                hsseStatus == 'disetujui',
                data['hsse_approver_name']?.toString() ?? 'Menunggu',
                data['hsse_approved_at'] is Timestamp
                    ? _timeFormatter.format(
                        (data['hsse_approved_at'] as Timestamp).toDate(),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStep(
    String label,
    bool isApproved,
    String name,
    String? time,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isApproved ? Colors.green : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (time != null)
            Text(
              time,
              style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  // ============== BOTTOM ACTIONS ==============
  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    final IconData icon;
    final String label;

    switch (status) {
      case 'disetujui':
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Disetujui';
        break;
      case 'ditolak':
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Ditolak';
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPERS ==============
  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 🔥 CACHED RISK CATEGORY
  Map<String, dynamic> _getRiskCategoryCached(String value) {
    final key = value.toLowerCase();
    return _riskCategoryCache[key] ??= _computeRiskCategory(key);
  }

  Map<String, dynamic> _computeRiskCategory(String value) {
    switch (value) {
      case 'tinggi':
      case 'high':
      case 'critical':
        return {
          'color': const Color(0xFFDC2626),
          'label': 'Tinggi',
          'icon': Icons.dangerous,
        };
      case 'sedang':
      case 'medium':
        return {
          'color': const Color(0xFFF59E0B),
          'label': 'Sedang',
          'icon': Icons.warning_amber_rounded,
        };
      default:
        return {
          'color': const Color(0xFF10B981),
          'label': 'Rendah',
          'icon': Icons.info_outline,
        };
    }
  }
}