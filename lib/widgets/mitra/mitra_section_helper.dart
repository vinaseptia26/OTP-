// lib/widgets/mitra/mitra_section_helper.dart
import 'package:flutter/material.dart';

class MitraCorporateDivider extends StatelessWidget {
  final String title;
  
  const MitraCorporateDivider({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1565C0),
              letterSpacing: 1.5,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), thickness: 1),
        ),
      ],
    );
  }
}