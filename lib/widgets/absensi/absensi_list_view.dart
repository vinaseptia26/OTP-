import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/overtime_history_service.dart';
import '/widgets/absensi/absensi_detail_content.dart';

class AbsensiListView extends StatefulWidget {
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String selectedBulan;
  final String selectedStatus;
  final String searchQuery; // <-- baru
  final String? lemburIdHighlight;

  const AbsensiListView({
    super.key,
    required this.userRole,
    this.userFungsi,
    this.userId,
    required this.selectedBulan,
    required this.selectedStatus,
    this.searchQuery = '', // default kosong
    this.lemburIdHighlight,
  });

  @override
  State<AbsensiListView> createState() => _AbsensiListViewState();
}

class _AbsensiListViewState extends State<AbsensiListView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<OvertimeHistory>> _getLemburMitraStream() {
    Query<Map<String, dynamic>> query =
        _firestore.collection('lembur_mitra');

    if (widget.userRole == 'mitra' && widget.userId != null) {
      query = query.where('mitra_id', isEqualTo: widget.userId);
    } else if (widget.userRole == 'pengawas' && widget.userId != null) {
      query = query.where('diajukan_oleh_id', isEqualTo: widget.userId);
    } else if (widget.userRole == 'manager' &&
        widget.userFungsi != null &&
        widget.userFungsi!.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: widget.userFungsi);
    }

    if (widget.selectedBulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: widget.selectedBulan);
    }

    query = query.orderBy('tanggal', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeHistory.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeHistory>>(
      stream: _getLemburMitraStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allData = snapshot.data ?? [];

        // Dedup by ID
        final seen = <String>{};
        final deduped = allData.where((e) => seen.add(e.id)).toList();

        List<OvertimeHistory> filtered = deduped;

        // Filter status absensi
        if (widget.selectedStatus == 'belum_absen') {
          filtered = filtered
              .where((e) =>
                  (e.status == 'disetujui' || e.status == 'approved') &&
                  (e.absensiStatus == 'belum_absen'))
              .toList();
        } else if (widget.selectedStatus == 'sudah_absen') {
          filtered = filtered
              .where((e) =>
                  e.absensiStatus == 'check_in' ||
                  e.absensiStatus == 'check_out' ||
                  e.absensiStatus == 'selesai')
              .toList();
        } else if (widget.selectedStatus == 'kadaluarsa') {
          filtered = filtered.where((e) => e.status == 'kadaluarsa').toList();
        }

        // Filter search (client-side)
        if (widget.searchQuery.isNotEmpty) {
          final q = widget.searchQuery.toLowerCase();
          filtered = filtered.where((e) {
            final nama = (e.namaMitra ?? '').toLowerCase();
            final pengawas = (e.namaPengawas ?? '').toLowerCase();
            final tanggalStr =
                DateFormat('dd MMM yyyy', 'id_ID').format(e.tanggal).toLowerCase();
            return nama.contains(q) ||
                   pengawas.contains(q) ||
                   tanggalStr.contains(q) ||
                   e.jamMulai.contains(q) ||
                   e.jamSelesai.contains(q);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada data absensi',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _AbsensiCard(
              overtime: item,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => AbsensiDetailContent(overtime: item),
                );
              },
              highlight: item.id == widget.lemburIdHighlight,
            );
          },
        );
      },
    );
  }
}

// ========== CARD YANG DIPERBAIKI ==========
class _AbsensiCard extends StatelessWidget {
  final OvertimeHistory overtime;
  final VoidCallback onTap;
  final bool highlight;

  const _AbsensiCard({
    required this.overtime,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final absensiStatus = overtime.absensiStatus ?? 'belum_absen';
    final sudahAbsen = absensiStatus == 'check_in' ||
        absensiStatus == 'check_out' ||
        absensiStatus == 'selesai';
    final isExpired = overtime.status == 'kadaluarsa';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Colors.grey;
      statusText = 'Kadaluarsa';
      statusIcon = Icons.timer_off;
    } else if (!sudahAbsen) {
      statusColor = Colors.orange;
      statusText = 'Belum Absen';
      statusIcon = Icons.pending;
    } else {
      statusColor = Colors.green;
      statusText = 'Sudah Absen';
      statusIcon = Icons.check_circle;
    }

    // Lokasi singkat
    String lokasiSingkat = 'Kantor PGE';
    if (overtime.lokasi.isNotEmpty) {
      final pilihan = overtime.lokasi['pilihan'] ?? 'kantor';
      if (pilihan == 'kantor') {
        lokasiSingkat = 'Kantor PGE';
      } else if (pilihan == 'proyek') {
        lokasiSingkat = overtime.lokasi['proyek'] ?? 'Proyek';
      } else {
        lokasiSingkat = overtime.lokasi['alamat'] ?? 'Lokasi Lain';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: highlight ? const Color(0xFFFFF3E0) : Colors.white,
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overtime.namaMitra ?? 'Mitra',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy', 'id_ID').format(overtime.tanggal),
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Info baris kedua: jam, durasi, lokasi
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(Icons.access_time, '${overtime.jamMulai} - ${overtime.jamSelesai}'),
                  _chip(Icons.timer, '${overtime.totalJam.toStringAsFixed(1)} jam'),
                  _chip(Icons.location_on, lokasiSingkat),
                  if (overtime.absensiWaktu != null)
                    _chip(Icons.login, DateFormat('HH:mm').format(overtime.absensiWaktu!)),
                  if (overtime.namaPengawas != null)
                    _chip(Icons.person, overtime.namaPengawas!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}