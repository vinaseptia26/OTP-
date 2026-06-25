// lib/pages/report_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_absensi_service.dart';

// ==================== MODEL ====================

class ReportData {
  final String id;
  final String type;
  final DateTime createdAt;
  final String status;
  final String absensiStatus;
  final Map<String, dynamic> data;
  final String userId;
  final String userName;
  final String? userFungsi;

  ReportData({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.status,
    required this.absensiStatus,
    required this.data,
    this.userId = '',
    this.userName = '',
    this.userFungsi,
  });

  factory ReportData.fromOvertimeHistory(OvertimeHistory overtime) {
    return ReportData(
      id: overtime.id,
      type: 'lembur',
      createdAt: overtime.tanggal,
      status: overtime.status,
      absensiStatus: overtime.absensiStatus,
      data: {
        'check_in': overtime.jamMulai,
        'check_out': overtime.jamSelesai,
        'jam_mulai': overtime.jamMulai,
        'jam_selesai': overtime.jamSelesai,
        'total_jam': overtime.totalJam,
        'total_jam_desimal': overtime.totalJam,
        'alasan': overtime.alasan,
        'catatan_tambahan': overtime.catatanTambahan,
        'lokasi': overtime.lokasi,
        'jenis_lembur': overtime.jenisLembur,
        'absensi_status': overtime.absensiStatus,
        'approved_by': overtime.approvedBy,
        'approved_by_name': overtime.approvedByName,
        'approved_at': overtime.approvedAt,
        'estimasi_biaya_per_mitra': overtime.estimasiBiayaPerMitra,
        'estimasi_biaya_total': overtime.estimasiBiayaTotal,
        'urgensi': overtime.urgensi,
      },
      userId: overtime.mitraId ?? overtime.pengawasId ?? '',
      userName: overtime.namaMitra ?? overtime.namaPengawas ?? 'Unknown',
      userFungsi: overtime.fungsiMitra ?? overtime.pengawasFungsi,
    );
  }

  bool get isReallyWorked {
    return absensiStatus == 'selesai' ||
        absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'sudah_absen';
  }

  bool get hasValidAttendance {
    final checkIn = data['check_in']?.toString() ?? '';
    final checkOut = data['check_out']?.toString() ?? '';
    return checkIn.isNotEmpty && checkOut.isNotEmpty;
  }

  bool get isFullyValid => isReallyWorked && hasValidAttendance;
}

class TADStatistic {
  final String tadName;
  int totalLembur;
  double totalJam;
  int approved;
  int pending;
  int rejected;
  int sudahAbsen;
  int belumAbsen;

  TADStatistic({
    required this.tadName,
    this.totalLembur = 0,
    this.totalJam = 0,
    this.approved = 0,
    this.pending = 0,
    this.rejected = 0,
    this.sudahAbsen = 0,
    this.belumAbsen = 0,
  });
}

// ==================== MAIN PAGE ====================

class ReportPage extends StatefulWidget {
  final String userRole;
  final String? userFungsi;
  final String? userId;

  const ReportPage({
    super.key,
    required this.userRole,
    this.userFungsi,
    this.userId,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  final OvertimeHistoryService _historyService = OvertimeHistoryService();

  StreamSubscription<List<OvertimeHistory>>? _historySubscription;

  // ==================== STATE ====================

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  int _selectedTabIndex = 0;
  String _selectedStatus = 'semua';
  String _selectedFungsi = 'semua';
  String _searchQuery = '';

  List<ReportData> _reports = [];
  List<TADStatistic> _tadStatistics = [];
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _statistics = {};

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ==================== FILTER OPTIONS ====================

  List<String> get _statusOptions {
    return [
      'semua',
      'pending',
      'disetujui',
      'ditolak',
      'selesai',
      'dibatalkan'
    ];
  }

  List<String> get _fungsiOptions {
    final userRole = widget.userRole;
    final userFungsi = widget.userFungsi;

    if (userRole == 'super_admin' || userRole == 'superadmin') {
      return ['semua', 'operation', 'lab', 'maintenance', 'hsse', 'gpr', 'bs'];
    } else if (userRole == 'manager_hsse') {
      return ['semua', 'hsse'];
    } else if (userRole == 'manager_fungsi' && userFungsi != null) {
      return ['semua', userFungsi];
    } else if (userRole == 'pengawas' && userFungsi != null) {
      return [userFungsi];
    }
    return ['semua'];
  }

  // ==================== INIT ====================

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startRealtimeListener();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== 🔥 REAL-TIME LISTENER ====================

  void _startRealtimeListener() {
    _historySubscription?.cancel();
    setState(() => _isLoading = true);

    final bulan = _dateRange.start.month == _dateRange.end.month &&
            _dateRange.start.year == _dateRange.end.year
        ? DateFormat('yyyy-MM').format(_dateRange.start)
        : null;

    _historySubscription = _historyService
        .getOvertimeHistoryStream(
          userRole: widget.userRole,
          userFungsi: widget.userFungsi,
          userId: widget.userId,
          bulan: bulan,
          statusFilter: _selectedStatus != 'semua' ? _selectedStatus : null,
        )
        .listen(
          (List<OvertimeHistory> historyList) {
            _processRealtimeData(historyList);
          },
          onError: (error) {
            debugPrint('❌ Stream error: $error');
            _showError('Gagal streaming data: $error');
            setState(() => _isLoading = false);
          },
        );
  }

  void _processRealtimeData(List<OvertimeHistory> historyList) {
    final validOvertime = historyList.where((overtime) {
      final isInRange = overtime.tanggal
              .isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
          overtime.tanggal
              .isBefore(_dateRange.end.add(const Duration(days: 1)));

      final absensiStatus = overtime.absensiStatus;
      final isAbsensiValid = absensiStatus == 'selesai' ||
          absensiStatus == 'selesai_terlambat' ||
          absensiStatus == 'sudah_absen';

      final hasCheckIn = overtime.jamMulai.isNotEmpty;
      final hasCheckOut = overtime.jamSelesai.isNotEmpty;

      final isStatusValid =
          overtime.status == 'disetujui' || overtime.status == 'selesai';

      final matchFungsi = _selectedFungsi == 'semua' ||
          overtime.fungsiMitra == _selectedFungsi ||
          overtime.pengawasFungsi == _selectedFungsi;

      return isInRange &&
          isAbsensiValid &&
          hasCheckIn &&
          hasCheckOut &&
          isStatusValid &&
          matchFungsi;
    }).toList();

    List<OvertimeHistory> filtered = validOvertime;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = validOvertime.where((overtime) {
        final name =
            (overtime.namaMitra ?? overtime.namaPengawas ?? '').toLowerCase();
        final id = overtime.id.toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    }

    final reports =
        filtered.map((o) => ReportData.fromOvertimeHistory(o)).toList();
    _updateStatistics(filtered);

    setState(() {
      _reports = reports;
      _isLoading = false;
    });

    debugPrint('🔄 Real-time: ${_reports.length} laporan terverifikasi');
  }

  void _updateStatistics(List<OvertimeHistory> historyList) {
    int totalLembur = historyList.length;
    int pendingLembur =
        historyList.where((o) => o.status == 'pending').length;
    int approvedLembur =
        historyList.where((o) => o.status == 'disetujui').length;
    int rejectedLembur =
        historyList.where((o) => o.status == 'ditolak').length;
    int completedLembur =
        historyList.where((o) => o.status == 'selesai').length;
    int cancelledLembur =
        historyList.where((o) => o.status == 'dibatalkan').length;

    int sudahAbsen = historyList
        .where((o) =>
            o.absensiStatus == 'selesai' ||
            o.absensiStatus == 'selesai_terlambat' ||
            o.absensiStatus == 'sudah_absen')
        .length;
    int belumAbsen =
        historyList.where((o) => o.absensiStatus == 'belum_absen').length;
    int tidakLembur =
        historyList.where((o) => o.absensiStatus == 'tidak_lembur').length;
    int expiredAbsen = historyList
        .where((o) => o.absensiStatus == 'expired' || o.status == 'kadaluarsa')
        .length;

    double totalJamLembur = historyList.fold(0, (sum, o) => sum + o.totalJam);
    double totalBiaya = historyList.fold(
        0, (sum, o) => sum + (o.estimasiBiayaTotal > 0 ? o.estimasiBiayaTotal : o.estimasiBiayaPerMitra));

    final Map<String, TADStatistic> tadMap = {};
    for (var overtime in historyList) {
      final tadName = overtime.namaMitra ?? overtime.namaPengawas ?? 'Unknown';

      if (!tadMap.containsKey(tadName)) {
        tadMap[tadName] = TADStatistic(tadName: tadName);
      }

      final tad = tadMap[tadName]!;
      tad.totalLembur++;
      tad.totalJam += overtime.totalJam;

      switch (overtime.status) {
        case 'disetujui':
        case 'selesai':
          tad.approved++;
          break;
        case 'pending':
          tad.pending++;
          break;
        case 'ditolak':
          tad.rejected++;
          break;
      }

      if (overtime.absensiStatus == 'selesai' ||
          overtime.absensiStatus == 'selesai_terlambat' ||
          overtime.absensiStatus == 'sudah_absen') {
        tad.sudahAbsen++;
      } else if (overtime.absensiStatus == 'belum_absen') {
        tad.belumAbsen++;
      }
    }

    final uniqueUsers = historyList
        .map((o) => o.mitraId ?? o.pengawasId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .length;

    setState(() {
      _statistics = {
        'totalReports': totalLembur,
        'totalLembur': totalLembur,
        'pendingLembur': pendingLembur,
        'approvedLembur': approvedLembur,
        'rejectedLembur': rejectedLembur,
        'completedLembur': completedLembur,
        'cancelledLembur': cancelledLembur,
        'sudahAbsen': sudahAbsen,
        'belumAbsen': belumAbsen,
        'tidakLembur': tidakLembur,
        'expiredAbsen': expiredAbsen,
        'totalJamLembur': totalJamLembur,
        'totalBiaya': totalBiaya,
        'totalUsers': uniqueUsers,
      };
      _tadStatistics = tadMap.values.toList()
        ..sort((a, b) => b.totalJam.compareTo(a.totalJam));
    });
  }

  void _onFilterChanged() {
    _startRealtimeListener();
  }

  // ==================== 🔥 EXPORT PDF ====================

  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      final totalJam = (_statistics['totalJamLembur'] ?? 0.0);
      final totalBiaya = _statistics['totalBiaya'] ?? 0;
      final totalUsers = _statistics['totalUsers'] ?? 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // HEADER
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'LAPORAN LEMBUR TERVERIFIKASI',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Periode: ${DateFormat('dd MMM yyyy').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.green300),
                    ),
                    child: pw.Text(
                      'TERVERIFIKASI',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // RINGKASAN
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfSummaryItem(
                      'Total Laporan', '${_reports.length}', PdfColors.blue900),
                  _pdfSummaryItem(
                      'Total Jam',
                      '${totalJam.toStringAsFixed(1)} jam',
                      PdfColors.blue900),
                  _pdfSummaryItem(
                      'Total Biaya',
                      _historyService.formatRupiah(totalBiaya),
                      PdfColors.blue900),
                  _pdfSummaryItem(
                      'Total User', '$totalUsers', PdfColors.blue900),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // TABEL DATA
            pw.Text(
              'Detail Laporan',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FixedColumnWidth(65),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(95),
                4: const pw.FixedColumnWidth(65),
                5: const pw.FixedColumnWidth(65),
                6: const pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                  ),
                  children: [
                    _pdfHeaderCell('No'),
                    _pdfHeaderCell('Tanggal'),
                    _pdfHeaderCell('Status'),
                    _pdfHeaderCell('User'),
                    _pdfHeaderCell('Check-In'),
                    _pdfHeaderCell('Check-Out'),
                    _pdfHeaderCell('Total Jam'),
                  ],
                ),
                ..._reports.asMap().entries.map((entry) {
                  final index = entry.key;
                  final report = entry.value;
                  PdfColor statusColor;
                  switch (report.status) {
                    case 'disetujui':
                    case 'selesai':
                      statusColor = PdfColors.green700;
                      break;
                    case 'pending':
                      statusColor = PdfColors.orange700;
                      break;
                    case 'ditolak':
                      statusColor = PdfColors.red700;
                      break;
                    default:
                      statusColor = PdfColors.grey600;
                  }
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index.isEven ? PdfColors.white : PdfColors.grey200,
                    ),
                    children: [
                      _pdfCell('${index + 1}', align: pw.TextAlign.center),
                      _pdfCell(DateFormat('dd/MM').format(report.createdAt)),
                      _pdfCell(_historyService.getStatusText(report.status),
                          color: statusColor),
                      _pdfCell(report.userName),
                      _pdfCell(
                        report.data['check_in']?.toString() ?? '-',
                        color: PdfColors.green700,
                      ),
                      _pdfCell(
                        report.data['check_out']?.toString() ?? '-',
                        color: PdfColors.red700,
                      ),
                      _pdfCell(
                        '${report.data['total_jam_desimal'] ?? 0} jam',
                        align: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // FOOTER
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Dicetak: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'laporan_lembur_terverifikasi_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      _showSuccess('✅ PDF siap dibagikan');
    } catch (e) {
      _showError('❌ Gagal export PDF: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
          color: PdfColors.blue900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfCell(String text, {PdfColor? color, pw.TextAlign? align}) {
    final PdfColor finalColor = color ?? PdfColors.black;
    final pw.TextAlign finalAlign = align ?? pw.TextAlign.left;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, color: finalColor),
        textAlign: finalAlign,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  // ==================== ACTION FUNCTIONS ====================

  Future<void> _approveReport(String reportId) async {
    try {
      final result = await _historyService.updateOvertimeStatus(
        docId: reportId,
        status: 'disetujui',
        note: 'Disetujui dari halaman laporan',
      );
      if (result['success'] == true) {
        _showSuccess('✅ Laporan disetujui');
      } else {
        _showError('❌ ${result['message']}');
      }
    } catch (e) {
      _showError('❌ Gagal approve: $e');
    }
  }

  Future<void> _rejectReport(String reportId) async {
    final reasonController = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Laporan'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Alasan penolakan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await _historyService.updateOvertimeStatus(
                  docId: reportId,
                  status: 'ditolak',
                  note: reasonController.text,
                );
                if (result['success'] == true) {
                  _showSuccess('✅ Laporan ditolak');
                } else {
                  _showError('❌ ${result['message']}');
                }
              } catch (e) {
                _showError('❌ Gagal tolak: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  String _getStatusLabel(String status) {
    return _historyService.getStatusText(status);
  }

  Color _getStatusColor(String status) {
    return _historyService.getStatusColor(status);
  }

  String _getAbsensiLabel(String absensiStatus) {
    switch (absensiStatus) {
      case 'selesai':
        return '✅ Selesai';
      case 'selesai_terlambat':
        return '⚠️ Selesai Terlambat';
      case 'sudah_absen':
        return '📸 Sudah Absen';
      case 'belum_absen':
        return '⏳ Belum Absen';
      case 'tidak_lembur':
        return '❌ Tidak Lembur';
      case 'expired':
        return '🕐 Kadaluarsa';
      default:
        return absensiStatus;
    }
  }

  Color _getAbsensiColor(String absensiStatus) {
    switch (absensiStatus) {
      case 'selesai':
      case 'sudah_absen':
        return const Color(0xFF4CAF50);
      case 'selesai_terlambat':
        return const Color(0xFFFF9800);
      case 'belum_absen':
        return const Color(0xFF2196F3);
      case 'tidak_lembur':
      case 'expired':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text(
          '📊 Laporan Lembur Terverifikasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pilih Periode',
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
                locale: const Locale('id', 'ID'),
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _onFilterChanged();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _onFilterChanged,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _isExporting ? null : _exportToPDF,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() => _selectedTabIndex = index);
              },
              indicatorColor: const Color(0xFF1E3C72),
              indicatorWeight: 3,
              labelColor: const Color(0xFF1E3C72),
              unselectedLabelColor: const Color(0xFF9E9E9E),
              labelStyle:
                  GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.description), text: 'Laporan'),
                Tab(icon: Icon(Icons.bar_chart), text: 'Statistik'),
              ],
            ),
          ),
        ),
      ),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Mengekspor PDF...'),
                ],
              ),
            )
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedTabIndex == 0
                          ? _buildReportList()
                          : _buildStatisticsView(),
                ),
              ],
            ),
    );
  }

  // ==================== FILTER BAR ====================

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _onFilterChanged();
            },
            decoration: InputDecoration(
              hintText: '🔍 Cari laporan...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _onFilterChanged();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  value: _selectedStatus,
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                        value: status,
                        child: Text(_historyService.getStatusText(status)));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                      _onFilterChanged();
                    }
                  },
                ),
                const SizedBox(width: 8),
                if (_fungsiOptions.length > 1)
                  _buildFilterDropdown(
                    value: _selectedFungsi,
                    items: _fungsiOptions.map((fungsi) {
                      return DropdownMenuItem(
                        value: fungsi,
                        child: Text(fungsi == 'semua'
                            ? 'Semua Fungsi'
                            : fungsi.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedFungsi = value);
                        _onFilterChanged();
                      }
                    },
                  ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF4CAF50).withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user,
                          size: 16, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 4),
                      Text(
                        'Terverifikasi (Absen + Check-In/Out)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
              fontSize: 12, color: const Color(0xFF1E3C72)),
        ),
      ),
    );
  }

  // ==================== REPORT LIST ====================

  Widget _buildReportList() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data laporan terverifikasi',
              style: GoogleFonts.poppins(
                  fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Hanya menampilkan data yang sudah absen & check-in/out',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _onFilterChanged(),
      color: const Color(0xFF1E3C72),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(ReportData report) {
    final isPending = report.status == 'pending';
    final canApprove = isPending &&
        (widget.userRole == 'super_admin' ||
            widget.userRole == 'superadmin' ||
            widget.userRole == 'manager_fungsi' ||
            widget.userRole == 'manager_hsse' ||
            widget.userRole == 'pengawas');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending
              ? const Color(0xFFFF9800).withAlpha(128)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _showDetailDialog(report),
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
                      color: _getStatusColor(report.status).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.work_history,
                      size: 22,
                      color: _getStatusColor(report.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lembur',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF1E3C72),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm')
                              .format(report.createdAt),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusLabel(report.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(report.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.userName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: const Color(0xFF1E3C72),
                      ),
                    ),
                  ),
                  if (report.userFungsi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.userFungsi!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getAbsensiColor(report.absensiStatus)
                          .withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _getAbsensiColor(report.absensiStatus)
                              .withAlpha(77)),
                    ),
                    child: Text(
                      _getAbsensiLabel(report.absensiStatus),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getAbsensiColor(report.absensiStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.login,
                        size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Check-In: ${report.data['check_in'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF4CAF50)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.logout,
                        size: 14, color: Color(0xFFEF5350)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Check-Out: ${report.data['check_out'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFEF5350)),
                      ),
                    ),
                  ],
                ),
              ),
              if (report.status == 'pending' && canApprove)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _approveReport(report.id),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Setujui'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          backgroundColor:
                              const Color(0xFF4CAF50).withAlpha(26),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _rejectReport(report.id),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Tolak'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF5350),
                          backgroundColor:
                              const Color(0xFFEF5350).withAlpha(26),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DETAIL DIALOG ====================

  void _showDetailDialog(ReportData report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status).withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.work_history,
                              color: _getStatusColor(report.status), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lembur',
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E3C72))),
                              Text(
                                  'ID: ${report.id.substring(0, 8)}...',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status).withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_getStatusLabel(report.status),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(report.status))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('📅 Tanggal',
                        DateFormat('dd MMM yyyy, HH:mm').format(report.createdAt)),
                    _buildInfoRow('👤 User', report.userName),
                    if (report.userFungsi != null)
                      _buildInfoRow('🏢 Fungsi', report.userFungsi!.toUpperCase()),
                    _buildInfoRow('📋 Absensi',
                        _getAbsensiLabel(report.absensiStatus)),
                    const Divider(height: 30),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.login,
                                    color: Color(0xFF4CAF50), size: 20),
                                const SizedBox(height: 4),
                                Text('Check-In',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 2),
                                Text(report.data['check_in'] ?? '-',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4CAF50),
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.shade300),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.logout,
                                    color: Color(0xFFEF5350), size: 20),
                                const SizedBox(height: 4),
                                Text('Check-Out',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 2),
                                Text(report.data['check_out'] ?? '-',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF5350),
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        '⏰ Jam Mulai', report.data['jam_mulai'] ?? '-'),
                    _buildInfoRow(
                        '⏰ Jam Selesai', report.data['jam_selesai'] ?? '-'),
                    _buildInfoRow('📊 Total Jam',
                        '${report.data['total_jam_desimal'] ?? 0} jam'),
                    _buildInfoRow(
                        '💰 Biaya',
                        _historyService.formatRupiah(
                            report.data['estimasi_biaya_per_mitra'] ?? 0)),
                    _buildInfoRow('📝 Alasan', report.data['alasan'] ?? '-'),
                    if (report.data['catatan_tambahan'] != null &&
                        report.data['catatan_tambahan'].toString().isNotEmpty)
                      _buildInfoRow('📋 Catatan',
                          report.data['catatan_tambahan'] ?? '-'),
                    if (report.status == 'ditolak')
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFEF5350).withAlpha(77)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('❌ Alasan Ditolak',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEF5350))),
                            const SizedBox(height: 4),
                            Text(report.data['rejected_reason'] ?? '-',
                                style: const TextStyle(
                                    color: Color(0xFFEF5350))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (report.status == 'pending')
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _approveReport(report.id);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Setujui'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _rejectReport(report.id);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Tolak'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF5350),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      child: const Text('Tutup',
                          style: TextStyle(color: Color(0xFF1E3C72))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E3C72))),
          ),
        ],
      ),
    );
  }

  // ==================== STATISTICS VIEW ====================

  Widget _buildStatisticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildTADRecap(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalReports = _statistics['totalReports'] ?? 0;
    final totalUsers = _statistics['totalUsers'] ?? 0;
    final pending = _statistics['pendingLembur'] ?? 0;
    final approved = _statistics['approvedLembur'] ?? 0;
    final rejected = _statistics['rejectedLembur'] ?? 0;
    final sudahAbsen = _statistics['sudahAbsen'] ?? 0;
    final belumAbsen = _statistics['belumAbsen'] ?? 0;
    final tidakLembur = _statistics['tidakLembur'] ?? 0;
    final expired = _statistics['expiredAbsen'] ?? 0;
    final totalJam = (_statistics['totalJamLembur'] ?? 0.0);
    final totalBiaya = _statistics['totalBiaya'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Total Laporan', '$totalReports', const Color(0xFF1565C0), Icons.description)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Total User', '$totalUsers', const Color(0xFF4CAF50), Icons.people)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Pending', '$pending', const Color(0xFFFF9800), Icons.pending)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Disetujui', '$approved', const Color(0xFF4CAF50), Icons.check_circle)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Ditolak', '$rejected', const Color(0xFFEF5350), Icons.cancel)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Sudah Absen', '$sudahAbsen', const Color(0xFF4CAF50), Icons.verified_user)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Belum Absen', '$belumAbsen', const Color(0xFFFF9800), Icons.warning_amber)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Tidak Lembur', '$tidakLembur', const Color(0xFFF44336), Icons.cancel_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Expired', '$expired', const Color(0xFF9E9E9E), Icons.timer_off)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    Text('Total Jam Lembur',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF1E3C72))),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${totalJam.toStringAsFixed(1)} jam',
                    style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF9800)),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalJam / 500).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF5F7FA),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF9800)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Target: 500 jam',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Text('Total Biaya Lembur',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF1E3C72))),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _historyService.formatRupiah(totalBiaya),
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4CAF50)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(title,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ==================== TAD RECAP ====================

  Widget _buildTADRecap() {
    if (_tadStatistics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Center(
            child: Text('Belum ada data TAD',
                style: GoogleFonts.poppins(color: Colors.grey.shade500))),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: Color(0xFF1E3C72)),
                const SizedBox(width: 8),
                Text('Rekapitulasi TAD',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF1E3C72))),
                const Spacer(),
                Text('Total: ${_tadStatistics.length} TAD',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tadStatistics.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
              itemBuilder: (context, index) {
                final tad = _tadStatistics[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${index + 1}. ${tad.tadName}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: const Color(0xFF1E3C72))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '${tad.totalJam.toStringAsFixed(1)} jam',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF9800))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTadBadge('📝 ${tad.totalLembur}',
                              const Color(0xFF9E9E9E)),
                          const SizedBox(width: 8),
                          _buildTadBadge('✅ ${tad.approved}',
                              const Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          _buildTadBadge('⏳ ${tad.pending}',
                              const Color(0xFFFF9800)),
                          const SizedBox(width: 8),
                          _buildTadBadge('❌ ${tad.rejected}',
                              const Color(0xFFEF5350)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTadBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500)),
    );
  }
}