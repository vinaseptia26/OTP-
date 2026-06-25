// lib/widgets/key_metrics.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KeyMetrics extends StatelessWidget {
  final int newUsersToday;
  final int lockedAccounts;
  final int totalOvertime;
  final String Function(int) formatNumber;

  const KeyMetrics({
    super.key,
    required this.newUsersToday,
    required this.lockedAccounts,
    required this.totalOvertime,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isSmallMobile = width < 360;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // HEADER
          // =========================

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E3C72),
                      Color(0xFF2563EB),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Key Metrics',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Ringkasan performa sistem hari ini',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =========================
          // METRICS
          // =========================

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            physics: const BouncingScrollPhysics(),

            child: Row(
              children: [
                _buildMetricCard(
                  title: 'Pengguna Baru',
                  value: '$newUsersToday',
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF10B981),
                  subtitle: 'Hari ini',
                  isSmallMobile: isSmallMobile,
                ),

                const SizedBox(width: 12),

                _buildMetricCard(
                  title: 'Akun Terkunci',
                  value: '$lockedAccounts',
                  icon: Icons.lock_outline_rounded,
                  color: const Color(0xFFEF4444),
                  subtitle: 'Perlu perhatian',
                  isSmallMobile: isSmallMobile,
                ),

                const SizedBox(width: 12),

                _buildMetricCard(
                  title: 'Total Lembur',
                  value: formatNumber(totalOvertime),
                  icon: Icons.work_history_rounded,
                  color: const Color(0xFF2563EB),
                  subtitle: 'Bulan ini',
                  isSmallMobile: isSmallMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // METRIC CARD
  // =========================

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required bool isSmallMobile,
  }) {
    return Container(
      width: isSmallMobile ? 150 : 170,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(28),
            color.withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: color.withAlpha(40),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // ICON
          // =========================

          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),

          const SizedBox(height: 14),

          // =========================
          // VALUE
          // =========================

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,

            child: Text(
              value,
              maxLines: 1,

              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                height: 1,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // =========================
          // TITLE
          // =========================

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),

          const SizedBox(height: 2),

          // =========================
          // SUBTITLE
          // =========================

          Text(
            subtitle,

            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}