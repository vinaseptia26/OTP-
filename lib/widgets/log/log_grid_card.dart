import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogGridCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final String Function(String) getLevelFromType;
  final VoidCallback onTap;

  final Map<String, Color> _levelColors = const {
    'info': Color(0xFF2196F3),
    'warning': Color(0xFFFF9800),
    'error': Color(0xFFF44336),
    'success': Color(0xFF4CAF50),
    'debug': Color(0xFF9C27B0),
  };

  const LogGridCard({
    super.key,
    required this.log,
    required this.getLevelFromType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;
    final description = log['description'] ?? '';
    final user = log['user'] ?? 'system';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.info, color: levelColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: levelColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timestamp != null
                        ? DateFormat('HH:mm').format(timestamp)
                        : '-',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  style: GoogleFonts.poppins(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF1E3C72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}