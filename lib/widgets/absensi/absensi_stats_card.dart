import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/core/services/overtime_history_service.dart';

class AbsensiStatsCard extends StatefulWidget {
  final OvertimeHistoryService historyService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String selectedBulan;

  const AbsensiStatsCard({
    super.key,
    required this.historyService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    required this.selectedBulan,
  });

  @override
  State<AbsensiStatsCard> createState() => _AbsensiStatsCardState();
}

class _AbsensiStatsCardState extends State<AbsensiStatsCard> {
  Map<String, int> _counts = {
    'total': 0,
    'belum': 0,
    'sudah': 0,
    'kadaluarsa': 0,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant AbsensiStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBulan != widget.selectedBulan) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stream = widget.historyService.getOvertimeHistoryStream(
        userRole: widget.userRole,
        userFungsi: widget.userFungsi,
        userId: widget.userId,
        bulan: widget.selectedBulan,
        statusFilter: 'semua',
      );
      final data = await stream.first;
      int total = data.length;
      int belum = data.where((e) =>
          (e.status == 'disetujui' || e.status == 'approved') &&
          (e.absensiStatus == 'belum_absen')).length;
      int sudah = data.where((e) =>
          e.absensiStatus == 'check_in' || e.absensiStatus == 'check_out' || e.absensiStatus == 'selesai').length;
      int kadaluarsa = data.where((e) => e.status == 'kadaluarsa').length;

      if (mounted) {
        setState(() {
          _counts = {'total': total, 'belum': belum, 'sudah': sudah, 'kadaluarsa': kadaluarsa};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Total', _counts['total']!.toString(), Icons.work_history),
                _statItem('Belum', _counts['belum']!.toString(), Icons.pending, color: Colors.orange),
                _statItem('Sudah', _counts['sudah']!.toString(), Icons.check_circle, color: Colors.green),
                _statItem('Kadaluarsa', _counts['kadaluarsa']!.toString(), Icons.timer_off, color: Colors.grey),
              ],
            ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
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
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}