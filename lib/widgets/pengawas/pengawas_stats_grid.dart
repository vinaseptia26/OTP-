// lib/widgets/pengawas_stats_grid.dart

import 'package:flutter/material.dart';
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
        subtitle: 'Total pengajuan lembur',
        gradientColors: const [
          Color(0xFF2563EB),
          Color(0xFF1D4ED8),
        ],
        badge: '$totalLemburToday Hari Ini',
      ),
      _StatItem(
        title: 'Pending Persetujuan',
        value: '$pendingApproval',
        icon: Icons.pending_actions_rounded,
        subtitle: 'Menunggu persetujuan',
        gradientColors: const [
          Color(0xFFF97316),
          Color(0xFFEA580C),
        ],
        badge: pendingApproval > 3 ? 'Perhatian' : 'Aman',
      ),
      _StatItem(
        title: 'Disetujui Hari Ini',
        value: '$totalLemburToday',
        icon: Icons.check_circle_rounded,
        subtitle: 'Lembur disetujui',
        gradientColors: const [
          Color(0xFF10B981),
          Color(0xFF059669),
        ],
      ),
      _StatItem(
        title: 'Anggota Tim',
        value: '$totalMembers',
        icon: Icons.people_alt_rounded,
        subtitle: '$onlineMembers anggota online',
        gradientColors: const [
          Color(0xFF7C3AED),
          Color(0xFF6D28D9),
        ],
        badge: '$onlineMembers Online',
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// HEADER
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistik Tim',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2B4C),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ringkasan aktivitas lembur',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            if (onRefresh != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: Color(0xFF1A2B4C),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        /// GRID
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: screenWidth < 370 ? 0.95 : 1.08,
          ),
          itemBuilder: (context, index) {
            return _StatCard(item: items[index]);
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors.first.withValues(alpha: 0.20),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          /// Decorative Circle
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          Positioned(
            bottom: -35,
            left: -25,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// TOP SECTION
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),

                    const Spacer(),

                    if (item.badge != null)
                      Container(
                        constraints: const BoxConstraints(
                          maxWidth: 90,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          item.badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const Spacer(),

                /// VALUE
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                /// TITLE
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 4),

                /// SUBTITLE
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
  });
}