// lib/widgets/overtime_history/overtime_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/core/services/spkl_generator_service.dart';
import '/widgets/overtime_history/overtime_helpers.dart';

// ===========================================================================
// PUBLIC API
// ===========================================================================

class OvertimeDetailSheet {
  static void show(
    BuildContext context,
    OvertimeHistory item,
    OvertimeRateService rateService,
    String? userId,
    String? userName,
  ) {
    if (!context.mounted) return;
    try {
      final hasSpkl = item.spklGenerated == true &&
          item.status.toLowerCase() == 'disetujui';

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.50,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return _DetailSheetContent(
                item: item,
                rateService: rateService,
                hasSpkl: hasSpkl,
                scrollController: scrollController,
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('ERROR: OvertimeDetailSheet.show(): $e');
    }
  }
}

// ===========================================================================
// PRIVATE CONTENT WIDGET
// ===========================================================================

class _DetailSheetContent extends StatefulWidget {
  final OvertimeHistory item;
  final OvertimeRateService rateService;
  final bool hasSpkl;
  final ScrollController scrollController;

  const _DetailSheetContent({
    required this.item,
    required this.rateService,
    required this.hasSpkl,
    required this.scrollController,
  });

  @override
  State<_DetailSheetContent> createState() => _DetailSheetContentState();
}

class _DetailSheetContentState extends State<_DetailSheetContent> {
  final SpklGeneratorService _spklGenerator = SpklGeneratorService();
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  final OvertimeHistoryService _historyService = OvertimeHistoryService();

  bool _isLoading = false;
  String _loadingMessage = '';

  List<OvertimeHistory> _mitraList = [];
  bool _loadingMitra = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isMultiple == true) {
      _loadMitraList();
    }
  }

  Future<void> _loadMitraList() async {
    if (_loadingMitra) return;
    setState(() => _loadingMitra = true);
    try {
      final groupId = widget.item.groupId;
      if (groupId.isNotEmpty) {
        final list = await _historyService.getOvertimeByGroupId(groupId);
        if (mounted) setState(() => _mitraList = list);
      }
    } catch (e) {
      debugPrint('Error loading mitra list: $e');
    } finally {
      if (mounted) setState(() => _loadingMitra = false);
    }
  }

  // ===========================================================================
  // SAFE HELPERS
  // ===========================================================================
  String _safeString(dynamic val, [String fallback = '-']) {
    if (val == null) return fallback;
    final text = val.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _safeDateLong(dynamic date) {
    if (date == null) return '-';
    if (date is DateTime) {
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    }
    if (date is int || date is double) {
      final ms = date.toInt();
      if (ms > 0) {
        return DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }
    }
    return '-';
  }

  String _safeDate(dynamic date) {
    if (date == null) return '-';
    if (date is DateTime) {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    }
    return '-';
  }

  String _formatRupiah(dynamic amount) {
    double value = 0;
    if (amount is double) value = amount;
    else if (amount is int) value = amount.toDouble();
    else if (amount is String) value = double.tryParse(amount) ?? 0;
    return widget.rateService.formatRupiah(value);
  }

  Map<String, dynamic> get _lokasi {
    return widget.item.lokasi;
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================
  void _showSnack(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(color == Colors.red ? Icons.error_outline : Icons.info_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ===========================================================================
  // SPKL ACTIONS
  // ===========================================================================
  Future<void> _viewSpkl() async {
    if (_isLoading) return;
    if (!mounted) return;
    try {
      setState(() { _isLoading = true; _loadingMessage = '⏳ Memuat data SPKL...'; });
      final groupId = _safeString(widget.item.groupId, '');
      if (groupId.isEmpty) { _showSnack('Group ID tidak ditemukan', color: Colors.orange); return; }
      if (widget.item.status.toLowerCase() != 'disetujui') { _showSnack('SPKL hanya tersedia untuk lembur yang disetujui', color: Colors.orange); return; }
      if (widget.item.spklGenerated != true) { _showSnack('SPKL belum dibuat', color: Colors.orange); return; }
      setState(() => _loadingMessage = '📡 Mengambil data dari server...');
      final spklData = await _approvalService.getSpkl(groupId);
      if (spklData == null) { _showSnack('Data SPKL tidak ditemukan', color: Colors.orange); return; }
      setState(() => _loadingMessage = '📄 Menyiapkan dokumen PDF...');
      final filePath = await _spklGenerator.generateSpklPdf(spklData);
      if (filePath.isEmpty) { _showSnack('Gagal membuat file PDF', color: Colors.red); return; }
      setState(() => _loadingMessage = '📱 Membuka PDF...');
      final result = await OpenFile.open(filePath);
      if (result.type == ResultType.noAppToOpen) { _showSnack('Tidak ada aplikasi PDF reader', color: Colors.orange); }
      else if (result.type != ResultType.done) { _showSnack('Gagal membuka PDF', color: Colors.red); }
    } catch (e) {
      _showSnack('Gagal membuka SPKL: $e', color: Colors.red);
    } finally {
      if (mounted) { setState(() { _isLoading = false; _loadingMessage = ''; }); }
    }
  }

  Future<void> _shareSpkl() async {
    if (_isLoading) return;
    if (!mounted) return;
    try {
      setState(() { _isLoading = true; _loadingMessage = '⏳ Menyiapkan share SPKL...'; });
      final groupId = _safeString(widget.item.groupId, '');
      if (groupId.isEmpty) { _showSnack('Group ID tidak ditemukan', color: Colors.orange); return; }
      if (widget.item.status.toLowerCase() != 'disetujui') { _showSnack('Hanya lembur yang disetujui yang bisa dibagikan', color: Colors.orange); return; }
      setState(() => _loadingMessage = '📡 Mengambil data...');
      final spklData = await _approvalService.getSpkl(groupId);
      if (spklData == null) { _showSnack('Data SPKL tidak tersedia', color: Colors.orange); return; }
      setState(() => _loadingMessage = '📄 Membuat PDF...');
      final pdfBytes = await _spklGenerator.generatePdfBytes(spklData);
      if (pdfBytes.isEmpty) { _showSnack('Gagal membuat PDF untuk share', color: Colors.red); return; }
      setState(() => _loadingMessage = '📤 Membuka share dialog...');
      final fileName = 'SPKL_${widget.item.spklNomor ?? 'document'}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      _showSnack('Gagal membagikan SPKL', color: Colors.red);
    } finally {
      if (mounted) { setState(() { _isLoading = false; _loadingMessage = ''; }); }
    }
  }

  // ===========================================================================
  // PETA DIALOG
  // ===========================================================================
  void _showLokasiOnMap(BuildContext context, double lat, double lng, String alamat) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              AppBar(
                title: Text(alamat.isNotEmpty ? alamat : 'Lokasi Lembur',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 18.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.pge.overtimeapp',
                    ),
                    MarkerLayer(markers: [
                      Marker(point: LatLng(lat, lng), width: 50, height: 50,
                          child: const Icon(Icons.location_pin, color: Colors.red, size: 44))
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

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildStatusSection(),
                    const SizedBox(height: 14),
                    _buildTimeSection(),
                    const SizedBox(height: 14),
                    _buildLokasiSection(),
                    const SizedBox(height: 14),
                    _buildPersonnelSection(),
                    const SizedBox(height: 14),
                    _buildCostSection(),
                    const SizedBox(height: 14),
                    if (widget.hasSpkl) _buildSpklActions(),
                    const SizedBox(height: 14),
                    _buildTimestampSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- HEADER ----------
  Widget _buildHandle() => Center(
        child: Container(
          width: 50, height: 5,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
        ),
      );

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: Text('Detail Lembur', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))),
        if (widget.hasSpkl)
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _viewSpkl,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(_isLoading ? 'Loading...' : 'SPKL', style: GoogleFonts.poppins(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
      ],
    );
  }

  // ---------- SECTIONS ----------
  Widget _buildStatusSection() {
    final color = OvertimeHelpers.getStatusColor(widget.item.status);
    final statusText = OvertimeHelpers.getStatusText(widget.item.status);
    return _card(title: 'Status', icon: Icons.flag, child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(statusText, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ),
      if (widget.item.spklNomor != null && widget.item.spklNomor!.isNotEmpty) ...[
        const SizedBox(width: 12),
        Expanded(child: Text('No: ${widget.item.spklNomor}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
      ],
    ]));
  }

  Widget _buildTimeSection() {
    return _card(title: 'Waktu', icon: Icons.access_time, child: Column(children: [
      _detailRow('Tanggal', _safeDateLong(widget.item.tanggal)),
      _detailRow('Jam', '${_safeString(widget.item.jamMulai)} - ${_safeString(widget.item.jamSelesai)}'),
      _detailRow('Durasi', '${widget.item.totalJam.toStringAsFixed(1)} jam'),
    ]));
  }

  Widget _buildLokasiSection() {
    final alamat = _lokasi['alamat'] ?? '';
    final rt = _lokasi['rt'] ?? '';
    final rw = _lokasi['rw'] ?? '';
    String alamatLengkap = alamat;
    if (rt.toString().isNotEmpty) alamatLengkap += ' RT $rt';
    if (rw.toString().isNotEmpty) alamatLengkap += ' RW $rw';
    final lat = _lokasi['latitude'];
    final lng = _lokasi['longitude'];
    final bool hasCoordinates = lat != null && lng != null;
    return _card(title: 'Lokasi', icon: Icons.location_on, child: Column(children: [
      _detailRow('Alamat', alamatLengkap.isNotEmpty ? alamatLengkap : 'Tidak diketahui'),
      if (hasCoordinates) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.pin_drop, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(child: Text('${(lat as num).toDouble().toStringAsFixed(6)}, ${(lng as num).toDouble().toStringAsFixed(6)}', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]))),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showLokasiOnMap(context, (lat).toDouble(), (lng).toDouble(), alamatLengkap),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.map, size: 14, color: Colors.blue),
                SizedBox(width: 4),
                Text('Lihat di Peta', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ],
    ]));
  }

  Widget _buildPersonnelSection() {
    final namaPengaju = widget.item.namaPengaju;
    return _card(title: 'Personil', icon: Icons.people, child: Column(children: [
      _detailRow('Pengawas', _safeString(namaPengaju)),
      if (widget.item.isMultiple == true) ...[
        _detailRow('Mitra', '${widget.item.totalMitra} Orang'),
        const SizedBox(height: 8),
        if (_loadingMitra)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_mitraList.isNotEmpty)
          _buildMitraTable(_mitraList)
        else
          Text('Daftar mitra tidak tersedia', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      ] else ...[
        _detailRow('Nama Mitra', _safeString(widget.item.namaMitra)),
      ],
    ]));
  }

  Widget _buildMitraTable(List<OvertimeHistory> mitraList) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
      children: [
        TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
          _tableCellHeader('Nama'), _tableCellHeader('Fungsi'), _tableCellHeader('Biaya'),
        ]),
        ...mitraList.map((m) {
          final biaya = m.estimasiBiayaPerMitra;
          return TableRow(children: [
            _tableCell(m.namaMitra ?? '-'),
            _tableCell(m.fungsiMitra ?? '-'),
            _tableCell(_formatRupiah(biaya), bold: true),
          ]);
        }),
      ],
    );
  }

  Widget _tableCellHeader(String text) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
      );

  Widget _tableCell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: Colors.black87)),
      );

  Widget _buildCostSection() {
    final isMitraDoc = widget.item.isMitraDocument;
    final perMitra = widget.item.estimasiBiayaPerMitra;
    final total = widget.item.estimasiBiayaTotal;
    return _card(title: 'Estimasi Biaya', icon: Icons.payments, child: Column(children: [
      if (isMitraDoc)
        _detailRow('Biaya', _formatRupiah(perMitra))
      else ...[
        if (widget.item.isMultiple == true) _detailRow('Per Mitra', _formatRupiah(perMitra)),
        _detailRow('Total', _formatRupiah(total)),
      ],
    ]));
  }

  Widget _buildSpklActions() {
    return Column(
      children: [
        if (_isLoading && _loadingMessage.isNotEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(_loadingMessage, style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue.shade700)),
            ]),
          ),
        if (_isLoading) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _viewSpkl,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text('Lihat SPKL', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300, disabledForegroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _shareSpkl,
            icon: const Icon(Icons.share),
            label: Text('Share SPKL', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700, disabledForegroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: _isLoading ? Colors.grey.shade300 : Colors.red.shade700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimestampSection() {
    return _card(title: 'Riwayat', icon: Icons.history, child: Column(children: [
      _detailRow('Dibuat', _safeDate(widget.item.createdAt)),
      _detailRow('Diupdate', _safeDate(widget.item.updatedAt)),
    ]));
  }

  // ===========================================================================
  // REUSABLE COMPONENTS
  // ===========================================================================
  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87))),
      ]),
    );
  }
}