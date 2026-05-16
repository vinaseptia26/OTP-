import 'package:flutter/material.dart';

class OvertimeFilterChips extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const OvertimeFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  static const List<Map<String, dynamic>> _filters = [
    {'value': 'semua', 'label': 'Semua', 'color': Colors.grey},
    {'value': 'pending', 'label': 'Pending', 'color': Colors.orange},
    {'value': 'disetujui', 'label': 'Disetujui', 'color': Colors.green},
    {'value': 'ditolak', 'label': 'Ditolak', 'color': Colors.red},
    {'value': 'selesai', 'label': 'Selesai', 'color': Colors.blue},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = selectedStatus == filter['value'];
          final color = filter['color'] as Color;

          return FilterChip(
            label: Text(
              filter['label'] as String,
              style: const TextStyle(fontSize: 13),
            ),
            selected: isSelected,
            onSelected: (_) => onStatusChanged(filter['value'] as String),
            backgroundColor: Colors.white,
            selectedColor: color.withValues(alpha: 0.2),
            checkmarkColor: color,
            labelStyle: TextStyle(
              color: isSelected ? color : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? color : Colors.grey.shade300,
              ),
            ),
          );
        },
      ),
    );
  }
}