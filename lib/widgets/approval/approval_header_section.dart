// lib/widgets/approval/approval_header_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ApprovalHeaderSection extends StatelessWidget {
  final bool isHSSEManager;
  final int? pendingCount;
  final int? hssePendingCount; // 🔥 NEW: Khusus pending HSSE
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showRiskSummary; // 🔥 NEW: Tampilkan ringkasan risiko

  const ApprovalHeaderSection({
    super.key,
    required this.isHSSEManager,
    this.pendingCount,
    this.hssePendingCount,
    this.subtitle,
    this.onTap,
    this.showRiskSummary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = isHSSEManager
        ? const Color(0xFF9C27B0)  // Purple untuk HSSE
        : const Color(0xFF6366F1); // Indigo untuk Manager biasa

    final String title = isHSSEManager 
        ? 'Validasi Risiko HSSE'  // 🔥 UBAH: Lebih spesifik
        : 'Approval Lembur';

    final IconData headerIcon = isHSSEManager
        ? Icons.health_and_safety_rounded
        : Icons.assignment_turned_in_rounded;

    // 🔥 Subtitle dinamis
    final String displaySubtitle = subtitle ?? (isHSSEManager
        ? 'Pengajuan lembur dengan risiko tinggi'
        : 'Persetujuan pengajuan lembur mitra');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Animated Icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          headerIcon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 14),
                    
                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                          
                          // Subtitle
                          const SizedBox(height: 3),
                          Text(
                            displaySubtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Pending Badge
                    if (pendingCount != null && pendingCount! > 0) ...[
                      const SizedBox(width: 8),
                      _buildPendingBadge(pendingCount!),
                    ],
                    
                    // Arrow (if tappable)
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                
                // 🔥 HSSE Risk Summary (hanya untuk HSSE Manager)
                if (isHSSEManager && showRiskSummary) ...[
                  const SizedBox(height: 12),
                  _buildRiskSummary(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 PENDING BADGE - Clean & eye-catching
  Widget _buildPendingBadge(int count) {
    final Color badgeColor = count > 5 
        ? const Color(0xFFEF4444)  // Merah jika > 5
        : const Color(0xFFF59E0B); // Orange jika <= 5
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            count > 5 ? Icons.priority_high_rounded : Icons.notifications_rounded,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'pending',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: badgeColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 RISK SUMMARY - Ringkasan level risiko
  Widget _buildRiskSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _buildRiskItem('Critical', const Color(0xFFDC2626), Icons.dangerous_rounded),
          _buildDivider(),
          _buildRiskItem('High', const Color(0xFFF59E0B), Icons.warning_amber_rounded),
          _buildDivider(),
          _buildRiskItem('Medium', const Color(0xFF3B82F6), Icons.info_outline_rounded),
          _buildDivider(),
          _buildRiskItem('Low', const Color(0xFF10B981), Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}