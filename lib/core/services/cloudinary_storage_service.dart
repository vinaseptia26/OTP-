// lib/core/services/cloudinary_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryStorageService {
  static final CloudinaryStorageService _instance =
      CloudinaryStorageService._internal();
  factory CloudinaryStorageService() => _instance;
  CloudinaryStorageService._internal();

  // Konfigurasi Cloudinary
  static const String _cloudName = 'dqmfcji94';
  static const String _uploadPreset = 'absensi_preset'; // ← Upload preset (unsigned)
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName';

  /// Upload foto absensi ke Cloudinary
  Future<Map<String, dynamic>> uploadFoto({
    required File photoFile,
    required String fileName,
    required String lemburId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'absensi_lembur/$lemburId'
        ..fields['public_id'] = fileName
        ..files.add(
          await http.MultipartFile.fromPath('file', photoFile.path),
        );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);

        return {
          'success': true,
          'url': data['secure_url'] ?? '',
          'publicId': data['public_id'] ?? '',
          'width': data['width'] ?? 0,
          'height': data['height'] ?? 0,
          'format': data['format'] ?? 'jpg',
          'size': data['bytes'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': 'Upload gagal (HTTP ${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error upload Cloudinary: $e');
      return {
        'success': false,
        'message': 'Gagal upload: $e',
      };
    }
  }

  /// Hapus foto dari Cloudinary
  Future<bool> deleteFoto(String publicId) async {
    try {
      final uri = Uri.parse('$_baseUrl/image/destroy');

      final response = await http.post(
        uri,
        body: {
          'upload_preset': _uploadPreset,
          'public_id': publicId,
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Gagal hapus foto: $e');
      return false;
    }
  }

  /// Generate URL dengan transformasi (auto format + auto quality)
  String getOptimizedUrl(String publicId) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/'
        'f_auto,q_auto/$publicId';
    // f_auto = automatic format selection (WebP, AVIF, etc)
    // q_auto = automatic quality optimization
  }
}