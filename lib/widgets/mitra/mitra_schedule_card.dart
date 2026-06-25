// lib/widgets/mitra/mitra_schedule_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';  // ✅ TAMBAHKAN IMPORT INI
import 'package:intl/intl.dart';

class MitraScheduleCard extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;

  const MitraScheduleCard({
    super.key,
    required this.schedules,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6A1B9A).withAlpha(30), const Color(0xFF8E24AA).withAlpha(20)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF6A1B9A)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '📅 Jadwal Lembur Minggu Ini',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2B4C)),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/full-schedule'),  // ✅ Sekarang berfungsi karena ada import go_router
                child: const Text('Semua', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...schedules.take(3).map((schedule) => _buildScheduleItem(schedule)),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final date = schedule['date']?.toString() ?? '';
    final jamMulai = schedule['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = schedule['jam_selesai']?.toString() ?? '--:--';
    final description = schedule['description']?.toString() ?? 'Lembur Rutin';
    final status = schedule['status']?.toString() ?? 'scheduled';

    final Map<String, Color> statusColor = {
      'scheduled': const Color(0xFF1565C0),
      'in_progress': const Color(0xFFFF6B35),
      'completed': const Color(0xFF00C853),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF5F5F5), Colors.grey.withAlpha(20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor[status] ?? const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A2B4C)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$jamMulai - $jamSelesai',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (statusColor[status] ?? const Color(0xFF1565C0)).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status == 'scheduled' ? 'Terjadwal' : status == 'in_progress' ? 'Berjalan' : 'Selesai',
              style: TextStyle(
                fontSize: 9,
                color: statusColor[status] ?? const Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}