import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogDetailSheet extends StatelessWidget {
  final Map<String, dynamic> log;
  final String Function(String) getLevelFromType;
  final Color primaryBlue;

  final Map<String, Color> _levelColors = const {
    'info': Color(0xFF2196F3),
    'warning': Color(0xFFFF9800),
    'error': Color(0xFFF44336),
    'success': Color(0xFF4CAF50),
    'debug': Color(0xFF9C27B0),
  };

  const LogDetailSheet({
    super.key,
    required this.log,
    required this.getLevelFromType,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info, color: levelColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Detail Log',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  _buildDetailRow('ID', log['id'] ?? '-'),
                  _buildDetailRow('Tipe', type),
                  _buildDetailRow('Level', level, color: levelColor),
                  _buildDetailRow(
                    'Waktu',
                    timestamp != null
                        ? DateFormat('EEEE, dd MMMM yyyy HH:mm:ss', 'id_ID')
                            .format(timestamp)
                        : '-',
                  ),
                  _buildDetailRow('User', log['user'] ?? 'system'),
                  _buildDetailRow('User Role', log['user_role'] ?? '-'),
                  if (log['target_user'] != null)
                    _buildDetailRow('Target User', log['target_user']),
                  if (log['session_id'] != null)
                    _buildDetailRow('Session ID', log['session_id']),
                  _buildDetailRow(
                    'Deskripsi',
                    log['description'] ?? '-',
                    isLong: true,
                  ),
                  if (log['data'] != null)
                    _buildDetailRow(
                      'Data',
                      log['data'].toString(),
                      isLong: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Tutup'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isLong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: color ?? Colors.black87,
              ),
              maxLines: isLong ? 10 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}