import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthPickerSheet {
  static void show(BuildContext context, {
    required String selectedMonth,
    required ValueChanged<String> onMonthSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final now = DateTime.now();
        final months = List.generate(12, (i) {
          final date = DateTime(now.year, now.month - i, 1);
          return {
            'value': DateFormat('yyyy-MM').format(date),
            'display': DateFormat('MMMM yyyy', 'id_ID').format(date),
          };
        });
        return ListView(
          shrinkWrap: true,
          children: months.map((m) {
            final isSelected = m['value'] == selectedMonth;
            return ListTile(
              title: Text(m['display']!),
              selected: isSelected,
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                onMonthSelected(m['value']!);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        );
      },
    );
  }
}