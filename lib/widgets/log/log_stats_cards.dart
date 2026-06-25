import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LogStatsCards extends StatelessWidget {
  final Map<String, int> logStats;
  final int totalLogs;
  final Color primaryBlue;
  final bool isLoading;
  final String? errorMessage;
  final Function(String statType)? onCardTap;

  const LogStatsCards({
    super.key,
    required this.logStats,
    required this.totalLogs,
    required this.primaryBlue,
    this.isLoading = false,
    this.errorMessage,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _buildStatsList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact Header
        _buildCompactHeader(context, stats.length),

        const SizedBox(height: 8),

        // Content
        if (isLoading)
          _buildCompactLoading()
        else if (errorMessage != null)
          _buildCompactError(context)
        else
          _buildUltraCompactGrid(context, stats),
      ],
    );
  }

  // Header super compact
  Widget _buildCompactHeader(BuildContext context, int totalStats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Statistik',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (totalStats > 6)
            GestureDetector(
              onTap: () => _showCompactBottomSheet(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Semua',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16, color: primaryBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // GRID ULTRA COMPACT - 3 kolom fixed, super hemat tempat
  Widget _buildUltraCompactGrid(BuildContext context, List<_StatItem> stats) {
    final displayStats = stats.take(6).toList(); // Max 6 items

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4, // Lebih lebar dari tinggi = hemat vertikal
        ),
        itemCount: displayStats.length,
        itemBuilder: (context, index) {
          return _buildMicroCard(context, displayStats[index], index);
        },
      ),
    );
  }

  // MICRO CARD - Paling hemat ruang
  Widget _buildMicroCard(BuildContext context, _StatItem stat, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onCardTap?.call(stat.title);
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: stat.color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : stat.color.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Row 1: Icon & Count (horizontal untuk hemat vertikal)
              Row(
                children: [
                  // Mini icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: stat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stat.icon,
                      color: stat.color,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Count number
                  Expanded(
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: stat.count),
                      duration: Duration(milliseconds: 600 + (index * 80)),
                      builder: (context, value, child) {
                        return Text(
                          _formatCompact(value),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            height: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Row 2: Title
              Text(
                stat.title,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Mini progress bar untuk indikasi visual
              if (stat.count > 0) ...[
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: stat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _calculateProgressFactor(stat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: stat.color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgressFactor(_StatItem stat) {
    // Progress relatif terhadap total logs
    if (totalLogs == 0) return 0;
    return (stat.count / totalLogs).clamp(0.05, 1.0);
  }

  // Compact loading - 6 card skeletons
  Widget _buildCompactLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    primaryBlue.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Compact error
  Widget _buildCompactError(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage ?? 'Gagal memuat statistik',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red[400],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Retry callback bisa ditambahkan
            },
            child: Text(
              'Coba Lagi',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact bottom sheet
  void _showCompactBottomSheet(BuildContext context) {
    final allStats = _buildStatsList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Semua Statistik',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Grid
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: allStats.length,
                itemBuilder: (context, index) {
                  return _buildMicroCard(context, allStats[index], index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_StatItem> _buildStatsList() {
    return [
      _StatItem('Total', totalLogs, Icons.analytics_outlined, primaryBlue),
      _StatItem(
        'User',
        logStats['user'] ?? 0,
        Icons.people_alt_outlined,
        const Color(0xFF4CAF50),
      ),
      _StatItem(
        'Lembur',
        logStats['overtime'] ?? 0,
        Icons.work_history_outlined,
        const Color(0xFFFF9800),
      ),
      _StatItem(
        'Absensi',
        logStats['absensi'] ?? 0,
        Icons.camera_alt_outlined,
        const Color(0xFF9C27B0),
      ),
      _StatItem(
        'Error',
        logStats['error'] ?? 0,
        Icons.error_outline,
        const Color(0xFFF44336),
      ),
      _StatItem(
        'Broadcast',
        logStats['broadcast'] ?? 0,
        Icons.campaign_outlined,
        const Color(0xFF009688),
      ),
    ];
  }

  String _formatCompact(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}JT';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}RB';
    if (count >= 100) return count.toString();
    return count.toString();
  }
}

class _StatItem {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  _StatItem(this.title, this.count, this.icon, this.color);
}