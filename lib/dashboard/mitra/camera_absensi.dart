// FILE: lib/dashboard/mitra/camera_absensi.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final logger = Logger();

class CameraAbsensiScreen extends StatefulWidget {
  final String? lemburId;
  final Map<String, dynamic>? lemburData;
  final String? groupId;
  final String? userId;
  final bool isMultiple;
  final bool isForcedAbsensi;
  final String? absensiType;
  
  const CameraAbsensiScreen({
    super.key,
    this.lemburId,
    this.lemburData,
    this.groupId,
    this.userId,
    this.isMultiple = false,
    this.isForcedAbsensi = false,
    this.absensiType = 'check_in',
  });

  @override
  State<CameraAbsensiScreen> createState() => _CameraAbsensiScreenState();
}

class _CameraAbsensiScreenState extends State<CameraAbsensiScreen>
    with WidgetsBindingObserver {
  
  // Camera Controllers
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  // GPS Data
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoadingLocation = true;
  bool _isLocationValid = false;
  String? _locationValidationMessage;
  double? _jarakDariKantor;
  double? _jarakDariProyek;
  
  // UI State
  bool _isCapturing = false;
  String? _errorMessage;
  
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Colors
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);
  final Color accentGreen = const Color(0xFF4CAF50);
  final Color accentRed = const Color(0xFFF44336);
  final Color accentOrange = const Color(0xFFFF9800);
  
  // Koordinat Kantor (sesuaikan dengan kantor Anda)
  static const double kantorLatitude = -6.200000;
  static const double kantorLongitude = 106.816666;
  static const double radiusKantor = 500;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _requestPermissions();
    _checkExpiredOvertime();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      _getCurrentLocation();
    }
  }
  
  Future<void> _checkExpiredOvertime() async {
    if (widget.lemburId == null) return;
    
    try {
      final lemburDoc = await _firestore.collection('lembur').doc(widget.lemburId!).get();
      final data = lemburDoc.data();
      
      if (data == null) return;
      
      final now = DateTime.now();
      final tanggalLembur = (data['tanggal'] as Timestamp).toDate();
      final jamSelesai = data['jam_selesai'] ?? '00:00';
      
      final waktuSelesai = DateTime(
        tanggalLembur.year,
        tanggalLembur.month,
        tanggalLembur.day,
        int.parse(jamSelesai.split(':')[0]),
        int.parse(jamSelesai.split(':')[1]),
      );
      
      final batasWaktu = waktuSelesai.add(const Duration(days: 1));
      
      if (now.isAfter(batasWaktu) && mounted) {
        setState(() {
          _errorMessage = 'Jadwal lembur ini sudah kadaluarsa. Tidak dapat melakukan absensi.';
        });
      }
    } catch (e) {
      logger.e('Error checking expired overtime: $e');
    }
  }
  
  Future<void> _requestPermissions() async {
    try {
      // Skip permission requests on web
      if (kIsWeb) {
        await _getCurrentLocation();
        return;
      }
      
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.location,
        Permission.locationWhenInUse,
        Permission.locationAlways,
      ].request();
      
      if (statuses[Permission.camera]!.isGranted &&
          (statuses[Permission.location]!.isGranted || 
           statuses[Permission.locationWhenInUse]!.isGranted)) {
        await _getCurrentLocation();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Izin kamera dan lokasi diperlukan untuk absensi';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error request permissions: $e';
        });
      }
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      // Skip camera initialization on web if needed
      if (kIsWeb) {
        setState(() {
          _isCameraInitialized = true;
        });
        return;
      }
      
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia');
      }
      
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menginisialisasi kamera: $e';
        });
      }
    }
  }
  
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
      _isLocationValid = false;
    });
    
    try {
      // For web, use browser geolocation
      if (kIsWeb) {
        // Web implementation would need to use dart:html
        // For now, throw error
        throw Exception('Web geolocation not fully implemented. Use mobile app.');
      }
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan GPS tidak aktif. Aktifkan GPS untuk melanjutkan.');
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen');
      }
      
      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
      
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
          if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
          if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);
          
          _currentAddress = addressParts.isNotEmpty ? addressParts.join(', ') : 'Alamat tidak tersedia';
        } else {
          _currentAddress = 'Alamat tidak tersedia';
        }
      } catch (e) {
        _currentAddress = 'Alamat tidak tersedia (${e.toString()})';
      }
      
      // Validate location
      await _validateLocation();
      
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  Future<void> _validateLocation() async {
    if (_currentPosition == null) {
      _isLocationValid = false;
      _locationValidationMessage = 'Lokasi tidak tersedia';
      return;
    }
    
    // Hitung jarak dari kantor
    _jarakDariKantor = _hitungJarakAntarKoordinat(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      kantorLatitude,
      kantorLongitude,
    );
    
    bool isValid = false;
    String validationMessage = '';
    
    // Cek apakah dalam radius kantor
    if (_jarakDariKantor! <= radiusKantor) {
      isValid = true;
      validationMessage = '✓ Lokasi valid (dalam radius kantor)';
    }
    
    // Jika tidak dalam radius kantor, cek apakah ada lokasi proyek yang ditentukan
    if (!isValid && widget.lemburData != null) {
      final lokasiProyek = widget.lemburData!['lokasi'];
      if (lokasiProyek != null && lokasiProyek['latitude'] != null && lokasiProyek['longitude'] != null) {
        final proyekLat = lokasiProyek['latitude'] as double;
        final proyekLng = lokasiProyek['longitude'] as double;
        
        _jarakDariProyek = _hitungJarakAntarKoordinat(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          proyekLat,
          proyekLng,
        );
        
        if (_jarakDariProyek! <= 100) {
          isValid = true;
          validationMessage = '✓ Lokasi valid (dalam radius proyek)';
        } else {
          validationMessage = '⚠ Lokasi di luar radius proyek (${_jarakDariProyek!.toStringAsFixed(0)}m)';
        }
      } else {
        validationMessage = '⚠ Lokasi di luar radius kantor (${_jarakDariKantor!.toStringAsFixed(0)}m)';
      }
    } else if (!isValid) {
      validationMessage = '⚠ Lokasi di luar radius kantor (${_jarakDariKantor!.toStringAsFixed(0)}m)';
    }
    
    // Cek akurasi GPS
    if (_currentPosition!.accuracy > 50) {
      validationMessage += '\n⚠ Akurasi GPS rendah (±${_currentPosition!.accuracy.toStringAsFixed(0)}m)';
    }
    
    setState(() {
      _isLocationValid = isValid;
      _locationValidationMessage = validationMessage;
    });
  }
  
  double _hitungJarakAntarKoordinat(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371000; // Radius bumi dalam meter
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  
  double _toRadians(double degree) {
    return degree * pi / 180;
  }
  
  Future<File> _addTextToImage(File originalImage, List<String> textLines) async {
    try {
      final bytes = await originalImage.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Gagal memproses gambar');
      }
      
      const int padding = 20;
      const int lineHeight = 35;
      
      int startY = image.height - (textLines.length * lineHeight) - padding;
      if (startY < padding) startY = padding;
      
      // Background hitam semi-transparan
      img.fillRect(
        image,
        x1: 0,
        y1: startY - 10,
        x2: image.width,
        y2: startY + (textLines.length * lineHeight) + 10,
        color: img.ColorRgba8(0, 0, 0, 200),
      );
      
      // Border putih
      img.drawRect(
        image,
        x1: 0,
        y1: startY - 10,
        x2: image.width,
        y2: startY + (textLines.length * lineHeight) + 10,
        color: img.ColorRgba8(255, 255, 255, 100),
        thickness: 2,
      );
      
      // Add text lines
      for (int i = 0; i < textLines.length; i++) {
        final y = startY + (i * lineHeight);
        final line = textLines[i];
        
        if (line.isEmpty) continue;
        
        img.Color color;
        if (line.contains('═══') || line.contains('ABSENSI')) {
          color = img.ColorRgba8(255, 215, 0, 255); // Emas
        } else if (line.contains('📍') || line.contains('⏰') || line.contains('📋')) {
          color = img.ColorRgba8(100, 255, 100, 255); // Hijau muda
        } else if (line.contains('⚠') && !_isLocationValid) {
          color = img.ColorRgba8(255, 100, 100, 255); // Merah untuk warning
        } else {
          color = img.ColorRgba8(255, 255, 255, 255); // Putih
        }
        
        img.drawString(
          image, 
          line, 
          font: img.arial14,
          x: padding, 
          y: y + 12,
          color: color,
        );
      }
      
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final newPath = '${directory.path}/absensi_watermark_$timestamp.jpg';
      final newFile = File(newPath);
      
      await newFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      return newFile;
    } catch (e) {
      debugPrint('Error adding text to image: $e');
      debugPrint('Full error details: $e');
      throw Exception('Gagal membuat watermark: ${e.toString()}');
    }
  }
  
  Future<File> _captureWithWatermark() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Kamera belum siap');
    }
    
    if (_currentPosition == null) {
      throw Exception('Lokasi belum tersedia');
    }
    
    try {
      final XFile picture = await _cameraController!.takePicture();
      final File originalFile = File(picture.path);
      
      final user = _auth.currentUser;
      final userName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
      final userEmail = user?.email ?? 'unknown';
      final userNip = user?.uid ?? 'unknown';
      
      final currentTime = DateTime.now();
      final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(currentTime);
      final formattedTime = DateFormat('HH:mm:ss', 'id_ID').format(currentTime);
      final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(currentTime);
      
      final displayNip = userNip.length > 8 ? userNip.substring(0, 8) : userNip;
      
      // Get device platform safely
      final String devicePlatform = _getPlatformName();
      
      // Build watermark lines with validation status
      final List<String> watermarkLines = [
        '═══════════════════════════════════════════════════',
        '              📸 ABSENSI KARYAWAN 📸               ',
        '═══════════════════════════════════════════════════',
        '',
        '👤 DATA KARYAWAN',
        '   Nama      : $userName',
        '   Email     : $userEmail',
        '   NIP       : $displayNip',
        '',
        '📍 LOKASI ABSENSI',
        '   Latitude  : ${_currentPosition!.latitude.toStringAsFixed(6)}°',
        '   Longitude : ${_currentPosition!.longitude.toStringAsFixed(6)}°',
        '   Akurasi   : ±${_currentPosition!.accuracy.toStringAsFixed(0)} meter',
        '   Alamat    : ${_currentAddress ?? 'Tidak tersedia'}',
        if (_jarakDariKantor != null) '   Jarak Kantor: ${(_jarakDariKantor! / 1000).toStringAsFixed(2)} km',
        if (_jarakDariProyek != null) '   Jarak Proyek: ${(_jarakDariProyek! / 1000).toStringAsFixed(2)} km',
        '   Status    : ${_isLocationValid ? "✅ VALID" : "⚠️ TIDAK VALID"}',
        if (!_isLocationValid && _locationValidationMessage != null) '   ${_locationValidationMessage!.split("\n")[0]}',
        '',
        '⏰ WAKTU ABSENSI',
        '   Tanggal   : $formattedDate',
        '   Waktu     : $formattedTime',
        '   Server    : $formattedDateTime',
        '',
        '📋 INFORMASI TAMBAHAN',
        '   Tipe      : ${widget.lemburId != null ? "Absensi Lembur" : "Absensi Reguler"}',
        if (widget.lemburId != null) '   ID Lembur : ${widget.lemburId!.substring(0, 8)}...',
        if (widget.isMultiple) '   Mode      : Lembur Grup',
        '   Status    : ${_isLocationValid ? "Valid & Tervalidasi" : "Perlu Verifikasi Manual"}',
        '   Device    : $devicePlatform',
        '',
        '═══════════════════════════════════════════════════',
        _isLocationValid 
            ? '    Dokumen ini telah tervalidasi secara digital    '
            : '    ⚠️ DOKUMEN PERLU VERIFIKASI MANUAL ⚠️    ',
        '═══════════════════════════════════════════════════',
      ].where((line) => line.isNotEmpty).toList();
      
      final watermarkedFile = await _addTextToImage(originalFile, watermarkLines);
      return watermarkedFile;
    } catch (e) {
      debugPrint('Full error in _captureWithWatermark: $e');
      throw Exception('Gagal membuat watermark: ${e.toString()}');
    }
  }
  
  String _getPlatformName() {
    // Safe platform detection without using Platform.operatingSystem
    if (kIsWeb) {
      return 'Web';
    }
    
    // Use try-catch for Platform checks
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
    } catch (e) {
      debugPrint('Error detecting platform: $e');
    }
    
    return 'Mobile Device';
  }
  
  Future<void> _uploadAbsensi(File imageFile) async {
    if (!mounted) return;
    
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });
    
    final currentContext = context;
    
    if (mounted) {
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Mengupload absensi...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );
    }
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');
      
      final timestamp = DateTime.now();
      final fileName = 'absensi/${user.uid}/${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}.jpg';
      
      final storageRef = _storage.ref().child(fileName);
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Prepare absensi data with user role information
      final absensiData = {
        'user_id': user.uid,
        'user_name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'user_email': user.email,
        'foto_url': downloadUrl,
        'foto_path': fileName,
        'waktu_device': DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'lokasi': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'accuracy': _currentPosition!.accuracy,
          'altitude': _currentPosition?.altitude ?? 0.0,
          'address': _currentAddress,
          'jarak_dari_kantor': _jarakDariKantor,
          'jarak_dari_proyek': _jarakDariProyek,
          'timestamp': timestamp.toIso8601String(),
        },
        'metadata': {
          'device_info': await _getDeviceInfo(),
          'app_version': '2.0.0',
          'platform': _getPlatformName(),
          'timestamp': timestamp.toIso8601String(),
        },
        'validasi_lokasi': {
          'is_valid': _isLocationValid,
          'validation_message': _locationValidationMessage,
          'radius_kantor': radiusKantor,
          'jarak_aktual': _jarakDariKantor,
          'validasi_metode': 'gps',
          'validated_at': FieldValue.serverTimestamp(),
        },
        'lembur_id': widget.lemburId,
        'group_id': widget.groupId ?? widget.lemburData?['group_id'],
        'is_multiple': widget.isMultiple,
        'status': widget.absensiType,
        'type': 'camera_absensi',
        'absensi_status': 'check_in',
        // Additional fields for role-based visibility
        'visible_to_roles': ['pengawas', 'manager', 'superadmin'],
        'requires_manual_verification': !_isLocationValid,
      };
      
      final docRef = await _firestore.collection('absensi').add(absensiData);
      
      // Update lembur collection
      if (widget.lemburId != null) {
        await _updateLemburCollection(docRef.id, downloadUrl, user);
      }
      
      if (mounted) {
        if (Navigator.canPop(currentContext)) {
          Navigator.pop(currentContext);
        }
      }
      
      // Show success message with role-based info
      if (mounted) {
        String successMessage;
        if (_isLocationValid) {
          successMessage = '✓ Absensi berhasil! Data tervalidasi.';
        } else {
          successMessage = '⚠ Absensi berhasil namun perlu verifikasi manual oleh pengawas.';
        }
            
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_isLocationValid ? Icons.check_circle : Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: _isLocationValid ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          Navigator.pop(currentContext, {
            'success': true,
            'is_valid': _isLocationValid,
            'lembur_id': widget.lemburId,
            'requires_verification': !_isLocationValid,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(currentContext)) {
          Navigator.pop(currentContext);
        }
        
        setState(() {
          _errorMessage = 'Gagal upload: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }
  
  Future<void> _updateLemburCollection(String absensiId, String downloadUrl, User user) async {
    try {
      final lemburDoc = await _firestore.collection('lembur').doc(widget.lemburId!).get();
      final lemburData = lemburDoc.data();
      
      if (lemburData == null) return;
      
      // Get existing absensi list
      final absensiList = List<Map<String, dynamic>>.from(lemburData['absensi_list'] ?? []);
      
      // Add new absensi with role visibility
      absensiList.add({
        'absensi_id': absensiId,
        'user_id': user.uid,
        'user_name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'foto_url': downloadUrl,
        'waktu': FieldValue.serverTimestamp(),
        'lokasi': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'address': _currentAddress,
          'jarak_dari_kantor': _jarakDariKantor,
        },
        'is_valid': _isLocationValid,
        'requires_verification': !_isLocationValid,
        'verified_by': null,
        'verified_at': null,
      });
      
      // Get mitra details
      final mitraDetails = List<Map<String, dynamic>>.from(lemburData['mitra_details'] ?? []);
      final mitraIndex = mitraDetails.indexWhere((m) => m['id'] == user.uid);
      
      if (mitraIndex != -1) {
        mitraDetails[mitraIndex]['absensi_status'] = 'selesai';
        mitraDetails[mitraIndex]['absensi_waktu'] = FieldValue.serverTimestamp();
        mitraDetails[mitraIndex]['foto_url'] = downloadUrl;
        mitraDetails[mitraIndex]['lokasi_valid'] = _isLocationValid;
        mitraDetails[mitraIndex]['jarak'] = _jarakDariKantor;
      }
      
      // Check if all mitra have completed absensi
      final totalMitra = lemburData['total_mitra'] ?? 1;
      final completedAbsensi = absensiList.length;
      final isAllCompleted = completedAbsensi >= totalMitra;
      
      Map<String, dynamic> updateData = {
        'absensi_list': absensiList,
        'mitra_details': mitraDetails,
        'absensi_status': isAllCompleted ? 'selesai' : 'partial',
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      if (isAllCompleted) {
        updateData['status'] = 'selesai';
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }
      
      await _firestore.collection('lembur').doc(widget.lemburId!).update(updateData);
      
      // Send notification to supervisor with location validity info
      await _sendNotificationToSupervisor(lemburData, user, completedAbsensi, totalMitra);
      
    } catch (e) {
      logger.e('Error updating lembur collection: $e');
      rethrow;
    }
  }
  
  Future<void> _sendNotificationToSupervisor(
    Map<String, dynamic> lemburData,
    User user,
    int completedAbsensi,
    int totalMitra,
  ) async {
    try {
      final supervisorId = lemburData['pengawas_id'];
      if (supervisorId == null) return;
      
      final isMultiple = lemburData['is_multiple'] ?? false;
      final isAllCompleted = completedAbsensi >= totalMitra;
      
      String title, body, type;
      Map<String, dynamic> data = {
        'lembur_id': widget.lemburId,
        'group_id': lemburData['group_id'],
        'mitra_name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'location_valid': _isLocationValid,
        'jarak': _jarakDariKantor,
        'needs_verification': !_isLocationValid,
      };
      
      if (isMultiple) {
        if (isAllCompleted) {
          title = '✅ Semua Mitra Sudah Absen';
          body = 'Semua $totalMitra mitra telah melakukan absensi untuk lembur grup.';
          if (!_isLocationValid) {
            body += ' Ada absensi yang perlu diverifikasi manual.';
          }
          type = 'all_mitra_absen';
          data['total_mitra'] = totalMitra;
        } else {
          title = _isLocationValid ? '📸 Mitra Melakukan Absensi' : '⚠️ Mitra Absen - Perlu Verifikasi';
          body = '${user.displayName ?? user.email} telah melakukan absensi. ($completedAbsensi/$totalMitra)';
          if (!_isLocationValid) {
            body += ' Lokasi tidak valid, perlu verifikasi.';
          }
          type = 'mitra_absen';
          data['progress'] = '$completedAbsensi/$totalMitra';
        }
      } else {
        title = _isLocationValid ? '📸 Absensi Lembur Selesai' : '⚠️ Absensi Lembur - Perlu Verifikasi';
        body = '${user.displayName ?? user.email} telah melakukan absensi untuk lembur.';
        if (!_isLocationValid) {
          body += ' Lokasi tidak valid, perlu verifikasi manual.';
        }
        type = 'absensi_completed';
      }
      
      await _firestore.collection('notifications').add({
        'userId': supervisorId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      logger.e('Error sending notification: $e');
    }
  }
  
  Future<String> _getDeviceInfo() async {
    final deviceInfo = <String, String>{};
    try {
      deviceInfo['platform'] = _getPlatformName();
      deviceInfo['model'] = _getPlatformName();
      deviceInfo['timestamp'] = DateTime.now().toIso8601String();
      deviceInfo['app_name'] = 'Absensi Kamera App v2.0';
    } catch (e) {
      deviceInfo['error'] = e.toString();
    }
    return deviceInfo.toString();
  }
  
  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Menginisialisasi kamera...',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CameraPreview(_cameraController!),
    );
  }
  
  Widget _buildLocationInfo() {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mendapatkan lokasi...',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_currentPosition == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gagal mendapatkan lokasi. Aktifkan GPS.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isLocationValid 
            ? Colors.green.withAlpha(25) 
            : Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLocationValid 
              ? Colors.green.withAlpha(76) 
              : Colors.orange.withAlpha(76),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLocationValid ? Icons.location_on : Icons.warning,
                color: _isLocationValid ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isLocationValid ? 'Lokasi Valid' : 'Lokasi Tidak Valid',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isLocationValid ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)} | Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          if (_jarakDariKantor != null)
            Text(
              'Jarak dari Kantor: ${(_jarakDariKantor! / 1000).toStringAsFixed(2)} km',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _jarakDariKantor! <= radiusKantor ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          if (_jarakDariProyek != null)
            Text(
              'Jarak dari Proyek: ${(_jarakDariProyek! / 1000).toStringAsFixed(2)} km',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
          const SizedBox(height: 4),
          if (_currentAddress != null)
            Text(
              _currentAddress!,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            'Akurasi: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m',
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
          ),
          if (_locationValidationMessage != null && !_isLocationValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _locationValidationMessage!,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ),
          // Additional info for users about verification
          if (!_isLocationValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi ini hanya dapat dilihat oleh Pengawas, Manager, dan Superadmin',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDateTimeInfo() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm:ss', 'id_ID').format(now),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'WIB',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLemburInfo() {
    if (widget.lemburData == null) return const SizedBox();
    
    final data = widget.lemburData!;
    final tanggal = (data['tanggal'] as Timestamp).toDate();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work, color: Colors.purple, size: 16),
              const SizedBox(width: 8),
              Text(
                'Informasi Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal)}',
            style: GoogleFonts.poppins(fontSize: 11),
          ),
          Text(
            'Jam: ${data['jam_mulai']} - ${data['jam_selesai']}',
            style: GoogleFonts.poppins(fontSize: 11),
          ),
          if (widget.isMultiple)
            Text(
              'Mode: Lembur Grup (${data['total_mitra']} mitra)',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.purple),
            ),
          Text(
            'Pengawas: ${data['nama_pengawas'] ?? '-'}',
            style: GoogleFonts.poppins(fontSize: 11),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.lemburId != null ? 'Absensi Lembur' : 'Absensi Kamera',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isCapturing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCameraPreview(),
              ),
            ),
            
            // Info Panel
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Error Message with details
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withAlpha(76)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _errorMessage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(51),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            // Show error details for debugging - removed fontFamily
                            if (_errorMessage != null && _errorMessage!.contains('Gagal membuat watermark'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Detail: ${_errorMessage!.replaceAll('Gagal membuat watermark: ', '')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    
                    // Lembur Info (if exists)
                    if (widget.lemburId != null)
                      _buildLemburInfo(),
                    
                    if (widget.lemburId != null)
                      const SizedBox(height: 12),
                    
                    // Date & Time
                    _buildDateTimeInfo(),
                    const SizedBox(height: 12),
                    
                    // Location Info
                    _buildLocationInfo(),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                            icon: const Icon(Icons.refresh),
                            label: Text('Refresh Lokasi', style: GoogleFonts.poppins()),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: (_isCapturing || _currentPosition == null || !_isCameraInitialized)
                                ? null
                                : () async {
                                    try {
                                      final imageFile = await _captureWithWatermark();
                                      await _uploadAbsensi(imageFile);
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() {
                                          _errorMessage = e.toString();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              'Ambil Absensi',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLocationValid ? accentGreen : accentOrange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Info Text with role visibility explanation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isLocationValid 
                            ? Colors.green.withAlpha(25)
                            : Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isLocationValid 
                              ? Colors.green.withAlpha(76)
                              : Colors.orange.withAlpha(76),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isLocationValid ? Icons.check_circle : Icons.warning,
                                color: _isLocationValid ? Colors.green : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isLocationValid
                                      ? '✓ Foto dilengkapi watermark GPS, waktu & user. Lokasi valid.'
                                      : '⚠️ Lokasi tidak dalam radius yang ditentukan. Absensi akan ditandai untuk verifikasi manual.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: _isLocationValid ? Colors.green[800] : Colors.orange[800],
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Data lokasi detail hanya dapat dilihat oleh Pengawas, Manager, dan Superadmin',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Info about expiry
                    if (widget.lemburId != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Batas waktu absensi: H+1 setelah jam selesai lembur',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}