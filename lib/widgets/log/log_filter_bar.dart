import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogFilterBar extends StatelessWidget {
  final String selectedLevel;
  final String selectedUser;
  final DateTimeRange? selectedDateRange;
  final Map<String, int> topUsers;
  final Color accentBlue;
  final Function(String) onLevelChanged;
  final Function(String) onUserChanged;
  final VoidCallback onDateRangeCleared;

  final List<Map<String, dynamic>> _levelOptions = const [
    {'value': 'all', 'label': 'Semua Level', 'color': Colors.grey},
    {'value': 'info', 'label': 'Info', 'color': Color(0xFF2196F3)},
    {'value': 'warning', 'label': 'Warning', 'color': Color(0xFFFF9800)},
    {'value': 'error', 'label': 'Error', 'color': Color(0xFFF44336)},
    {'value': 'success', 'label': 'Success', 'color': Color(0xFF4CAF50)},
    {'value': 'debug', 'label': 'Debug', 'color': Color(0xFF9C27B0)},
  ];

  LogFilterBar({
    super.key,
    required this.selectedLevel,
    required this.selectedUser,
    required this.selectedDateRange,
    required this.topUsers,
    required this.accentBlue,
    required this.onLevelChanged,
    required this.onUserChanged,
    required this.onDateRangeCleared,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedLevel,
              decoration: InputDecoration(
                labelText: 'Level',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _levelOptions.map((level) {
                return DropdownMenuItem(
                  value: level['value'] as String,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: level['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        level['label'] as String,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => onLevelChanged(value!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedUser,
              decoration: InputDecoration(
                labelText: 'User',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Semua User'),
                ),
                ...topUsers.keys.take(10).map((user) => DropdownMenuItem(
                  value: user,
                  child: Text(
                    user,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                )),
              ],
              onChanged: (value) => onUserChanged(value!),
            ),
          ),
          if (selectedDateRange != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 14, color: accentBlue),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: accentBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDateRangeCleared,
                    child: Icon(Icons.close, size: 12, color: accentBlue),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}