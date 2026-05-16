// lib/widgets/overtime_history/overtime_card.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/overtime_history/overtime_detail_sheet.dart';
import '/widgets/absensi/absensi_dialog.dart';
import '/widgets/overtime_history/overtime_helpers.dart';

class OvertimeCard extends StatelessWidget {
  final OvertimeHistory item;
  final OvertimeRateService rateService;
  final String? userId;
  final String? userName;
  final String? userRole;

  const OvertimeCard({
    super.key,
    required this.item,
    required this.rateService,
    this.userId,
    this.userName,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        OvertimeHelpers.getStatusColor(item.status);
    final isUrgent =
        item.urgensi == 'kritis' || item.urgensi == 'tinggi';
    final isMitraPelaksana = _isMitraPelaksana();
    final absensiValidation = _validateAbsensiTime();
    final canAbsen = absensiValidation['canAbsen'] as bool;
    final isLate = absensiValidation['isLate'] as bool;
    final isToday = absensiValidation['isToday'] as bool;

    final needAbsen = item.status == 'disetujui' &&
        item.absensiStatus != 'selesai' &&
        isMitraPelaksana;

    final isSelesaiTerlambat =
        item.absensiStatus == 'selesai_terlambat';
    final isTidakLembur =
        item.absensiStatus == 'tidak_lembur';

    // ✅ Biaya ditampilkan sesuai tipe dokumen
    final biayaTampil = item.isMitraDocument
        ? item.estimasiBiayaPerMitra   // lembur_mitra
        : item.estimasiBiayaTotal;     // pengajuan_lembur

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => OvertimeDetailSheet.show(
          context,
          item,
          rateService,
          userId,
          userName,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isUrgent
                ? LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.02),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(statusColor, isMitraPelaksana),
              const SizedBox(height: 10),
              _buildInfoChips(
                isUrgent: isUrgent,
                isMitraPelaksana: isMitraPelaksana,
                needAbsen: needAbsen,
                canAbsen: canAbsen,
                isLate: isLate,
                isToday: isToday,
                isSelesaiTerlambat: isSelesaiTerlambat,
                isTidakLembur: isTidakLembur,
              ),
              const SizedBox(height: 10),
              _buildCostRow(biayaTampil),
              if (item.spklGenerated &&
                  item.status == 'disetujui') ...[
                const SizedBox(height: 10),
                _buildSpklIndicator(),
              ],
              if (needAbsen && canAbsen && isToday) ...[
                const SizedBox(height: 10),
                _buildAbsenButton(context),
              ],
              if (needAbsen && !canAbsen && isToday && !isLate) ...[
                const SizedBox(height: 10),
                _buildNotYetTimeIndicator(),
              ],
              if (needAbsen && !isToday && !isLate) ...[
                const SizedBox(height: 10),
                _buildNotTodayIndicator(),
              ],
              if (needAbsen && isLate) ...[
                const SizedBox(height: 10),
                _buildLateAbsensiIndicator(context),
              ],
              if (isSelesaiTerlambat) ...[
                const SizedBox(height: 10),
                _buildSelesaiTerlambatIndicator(),
              ],
              if (isTidakLembur) ...[
                const SizedBox(height: 10),
                _buildTidakLemburIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  bool _isMitraPelaksana() {
    if (userRole != 'mitra') return false;

    if (item.mitraId != null && item.mitraId!.isNotEmpty) {
      return item.mitraId == userId;
    }

    if (item.isMultiple &&
        item.mitraIds != null &&
        item.mitraIds!.isNotEmpty) {
      return item.mitraIds!.contains(userId);
    }

    if (item.namaMitra != null && item.namaMitra!.isNotEmpty) {
      return item.namaMitra == userName;
    }

    return false;
  }

  Map<String, dynamic> _validateAbsensiTime() {
    final now = DateTime.now();
    final tanggalLembur = item.tanggal;
    final jamMulai = item.jamMulai;
    final jamSelesai = item.jamSelesai;

    final mulaiParts = jamMulai.split(':');
    final selesaiParts = jamSelesai.split(':');

    if (mulaiParts.length < 2 || selesaiParts.length < 2) {
      return {
        'canAbsen': false,
        'isLate': false,
        'isToday': false,
        'isInRange': false,
        'message': 'Format jam tidak valid',
      };
    }

    final mulaiHour = int.tryParse(mulaiParts[0]) ?? 0;
    final mulaiMinute = int.tryParse(mulaiParts[1]) ?? 0;
    final selesaiHour = int.tryParse(selesaiParts[0]) ?? 0;
    final selesaiMinute = int.tryParse(selesaiParts[1]) ?? 0;

    final mulaiDateTime = DateTime(
      tanggalLembur.year,
      tanggalLembur.month,
      tanggalLembur.day,
      mulaiHour,
      mulaiMinute,
    );
    var selesaiDateTime = DateTime(
      tanggalLembur.year,
      tanggalLembur.month,
      tanggalLembur.day,
      selesaiHour,
      selesaiMinute,
    );

    if (selesaiDateTime.isBefore(mulaiDateTime)) {
      selesaiDateTime =
          selesaiDateTime.add(const Duration(days: 1));
    }

    final isToday = now.year == tanggalLembur.year &&
        now.month == tanggalLembur.month &&
        now.day == tanggalLembur.day;

    final isInRange =
        now.isAfter(mulaiDateTime.subtract(
                const Duration(minutes: 30))) &&
            now.isBefore(selesaiDateTime.add(
                const Duration(hours: 2)));

    final isPastDeadline = now.isAfter(
        selesaiDateTime.add(const Duration(hours: 2)));

    return {
      'canAbsen': isToday && isInRange,
      'isLate': isPastDeadline && isToday,
      'isToday': isToday,
      'isInRange': isInRange,
      'jamMulai': DateFormat('HH:mm').format(mulaiDateTime),
      'jamSelesai': DateFormat('HH:mm').format(selesaiDateTime),
    };
  }

  // ============================================================================
  // HEADER
  // ============================================================================

  Widget _buildHeader(Color statusColor, bool isMitraPelaksana) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: OvertimeHelpers.getFungsiColor(
                    item.pengawasFungsi)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.isMultiple ? Icons.group : Icons.person,
            color: OvertimeHelpers.getFungsiColor(
                item.pengawasFungsi),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _getCardTitle(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMitraPelaksana)
                    _buildBadge('Anda', Colors.purple),
                  if (item.spklGenerated &&
                      item.status == 'disetujui')
                    _buildBadge('SPKL', Colors.blue),
                  _buildStatusBadge(statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal)} • ${item.jamMulai} - ${item.jamSelesai}',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCardTitle() {
    if (item.isMultiple)
      return 'Lembur Grup (${item.totalMitra} mitra)';
    if (item.namaMitra != null && item.namaMitra!.isNotEmpty)
      return item.namaMitra!;
    if (item.namaPengawas != null &&
        item.namaPengawas!.isNotEmpty)
      return item.namaPengawas!;
    return 'Unknown';
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 8,
            color: color,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        OvertimeHelpers.getStatusText(item.status),
        style: GoogleFonts.poppins(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  // ============================================================================
  // INFO CHIPS
  // ============================================================================

  Widget _buildInfoChips({
    required bool isUrgent,
    required bool isMitraPelaksana,
    required bool needAbsen,
    required bool canAbsen,
    required bool isLate,
    required bool isToday,
    required bool isSelesaiTerlambat,
    required bool isTidakLembur,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
            icon: Icons.access_time,
            label:
                '${item.totalJam.toStringAsFixed(1)} jam'),
        _InfoChip(
            icon: Icons.work,
            label: _getJenisLemburLabel()),
        if (item.lokasi.isNotEmpty)
          _InfoChip(
              icon: Icons.location_on,
              label: _getLokasiString(),
              color: Colors.blue),
        if (_isOutsideRadius())
          _InfoChip(
              icon: Icons.warning_amber,
              label: 'Luar Radius',
              color: Colors.orange),
        if (isMitraPelaksana &&
            item.absensiStatus == 'selesai')
          _InfoChip(
              icon: Icons.check_circle,
              label: 'Sudah Absen',
              color: Colors.green),
        if (isSelesaiTerlambat)
          _InfoChip(
              icon: Icons.check_circle_outline,
              label: 'Absen Terlambat',
              color: Colors.orange),
        if (isTidakLembur)
          _InfoChip(
              icon: Icons.cancel_outlined,
              label: 'Tidak Lembur',
              color: Colors.red),
        if (needAbsen && canAbsen && isToday)
          _InfoChip(
              icon: Icons.camera_alt,
              label: 'Siap Absen',
              color: Colors.blue),
        if (needAbsen && !canAbsen && !isLate && isToday)
          _InfoChip(
              icon: Icons.schedule,
              label: 'Belum Waktunya',
              color: Colors.grey),
        if (needAbsen && isLate)
          _InfoChip(
              icon: Icons.warning_amber,
              label: 'Terlambat Absensi',
              color: Colors.red),
        if (isUrgent)
          _InfoChip(
              icon: Icons.warning,
              label: 'Urgent',
              color: Colors.red),
      ],
    );
  }

  String _getJenisLemburLabel() {
    switch (item.jenisLembur) {
      case 'hari_kerja':
        return 'Hari Kerja';
      case 'hari_libur':
        return 'Hari Libur';
      default:
        return item.jenisLembur;
    }
  }

  String _getLokasiString() {
    final lokasi = item.lokasi;
    if (lokasi['nama_lokasi']?.toString().isNotEmpty == true)
      return lokasi['nama_lokasi'].toString();
    if (lokasi['alamat']?.toString().isNotEmpty == true)
      return lokasi['alamat'].toString();
    if (lokasi['latitude'] != null &&
        lokasi['longitude'] != null) {
      return '📍 ${lokasi['latitude']}, ${lokasi['longitude']}';
    }
    return 'Tidak diketahui';
  }

  bool _isOutsideRadius() =>
      item.lokasi['is_outside_radius'] == true;

  // ============================================================================
  // COST ROW (FIXED: Menampilkan biaya sesuai tipe dokumen)
  // ============================================================================

  Widget _buildCostRow(double biaya) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          item.isMitraDocument ? 'Biaya' : 'Total Biaya',
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500),
        ),
        Text(
          rateService.formatRupiahCompact(biaya),
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700),
        ),
      ],
    );
  }

  // ============================================================================
  // INDICATOR WIDGETS
  // ============================================================================

  Widget _buildSpklIndicator() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf,
              size: 14, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            item.spklNomor ?? 'SPKL Tersedia',
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Waktunya absensi! Klik untuk melakukan absensi sekarang.',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.blue[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  AbsensiDialog.show(context, item),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Absensi Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotYetTimeIndicator() {
    final validation = _validateAbsensiTime();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule,
              size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Absensi dibuka mulai ${validation['jamMulai']}',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotTodayIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event,
              size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Absensi: ${DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal)}',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateAbsensiIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  size: 14, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Anda belum melakukan absensi! Apakah Anda melakukan lembur?',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showLateAbsensiDialog(context),
              icon: const Icon(Icons.assignment_late,
                  size: 16),
              label: const Text(
                  'Konfirmasi Keterlambatan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelesaiTerlambatIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Anda sudah mengkonfirmasi keterlambatan absensi.',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTidakLemburIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined,
              size: 14, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Anda menyatakan tidak melakukan lembur.',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLateAbsensiDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          LateAbsensiDialog(item: item),
    );
  }
}

// ============================================================================
// DIALOG KETERLAMBATAN ABSENSI (TIDAK BERUBAH)
// ============================================================================

class LateAbsensiDialog extends StatefulWidget {
  final OvertimeHistory item;
  const LateAbsensiDialog({super.key, required this.item});

  @override
  State<LateAbsensiDialog> createState() =>
      _LateAbsensiDialogState();
}

class _LateAbsensiDialogState extends State<LateAbsensiDialog> {
  bool? _melakukanLembur;
  final TextEditingController _alasanController =
      TextEditingController();
  File? _buktiFoto;
  bool _isSubmitting = false;
  String _loadingMessage = 'Mengirim...';
  double _uploadProgress = 0;

  final OvertimeHistoryService _historyService =
      OvertimeHistoryService();

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_melakukanLembur == null) {
      _showSnackbar(
          'Pilih apakah Anda melakukan lembur atau tidak');
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      _showSnackbar('Alasan harus diisi');
      return;
    }
    if (_melakukanLembur == true && _buktiFoto == null) {
      _showSnackbar('Upload bukti melakukan lembur (wajib)');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loadingMessage = 'Menyiapkan data...';
      _uploadProgress = 0;
    });

    try {
      String? fotoUrl;

      if (_buktiFoto != null) {
        setState(() =>
            _loadingMessage = 'Mengupload bukti foto...');

        final storage = FirebaseStorage.instance;
        final fileName =
            'absensi/bukti_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = storage.ref().child(fileName);

        final uploadTask = ref.putFile(_buktiFoto!);

        uploadTask.snapshotEvents
            .listen((TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred /
                      snapshot.totalBytes) *
                  100;
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _loadingMessage =
                  'Mengupload... ${progress.toStringAsFixed(0)}%';
            });
          }
        });

        await uploadTask.timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Upload timeout. Coba lagi.'),
        );

        fotoUrl = await ref.getDownloadURL();
        setState(() =>
            _loadingMessage =
                'Upload selesai! Menyimpan data...');
      }

      setState(() =>
          _loadingMessage = 'Menyimpan ke database...');

      await _historyService.updateAbsensiStatus(
        lemburId: widget.item.id,
        absensiStatus: _melakukanLembur == true
            ? 'selesai_terlambat'
            : 'tidak_lembur',
        fotoUrl: fotoUrl,
        absensiOleh:
            FirebaseAuth.instance.currentUser?.uid,
        absensiNama: FirebaseAuth
                .instance.currentUser?.displayName ??
            'Mitra',
        absensiWaktu: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('lembur_mitra')
          .doc(widget.item.id)
          .update({
        'absensi_keterlambatan': {
          'melakukan_lembur': _melakukanLembur,
          'alasan': _alasanController.text.trim(),
          'bukti_foto_url': fotoUrl,
          'dikonfirmasi_pada': FieldValue.serverTimestamp(),
          'dikonfirmasi_oleh':
              FirebaseAuth.instance.currentUser?.uid,
          'dikonfirmasi_nama':
              FirebaseAuth.instance.currentUser
                      ?.displayName ??
                  'Mitra',
        },
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('✅ Konfirmasi berhasil dikirim'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackbar(
            'Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickBuktiFoto() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Pilih Sumber Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: Color(0xFF1976D2)),
                title: const Text('Kamera'),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                onTap: () => Navigator.pop(
                    context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: Color(0xFF1976D2)),
                title: const Text('Galeri'),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                onTap: () => Navigator.pop(
                    context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final picker = ImagePicker();
        final photo = await picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1280,
          maxHeight: 1280,
        );

        if (photo != null && mounted) {
          setState(() => _buktiFoto = File(photo.path));
        }
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogHeader(),
                const SizedBox(height: 16),
                _buildLemburInfo(),
                const SizedBox(height: 20),

                if (_isSubmitting) ...[
                  _buildLoadingSection(),
                  const SizedBox(height: 20),
                ],

                if (!_isSubmitting) ...[
                  Text('Apakah Anda melakukan lembur?',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildOptionYa(),
                  const SizedBox(height: 10),
                  _buildOptionTidak(),

                  if (_melakukanLembur != null) ...[
                    const SizedBox(height: 16),
                    _buildAlasanInput(),
                    if (_melakukanLembur == true) ...[
                      const SizedBox(height: 12),
                      _buildBuktiUpload(),
                    ],
                  ],

                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assignment_late,
              color: Colors.red, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Konfirmasi Keterlambatan',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text('Absensi lembur belum dilakukan',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLemburInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lembur: ${DateFormat('dd MMM yyyy', 'id_ID').format(widget.item.tanggal)} • ${widget.item.jamMulai}-${widget.item.jamSelesai}',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_loadingMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.blue[700])),
          if (_uploadProgress > 0 &&
              _uploadProgress < 100) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress / 100,
                backgroundColor: Colors.blue[100],
                color: const Color(0xFF1976D2),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text('${_uploadProgress.toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionYa() {
    return InkWell(
      onTap: () =>
          setState(() => _melakukanLembur = true),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _melakukanLembur == true
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _melakukanLembur == true
                ? Colors.green
                : Colors.grey.shade300,
            width: _melakukanLembur == true ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle,
                color: _melakukanLembur == true
                    ? Colors.green
                    : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ya, saya melakukan lembur',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text('Berikan alasan tidak absen + bukti',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey)),
                ],
              ),
            ),
            if (_melakukanLembur == true)
              Icon(Icons.check_circle,
                  color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTidak() {
    return InkWell(
      onTap: () =>
          setState(() => _melakukanLembur = false),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _melakukanLembur == false
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _melakukanLembur == false
                ? Colors.red
                : Colors.grey.shade300,
            width: _melakukanLembur == false ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel,
                color: _melakukanLembur == false
                    ? Colors.red
                    : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Tidak, saya tidak melakukan lembur',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text('Berikan alasan tidak melakukan lembur',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey)),
                ],
              ),
            ),
            if (_melakukanLembur == false)
              Icon(Icons.check_circle,
                  color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAlasanInput() {
    return TextField(
      controller: _alasanController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: _melakukanLembur == true
            ? 'Alasan tidak melakukan absensi...'
            : 'Alasan tidak melakukan lembur...',
        labelText: 'Alasan *',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildBuktiUpload() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt,
                  size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Upload bukti melakukan lembur (wajib)',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange[700])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_buktiFoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _buktiFoto!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _pickBuktiFoto,
            icon: const Icon(Icons.add_a_photo, size: 16),
            label: Text(_buktiFoto != null
                ? 'Ganti Foto'
                : 'Ambil/Upload Foto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.send, size: 18),
        label: const Text('Kirim Konfirmasi'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3C72),
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ============================================================================
// INFO CHIP WIDGET
// ============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip(
      {required this.icon,
      required this.label,
      this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF1976D2);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: chipColor)),
        ],
      ),
    );
  }
}