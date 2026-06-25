// lib/widgets/absensi/absensi_filter_chips.dart
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
          // 🔥 URGENT CHIP - Special styling with pulse effect
          _urgentChip('🔴 Mendesak', 'urgent'),
          const SizedBox(width: 10),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // Status chips
          _chip('📋 Semua', 'semua'),
          const SizedBox(width: 8),
          _chip('🟠 Belum Absen', 'belum_absen'),
          const SizedBox(width: 8),
          _chip('🟢 Sudah Absen', 'sudah_absen'),
          const SizedBox(width: 8),
          _chip('⏰ Kadaluarsa', 'kadaluarsa'),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  URGENT CHIP - Special attention grabber                               ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _urgentChip(String label, String value) {
    final isSelected = selectedStatus == value;

    return GestureDetector(
      onTap: () {
        // 🔥 Jika sudah selected, toggle ke 'semua'
        if (isSelected) {
          onStatusChanged('semua');
        } else {
          onStatusChanged(value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFEF5350), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFFEF5350).withValues(alpha: 0.1),
                    const Color(0xFFFF5252).withValues(alpha: 0.1),
                  ],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF5350)
                : const Color(0xFFEF5350).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 Pulsing dot animation
            _PulsingDot(isActive: isSelected),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : const Color(0xFFEF5350),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  REGULAR CHIP                                                           ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _chip(String label, String value) {
    final isSelected = selectedStatus == value;

    // Tentukan warna per chip
    Color chipColor;
    Color selectedBgColor;
    Color selectedBorderColor;

    switch (value) {
      case 'belum_absen':
        chipColor = const Color(0xFFFF9800);
        selectedBgColor = const Color(0xFFFF9800).withValues(alpha: 0.1);
        selectedBorderColor = const Color(0xFFFF9800);
        break;
      case 'sudah_absen':
        chipColor = const Color(0xFF4CAF50);
        selectedBgColor = const Color(0xFF4CAF50).withValues(alpha: 0.1);
        selectedBorderColor = const Color(0xFF4CAF50);
        break;
      case 'kadaluarsa':
        chipColor = const Color(0xFF9E9E9E);
        selectedBgColor = const Color(0xFF9E9E9E).withValues(alpha: 0.1);
        selectedBorderColor = const Color(0xFF9E9E9E);
        break;
      default: // 'semua'
        chipColor = const Color(0xFF1E3C72);
        selectedBgColor = const Color(0xFF1E3C72).withValues(alpha: 0.1);
        selectedBorderColor = const Color(0xFF1E3C72);
    }

    return GestureDetector(
      onTap: () {
        // 🔥 Jika sudah selected, toggle ke 'semua'
        if (isSelected) {
          onStatusChanged('semua');
        } else {
          onStatusChanged(value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? selectedBorderColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? chipColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            // 🔥 Small indicator dot when selected
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  PULSING DOT - Animated indicator for urgent items                      ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _PulsingDot extends StatefulWidget {
  final bool isActive;

  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFFEF5350).withValues(alpha: 0.6),
              shape: BoxShape.circle,
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
        );
      },
    );
  }
}