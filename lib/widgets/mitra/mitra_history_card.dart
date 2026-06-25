// lib/widgets/mitra/mitra_history_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> historyList;
  final VoidCallback onViewAll;

  const MitraHistoryCard({
    super.key,
    required this.historyList,
    required this.onViewAll,
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
                    colors: [const Color(0xFFFF6B35).withAlpha(30), const Color(0xFFFF8A5C).withAlpha(20)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, size: 20, color: Color(0xFFFF6B35)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '🕐 Riwayat Lembur Terbaru',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2B4C)),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...historyList.take(3).map((history) => _buildHistoryItem(history)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final date = history['date']?.toString() ?? '';
    final jamMulai = history['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = history['jam_selesai']?.toString() ?? '--:--';
    final income = (history['income'] ?? 0).toDouble();
    final status = history['status']?.toString() ?? 'pending';

    // ✅ FIX: Definisikan tipe Map dengan jelas
    final Map<String, Map<String, dynamic>> statusConfig = {
      'approved': {
        'icon': Icons.check_circle,
        'color': const Color(0xFF00C853),
        'label': 'Disetujui',
      },
      'rejected': {
        'icon': Icons.cancel,
        'color': const Color(0xFFE53935),
        'label': 'Ditolak',
      },
      'pending': {
        'icon': Icons.pending,
        'color': const Color(0xFFFFAB40),
        'label': 'Pending',
      },
    };

    final config = statusConfig[status] ?? statusConfig['pending']!;
    
    // ✅ Ambil nilai dengan cast yang benar
    final Color configColor = config['color'] as Color;
    final IconData configIcon = config['icon'] as IconData;
    final String configLabel = config['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: configColor.withAlpha(15),                    // ✅ Sekarang aman
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: configColor.withAlpha(30)), // ✅ Sekarang aman
      ),
      child: Row(
        children: [
          Icon(configIcon, size: 24, color: configColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$jamMulai - $jamSelesai',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(income),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: configColor.withAlpha(200),          // ✅ Sekarang aman
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  configLabel,
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}