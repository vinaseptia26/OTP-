// lib/widgets/ajukan_lembur/waktu_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class WaktuSection extends StatelessWidget {
  final DateTime? tanggalLembur;
  final TimeOfDay? jamMulai;
  final TimeOfDay? jamSelesai;
  final double totalJam;
  final Function(DateTime?) onTanggalChanged;
  final Function(TimeOfDay) onJamMulaiChanged;
  final Function(TimeOfDay) onJamSelesaiChanged;
  final VoidCallback onClear;
  final String Function(TimeOfDay) formatTime;
  final String Function(DateTime) formatTanggal;

  const WaktuSection({
    super.key,
    this.tanggalLembur,
    this.jamMulai,
    this.jamSelesai,
    required this.totalJam,
    required this.onTanggalChanged,
    required this.onJamMulaiChanged,
    required this.onJamSelesaiChanged,
    required this.onClear,
    required this.formatTime,
    required this.formatTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Waktu Lembur',
      icon: Icons.access_time_filled_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: [
        // Info waktu lembur
        _buildTimeInfo(),
        const SizedBox(height: 16),
        
        // Tanggal picker
        _buildTanggalPicker(context),
        
        // Time pickers
        if (tanggalLembur != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  context: context,
                  label: 'Jam Mulai',
                  time: jamMulai,
                  isJamMulai: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePicker(
                  context: context,
                  label: 'Jam Selesai',
                  time: jamSelesai,
                  isJamMulai: false,
                ),
              ),
            ],
          ),
        ],
        
        // Time summary
        if (totalJam > 0) ...[
          const SizedBox(height: 16),
          _buildTimeSummary(),
        ],
        
        // Clear button
        if (tanggalLembur != null) ...[
          const SizedBox(height: 12),
          _buildClearButton(),
        ],
      ],
    );
  }

  Widget _buildTimeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lembur dihitung setelah jam kerja normal (17:00 - selesai)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalPicker(BuildContext context) {
    final isWeekend = tanggalLembur != null &&
        (tanggalLembur!.weekday == DateTime.saturday ||
            tanggalLembur!.weekday == DateTime.sunday);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final selectedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 60)),
            locale: const Locale('id', 'ID'),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF1976D2),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (selectedDate != null) {
            onTanggalChanged(selectedDate);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: tanggalLembur == null
                  ? const Color(0xFFE2E8F0)
                  : isWeekend
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF1976D2),
              width: tanggalLembur == null ? 1 : 2,
            ),
            borderRadius: BorderRadius.circular(14),
            color: tanggalLembur == null
                ? const Color(0xFFF8FAFF)
                : isWeekend
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFF5F8FF),
            boxShadow: tanggalLembur != null
                ? [
                    BoxShadow(
                      color: (isWeekend
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF1976D2))
                          .withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tanggalLembur == null
                      ? Colors.grey.shade100
                      : isWeekend
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 22,
                  color: tanggalLembur == null
                      ? const Color(0xFFA0AEC0)
                      : isWeekend
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal Lembur',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tanggalLembur == null
                          ? 'Pilih tanggal'
                          : formatTanggal(tanggalLembur!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tanggalLembur == null
                            ? const Color(0xFFA0AEC0)
                            : const Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ),
              if (tanggalLembur != null)
                Row(
                  children: [
                    if (isWeekend)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.beach_access_rounded,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Libur',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ],
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required BuildContext context,
    required String label,
    required TimeOfDay? time,
    required bool isJamMulai,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (tanggalLembur == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Pilih tanggal terlebih dahulu'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.orange.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }

          final selectedTime = await showTimePicker(
            context: context,
            initialTime: isJamMulai
                ? const TimeOfDay(hour: 17, minute: 0)
                : const TimeOfDay(hour: 21, minute: 0),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF1976D2),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (selectedTime != null) {
            if (isJamMulai) {
              onJamMulaiChanged(selectedTime);
            } else {
              onJamSelesaiChanged(selectedTime);
            }
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: time == null
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF1976D2),
              width: time == null ? 1 : 2,
            ),
            borderRadius: BorderRadius.circular(14),
            color: time == null
                ? const Color(0xFFF8FAFF)
                : const Color(0xFFF5F8FF),
            boxShadow: time != null
                ? [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: time == null
                      ? const Color(0xFFA0AEC0)
                      : const Color(0xFF1976D2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: time == null
                          ? Colors.grey.shade100
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: time == null
                            ? Colors.transparent
                            : const Color(0xFF1976D2).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      isJamMulai
                          ? Icons.login_rounded
                          : Icons.logout_rounded,
                      size: 18,
                      color: time == null
                          ? const Color(0xFFA0AEC0)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      time == null ? '--:--' : formatTime(time),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: time == null
                            ? const Color(0xFFA0AEC0)
                            : const Color(0xFF212121),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (time != null)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: const Color(0xFF1976D2).withValues(alpha: 0.5),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSummary() {
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday ||
        tanggalLembur!.weekday == DateTime.sunday;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWeekend
              ? [const Color(0xFFFFF8E1), const Color(0xFFFFE0B2)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWeekend
              ? Colors.orange.shade200
              : Colors.green.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isWeekend
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF2E7D32))
                .withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isWeekend
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.timer_rounded,
              size: 24,
              color: isWeekend
                  ? const Color(0xFFFF9800)
                  : const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durasi Lembur',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWeekend
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatTime(jamMulai!)} - ${formatTime(jamSelesai!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isWeekend
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isWeekend
                    ? Colors.orange.shade300
                    : Colors.green.shade300,
              ),
            ),
            child: Text(
              '${totalJam.toStringAsFixed(1)} jam',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isWeekend
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.clear_all_rounded, size: 18),
        label: const Text(
          'Reset Waktu',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: Colors.red.shade50,
        ),
        onPressed: onClear,
      ),
    );
  }
}