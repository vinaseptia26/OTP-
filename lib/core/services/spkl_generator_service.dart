// lib/core/services/spkl_generator_service.dart

// SPKL GENERATOR SERVICE - BISA PREVIEW DI WEB & MOBILE


import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SpklGeneratorService {
  static final SpklGeneratorService _instance =
      SpklGeneratorService._internal();

  factory SpklGeneratorService() => _instance;

  SpklGeneratorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache font
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  
  // LOAD FONTS
  

  Future<void> _loadFonts() async {
    if (_regularFont != null && _boldFont != null) return;

    try {
      final regularFontData =
          await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final boldFontData =
          await rootBundle.load('assets/fonts/Inter-Bold.ttf');

      _regularFont = pw.Font.ttf(regularFontData);
      _boldFont = pw.Font.ttf(boldFontData);
      debugPrint('✅ Custom fonts loaded');
    } catch (e) {
      debugPrint('⚠️ Using default Helvetica font: $e');
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    }
  }

  
  // GENERATE PDF BYTES (DIGUNAKAN UNTUK PREVIEW)
  

  Future<Uint8List> generatePdfBytes(
    Map<String, dynamic> spklData,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    // =========================================================================
    // SAFE DATA PARSING
    // =========================================================================

    final nomorSpkl =
        (spklData['nomor_spkl'] ?? 'SPKL/XXX/XXX').toString();

    final tanggal =
        (spklData['tanggal_lembur'] as Timestamp?)?.toDate() ??
            DateTime.now();

    final pengawasNama =
        (spklData['pengawas_nama'] ?? '-').toString();

    final pengawasFungsi =
        (spklData['pengawas_fungsi'] ?? '-').toString();

    final jamMulai = (spklData['jam_mulai'] ?? '-').toString();
    final jamSelesai =
        (spklData['jam_selesai'] ?? '-').toString();

    final totalJam =
        ((spklData['total_jam'] ?? 0) as num).toDouble();

    final jenisLembur = spklData['jenis_lembur'] == 'hari_libur'
        ? 'Hari Libur'
        : 'Hari Kerja';

    final alasan = (spklData['alasan'] ?? '-').toString();

    final lokasi =
        (spklData['lokasi'] as Map<String, dynamic>?) ?? {};
    final lokasiStr =
        (lokasi['alamat'] ?? 'Kantor PGE').toString();

    final estimasiBiaya =
        ((spklData['estimasi_biaya_total'] ?? 0) as num)
            .toDouble();

    final totalMitra =
        ((spklData['total_mitra'] ?? 1) as num).toInt();

    final approvedByName =
        (spklData['approved_by_name'] ?? '-').toString();

    final approvedAt =
        (spklData['approved_at'] as Timestamp?)?.toDate() ??
            DateTime.now();

    final mitraList = (spklData['mitra_list'] as List?) ?? [];

    // Safe string
    final safeNomorSpkl = nomorSpkl.length > 30
        ? '${nomorSpkl.substring(0, 30)}...'
        : nomorSpkl;

    // =========================================================================
    // PDF CONTENT
    // =========================================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: _regularFont ?? pw.Font.helvetica(),
          bold: _boldFont ?? pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(safeNomorSpkl),
        footer: (context) => _buildFooter(),
        build: (context) => [
          // TITLE
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'SURAT PERINTAH KERJA LEMBUR',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '(SPKL)',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Nomor: $nomorSpkl',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // INFORMASI LEMBUR
          _buildPdfSection('I. INFORMASI LEMBUR', [
            _buildPdfRow(
              'Tanggal',
              DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                  .format(tanggal),
            ),
            _buildPdfRow(
              'Waktu',
              '$jamMulai - $jamSelesai (${totalJam.toStringAsFixed(1)} jam)',
            ),
            _buildPdfRow('Jenis', jenisLembur),
            _buildPdfRow('Lokasi', lokasiStr),
            _buildPdfRow(
              'Urgensi',
              (spklData['urgensi'] ?? 'normal')
                  .toString()
                  .toUpperCase(),
            ),
          ]),

          pw.SizedBox(height: 16),

          // PENGAWAS
          _buildPdfSection('II. DATA PENGAWAS', [
            _buildPdfRow('Nama', pengawasNama),
            _buildPdfRow('Fungsi', pengawasFungsi),
          ]),

          pw.SizedBox(height: 16),

          // MITRA
          _buildPdfSection(
            'III. DAFTAR MITRA ($totalMitra orang)',
            [
              if (mitraList.isEmpty)
                pw.Text(
                  'Tidak ada data mitra',
                  style: const pw.TextStyle(fontSize: 10),
                )
              else
                _buildMitraTable(mitraList),
            ],
          ),

          pw.SizedBox(height: 16),

          // ALASAN
          _buildPdfSection('IV. ALASAN LEMBUR', [
            pw.Text(
              alasan,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ]),

          pw.SizedBox(height: 16),

          // BIAYA
          _buildPdfSection('V. ESTIMASI BIAYA', [
            _buildPdfRow(
              'Total Biaya',
              'Rp ${NumberFormat('#,###', 'id_ID').format(estimasiBiaya)}',
            ),
            _buildPdfRow(
              'Jumlah Mitra',
              '$totalMitra orang',
            ),
          ]),

          pw.SizedBox(height: 36),

          // TTD
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              // APPROVAL
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Disetujui oleh,',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 50),
                  pw.Text(
                    approvedByName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Manager',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    DateFormat('dd MMM yyyy', 'id_ID')
                        .format(approvedAt),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),

              // PENGAWAS
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Diketahui oleh,',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 50),
                  pw.Text(
                    pengawasNama,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Pengawas $pengawasFungsi',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    DateFormat('dd MMM yyyy', 'id_ID')
                        .format(tanggal),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  
  // GENERATE & SAVE PDF (MOBILE ONLY)
  

  Future<String> generateSpklPdf(
    Map<String, dynamic> spklData,
  ) async {
    try {
      final pdfBytes = await generatePdfBytes(spklData);

      if (kIsWeb) {
        // Web: return dummy path untuk preview
        debugPrint(
            '⚠️ Web preview mode - PDF generated as bytes');
        return 'preview_spkl_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Mobile: save file
      final nomorSpkl =
          (spklData['nomor_spkl'] ?? 'SPKL').toString();
      final safeFileName = nomorSpkl
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_');

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/SPKL_$safeFileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      debugPrint('✅ PDF saved to: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving PDF: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  
  // OPEN PDF
  

  Future<void> openPdf(String path) async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Open file not supported on web');
        return;
      }
      await OpenFile.open(path);
    } catch (e) {
      debugPrint('❌ Open PDF error: $e');
    }
  }

  
  // PRINT PDF
  

  Future<void> printPdf(
    Map<String, dynamic> spklData,
  ) async {
    try {
      final pdfBytes = await generatePdfBytes(spklData);

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name:
            'SPKL_${spklData['nomor_spkl'] ?? 'document'}.pdf',
      );
    } catch (e) {
      debugPrint('❌ Print PDF error: $e');
    }
  }

  
  // HELPER WIDGETS
  

  pw.Widget _buildHeader(String nomorSpkl) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
              color: PdfColors.blue, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'PT. PERTAMINA GEOTHERMAL ENERGY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.Text(
            'No: $nomorSpkl',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: PdfColors.grey, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dicetak otomatis oleh sistem',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey,
            ),
          ),
          pw.Text(
            DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.now()),
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSection(
    String title,
    List<pw.Widget> children,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(
            vertical: 5,
            horizontal: 8,
          ),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMitraTable(List mitraList) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue50,
          ),
          children: [
            _tableHeader('No'),
            _tableHeader('Nama'),
            _tableHeader('Fungsi'),
          ],
        ),
        ...mitraList.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final mitra =
              entry.value as Map<String, dynamic>;
          return pw.TableRow(
            children: [
              _tableCell(index.toString()),
              _tableCell(
                (mitra['nama_mitra'] ?? '-').toString(),
              ),
              _tableCell(
                (mitra['fungsi_mitra'] ?? '-').toString(),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }
}