// lib/widgets/pengawas_stats_grid.dart
import 'package:flutter/material.dart';
// Asumsikan PengawasDashboardData sudah di-import dari service
import '/core/services/pengawas_service.dart';

class PengawasStatsGrid extends StatelessWidget {
  final PengawasDashboardData data;
  final VoidCallback? onRefresh;

  const PengawasStatsGrid({
    super.key,
    required this.data,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Pakai field asli dari PengawasDashboardData
    final totalLemburWeek = data.totalLemburWeek;
    final pendingApproval = data.pendingApproval;
    final totalLemburToday = data.totalLemburToday;
    final totalMembers = data.totalTeamMembers;
    final onlineMembers = data.onlineMembers;

    final items = [
      _StatItem(
        title: 'Lembur Minggu Ini',
        value: '$totalLemburWeek',
        icon: Icons.work_history_rounded,
        subtitle: 'Total pengajuan',
        gradientColors: const [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        badge: 'Disetujui: $totalLemburToday',
      ),
      _StatItem(
        title: 'Pending Approval',
        value: '$pendingApproval',
        icon: Icons.pending_actions_rounded,
        subtitle: 'Menunggu konfirmasi',
        gradientColors: const [Color(0xFFf12711), Color(0xFFf5af19)],
        badge: pendingApproval > 3 ? '⚠️ Perhatian' : 'Aman',
      ),
      _StatItem(
        title: 'Disetujui Hari Ini',
        value: '$totalLemburToday',
        icon: Icons.check_circle_rounded,
        subtitle: 'Approved',
        gradientColors: const [Color(0xFF00b09b), Color(0xFF96c93d)],
        badge: null,
      ),
      _StatItem(
        title: 'Anggota Tim',
        value: '$totalMembers',
        icon: Icons.people_rounded,
        subtitle: 'Online: $onlineMembers',
        gradientColors: const [Color(0xFF834d9b), Color(0xFFd04ed6)],
        badge: '$onlineMembers online',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📊 Statistik Pengawas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2B4C),
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
      ],
    );
  }

  Widget _buildStatCard(_StatItem item) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                item.subtitle,
                style: const TextStyle(fontSize: 9, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String? badge;

  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
  });
}