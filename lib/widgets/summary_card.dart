// lib/features/pengawas/lembur/widgets/summary_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_rate_service.dart';

class SummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> selectedMiras;
  final DateTime? tanggalLembur;
  final TimeOfDay? jamMulai;
  final TimeOfDay? jamSelesai;
  final double totalJam;
  final double totalBiaya;
  final double biayaPerMitra;
  final String urgensi;
  final String lokasiInfo;
  final bool isOverride;

  const SummaryCard({
    super.key,
    required this.selectedMiras,
    required this.tanggalLembur,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.totalBiaya,
    required this.biayaPerMitra,
    required this.urgensi,
    required this.lokasiInfo,
    required this.isOverride,
  });

  @override
  Widget build(BuildContext context) {
    final overtimeRateService = OvertimeRateService();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4), // Perbaikan: .withOpacity bukan .withAlpha
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(overtimeRateService),
          const SizedBox(height: 16),
          _buildCostSummary(overtimeRateService),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), // Perbaikan: .withOpacity
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.summarize, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          "Ringkasan Pengajuan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(OvertimeRateService overtimeService) {
    return Column(
      children: [
        if (selectedMiras.length > 2)
          _summaryRow("  • dan ${selectedMiras.length - 2} lainnya", "", isSub: true),
        const SizedBox(height: 4),
        _summaryRow(
          "📅 Tanggal",
          tanggalLembur != null
              ? DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggalLembur!)
              : "-",
        ),
        _summaryRow(
          "⏰ Waktu",
          "${_formatTime(jamMulai!)} - ${_formatTime(jamSelesai!)}",
        ),
        _summaryRow("⏱️ Durasi", "${totalJam.toStringAsFixed(1)} jam"),
        _summaryRow("📍 Lokasi", lokasiInfo),
        _summaryRow("⚡ Urgensi", _getUrgensiLabel()),
        if (isOverride)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // Perbaikan: .withOpacity
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "⚠️ Melebihi batas 60 jam/bulan",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCostSummary(OvertimeRateService overtimeRateService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15), // Perbaikan: .withOpacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Biaya per Mitra:",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                overtimeRateService.formatRupiah(biayaPerMitra),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFFC6F6D5),
                ),
              ),
            ],
          ),
          if (selectedMiras.length > 1) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Biaya:",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  overtimeRateService.formatRupiah(totalBiaya),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: const Color(0xFFC6F6D5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isSub = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isSub ? 2 : 4, bottom: isSub ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSub ? 110 : 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isSub ? 11 : 12,
                color: Colors.white.withOpacity(0.9), // Perbaikan: .withOpacity
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isSub ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getUrgensiLabel() {
    switch (urgensi) {
      case 'rendah': return "Urgensi Rendah";
      case 'normal': return "Urgensi Normal";
      case 'tinggi': return "Urgensi Tinggi";
      case 'kritis': return "Urgensi Kritis";
      default: return "Urgensi Normal";
    }
  }
}