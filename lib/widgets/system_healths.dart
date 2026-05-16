// lib/widgets/system_health.dart
import 'package:flutter/material.dart';

class SystemHealthWidget extends StatelessWidget {
  final Map<String, dynamic> healthData;
  final Color? accentColor;
  final String? Function(dynamic)? getTimeAgo;
  final dynamic lastBackup;

  const SystemHealthWidget({
    super.key,
    required this.healthData,
    this.accentColor,
    this.getTimeAgo,
    this.lastBackup,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF1E3C72);

    final database = healthData['database'] ?? 98;
    final api = healthData['api'] ?? 95;
    final storage = healthData['storage'] ?? 76;
    final memory = healthData['memory'] ?? 82;
    final cpu = healthData['cpu'] ?? 23;
    final network = healthData['network'] ?? 45;
    final uptime = healthData['uptime'] ?? 15;

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
            children: [
              Icon(Icons.health_and_safety, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kesehatan Sistem',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Health indicators
          Row(
            children: [
              _buildHealthIndicator('Database', database, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('API', api, Colors.green),
              const SizedBox(width: 12),
              _buildHealthIndicator('Storage', storage, 
                  storage > 80 ? Colors.green : Colors.orange),
              const SizedBox(width: 12),
              _buildHealthIndicator('Memory', memory, 
                  memory > 80 ? Colors.green : Colors.orange),
            ],
          ),
          const SizedBox(height: 16),

          // System info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem('CPU', '$cpu%', Icons.speed),
              _buildInfoItem('Network', '$network Mbps', Icons.network_check),
              _buildInfoItem('Uptime', '$uptime hari', Icons.timer),
            ],
          ),

          // Last backup (opsional)
          if (lastBackup != null && getTimeAgo != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.backup, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Last Backup: ${getTimeAgo!(lastBackup)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            Text(value,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}