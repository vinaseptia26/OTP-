// lib/widgets/overtime_history/overtime_stats_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';

class OvertimeStatsCard extends StatelessWidget {
  final OvertimeHistoryService historyService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String selectedBulan;

  const OvertimeStatsCard({
    super.key,
    required this.historyService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    required this.selectedBulan,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: historyService.getOvertimeStats(
        userRole: userRole,
        userFungsi: userFungsi,
        userId: userId,
        bulan: selectedBulan,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData) {
          return _buildEmptyCard();
        }

        final stats = snapshot.data!;
        return _buildStatsCard(context, stats);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          'Tidak ada data',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, Map<String, dynamic> stats) {
    final rateService = OvertimeRateService();
    final total = stats['total'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final approved = stats['approved'] ?? 0;
    final completed = stats['completed'] ?? 0;
    final rejected = stats['rejected'] ?? 0;
    final needAbsensi = stats['needAbsensi'] ?? 0;
    final totalJam = (stats['totalJam'] ?? 0).toDouble();
    final totalBiaya = (stats['totalBiaya'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris 1: 4 stat counter utama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Total',
                value: total,
                icon: Icons.article_outlined,
              ),
              _StatItem(
                label: 'Pending',
                value: pending,
                color: Colors.orange,
                icon: Icons.hourglass_empty,
              ),
              _StatItem(
                label: 'Selesai',
                value: completed,
                color: Colors.green,
                icon: Icons.check_circle_outline,
              ),
              _StatItem(
                label: 'Ditolak',
                value: rejected,
                color: Colors.red,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
          // Baris info tambahan
          if (total > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoItem(
                  label: 'Total Jam',
                  value: '${totalJam.toStringAsFixed(1)} jam',
                  icon: Icons.timer_outlined,
                ),
                _InfoItem(
                  label: 'Total Biaya',
                  value: rateService.formatRupiahCompact(totalBiaya),
                  icon: Icons.payments_outlined,
                ),
                if (needAbsensi > 0)
                  _InfoItem(
                    label: 'Belum Absen',
                    value: '$needAbsensi',
                    icon: Icons.camera_alt_outlined,
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;
    return Column(
      children: [
        Icon(icon, color: effectiveColor.withOpacity(0.8), size: 18),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            color: effectiveColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: effectiveColor.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: effectiveColor, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: effectiveColor.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}