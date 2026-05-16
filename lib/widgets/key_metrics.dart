// lib/widgets/key_metrics.dart
import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed, color: Color(0xFF1E3C72), size: 20),
              SizedBox(width: 8),
              Text('Key Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('Pengguna Baru', '$newUsersToday', Icons.person_add, Colors.green),
                const SizedBox(width: 8),
                _buildChip('Akun Terkunci', '$lockedAccounts', Icons.lock, Colors.red),
                const SizedBox(width: 8),
                _buildChip('Lembur Bulan Ini', formatNumber(totalOvertime), Icons.work_history, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}