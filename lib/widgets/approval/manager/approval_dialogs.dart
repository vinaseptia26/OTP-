// lib/widgets/approval/manager/approval_dialogs.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_rate_service.dart';

// ============================================================================
// APPROVE DIALOG (dengan ringkasan mitra dari lembur_mitra)
// ============================================================================
class ApprovalApproveDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> mitraList; // ← dari lembur_mitra
  final Function(String notes) onConfirm;

  const ApprovalApproveDialog({
    super.key,
    required this.data,
    required this.mitraList,
    required this.onConfirm,
  });

  @override
  State<ApprovalApproveDialog> createState() => _ApprovalApproveDialogState();
}

class _ApprovalApproveDialogState extends State<ApprovalApproveDialog> {
  final TextEditingController _catatanController = TextEditingController();
  final OvertimeRateService _rateService = OvertimeRateService();

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.data['urgensi'] == 'kritis';
    final isOverride = widget.data['is_override'] ?? false;

    final lokasiData = widget.data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutsideRadius = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final mitraCount = widget.mitraList.length;
    final totalBiaya = (widget.data['estimasi_biaya_total'] ?? 0).toDouble();
    final biayaPerMitra = mitraCount > 0 ? totalBiaya / mitraCount : 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 12),
          Text(
            'Setujui Pengajuan?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning jika urgent / override
            if (isUrgent || isOverride)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    if (isUrgent)
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pengajuan KRITIS',
                              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    if (isOverride)
                      Row(
                        children: [
                          if (isUrgent) const SizedBox(height: 8),
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Melebihi 60 jam/bulan',
                              style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // Warning jika luar radius
            if (isOutsideRadius)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi lembur di LUAR RADIUS!\nLokasi: $lokasiString',
                        style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const Text(
              'Apakah Anda yakin ingin menyetujui?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Ringkasan data
            _buildInfoRow('Pengawas', widget.data['nama_pengawas'] ?? '-'),
            _buildInfoRow('Fungsi', _getFungsiLabel(widget.data['pengawas_fungsi'])),
            _buildInfoRow('Mitra', '$mitraCount orang'),
            if (lokasiMap.isNotEmpty)
              _buildInfoRow('Lokasi', lokasiString),
            _buildInfoRow('Biaya Total', _rateService.formatRupiah(totalBiaya)),
            _buildInfoRow('Biaya/Mitra', _rateService.formatRupiah(biayaPerMitra)),

            // Nama-nama mitra (jika tidak lebih dari 5, tampilkan)
            if (mitraCount <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Mitra: ${widget.mitraList.map((m) => m['nama_mitra'] ?? '?').join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 12),

            // Catatan approval
            TextFormField(
              controller: _catatanController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Tambahkan catatan approval...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () => widget.onConfirm(_catatanController.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Setujui', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          ),
          const Text(' : ', style: TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getLokasiSingkat(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return '-';
    if (lokasi['nama_lokasi'] != null && lokasi['nama_lokasi'].toString().isNotEmpty) {
      final nama = lokasi['nama_lokasi'].toString();
      return nama.length > 25 ? '${nama.substring(0, 25)}...' : nama;
    }
    if (lokasi['alamat'] != null && lokasi['alamat'].toString().isNotEmpty) {
      final alamat = lokasi['alamat'].toString();
      return alamat.length > 25 ? '${alamat.substring(0, 25)}...' : alamat;
    }
    if (lokasi['nama'] != null && lokasi['nama'].toString().isNotEmpty) {
      return lokasi['nama'].toString();
    }
    return '-';
  }

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return f ?? 'Unknown';
    }
  }
}

// ============================================================================
// REJECT DIALOG (tidak berubah)
// ============================================================================
class ApprovalRejectDialog extends StatefulWidget {
  final Function(String notes) onConfirm;

  const ApprovalRejectDialog({super.key, required this.onConfirm});

  @override
  State<ApprovalRejectDialog> createState() => _ApprovalRejectDialogState();
}

class _ApprovalRejectDialogState extends State<ApprovalRejectDialog> {
  final TextEditingController _alasanController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cancel, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          Text(
            'Tolak Pengajuan?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masukkan alasan penolakan:',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _alasanController,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Alasan Penolakan *',
              hintText: 'Jelaskan mengapa ditolak...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () {
            if (_alasanController.text.trim().isEmpty) {
              setState(() => _errorText = 'Alasan wajib diisi');
              return;
            }
            widget.onConfirm(_alasanController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Tolak', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}