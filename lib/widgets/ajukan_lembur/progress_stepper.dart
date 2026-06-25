// lib/widgets/ajukan_lembur/progress_stepper.dart
import 'package:flutter/material.dart';

class ProgressStepper extends StatelessWidget {
  final double completionPercentage;
  final bool hasMitra;
  final bool hasTanggal;
  final bool hasWaktu;
  final bool hasLokasi;
  final bool hasAlasan;

  const ProgressStepper({
    super.key,
    required this.completionPercentage,
    this.hasMitra = false,
    this.hasTanggal = false,
    this.hasWaktu = false,
    this.hasLokasi = false,
    this.hasAlasan = false,
  });

  int get _currentStep {
    if (hasAlasan && hasLokasi && hasWaktu && hasTanggal && hasMitra) return 4;
    if (hasLokasi && hasWaktu && hasTanggal && hasMitra) return 3;
    if (hasWaktu && hasTanggal && hasMitra) return 2;
    if (hasTanggal && hasMitra) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(icon: Icons.people_alt_rounded, label: "Mitra"),
      _StepData(icon: Icons.access_time_rounded, label: "Waktu"),
      _StepData(icon: Icons.location_on_rounded, label: "Lokasi"),
      _StepData(icon: Icons.description_rounded, label: "Alasan"),
      _StepData(icon: Icons.check_circle_rounded, label: "Selesai"),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // ✅ Fix deprecated
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _buildStepCircle(
                  icon: steps[i].icon,
                  label: steps[i].label,
                  isActive: _currentStep > i,
                  isCurrent: _currentStep == i,
                  stepNumber: i + 1,
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: _currentStep > i
                            ? const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade300
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionPercentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(completionPercentage * 100).toInt()}% Lengkap",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: completionPercentage > 0.5
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCurrent,
    required int stepNumber,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  )
                : isCurrent
                    ? const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade200, Colors.grey.shade300],
                      ),
            boxShadow: isActive || isCurrent
                ? [
                    BoxShadow(
                      color: (isActive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF1976D2))
                          .withValues(alpha: 0.4), // ✅ Fix deprecated
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : isCurrent
                    ? Icon(icon, size: 20, color: Colors.white)
                    : Text(
                        stepNumber.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive || isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? const Color(0xFF2E7D32)
                : isCurrent
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  const _StepData({required this.icon, required this.label});
}