import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class WatermarkService {
  /// Menambahkan watermark ke foto selfie menggunakan library image
  Future<Uint8List> addWatermark({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime timestamp,
    required String workerName,
  }) async {
    // Baca file gambar
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();

    // Decode gambar
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception('Gagal decode gambar');
    }

    // Buat copy untuk diedit
    final img.Image watermarkedImage = img.copyResize(originalImage, width: originalImage.width);

    // Siapkan data watermark
    final String dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(timestamp);
    final String timeStr = DateFormat('HH:mm:ss', 'id_ID').format(timestamp);
    final String coordStr = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    // Format alamat (potong jika terlalu panjang)
    final String formattedAddress = address.length > 50 
        ? '${address.substring(0, 50)}...' 
        : address;

    // Buat teks watermark
    final List<String> watermarkLines = [
      'ABSENSI LEMBUR',
      'Pekerja: $workerName',
      'Tanggal: $dateStr',
      'Waktu: $timeStr',
      'Lokasi: $coordStr',
      formattedAddress,
    ];

    // Ukuran teks (proporsional dengan gambar)
    final int fontSize = (watermarkedImage.width * 0.028).round().clamp(14, 28);
    final int lineHeight = (fontSize * 1.6).round();
    final int padding = (fontSize * 0.6).round();

    // Hitung total tinggi watermark
    final int totalHeight = (watermarkLines.length * lineHeight) + (padding * 2);

    // Posisi watermark di bagian bawah
    final int watermarkY = watermarkedImage.height - totalHeight - 20;

    // Gambar background semi-transparan di area watermark
    // fillRect: x1, y1, x2, y2
    img.fillRect(
      watermarkedImage,
      x1: 0,
      y1: watermarkY,
      x2: watermarkedImage.width,
      y2: watermarkY + totalHeight,
      color: img.ColorRgba8(0, 0, 0, 200), // Hitam semi-transparan (alpha ~0.78)
    );

    // Gambar teks watermark
    for (int i = 0; i < watermarkLines.length; i++) {
      final int textX = padding;
      final int textY = watermarkY + padding + (i * lineHeight) + fontSize;

      img.drawString(
        watermarkedImage,
        watermarkLines[i],
        font: img.arial24,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255), // Putih solid
      );
    }

    // Tambahkan timestamp kecil di pojok kanan atas
    final String cornerText = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final int cornerFontSize = (fontSize * 0.6).round();
    final int cornerX = watermarkedImage.width - (cornerText.length * cornerFontSize * 0.5).round() - 10;
    final int cornerY = 10 + cornerFontSize;

    // Background kecil untuk timestamp pojok atas
    img.fillRect(
      watermarkedImage,
      x1: cornerX - 5,
      y1: 5,
      x2: watermarkedImage.width - 5,
      y2: cornerY + 8,
      color: img.ColorRgba8(0, 0, 0, 160), // Hitam semi-transparan
    );

    img.drawString(
      watermarkedImage,
      cornerText,
      font: img.arial14,
      x: cornerX,
      y: cornerY,
      color: img.ColorRgba8(255, 255, 255, 220), // Putih sedikit transparan
    );

    // Encode kembali ke JPEG
    return Uint8List.fromList(img.encodeJpg(watermarkedImage, quality: 90));
  }

  /// Alternatif: Menggunakan Flutter rendering untuk kualitas lebih baik
  /// (Digunakan jika ingin custom font dan layout yang lebih baik)
  Future<Uint8List> addWatermarkWithFlutter({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime timestamp,
    required String workerName,
  }) async {
    // Untuk sementara, gunakan metode image library
    // Bisa di-upgrade nanti dengan Flutter rendering
    return addWatermark(
      imagePath: imagePath,
      latitude: latitude,
      longitude: longitude,
      address: address,
      timestamp: timestamp,
      workerName: workerName,
    );
  }
}