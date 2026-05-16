// lib/features/superadmin/widgets/user_distribution.dart
import 'package:flutter/material.dart';

class UserDistribution extends StatelessWidget {
  final Map<String, int> distribution;
  final int verifiedUsers;
  final int lockedAccounts;
  final int activeToday;
  final Color Function(String) getRoleColor;

  const UserDistribution({
    super.key,
    required this.distribution,
    required this.verifiedUsers,
    required this.lockedAccounts,
    required this.activeToday,
    required this.getRoleColor,
  });

  @override
  Widget build(BuildContext context) {
    int total = distribution.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Distribusi User',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3C72).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Total: $total',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E3C72), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Role Distribution
          ...distribution.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total) : 0.0;
            final color = getRoleColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Row(
                        children: [
                          Text('${entry.value}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                          const SizedBox(width: 4),
                          Text('(${(percentage * 100).toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
          
          const Divider(),
          const SizedBox(height: 8),
          
          // Stats Row (TANPA real-time online)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Terverifikasi', '$verifiedUsers', Colors.green),
              _buildStat('Terkunci', '$lockedAccounts', Colors.red),
              _buildStat('Login Hari Ini', '$activeToday', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, 
          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}