// lib/widgets/approval/hsse_approval_progress_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HSSEApprovalProgressDialog extends StatelessWidget {
  final String groupId;
  final String status;
  final String? approvedBy;
  final dynamic approvedAt;
  final String? rejectedBy;
  final dynamic rejectedAt;
  final String? rejectReason;
  final bool needConfirmation;
  final String? confirmedBy;
  final dynamic confirmedAt;
  final bool isDarkMode;

  const HSSEApprovalProgressDialog({
    super.key,
    required this.groupId,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectReason,
    required this.needConfirmation,
    this.confirmedBy,
    this.confirmedAt,
    required this.isDarkMode,
  });

  // 🔥 Static cache untuk DateFormat
  static final _dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDarkMode ? Colors.grey[400]! : const Color(0xFF64748B);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    final showConfirmationStep = confirmedBy != null || confirmedAt != null;
    final isFullyApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardColor,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(textPrimary, textSecondary),
            const SizedBox(height: 28),

            // Step 1: Identifikasi Risiko
            _buildStep(
              isCompleted: true,
              isActive: false,
              isRejected: false,
              icon: Icons.warning_amber_rounded,
              title: 'Identifikasi Risiko',
              subtitle: 'Pekerjaan terdeteksi memiliki risiko',
              time: needConfirmation ? confirmedAt : null,
              actor: needConfirmation ? 'Sistem' : null,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            
            // Step 2: Konfirmasi Butuh HSSE
            if (showConfirmationStep)
              _buildStep(
                isCompleted: true,
                isActive: false,
                isRejected: false,
                icon: Icons.fact_check_outlined,
                title: 'Konfirmasi Butuh HSSE',
                subtitle: 'Manager mengkonfirmasi perlunya review HSSE',
                time: confirmedAt,
                actor: confirmedBy,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            
            // Step 3: Review HSSE
            _buildStep(
              isCompleted: isFullyApproved || isRejected,
              isActive: status == 'pending',
              isRejected: isRejected,
              icon: isFullyApproved
                  ? Icons.verified_user
                  : isRejected
                      ? Icons.gpp_bad
                      : Icons.pending_actions,
              title: isFullyApproved
                  ? 'Disetujui HSSE'
                  : isRejected
                      ? 'Ditolak HSSE'
                      : 'Review HSSE',
              subtitle: isFullyApproved
                  ? 'Pekerjaan disetujui dari sisi K3'
                  : isRejected
                      ? 'Pekerjaan ditolak dari sisi K3'
                      : 'Manager HSSE sedang melakukan review',
              time: isFullyApproved ? approvedAt : (isRejected ? rejectedAt : null),
              actor: isFullyApproved ? approvedBy : (isRejected ? rejectedBy : null),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Rejection reason
            if (isRejected && rejectReason != null) ...[
              const SizedBox(height: 16),
              _buildRejectionReason(),
            ],

            // Status summary
            const SizedBox(height: 20),
            _buildStatusSummary(textPrimary),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.health_and_safety,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Persetujuan Lanjutan HSSE',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Progress persetujuan K3 - Group: $groupId',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep({
    required bool isCompleted,
    required bool isActive,
    required bool isRejected,
    required IconData icon,
    required String title,
    required String subtitle,
    dynamic time,
    String? actor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final Color stepColor;
    final Color bgColor;
    
    if (isRejected) {
      stepColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.1);
    } else if (isCompleted) {
      stepColor = const Color(0xFF10B981);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
    } else if (isActive) {
      stepColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
    } else {
      stepColor = Colors.grey;
      bgColor = Colors.grey.withValues(alpha: 0.1);
    }

    String? formattedTime;
    if (time != null) {
      final DateTime dateTime = _parseDateTime(time);
      formattedTime = _dateFormatter.format(dateTime);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: stepColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, color: stepColor, size: 20),
                ),
                if (isActive)
                  Container(
                    width: 2,
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          stepColor,
                          stepColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (formattedTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: stepColor),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: stepColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (actor != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 12, color: stepColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Oleh: $actor',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: stepColor,
                              fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  Widget _buildRejectionReason() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Alasan Penolakan K3',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
            ),
            child: Text(
              rejectReason!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.red.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(Color textPrimary) {
    final Color statusColor;
    final String statusText;
    final String statusDesc;
    final IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusText = 'APPROVED';
        statusDesc = 'Pekerjaan telah disetujui dari sisi K3 oleh HSSE';
        statusIcon = Icons.verified;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusDesc = 'Pekerjaan ditolak dari sisi K3 oleh HSSE';
        statusIcon = Icons.gpp_bad;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'PENDING';
        statusDesc = 'Menunggu review dari Manager HSSE';
        statusIcon = Icons.hourglass_top;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDesc,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Helper untuk parse datetime
  DateTime _parseDateTime(dynamic time) {
    if (time is Timestamp) return time.toDate();
    if (time is DateTime) return time;
    return DateTime.now();
  }
}