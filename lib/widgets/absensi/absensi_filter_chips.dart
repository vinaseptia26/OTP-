import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AbsensiFilterChips extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const AbsensiFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip('Semua', 'semua'),
          const SizedBox(width: 8),
          _chip('Belum Absen', 'belum_absen'),
          const SizedBox(width: 8),
          _chip('Sudah Absen', 'sudah_absen'),
          const SizedBox(width: 8),
          _chip('Kadaluarsa', 'kadaluarsa'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = selectedStatus == value;
    final color = isSelected ? const Color(0xFF1976D2) : Colors.grey.shade300;
    return GestureDetector(
      onTap: () => onStatusChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF1976D2) : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}