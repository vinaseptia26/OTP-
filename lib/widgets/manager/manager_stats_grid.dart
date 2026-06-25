// lib/widgets/manager/manager_stats_grid.dart
import 'package:flutter/material.dart';
import 'manager_stat_card.dart';

class ManagerStatsGrid extends StatelessWidget {
  final int totalTeamMembers;
  final int onlineMembers;
  final int totalPending;
  final int totalApproved;
  final double totalHoursThisMonth;
  final VoidCallback? onRefresh;
  final Function(String type)? onCardTap;

  const ManagerStatsGrid({
    super.key,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.totalPending,
    required this.totalApproved,
    required this.totalHoursThisMonth,
    this.onRefresh,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final offlineMembers = totalTeamMembers - onlineMembers;

    final items = [
      _StatItem(
        title: 'Total Tim',
        value: '$totalTeamMembers',
        icon: Icons.people_rounded,
        subtitle: '$onlineMembers online',
        gradientColors: const [
          Color(0xFF6366F1),
          Color(0xFF4F46E5),
        ],
      ),
      _StatItem(
        title: 'Pending',
        value: '$totalPending',
        icon: Icons.pending_actions_rounded,
        subtitle: 'Perlu persetujuan',
        gradientColors: totalPending > 3
            ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
            : const [Color(0xFFF59E0B), Color(0xFFD97706)],
        badge: totalPending > 3 ? 'Urgent' : (totalPending > 0 ? 'Ada' : null),
        type: 'pending',
      ),
      _StatItem(
        title: 'Disetujui',
        value: '$totalApproved',
        icon: Icons.check_circle_rounded,
        subtitle: 'Approved',
        gradientColors: const [
          Color(0xFF10B981),
          Color(0xFF059669),
        ],
        badge: totalApproved > 0 ? 'Done' : null,
        type: 'approved',
      ),
      _StatItem(
        title: 'Jam Kerja',
        value: '${totalHoursThisMonth.toStringAsFixed(0)}h',
        icon: Icons.access_time_filled_rounded,
        subtitle: 'Bulan ini',
        gradientColors: totalHoursThisMonth > 100
            ? const [Color(0xFF8B5CF6), Color(0xFF7C3AED)]
            : const [Color(0xFF06B6D4), Color(0xFF0891B2)],
        badge: totalHoursThisMonth > 100 ? 'Tinggi' : null,
        type: 'hours',
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        /// HEADER - Lebih compact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              // Header Icon - Lebih kecil
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),

              const SizedBox(width: 10),

              // Title & Subtitle - Lebih kecil
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Kinerja',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B4C),
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Statistik tim & lembur',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Refresh Button - Lebih compact
              if (onRefresh != null)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        /// STATS GRID - Aspect ratio lebih compact
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: screenWidth < 370 ? 1.15 : 1.25,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return ManagerStatCard(
              title: item.title,
              value: item.value,
              icon: item.icon,
              subtitle: item.subtitle,
              gradientColors: item.gradientColors,
              badge: item.badge,
              index: index,
              onTap: () {
                if (onCardTap != null) {
                  onCardTap!(item.type);
                }
              },
            );
          },
        ),

        /// INSIGHT BANNER - Lebih compact
        if (totalPending > 0 || offlineMembers > 0) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildInsightBanner(totalPending, offlineMembers),
          ),
        ],
      ],
    );
  }

  Widget _buildInsightBanner(int pending, int offline) {
    String message;
    IconData icon;
    Color color;

    if (pending > 3) {
      message = '$pending pengajuan butuh persetujuan segera';
      icon = Icons.warning_rounded;
      color = const Color(0xFFEF4444);
    } else if (pending > 0) {
      message = 'Ada $pending pengajuan perlu ditinjau';
      icon = Icons.info_rounded;
      color = const Color(0xFFF59E0B);
    } else if (offline > 0) {
      message = '$offline anggota tim sedang offline';
      icon = Icons.people_outline_rounded;
      color = const Color(0xFF6366F1);
    } else {
      message = 'Semua berjalan lancar!';
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
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
  final String type;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
    this.type = '',
  });
}