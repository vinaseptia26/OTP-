import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '/core/services/overtime_history_service.dart';

class AbsensiDetailContent extends StatelessWidget {
  final OvertimeHistory overtime;
  const AbsensiDetailContent({super.key, required this.overtime});

  @override
  Widget build(BuildContext context) {
    final absensiStatus = overtime.absensiStatus ?? 'belum_absen';
    final sudahAbsen = absensiStatus == 'check_in' || absensiStatus == 'check_out' || absensiStatus == 'selesai';
    final isExpired = overtime.status == 'kadaluarsa';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.grey.shade200 :
                             sudahAbsen ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isExpired ? Icons.timer_off :
                      sudahAbsen ? Icons.check_circle : Icons.pending,
                      color: isExpired ? Colors.grey :
                             sudahAbsen ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired ? 'Lembur Kadaluarsa' :
                          sudahAbsen ? 'Absensi Tercatat' : 'Belum Absensi',
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          overtime.namaMitra ?? 'Mitra',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _detailRow('Tanggal', DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(overtime.tanggal)),
              _detailRow('Jam', '${overtime.jamMulai} - ${overtime.jamSelesai}'),
              _detailRow('Durasi', '${overtime.totalJam.toStringAsFixed(1)} jam'),
              _detailRow('Jenis', overtime.jenisLembur == 'hari_libur' ? 'Hari Libur' : 'Hari Kerja'),
              _detailRow('Lokasi', _lokasiText(overtime.lokasi)),
              if (sudahAbsen) ...[
                const SizedBox(height: 12),
                if (overtime.absensiWaktu != null)
                  _detailRow('Check‑in', DateFormat('dd MMM yyyy, HH:mm:ss').format(overtime.absensiWaktu!)),
                if (overtime.absensiNama != null)
                  _detailRow('Diinput oleh', overtime.absensiNama!),
              ],
              const SizedBox(height: 20),
              if (overtime.absensiFotoUrl != null)
                InkWell(
                  onTap: () => _lihatFoto(context, overtime.absensiFotoUrl!),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(overtime.absensiFotoUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _lokasiText(Map<String, dynamic> lokasi) {
    final pilihan = lokasi['pilihan'] ?? 'kantor';
    if (pilihan == 'kantor') return 'Kantor PGE';
    if (pilihan == 'proyek') return lokasi['proyek'] ?? 'Proyek';
    return lokasi['alamat'] ?? 'Lokasi Lain';
  }

  void _lihatFoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}