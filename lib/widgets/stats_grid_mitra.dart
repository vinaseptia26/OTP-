// lib/widgets/stats_grid_mitra.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/mitra_service.dart';

class StatsGridMitra extends StatelessWidget {
  final MitraDashboardData data;
  final VoidCallback? onRefresh;

  const StatsGridMitra({
    super.key,
    required this.data,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _MitraStatItem(
        title: 'Total Lembur',
        value: _formatNumber(data.totalLemburStat),
        icon: Icons.work_history_rounded,
        subtitle: 'Disetujui & Selesai',
        gradientColors: const [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        badge: '${data.selesaiStat} selesai',
      ),
      _MitraStatItem(
        title: 'Total Jam',
        value: '${data.totalJamStat} Jam',
        icon: Icons.timer_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [Color(0xFF00b09b), Color(0xFF96c93d)],
        badge: 'Kuota: ${data.sisaKuotaStat} jam',
      ),
      _MitraStatItem(
        title: 'Pending',
        value: _formatNumber(data.pendingStat),
        icon: Icons.pending_actions_rounded,
        subtitle: 'Menunggu Konfirmasi',
        gradientColors: const [Color(0xFFf12711), Color(0xFFf5af19)],
        badge: data.pendingStat > 3 ? '⚠️ Urgent' : 'Aman',
      ),
      _MitraStatItem(
        title: 'Pendapatan',
        value: _formatCurrency(data.totalIncomeStat),
        icon: Icons.payments_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [Color(0xFF834d9b), Color(0xFFd04ed6)],
        badge: 'Selesai: ${data.selesaiStat}',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📊 Statistik Mitra',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2B4C),
              ),
            ),
            if (onRefresh != null)
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 18, color: Color(0xFF1A2B4C)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildStatCard(items[index]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2B4C).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildStatusDot(Colors.green, 'Disetujui: ${data.disetujuiStat}'),
              const SizedBox(width: 16),
              _buildStatusDot(Colors.red, 'Ditolak: ${data.ditolakStat}'),
              const Spacer(),
              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Update: ${_getCurrentTime()}',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(_MitraStatItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors[0].withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
              if (item.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                item.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF1A2B4C), fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return 'Rp ${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return 'Rp ${(amount / 1000).toStringAsFixed(1)}K';
    return 'Rp ${amount.toInt()}';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _MitraStatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String? badge;

  _MitraStatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
  });
}