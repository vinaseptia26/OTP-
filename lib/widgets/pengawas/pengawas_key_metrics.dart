import 'package:flutter/material.dart';

class PengawasKeyMetrics extends StatelessWidget {
  final int totalLemburWeek;
  final int pendingApprovals;
  final int totalTeamMembers;
  final int onlineMembers;
  final String Function(int) formatNumber;

  const PengawasKeyMetrics({
    super.key,
    required this.totalLemburWeek,
    required this.pendingApprovals,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔑 Metrik Penting',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A2B4C)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricItem(
                icon: Icons.work_history_rounded,
                label: 'Lembur Minggu Ini',
                value: formatNumber(totalLemburWeek),
                color: const Color(0xFF1E3C72),
              ),
              const SizedBox(width: 12),
              _buildMetricItem(
                icon: Icons.pending_actions_rounded,
                label: 'Pending Approval',
                value: formatNumber(pendingApprovals),
                color: const Color(0xFFf5af19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem(
                icon: Icons.people_rounded,
                label: 'Anggota Tim',
                value: formatNumber(totalTeamMembers),
                color: const Color(0xFF00b09b),
              ),
              const SizedBox(width: 12),
              _buildMetricItem(
                icon: Icons.online_prediction_rounded,
                label: 'Online Sekarang',
                value: formatNumber(onlineMembers),
                color: const Color(0xFF834d9b),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}