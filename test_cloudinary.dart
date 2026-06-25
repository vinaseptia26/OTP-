import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const cloudName = 'dqmfcji94';
  const apiKey = '189222175557667';
  const uploadPreset = 'absensi_preset';  // ← Upload preset yang dibuat

  print('🚀 Uploading test image to Cloudinary...\n');

  try {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final response = await http.post(
      uri,
      body: {
        'file': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'upload_preset': uploadPreset,  // ← Pakai upload preset
        'folder': 'test_flutter',
        'public_id': 'test_upload',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      print('✅ Upload berhasil!');
      print('📷 Secure URL: ${data['secure_url']}');
      print('🆔 Public ID: ${data['public_id']}');
      print('📐 Width: ${data['width']}px');
      print('📏 Height: ${data['height']}px');
      print('📁 Format: ${data['format']}');
      print('📦 Size: ${data['bytes']} bytes\n');

      final optimizedUrl = 'https://res.cloudinary.com/$cloudName/image/upload/'
          'f_auto,q_auto/${data['public_id']}';
      print('✨ Optimized URL: $optimizedUrl');
      print('📋 Done! Buka link di atas.');
    } else {
      print('❌ Upload gagal (HTTP ${response.statusCode})');
      print('   Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}