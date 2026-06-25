// lib/widgets/ajukan_lembur/alasan_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class AlasanSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;

  const AlasanSection({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Alasan Lembur',
      icon: Icons.description_outlined,
      iconColor: const Color(0xFF7B1FA2), // Purple
      children: [
        Text(
          'Jelaskan alasan lembur secara detail',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            hintText: 'Tulis alasan lembur (minimal 20 karakter)...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Alasan lembur harus diisi';
            }
            if (value.trim().length < 20) {
              return 'Alasan minimal 20 karakter (${value.trim().length}/20)';
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '${controller.text.length}/500 karakter',
              style: TextStyle(
                fontSize: 11,
                color: controller.text.length >= 20
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (controller.text.length >= 20)
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade600)
            else if (controller.text.isNotEmpty)
              Text(
                'min. 20 karakter',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}