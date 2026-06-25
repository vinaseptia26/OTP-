import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LogCategoryTabs extends StatelessWidget {
  final Map<String, String> categories;
  final String selectedCategory;
  final Map<String, int> logStats;
  final Color primaryBlue;
  final Function(String) onCategorySelected;
  final ScrollController? scrollController;

  final Map<String, _CategoryStyle> _categoryStyles = {
    'system': _CategoryStyle(
      icon: Icons.computer_rounded,
      gradient: [Color(0xFF4A90E2), Color(0xFF357ABD)],
    ),
    'user': _CategoryStyle(
      icon: Icons.people_alt_rounded,
      gradient: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    ),
    'overtime': _CategoryStyle(
      icon: Icons.work_history_rounded,
      gradient: [Color(0xFFFF9800), Color(0xFFF57C00)],
    ),
    'absensi': _CategoryStyle(
      icon: Icons.camera_alt_rounded,
      gradient: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
    ),
    'broadcast': _CategoryStyle(
      icon: Icons.campaign_rounded,
      gradient: [Color(0xFF009688), Color(0xFF00796B)],
    ),
    'backup': _CategoryStyle(
      icon: Icons.backup_rounded,
      gradient: [Color(0xFF607D8B), Color(0xFF455A64)],
    ),
    'export_import': _CategoryStyle(
      icon: Icons.swap_horiz_rounded,
      gradient: [Color(0xFF795548), Color(0xFF5D4037)],
    ),
    'error': _CategoryStyle(
      icon: Icons.error_outline_rounded,
      gradient: [Color(0xFFF44336), Color(0xFFD32F2F)],
    ),
    'login': _CategoryStyle(
      icon: Icons.login_rounded,
      gradient: [Color(0xFF2196F3), Color(0xFF1976D2)],
    ),
    'audit': _CategoryStyle(
      icon: Icons.history_rounded,
      gradient: [Color(0xFFFF5722), Color(0xFFE64A19)],
    ),
  };

  LogCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.logStats,
    required this.primaryBlue,
    required this.onCategorySelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header dengan spacing yang jelas
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              // Indikator visual
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, primaryBlue.withOpacity(0.3)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              // Title
              Text(
                'Kategori Log',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Badge total categories
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${categories.length} Kategori',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Clear separator for breathing space
        const SizedBox(height: 4),

        // Tabs Container dengan background subtle
        Container(
          height: 56, // Fixed height biar gak merembet
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: categories.entries.length,
            itemBuilder: (context, index) {
              final entry = categories.entries.elementAt(index);
              final isSelected = selectedCategory == entry.key;
              final count = logStats[entry.key] ?? 0;
              final style = _categoryStyles[entry.key] ??
                  _CategoryStyle(
                    icon: Icons.category_rounded,
                    gradient: [Colors.grey, Colors.grey[600]!],
                  );

              return Padding(
                padding: EdgeInsets.only(
                  right: index < categories.length - 1 ? 8 : 0,
                ),
                child: _buildPremiumChip(
                  context: context,
                  key: entry.key,
                  label: entry.value,
                  icon: style.icon,
                  isSelected: isSelected,
                  count: count,
                  gradientColors: style.gradient,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCategorySelected(entry.key);
                  },
                ),
              );
            },
          ),
        ),

        // Bottom spacing biar gak nempel widget bawah
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPremiumChip({
    required BuildContext context,
    required String key,
    required String label,
    required IconData icon,
    required bool isSelected,
    required int count,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: gradientColors.first.withOpacity(0.1),
        highlightColor: gradientColors.first.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : gradientColors.first.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon dengan animasi subtle
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : gradientColors.first.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : gradientColors.first,
                ),
              ),

              const SizedBox(width: 8),

              // Label
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                  letterSpacing: -0.2,
                ),
              ),

              // Count Badge (hanya tampil jika > 0)
              if (count > 0) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : gradientColors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 0.5,
                          )
                        : null,
                  ),
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: count),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) {
                      return Text(
                        _formatBadgeCount(value),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : gradientColors.first,
                          letterSpacing: 0.3,
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Selected indicator arrow
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatBadgeCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    if (count >= 100) return '99+';
    return count.toString();
  }
}

// Style class untuk setiap kategori
class _CategoryStyle {
  final IconData icon;
  final List<Color> gradient;

  const _CategoryStyle({
    required this.icon,
    required this.gradient,
  });
}