// lib/features/pengawas/lembur/widgets/submit_button.dart
import 'package:flutter/material.dart';

class SubmitButton extends StatelessWidget {
  final bool isComplete;
  final bool hasDuplicateMitra;
  final double completionPercentage;
  final VoidCallback onPressed;

  const SubmitButton({
    super.key,
    required this.isComplete,
    required this.hasDuplicateMitra,
    required this.completionPercentage,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasDuplicateMitra) _buildDuplicateWarning(),
        _buildButton(),
        if (!isComplete && completionPercentage > 0) _buildProgressText(),
      ],
    );
  }

  Widget _buildDuplicateWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Hapus mitra duplikat untuk melanjutkan pengajuan",
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isComplete
            ? const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              )
            : LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade400],
              ),
        boxShadow: isComplete
            ? [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isComplete ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isComplete) ...[
                  const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(
                  isComplete ? "AJUKAN LEMBUR" : "LENGKAPI DATA",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isComplete ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressText() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        "${(completionPercentage * 100).toInt()}% data terisi",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}