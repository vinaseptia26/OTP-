// lib/widgets/approval/manager/approval_detail_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/services/overtime_rate_service.dart';

class ApprovalDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> mitraList;
  final bool isDarkMode;
  final String userRole;
  final String userName;
  final bool isManager;
  final bool isSuperadmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onPreviewSpkl;

  const ApprovalDetailBottomSheet({
    super.key,
    required this.data,
    required this.mitraList,
    required this.isDarkMode,
    required this.userRole,
    required this.userName,
    required this.isManager,
    required this.isSuperadmin,
    required this.onApprove,
    required this.onReject,
    this.onPreviewSpkl,
  });

  @override
  Widget build(BuildContext context) {
    final rateService = OvertimeRateService();
    final status = data['status'] ?? 'pending';
    final isPending = status == 'pending';
    final urgensi = data['urgensi'] ?? 'normal';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';

    final lokasiData = data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;

    final totalMitra = data['total_mitra'] ?? 1;
    final biayaTotal = (data['estimasi_biaya_total'] ?? 0).toDouble();
    final biayaPerMitra = mitraList.isNotEmpty ? biayaTotal / mitraList.length : 0.0;
    final canApprove = isPending && (isManager || isSuperadmin);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.description, color: _getStatusColor(status), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detail Pengajuan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : const Color(0xFF1E293B))),
                      Text('ID: ${(data['group_id'] ?? '').toString().substring(0, 8)}...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (onPreviewSpkl != null && !isPending)
                  IconButton(icon: Icon(Icons.preview, color: Colors.blue[300]), onPressed: onPreviewSpkl, tooltip: 'Preview SPKL'),
                Wrap(
                  spacing: 4,
                  children: [
                    _badge(_getStatusLabel(status), _getStatusColor(status)),
                    _badge(urgensi.toUpperCase(), _getUrgensiColor(urgensi)),
                    if (isWeekend) _badge('LIBUR', Colors.purple),
                    if (isOverride) _badge('OVERRIDE', Colors.orange),
                    if (isOutside) _badge('LUAR RADIUS', Colors.orange),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Informasi Pengawas', Icons.person, Colors.blue, [
                    _row('Nama', data['nama_pengawas'] ?? '-'),
                    _row('Fungsi', _getFungsiLabel(data['pengawas_fungsi'])),
                  ]),
                  const SizedBox(height: 12),

                  _section('Waktu Lembur', Icons.access_time, Colors.green, [
                    _row('Tanggal', data['tanggal'] != null ? DateFormat('EEEE, dd MMM yyyy', 'id_ID').format((data['tanggal'] as Timestamp).toDate()) : '-'),
                    _row('Jam', '${data['jam_mulai']} - ${data['jam_selesai']}'),
                    _row('Durasi', '${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam', bold: true),
                    _row('Jenis', isWeekend ? 'Hari Libur' : 'Hari Kerja'),
                  ]),
                  const SizedBox(height: 12),

                  if (lokasiMap.isNotEmpty) ...[
                    _buildLokasiSection(context, lokasiMap, isDarkMode),
                    const SizedBox(height: 12),
                  ],

                  _section('Estimasi Biaya', Icons.payments, Colors.green, [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)]), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          _costRow('Per Mitra', rateService.formatRupiah(biayaPerMitra)),
                          const Divider(color: Colors.white30),
                          _costRow('Total ($totalMitra mitra)', rateService.formatRupiah(biayaTotal), total: true),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  _section('Alasan', Icons.description, Colors.teal, [
                    Text(data['alasan'] ?? '-', style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black87)),
                  ]),

                  if (data['catatan_tambahan'] != null && data['catatan_tambahan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _section('Catatan Tambahan', Icons.note, Colors.amber, [
                      Text(data['catatan_tambahan'] ?? '', style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black87)),
                    ]),
                  ],

                  if (mitraList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _section('Daftar Mitra (${mitraList.length})', Icons.groups, Colors.purple, [
                      _buildMitraTable(mitraList, isDarkMode, rateService),
                    ]),
                  ],

                  if (data['spkl_nomor'] != null) ...[
                    const SizedBox(height: 12),
                    _section('SPKL', Icons.picture_as_pdf, Colors.red, [
                      _row('Nomor', data['spkl_nomor']!),
                    ]),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (canApprove)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLokasiSection(BuildContext context, Map<String, dynamic> lokasi, bool isDark) {
    // Ambil alamat langsung dari data (sudah lengkap dari pengajuan)
    String alamat = lokasi['alamat'] ?? '';
    final rt = lokasi['rt'] ?? '';
    final rw = lokasi['rw'] ?? '';
    if (rt.toString().isNotEmpty) alamat += ' RT $rt';
    if (rw.toString().isNotEmpty) alamat += ' RW $rw';
    final isOutside = lokasi['is_outside_radius'] == true;
    final lat = lokasi['latitude'];
    final lng = lokasi['longitude'];
    final bool hasCoordinates = lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.06), Colors.blue.withOpacity(0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on, size: 20, color: Colors.blue),
              ),
              const SizedBox(width: 10),
              Text('Lokasi Lembur', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[700])),
              const Spacer(),
              if (isOutside)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                  child: Text('⚠️ LUAR RADIUS', style: GoogleFonts.poppins(fontSize: 9, color: Colors.orange[700], fontWeight: FontWeight.w600)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: Text('✅ DALAM RADIUS', style: GoogleFonts.poppins(fontSize: 9, color: Colors.green[700], fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Alamat lengkap langsung dari Firestore
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alamat.isNotEmpty ? alamat : 'Tidak diketahui',
                  style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          // Koordinat + tombol lihat peta
          if (hasCoordinates) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pin_drop, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${(lat as num).toDouble().toStringAsFixed(6)}, ${(lng as num).toDouble().toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showLokasiOnMap(context, (lat).toDouble(), (lng).toDouble(), alamat),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('Lihat di Peta', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showLokasiOnMap(BuildContext context, double lat, double lng, String alamat) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              AppBar(
                title: Text(alamat.isNotEmpty ? alamat : 'Lokasi Lembur', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 18.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.pge.overtimeapp',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
                      )
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- helper widget (sama seperti sebelumnya) ----------
  Widget _buildMitraTable(List<Map<String, dynamic>> mitraList, bool isDark, OvertimeRateService rateService) {
    return Table(
      border: TableBorder.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100]),
          children: [
            _tableCellHeader('Nama', isDark),
            _tableCellHeader('Fungsi', isDark),
            _tableCellHeader('Biaya', isDark),
          ],
        ),
        ...mitraList.map((mitra) {
          final biaya = (mitra['estimasi_biaya_per_mitra'] ?? mitra['estimasi_biaya'] ?? 0).toDouble();
          return TableRow(
            children: [
              _tableCell(mitra['nama_mitra'] ?? '-', isDark),
              _tableCell(mitra['fungsi_mitra'] ?? '-', isDark),
              _tableCell(rateService.formatRupiah(biaya), isDark, bold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableCellHeader(String text, bool isDark) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
      );

  Widget _tableCell(String text, bool isDark, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: isDark ? Colors.white70 : Colors.black87)),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _section(String title, IconData icon, Color color, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
            Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: isDarkMode ? Colors.white : Colors.black87))),
          ],
        ),
      );

  Widget _costRow(String label, String value, {bool total = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: total ? 14 : 12, color: total ? Colors.white : Colors.white70, fontWeight: total ? FontWeight.w600 : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: total ? 18 : 14, fontWeight: FontWeight.bold, color: total ? Colors.amber : Colors.white)),
          ],
        ),
      );

  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      default: return s;
    }
  }

  Color _getUrgensiColor(String s) {
    switch (s) {
      case 'normal': return Colors.blue;
      case 'tinggi': return Colors.orange;
      case 'kritis': return Colors.red;
      default: return Colors.blue;
    }
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