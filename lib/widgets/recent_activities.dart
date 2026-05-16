// lib/features/superadmin/widgets/recent_activities.dart
import 'package:flutter/material.dart';
import '/core/app_colors.dart';
import '../core/services/superadmin_service.dart';

class RecentActivities extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final DashboardService service;

  const RecentActivities({
    super.key,
    required this.activities,
    required this.service,
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
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: AppColors.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Text('Aktivitas Terbaru',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${activities.length} baru',
                    style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 50, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('Tidak ada aktivitas',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...activities.take(8).map((activity) => _buildItem(activity, service)),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> activity, DashboardService service) {
    final type = activity['type'] ?? 'info';
    final color = service.getRoleColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['description'] ?? 'No description',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(activity['user'] ?? 'System',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(service.getTimeAgo(activity['timestamp']),
              style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }
}