// lib/widgets/absensi/absensi_stats_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ GANTI: Import dari absensi service (sudah include OvertimeHistory + extension)
import '/core/services/overtime_absensi_service.dart';

class AbsensiStatsCard extends StatefulWidget {
  final OvertimeAbsensiService absensiService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String selectedBulan;

  const AbsensiStatsCard({
    super.key,
    required this.absensiService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    required this.selectedBulan,
  });

  @override
  State<AbsensiStatsCard> createState() => _AbsensiStatsCardState();
}

class _AbsensiStatsCardState extends State<AbsensiStatsCard> with SingleTickerProviderStateMixin {
  Map<String, int> _counts = {
    'total': 0,
    'belum': 0,
    'sudah': 0,
    'kadaluarsa': 0,
  };

  // 🔥 TENGGAT STATS
  Map<String, dynamic> _expirySummary = {
    'totalPending': 0,
    'akanExpired': 0,
    'kritis': 0,
    'warning': 0,
    'perhatian': 0,
    'aman': 0,
  };

  bool _loading = true;
  bool _showTenggat = false;
  Timer? _refreshTimer;

  // 🔥 Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation untuk urgent items
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadStats();
    
    // 🔥 Auto refresh setiap 2 menit
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _loadStats();
    });
  }

  @override
  void didUpdateWidget(covariant AbsensiStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBulan != widget.selectedBulan) {
      _loadStats();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // ✅ Load basic stats
      final stats = await widget.absensiService.getAbsensiStats(
        userId: widget.userId ?? '',
        bulan: widget.selectedBulan,
      );

      // 🔥 Load expiry summary
      final summary = await widget.absensiService.getExpirySummary(
        userId: widget.userId ?? '',
        bulan: widget.selectedBulan,
      );

      if (mounted) {
        final hasUrgent = (summary['akanExpired'] as int? ?? 0) > 0 ||
            (summary['kritis'] as int? ?? 0) > 0;

        setState(() {
          _counts = {
            'total': stats['total'] as int? ?? 0,
            'belum': stats['belumAbsen'] as int? ?? 0,
            'sudah': stats['sudahAbsen'] as int? ?? 0,
            'kadaluarsa': stats['expired'] as int? ?? 0,
          };
          _expirySummary = summary;
          _loading = false;
          _showTenggat = (summary['totalPending'] as int? ?? 0) > 0;
        });

        // 🔥 Start/stop pulse animation
        if (hasUrgent) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }
    } catch (e) {
      debugPrint('Error loading absensi stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //═══════════════════════════════════════════════════════
        // MAIN STATS CARD
        //═══════════════════════════════════════════════════════
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    // Main stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(
                          'Total',
                          _counts['total']!.toString(),
                          Icons.work_history_rounded,
                          subtitle: 'Lembur',
                        ),
                        _statItem(
                          'Belum',
                          _counts['belum']!.toString(),
                          Icons.pending_actions_rounded,
                          color: Colors.orange,
                          subtitle: 'Pending',
                        ),
                        _statItem(
                          'Sudah',
                          _counts['sudah']!.toString(),
                          Icons.check_circle_rounded,
                          color: const Color(0xFF66BB6A),
                          subtitle: 'Absen',
                        ),
                        _statItem(
                          'Expired',
                          _counts['kadaluarsa']!.toString(),
                          Icons.timer_off_rounded,
                          color: const Color(0xFF9E9E9E),
                          subtitle: 'Kadaluarsa',
                        ),
                      ],
                    ),

                    // 🔥 Persentase progress bar
                    if (_counts['total']! > 0) ...[
                      const SizedBox(height: 16),
                      _buildOverallProgress(),
                    ],

                    // 🔥 Expand/collapse tenggat detail
                    if (_showTenggat) ...[
                      const SizedBox(height: 12),
                      _buildExpandButton(),
                    ],
                  ],
                ),
        ),

        //═══════════════════════════════════════════════════════
        // 🔥 TENGGAT DETAIL SECTION (Expandable)
        //═══════════════════════════════════════════════════════
        if (_showTenggat && _hasExpandedTenggat) _buildTenggatDetailSection(),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  OVERALL PROGRESS BAR                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildOverallProgress() {
    final total = _counts['total']!;
    final sudah = _counts['sudah']!;
    final percent = total > 0 ? (sudah / total) : 0.0;
    final percentText = '${(percent * 100).toStringAsFixed(0)}%';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress Absensi',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$sudah/$total ($percentText)',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              percent >= 0.8
                  ? const Color(0xFF66BB6A)
                  : percent >= 0.5
                      ? const Color(0xFFFFC107)
                      : const Color(0xFFFF9800),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  EXPAND BUTTON                                                          ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  bool _hasExpandedTenggat = false;

  Widget _buildExpandButton() {
    final akanExpired = (_expirySummary['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary['kritis'] as int?) ?? 0;
    final totalUrgent = akanExpired + kritis;

    return GestureDetector(
      onTap: () {
        setState(() {
          _hasExpandedTenggat = !_hasExpandedTenggat;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔥 Pulsing indicator untuk urgent items
            if (totalUrgent > 0)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            
            Text(
              _hasExpandedTenggat ? 'Sembunyikan Detail' : 'Lihat Detail Tenggat',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _hasExpandedTenggat
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
            if (totalUrgent > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalUrgent Urgent',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  TENGGAT DETAIL SECTION                                                 ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildTenggatDetailSection() {
    final akanExpired = (_expirySummary['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary['kritis'] as int?) ?? 0;
    final warning = (_expirySummary['warning'] as int?) ?? 0;
    final perhatian = (_expirySummary['perhatian'] as int?) ?? 0;
    final aman = (_expirySummary['aman'] as int?) ?? 0;
    final totalPending = (_expirySummary['totalPending'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 18, color: Color(0xFF1E3C72)),
              const SizedBox(width: 8),
              Text(
                'Detail Status Tenggat',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3C72),
                ),
              ),
              const Spacer(),
              Text(
                '$totalPending Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🔥 Tenggat progress overview
          _buildTenggatProgressOverview(),

          const SizedBox(height: 16),

          // Detail cards grid
          Row(
            children: [
              Expanded(
                child: _tenggatDetailCard(
                  label: 'Kadaluarsa',
                  count: akanExpired,
                  color: const Color(0xFFEF5350),
                  icon: Icons.timer_off_rounded,
                  emoji: '🔥',
                  description: '< 1 jam',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tenggatDetailCard(
                  label: 'Kritis',
                  count: kritis,
                  color: const Color(0xFFFF9800),
                  icon: Icons.hourglass_bottom_rounded,
                  emoji: '🔴',
                  description: '1-2 jam',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _tenggatDetailCard(
                  label: 'Warning',
                  count: warning,
                  color: const Color(0xFFFFC107),
                  icon: Icons.hourglass_top_rounded,
                  emoji: '🟠',
                  description: '2-6 jam',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tenggatDetailCard(
                  label: 'Perhatian',
                  count: perhatian,
                  color: const Color(0xFF42A5F5),
                  icon: Icons.info_outline_rounded,
                  emoji: '🟡',
                  description: '6-24 jam',
                ),
              ),
            ],
          ),

          if (aman > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _tenggatDetailCard(
                    label: 'Aman',
                    count: aman,
                    color: const Color(0xFF66BB6A),
                    icon: Icons.check_circle_outline_rounded,
                    emoji: '🟢',
                    description: '> 24 jam',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],

          // 🔥 Overall urgency indicator
          if (totalPending > 0) ...[
            const SizedBox(height: 16),
            _buildUrgencyMeter(totalPending),
          ],
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  TENGGAT PROGRESS OVERVIEW                                              ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildTenggatProgressOverview() {
    final akanExpired = (_expirySummary['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary['kritis'] as int?) ?? 0;
    final warning = (_expirySummary['warning'] as int?) ?? 0;
    final perhatian = (_expirySummary['perhatian'] as int?) ?? 0;
    final aman = (_expirySummary['aman'] as int?) ?? 0;
    final totalPending = (_expirySummary['totalPending'] as int?) ?? 0;

    if (totalPending == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (akanExpired > 0)
              Flexible(
                flex: akanExpired,
                child: Container(color: const Color(0xFFEF5350)),
              ),
            if (kritis > 0)
              Flexible(
                flex: kritis,
                child: Container(color: const Color(0xFFFF9800)),
              ),
            if (warning > 0)
              Flexible(
                flex: warning,
                child: Container(color: const Color(0xFFFFC107)),
              ),
            if (perhatian > 0)
              Flexible(
                flex: perhatian,
                child: Container(color: const Color(0xFF42A5F5)),
              ),
            if (aman > 0)
              Flexible(
                flex: aman,
                child: Container(color: const Color(0xFF66BB6A)),
              ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  TENGGAT DETAIL CARD                                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _tenggatDetailCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required String emoji,
    required String description,
  }) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  URGENCY METER                                                          ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildUrgencyMeter(int totalPending) {
    final akanExpired = (_expirySummary['akanExpired'] as int?) ?? 0;
    final kritis = (_expirySummary['kritis'] as int?) ?? 0;
    final urgentCount = akanExpired + kritis;

    // Tentukan tingkat urgensi
    String urgensiLevel;
    Color urgensiColor;
    IconData urgensiIcon;

    if (akanExpired > 0) {
      urgensiLevel = 'KRITIS';
      urgensiColor = const Color(0xFFEF5350);
      urgensiIcon = Icons.warning_rounded;
    } else if (kritis > 0) {
      urgensiLevel = 'TINGGI';
      urgensiColor = const Color(0xFFFF9800);
      urgensiIcon = Icons.error_outline_rounded;
    } else if (urgentCount == 0) {
      urgensiLevel = 'AMAN';
      urgensiColor = const Color(0xFF66BB6A);
      urgensiIcon = Icons.check_circle_rounded;
    } else {
      urgensiLevel = 'NORMAL';
      urgensiColor = const Color(0xFF42A5F5);
      urgensiIcon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: urgensiColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgensiColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(urgensiIcon, color: urgensiColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $urgensiLevel',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: urgensiColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  urgentCount > 0
                      ? '$urgentCount lembur butuh perhatian segera!'
                      : 'Semua lembur dalam batas aman',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Progress ring
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: totalPending > 0
                  ? (totalPending - urgentCount) / totalPending
                  : 1.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(urgensiColor),
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  STAT ITEM (MAIN CARD)                                                  ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _statItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
    String? subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
      ],
    );
  }
}