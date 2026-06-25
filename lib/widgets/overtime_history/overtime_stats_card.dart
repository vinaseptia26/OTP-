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
  final String? selectedBulan;

  const OvertimeStatsCard({
    super.key,
    required this.historyService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    this.selectedBulan,
  });

  @override
  Widget build(BuildContext context) {
    final isHSSE = userFungsi == 'hsse';
    final isHSSEManager = userRole == 'manager' && isHSSE;
    final bulanParam = (selectedBulan != null && selectedBulan!.isNotEmpty)
        ? selectedBulan
        : null;

    return FutureBuilder<Map<String, dynamic>>(
      future: historyService.getOvertimeStats(
        userRole: userRole,
        userFungsi: userFungsi,
        userId: userId,
        bulan: bulanParam,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(isHSSE);
        }

        if (!snapshot.hasData) {
          return _buildEmptyCard(isHSSE);
        }

        final stats = snapshot.data!;
        return _buildStatsCard(context, stats, isHSSE, isHSSEManager);
      },
    );
  }

  Widget _buildLoadingCard(bool isHSSE) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: isHSSE ? 180 : 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHSSE
              ? [const Color(0xFFB71C1C), const Color(0xFFC62828)]
              : [const Color(0xFF1E3C72), const Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isHSSE ? const Color(0xFFB71C1C) : const Color(0xFF1E3C72)).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildEmptyCard(bool isHSSE) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: isHSSE ? 180 : 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHSSE
              ? [const Color(0xFFB71C1C), const Color(0xFFC62828)]
              : [const Color(0xFF1E3C72), const Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isHSSE ? Icons.health_and_safety : Icons.inbox_outlined, color: Colors.white54, size: 32),
            const SizedBox(height: 8),
            Text('Tidak ada data', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    Map<String, dynamic> stats,
    bool isHSSE,
    bool isHSSEManager,
  ) {
    final rateService = OvertimeRateService();
    final total = stats['total'] as int? ?? 0;
    final pending = stats['pending'] as int? ?? 0;
    final approved = stats['approved'] as int? ?? 0;
    final completed = stats['completed'] as int? ?? 0;
    final rejected = stats['rejected'] as int? ?? 0;
    final needAbsensi = stats['needAbsensi'] as int? ?? 0;
    final cancelled = stats['cancelled'] as int? ?? 0;
    final totalJam = (stats['totalJam'] as num? ?? 0).toDouble();
    final totalBiaya = (stats['totalBiaya'] as num? ?? 0).toDouble();
    final riskyCount = stats['riskyCount'] as int? ?? 0;

    final List<Color> gradientColors = isHSSE
        ? [const Color(0xFFB71C1C), const Color(0xFFC62828)]
        : [const Color(0xFF1E3C72), const Color(0xFF2A4F8C)];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: gradientColors.first.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // 🔥 Baris 1: 4 stat counter utama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(label: 'Total', value: total, icon: Icons.article_outlined),
              _StatItem(label: 'Pending', value: pending, color: Colors.orange, icon: Icons.hourglass_empty),
              _StatItem(label: 'Disetujui', value: approved, color: Colors.green, icon: Icons.check_circle_outline),
              _StatItem(
                label: isHSSE ? 'Selesai' : 'Ditolak',
                value: isHSSE ? completed : rejected,
                color: isHSSE ? Colors.lightBlue : Colors.red,
                icon: isHSSE ? Icons.task_alt : Icons.cancel_outlined,
              ),
            ],
          ),

          // 🔥 HSSE: Baris tambahan untuk stat HSSE
          if (isHSSE && (riskyCount > 0 || cancelled > 0 || rejected > 0 || needAbsensi > 0)) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (riskyCount > 0)
                  _StatItem(label: 'HSSE', value: riskyCount, color: Colors.yellow, icon: Icons.health_and_safety),
                if (rejected > 0 && isHSSE)
                  _StatItem(label: 'Ditolak', value: rejected, color: Colors.red, icon: Icons.cancel_outlined),
                if (cancelled > 0)
                  _StatItem(label: 'Batal', value: cancelled, color: Colors.red[300]!, icon: Icons.remove_circle_outline),
                if (needAbsensi > 0)
                  _StatItem(label: 'Absensi', value: needAbsensi, color: Colors.orange, icon: Icons.camera_alt_outlined),
              ],
            ),
          ],

          // 🔥 HSSE Manager info bar
          if (isHSSEManager && (riskyCount > 0 || pending > 0)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety, color: Colors.yellow, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    riskyCount > 0 ? '$riskyCount perlu validasi HSSE' : 'Semua pengajuan telah divalidasi ✅',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],

          // Baris info tambahan (total jam & biaya)
          if (total > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoItem(label: 'Total Jam', value: '${totalJam.toStringAsFixed(1)} jam', icon: Icons.timer_outlined),
                _InfoItem(label: 'Total Biaya', value: rateService.formatRupiahCompact(totalBiaya), icon: Icons.payments_outlined),
                if (needAbsensi == 0 && !isHSSE)
                  _InfoItem(label: 'Total Mitra', value: '${stats['totalMitra'] ?? 0}', icon: Icons.people_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =========================================================================
// PRIVATE WIDGET: _StatItem
// =========================================================================
class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  final IconData icon;

  const _StatItem({required this.label, required this.value, this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;
    return Column(
      children: [
        Icon(icon, color: effectiveColor.withOpacity(0.8), size: 18),
        const SizedBox(height: 6),
        Text(value.toString(), style: GoogleFonts.poppins(color: effectiveColor, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(color: effectiveColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// =========================================================================
// PRIVATE WIDGET: _InfoItem
// =========================================================================
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _InfoItem({required this.label, required this.value, required this.icon, this.color});

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
            Text(value, style: GoogleFonts.poppins(color: effectiveColor, fontWeight: FontWeight.w600, fontSize: 13)),
            Text(label, style: GoogleFonts.poppins(color: effectiveColor.withOpacity(0.6), fontSize: 10)),
          ],
        ),
      ],
    );
  }
}