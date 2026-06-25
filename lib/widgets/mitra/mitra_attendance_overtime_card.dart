// lib/widgets/mitra/mitra_attendance_overtime_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/mitra_service.dart';
import '../../core/services/overtime_history_service.dart';
import '../../core/services/live_location_service.dart';
import '/widgets/absensi/absensi_dialog.dart';

class MitraAttendanceOvertimeCard extends StatefulWidget {
  final Map<String, dynamic>? attendanceData;
  final Map<String, dynamic>? overtime;
  final List<Map<String, dynamic>>? upcomingSchedules;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final bool canCheckIn;
  final String formattedCheckInTime;
  final String userName;
  final Map<String, dynamic> overtimeSettings;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback? onViewAllSchedules;

  const MitraAttendanceOvertimeCard({
    super.key,
    this.attendanceData,
    this.overtime,
    this.upcomingSchedules,
    required this.isCheckedIn,
    required this.isCheckedOut,
    required this.canCheckIn,
    required this.formattedCheckInTime,
    required this.userName,
    required this.overtimeSettings,
    required this.onCheckIn,
    required this.onCheckOut,
    this.onViewAllSchedules,
  });

  @override
  State<MitraAttendanceOvertimeCard> createState() =>
      _MitraAttendanceOvertimeCardState();
}

class _MitraAttendanceOvertimeCardState
    extends State<MitraAttendanceOvertimeCard>
    with SingleTickerProviderStateMixin {
  final _service = MitraService();
  bool _isLoadingAction = false;
  bool _showUpcomingExpanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isLoadingAction = true);
    try {
      final overtimeItem =
          await OvertimeHistoryService().getOvertimeById(widget.overtime!['id']);

      if (overtimeItem == null) {
        if (mounted) _showSnackBar('Data lembur tidak ditemukan', false);
        return;
      }

      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
      if (absensiSuccess == true && mounted) {
        await LiveLocationService().stopTracking();
        final income = await _service.checkOutLembur(
          widget.overtime!['id'],
          widget.userName,
          widget.overtimeSettings,
        );
        if (mounted) {
          widget.onCheckOut();
          _showSnackBar(
            '✅ Check-out berhasil! Pendapatan: Rp ${NumberFormat('#,###').format(income)}',
            true,
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal check-out: $e', false);
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _showSnackBar(String message, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: success ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.12,
          ),
          duration: const Duration(seconds: 4),
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final futureSchedules = widget.upcomingSchedules
            ?.where((s) => _calculateDaysLeft(s['date']?.toString() ?? '') > 0)
            .toList() ??
        [];

    // Jika tidak ada data lembur dan tidak ada jadwal mendatang, return empty
    if (widget.overtime == null && futureSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Card Lembur
        if (widget.overtime != null) ...[
          _buildOvertimeCard(),
        ],
        // Card Jadwal Mendatang
        if (futureSchedules.isNotEmpty) ...[
          if (widget.overtime != null) const SizedBox(height: 16),
          _buildFutureScheduleCard(futureSchedules),
        ],
      ],
    );
  }

  Widget _buildOvertimeCard() {
    final ot = widget.overtime!;
    final jamMulai = ot['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = ot['jam_selesai']?.toString() ?? '22:00';
    final deskripsi = ot['description']?.toString() ?? 'Lembur Rutin';
    final lokasi = ot['location']?.toString() ?? 'PLTP Kamojang';

    final Color primaryColor;
    final Color secondaryColor;
    final String statusText;
    final String statusEmoji;
    final IconData statusIcon;

    if (widget.isCheckedOut) {
      primaryColor = const Color(0xFF1B5E20);
      secondaryColor = const Color(0xFF4CAF50);
      statusText = 'Lembur Selesai';
      statusEmoji = '✅';
      statusIcon = Icons.check_circle_rounded;
    } else if (widget.isCheckedIn) {
      primaryColor = const Color(0xFFE65100);
      secondaryColor = const Color(0xFFFF9800);
      statusText = 'Sedang Lembur';
      statusEmoji = '🔵';
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      primaryColor = const Color(0xFFFF6B35);
      secondaryColor = const Color(0xFFFF8A65);
      statusText = 'Jadwal Lembur';
      statusEmoji = '📅';
      statusIcon = Icons.notifications_active_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$statusEmoji $statusText',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            deskripsi,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$jamMulai - $jamSelesai',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          if (!widget.isCheckedOut)
                            widget.isCheckedIn
                                ? _buildActionButton(
                                    'Check Out',
                                    Icons.logout_rounded,
                                    const Color(0xFFE53935),
                                    _isLoadingAction,
                                    _handleCheckOut,
                                  )
                                : widget.canCheckIn
                                    ? ScaleTransition(
                                        scale: _pulseAnimation,
                                        child: _buildActionButton(
                                          'Check In',
                                          Icons.login_rounded,
                                          const Color(0xFF43A047),
                                          _isLoadingAction,
                                          widget.onCheckIn,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.schedule_rounded,
                                            color: Colors.white70,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Mulai ${widget.formattedCheckInTime}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                        ],
                      ),
                      if (lokasi.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white60,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lokasi,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildFutureScheduleCard(List<Map<String, dynamic>> futureSchedules) {
    final hasManySchedules = futureSchedules.length > 2;
    final displaySchedules = _showUpcomingExpanded
        ? futureSchedules
        : futureSchedules.take(2).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        color: Colors.yellowAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Jadwal Mendatang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellowAccent
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${futureSchedules.length} jadwal',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF4A148C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Persiapkan diri untuk lembur berikutnya! 💪',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onViewAllSchedules != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onViewAllSchedules,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...displaySchedules.asMap().entries.map(
                      (entry) =>
                          _buildScheduleItem(entry.value, entry.key),
                    ),
                if (hasManySchedules) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(
                        () => _showUpcomingExpanded = !_showUpcomingExpanded,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showUpcomingExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showUpcomingExpanded
                                  ? 'Sembunyikan'
                                  : 'Lihat ${futureSchedules.length - 2} jadwal lainnya',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule, int index) {
    final date = schedule['date']?.toString() ?? '';
    final jamMulai = schedule['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = schedule['jam_selesai']?.toString() ?? '--:--';
    final description = schedule['description']?.toString() ?? 'Lembur Rutin';
    final status = schedule['status']?.toString() ?? 'scheduled';
    final int daysLeft = _calculateDaysLeft(date);
    final bool isTomorrow = daysLeft == 1;

    final Color statusColor = status == 'in_progress'
        ? const Color(0xFFFF6B35)
        : status == 'completed'
            ? const Color(0xFF00C853)
            : const Color(0xFFFFAB40);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator bar
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTomorrow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BESOK',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$jamMulai - $jamSelesai',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    const Spacer(),
                    if (daysLeft > 0 && daysLeft <= 7)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysLeft hari lagi',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.yellowAccent.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
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
    );
  }

  int _calculateDaysLeft(String dateStr) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduleDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateStr);
      final scheduleDay = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
      );
      return scheduleDay.difference(today).inDays;
    } catch (e) {
      return 999;
    }
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isLoading ? 'Memproses...' : label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Pagi';
    if (hour < 15) return 'Siang';
    if (hour < 19) return 'Sore';
    return 'Malam';
  }
}