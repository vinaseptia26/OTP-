// lib/widgets/manager/manager_stat_card.dart
import 'package:flutter/material.dart';

class ManagerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String? badge;
  final VoidCallback? onTap;
  final int index;

  const ManagerStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.30),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                /// Decorative Circle - Top Right
                Positioned(
                  top: -25,
                  right: -25,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                /// Decorative Circle - Bottom Left
                Positioned(
                  bottom: -35,
                  left: -25,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),

                /// Small Dot Decoration
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),

                /// Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// TOP SECTION - Icon & Badge
                      Row(
                        children: [
                          // Icon Container
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),

                          const Spacer(),

                          // Badge
                          if (badge != null)
                            Container(
                              constraints: const BoxConstraints(maxWidth: 85),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                badge!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      /// VALUE - Diperkecil ukuran font
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Diperkecil dari 32 menjadi 24
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 6), // Dikurangi dari 8 menjadi 6

                      /// TITLE
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13, // Diperkecil dari 14 menjadi 13
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 3), // Dikurangi dari 4 menjadi 3

                      /// SUBTITLE
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10, // Diperkecil dari 11 menjadi 10
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}