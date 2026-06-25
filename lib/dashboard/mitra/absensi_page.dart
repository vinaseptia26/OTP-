// lib/pages/mitra/absensi_page.dart
// ============================================================================
// ABSENSI PAGE - FULL SCREEN VERSION WITH BOTTOM NAV
// ============================================================================
// 
// Halaman ini digunakan oleh MITRA untuk melakukan absensi lembur.
// 
// ALUR KERJA:
// 1. Load data lembur hari ini (via getTodayOvertimeForAbsensi)
// 2. Cek status keterlambatan (via cekStatusKeterlambatan)
// 3. Jika dalam masa normal → Verifikasi lokasi → Ambil selfie → Submit
// 4. Jika terlambat → Tampilkan form konfirmasi keterlambatan
// 5. Jika sudah resolved → Tampilkan status
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE IMPORTS
// ═══════════════════════════════════════════════════════════════════════════════
import '/core/services/overtime_absensi_service.dart';  // Service absensi (submit, cek status, dll)
import '/core/services/overtime_history_service.dart';   // Model OvertimeHistory & history service
import '/core/services/watermark_service.dart';          // Watermark foto
import '/core/services/cloudinary_storage_service.dart'; // Upload foto ke Cloudinary
import '/widgets/absensi/location_validator.dart';       // Validasi lokasi GPS
import '/widgets/bottom_nav/mitra_bottom_nav.dart';      // Bottom navigation mitra

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {

  // SERVICES

  final ImagePicker _imagePicker = ImagePicker();
  final LocationValidator _locationValidator = LocationValidator();
  final WatermarkService _watermarkService = WatermarkService();
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  final CloudinaryStorageService _cloudinaryService = CloudinaryStorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // UI STATES

  
  /// Flag loading utama (pertama kali load data)
  bool _isLoading = true;
  
  /// Flag loading saat verifikasi lokasi
  bool _isLoadingLocation = false;
  
  /// Flag saat proses ambil foto
  bool _isTakingPhoto = false;
  
  /// Flag saat proses submit absensi
  bool _isSubmitting = false;
  
  /// Pesan status yang ditampilkan ke user
  String _statusMessage = 'Memuat data lembur...';
  
  /// Detail error (opsional)
  String? _errorDetail;
  
  /// Posisi GPS saat ini
  Position? _currentPosition;
  
  /// Alamat hasil reverse geocoding
  String? _currentAddress;
  
  /// File foto yang diambil (XFile dari image_picker)
  XFile? _capturedImage;
  
  /// File preview (File dari XFile)
  File? _previewFile;
  
  /// Apakah lokasi valid (dalam radius)
  bool _locationValid = false;
  
  /// Apakah user sudah mencoba verifikasi ulang
  bool _hasAttemptedRetry = false;
  
  /// Jarak user dari lokasi lembur (meter)
  double? _distanceInMeters;
  
  /// Radius maksimal yang diizinkan (meter)
  double? _maxRadius;
  
  /// Maksimal retry upload foto
  static const int _maxRetries = 2;


  // DATA LEMBUR

  
  /// Data lembur hari ini (null jika tidak ada)
  OvertimeHistory? _overtimeItem;


  // KONFIRMASI KETERLAMBATAN

  
  /// Flag saat cek status keterlambatan
  bool _isCheckingStatus = true;
  
  /// Apakah sudah lewat batas normal
  bool _isLate = false;
  
  /// Apakah bisa konfirmasi keterlambatan
  bool _canConfirm = false;
  
  /// Apakah form konfirmasi ditampilkan
  bool _showKonfirmasiForm = false;
  
  /// Pilihan user: true = tetap lembur, false = tidak, null = belum pilih
  bool? _melakukanLembur;
  
  /// Controller untuk input alasan keterlambatan
  final TextEditingController _alasanController = TextEditingController();
  
  /// File foto bukti untuk konfirmasi keterlambatan
  File? _buktiFotoTerlambat;


  // LIFECYCLE


  @override
  void initState() {
    super.initState();
    debugPrint('🔵 AbsensiPage: initState - Memulai load data');
    _loadOvertimeData();
  }

  @override
  void dispose() {
    debugPrint('🔵 AbsensiPage: dispose - Membersihkan resources');
    _cleanupPreviewFile();
    _alasanController.dispose();
    super.dispose();
  }

  /// Membersihkan file preview dari temporary directory
  Future<void> _cleanupPreviewFile() async {
    try {
      if (_previewFile != null && await _previewFile!.exists()) {
        await _previewFile!.delete();
        debugPrint('✅ Absensi: Preview file cleaned up');
      }
    } catch (e) {
      debugPrint('⚠️ Absensi: Failed to cleanup preview file: $e');
    }
  }


  // NAVIGATION


  /// Kembali ke halaman sebelumnya
  void _goBack() {
    debugPrint('🔵 AbsensiPage: Navigasi kembali');
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/mitra-dashboard');
    }
  }


  // LOAD DATA LEMBUR HARI INI


  /// Memuat data lembur untuk hari ini
  /// 
  /// Alur:
  /// 1. Cek user login
  /// 2. Panggil _getTodayOvertime() untuk cari lembur hari ini
  /// 3. Jika ditemukan → lanjut _initCheck()
  /// 4. Jika tidak → tampilkan "Tidak ada jadwal"
  Future<void> _loadOvertimeData() async {
    debugPrint('🔵 AbsensiPage: _loadOvertimeData - Memulai');
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Memuat data lembur...';
      _errorDetail = null;
    });

    try {
      // 1. Cek user login
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ AbsensiPage: User tidak login');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Silakan login terlebih dahulu';
            _errorDetail = 'Anda harus login untuk mengakses halaman ini';
          });
        }
        return;
      }

      debugPrint('   User ID: ${currentUser.uid}');
      debugPrint('   User Name: ${currentUser.displayName}');

      // 2. Cari lembur hari ini
      final overtime = await _getTodayOvertime(currentUser.uid);
      
      if (overtime == null) {
        debugPrint('❌ AbsensiPage: Tidak ada lembur hari ini');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Tidak ada jadwal lembur hari ini';
            _errorDetail = 'Silakan cek kembali jadwal lembur Anda';
          });
        }
        return;
      }

      // 3. Lembur ditemukan
      debugPrint('✅ AbsensiPage: Lembur ditemukan!');
      debugPrint('   ID: ${overtime.id}');
      debugPrint('   Status: ${overtime.status}');
      debugPrint('   Jam: ${overtime.jamMulai} - ${overtime.jamSelesai}');
      debugPrint('   Tanggal: ${DateFormat('yyyy-MM-dd HH:mm').format(overtime.tanggal)}');

      if (mounted) {
        setState(() {
          _overtimeItem = overtime;
          _isLoading = false;
        });
      }

      // 4. Cek status keterlambatan
      await _initCheck();
      
    } catch (e, stackTrace) {
      debugPrint('❌ AbsensiPage: _loadOvertimeData ERROR');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Gagal memuat data';
          _errorDetail = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }


  // GET TODAY OVERTIME - MENGGUNAKAN SERVICE BARU


  /// Mencari lembur hari ini untuk user tertentu
  /// 
  /// Menggunakan method getTodayOvertimeForAbsensi() dari service
  /// yang sudah support Timestamp range query.
  /// 
  /// [userId] - UID user yang sedang login
  /// Returns OvertimeHistory jika ditemukan, null jika tidak ada
  Future<OvertimeHistory?> _getTodayOvertime(String userId) async {
    try {
      debugPrint('🔍 AbsensiPage: Mencari lembur hari ini...');
      debugPrint('   User ID: $userId');
      
      // ✅ GUNAKAN METHOD BARU dari service!
      // Method ini melakukan:
      // - Range query Timestamp (start of day → end of day)
      // - Cek di lembur_mitra
      // - Cek di pengajuan_lembur
      // - Cek via mitra_ids (multi-mitra)
      final result = await _absensiService.getTodayOvertimeForAbsensi(userId);
      
      if (result != null) {
        debugPrint('✅ AbsensiPage: Lembur ditemukan!');
        debugPrint('   ID: ${result.id}');
        debugPrint('   Status: ${result.status}');
        debugPrint('   Jam: ${result.jamMulai} - ${result.jamSelesai}');
        debugPrint('   Tanggal: ${DateFormat('yyyy-MM-dd HH:mm').format(result.tanggal)}');
      } else {
        debugPrint('❌ AbsensiPage: Tidak ada lembur hari ini');
      }
      
      return result;
      
    } catch (e) {
      debugPrint('❌ AbsensiPage: _getTodayOvertime ERROR: $e');
      return null;
    }
  }


  // INIT CHECK - CEK STATUS KETERLAMBATAN


  /// Mengecek status keterlambatan absensi
  /// 
  /// Memanggil cekStatusKeterlambatan() dari service.
  /// 
  /// Possible outcomes:
  /// - isAlreadyResolved → Sudah diproses (selesai/expired/ditolak)
  /// - canConfirm → Sudah lewat batas, bisa konfirmasi keterlambatan
  /// - isInRange → Masih dalam masa absensi normal → lanjut verifikasi lokasi
  Future<void> _initCheck() async {
    if (_overtimeItem == null) {
      debugPrint('⚠️ AbsensiPage: _initCheck - _overtimeItem null');
      return;
    }
    
    debugPrint('🔍 AbsensiPage: _initCheck - Cek status keterlambatan...');
    debugPrint('   Lembur ID: ${_overtimeItem!.id}');
    
    setState(() {
      _isCheckingStatus = true;
      _statusMessage = 'Mengecek status absensi...';
      _errorDetail = null;
    });

    try {
      // Panggil service untuk cek status
      final status = await _absensiService.cekStatusKeterlambatan(_overtimeItem!.id);
      
      debugPrint('   Hasil cek status:');
      debugPrint('   - isLate: ${status['isLate']}');
      debugPrint('   - canConfirm: ${status['canConfirm']}');
      debugPrint('   - isInRange: ${status['isInRange']}');
      debugPrint('   - isAlreadyResolved: ${status['isAlreadyResolved']}');
      debugPrint('   - mulaiTime: ${status['mulaiTime']}');
      debugPrint('   - selesaiTime: ${status['selesaiTime']}');
      debugPrint('   - batasNormal: ${status['batasNormal']}');
      debugPrint('   - batasExpired: ${status['batasExpired']}');
      
      if (!mounted) return;
      
      setState(() {
        _isCheckingStatus = false;
        _isLate = status['isLate'] == true;
        _canConfirm = status['canConfirm'] == true;
        
        if (status['isAlreadyResolved'] == true) {
          // ═══════════════════════════════════════════════════════════
          // CASE 1: SUDAH DIPROSES SEBELUMNYA
          // ═══════════════════════════════════════════════════════════
          debugPrint('⚠️ AbsensiPage: Absensi sudah diproses');
          _statusMessage = status['message'] ?? 'Absensi sudah diproses';
          _errorDetail = status['statusLabel'] ?? '';
          
        } else if (_canConfirm) {
          // ═══════════════════════════════════════════════════════════
          // CASE 2: BISA KONFIRMASI KETERLAMBATAN
          // ═══════════════════════════════════════════════════════════
          debugPrint('⚠️ AbsensiPage: Sudah lewat batas normal - tampilkan form konfirmasi');
          _statusMessage = '⚠️ Sudah lewat batas absensi normal';
          _errorDetail = 'Anda dapat mengkonfirmasi keterlambatan\n'
              'Batas normal: ${status['batasNormal'] ?? '-'} WIB\n'
              'Batas expired: ${status['batasExpired'] ?? '-'} WIB';
          
        } else if (status['isInRange'] == true) {
          // ═══════════════════════════════════════════════════════════
          // CASE 3: MASIH DALAM MASA ABSENSI NORMAL
          // ═══════════════════════════════════════════════════════════
          debugPrint('✅ AbsensiPage: Masih dalam masa absensi normal');
          _statusMessage = '✅ Masih dalam masa absensi normal';
          _errorDetail = null;
          
          // Lanjut verifikasi lokasi
          _startLocationVerification();
          
        } else {
          // ═══════════════════════════════════════════════════════════
          // CASE 4: STATUS LAINNYA
          // ═══════════════════════════════════════════════════════════
          debugPrint('ℹ️ AbsensiPage: Status lainnya');
          _statusMessage = status['message'] ?? 'Memverifikasi...';
          _errorDetail = null;
        }
      });
      
    } catch (e) {
      debugPrint('❌ AbsensiPage: _initCheck ERROR: $e');
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _statusMessage = 'Gagal cek status';
          _errorDetail = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }


  // VERIFIKASI LOKASI GPS


  /// Memverifikasi lokasi user untuk absensi
  /// 
  /// Alur:
  /// 1. Cek GPS aktif
  /// 2. Cek izin lokasi
  /// 3. Dapatkan koordinat
  /// 4. Reverse geocoding (dapatkan alamat)
  /// 5. Validasi jarak dengan location_validator
  Future<void> _startLocationVerification() async {
    if (_overtimeItem == null) {
      debugPrint('⚠️ AbsensiPage: _startLocationVerification - _overtimeItem null');
      return;
    }
    
    if (_isLoadingLocation || _isSubmitting) {
      debugPrint('⚠️ AbsensiPage: Already processing location');
      return;
    }

    if (!mounted) return;

    debugPrint('📍 AbsensiPage: Memulai verifikasi lokasi...');

    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Memverifikasi lokasi Anda...';
      _errorDetail = null;
    });

    try {
      // Step 1: Cek GPS
      _updateStatus('Memeriksa GPS...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('❌ GPS tidak aktif');
        _updateStatus('GPS tidak aktif', errorDetail: 'Aktifkan GPS di pengaturan perangkat Anda');
        _showSnackBar('GPS tidak aktif', Colors.orange);
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Step 2: Cek izin lokasi
      _updateStatus('Memeriksa izin lokasi...');
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        _updateStatus('Meminta izin lokasi...');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _updateStatus('Izin lokasi ditolak', errorDetail: 'Anda harus mengizinkan akses lokasi');
        _showSnackBar('Izin lokasi diperlukan', Colors.orange);
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _updateStatus('Izin lokasi ditolak permanen', errorDetail: 'Buka Pengaturan > Aplikasi > Izin > Lokasi');
        _showSnackBar('Buka pengaturan untuk mengizinkan lokasi', Colors.red);
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Step 3: Dapatkan posisi
      _updateStatus('Mendapatkan lokasi...');
      final position = await _locationValidator.getCurrentLocation().timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Waktu mendapatkan lokasi habis'),
      );

      if (position == null) {
        _updateStatus('Gagal mendapatkan lokasi', errorDetail: 'Pastikan Anda di area dengan sinyal GPS baik');
        setState(() => _isLoadingLocation = false);
        return;
      }

      _currentPosition = position;
      debugPrint('📍 Lokasi didapat: ${position.latitude}, ${position.longitude}');

      // Step 4: Dapatkan alamat
      _updateStatus('Mendapatkan alamat...');
      try {
        _currentAddress = await _locationValidator
            .getAddressFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 10));
        debugPrint('📍 Alamat: $_currentAddress');
      } catch (e) {
        debugPrint('⚠️ Address lookup failed: $e');
        _currentAddress = 'Alamat tidak tersedia';
      }

      // Step 5: Validasi lokasi
      _updateStatus('Memvalidasi lokasi...');
      final validationResult = await _locationValidator
          .validateLocation(
            currentLat: position.latitude,
            currentLng: position.longitude,
            overtimeItem: _overtimeItem!,
          )
          .timeout(const Duration(seconds: 15));

      _locationValid = validationResult['valid'] as bool? ?? false;
      _distanceInMeters = validationResult['distance'] as double?;
      _maxRadius = validationResult['max_radius'] as double?;

      debugPrint('📍 Hasil validasi:');
      debugPrint('   Valid: $_locationValid');
      debugPrint('   Jarak: $_distanceInMeters m');
      debugPrint('   Max Radius: $_maxRadius m');

      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;

        if (_locationValid) {
          _statusMessage = '✅ Lokasi valid! Silakan ambil selfie.';
          _errorDetail = null;
        } else {
          _statusMessage = '❌ Anda berada di luar radius absensi.';
          if (_distanceInMeters != null && _maxRadius != null) {
            _errorDetail = 'Jarak Anda ${_distanceInMeters!.toStringAsFixed(0)}m '
                'dari lokasi. Maksimal ${_maxRadius!.toStringAsFixed(0)}m.';
          } else {
            _errorDetail = 'Pastikan Anda berada di lokasi yang ditentukan.';
          }
        }
      });
      
    } on TimeoutException catch (e) {
      debugPrint('❌ Location timeout: $e');
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _updateStatus('Waktu verifikasi habis', errorDetail: 'Koneksi lambat atau sinyal GPS lemah');
      _showSnackBar('Timeout. Silakan coba lagi.', Colors.orange);
      
    } catch (e) {
      debugPrint('❌ Location verification error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _statusMessage = 'Gagal verifikasi lokasi';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });
    }
  }


  // AMBIL SELFIE


  /// Membuka kamera untuk mengambil foto selfie
  /// 
  /// Fallback:
  /// 1. Kamera depan → 2. Kamera belakang → 3. Galeri
  Future<void> _takeSelfie() async {
    if (_isTakingPhoto || _isSubmitting) {
      debugPrint('⚠️ AbsensiPage: Already taking photo or submitting');
      return;
    }
    
    if (!_locationValid) {
      _showSnackBar('Lokasi tidak valid', Colors.red);
      return;
    }

    if (!mounted) return;

    debugPrint('📸 AbsensiPage: Membuka kamera...');

    setState(() {
      _isTakingPhoto = true;
      _statusMessage = 'Membuka kamera...';
    });

    try {
      XFile? photo;

      // Coba kamera depan
      try {
        _updateStatus('Mengambil foto (kamera depan)...');
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (e) {
        debugPrint('⚠️ Front camera failed: $e');
        
        // Coba kamera belakang
        try {
          _updateStatus('Mengambil foto (kamera belakang)...');
          photo = await _imagePicker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            imageQuality: 60,
            maxWidth: 1280,
            maxHeight: 1280,
          );
        } catch (e2) {
          debugPrint('⚠️ Rear camera failed: $e2');
          
          // Fallback ke galeri
          _updateStatus('Kamera tidak tersedia, membuka galeri...');
          photo = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 60,
            maxWidth: 1280,
            maxHeight: 1280,
          );
        }
      }

      if (!mounted) return;

      if (photo == null) {
        debugPrint('📸 Foto dibatalkan');
        setState(() {
          _isTakingPhoto = false;
          _statusMessage = _locationValid ? '✅ Lokasi valid! Silakan ambil selfie.' : _statusMessage;
        });
        _showSnackBar('Pengambilan foto dibatalkan', Colors.grey);
        return;
      }

      // Validasi file
      final file = File(photo.path);
      if (!await file.exists()) throw Exception('File foto tidak ditemukan');

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) throw Exception('Ukuran foto terlalu besar (max 10MB)');

      debugPrint('📸 Foto berhasil: ${photo.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      if (!mounted) return;

      await _cleanupPreviewFile();

      setState(() {
        _capturedImage = photo;
        _previewFile = file;
        _isTakingPhoto = false;
        _statusMessage = '📸 Foto berhasil! Silakan submit absensi.';
        _errorDetail = null;
      });

      _showSnackBar('Foto berhasil diambil! ✅', Colors.green);

    } catch (e) {
      debugPrint('❌ Photo capture error: $e');
      if (!mounted) return;
      setState(() {
        _isTakingPhoto = false;
        _statusMessage = 'Gagal mengambil foto';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });
      _showSnackBar('Gagal mengambil foto', Colors.red);
    }
  }


  // AMBIL BUKTI FOTO UNTUK KONFIRMASI KETERLAMBATAN


  Future<void> _pickBuktiFoto() async {
    try {
      debugPrint('📸 AbsensiPage: Ambil foto bukti keterlambatan...');
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (photo != null && mounted) {
        setState(() => _buktiFotoTerlambat = File(photo.path));
        debugPrint('📸 Foto bukti berhasil');
      }
    } catch (e) {
      debugPrint('❌ Gagal ambil foto bukti: $e');
      _showSnackBar('Gagal mengambil foto: $e', Colors.red);
    }
  }


  // SUBMIT ABSENSI NORMAL


  /// Submit absensi normal dengan foto selfie
  /// 
  /// Alur:
  /// 1. Tambah watermark ke foto
  /// 2. Simpan file sementara
  /// 3. Upload ke Cloudinary (dengan retry)
  /// 4. Submit via absensi service
  /// 5. Tampilkan hasil
  Future<void> _submitAbsensi() async {
    // Validasi
    if (_isSubmitting) return;
    if (_capturedImage == null) { _showSnackBar('Silakan ambil foto terlebih dahulu', Colors.orange); return; }
    if (_currentPosition == null) { _showSnackBar('Lokasi tidak tersedia', Colors.red); return; }
    if (_overtimeItem == null) { _showSnackBar('Data lembur tidak ditemukan', Colors.red); return; }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) { _showSnackBar('Anda harus login', Colors.red); return; }

    File? tempFile;

    try {
      if (!mounted) return;

      setState(() {
        _isSubmitting = true;
        _statusMessage = '🔄 Menyiapkan upload...';
        _errorDetail = null;
      });

      // ═══════════════════════════════════════════════════
      // STEP 1: WATERMARK
      // ═══════════════════════════════════════════════════
      _updateStatus('🎨 Menambahkan watermark...');
      Uint8List watermarkedBytes;
      try {
        watermarkedBytes = await _watermarkService
            .addWatermark(
              imagePath: _capturedImage!.path,
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              address: _currentAddress ?? 'Alamat tidak tersedia',
              timestamp: DateTime.now(),
              workerName: currentUser.displayName ?? 'Mitra',
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('⚠️ Watermark failed: $e - menggunakan foto original');
        final originalFile = File(_capturedImage!.path);
        watermarkedBytes = await originalFile.readAsBytes();
      }

      if (watermarkedBytes.isEmpty) throw Exception('Data foto kosong');
      if (!mounted) return;

      // ═══════════════════════════════════════════════════
      // STEP 2: SIMPAN FILE SEMENTARA
      // ═══════════════════════════════════════════════════
      _updateStatus('💾 Menyimpan file sementara...');
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueId = '${currentUser.uid}_$timestamp';
      tempFile = File('${tempDir.path}/absensi_$uniqueId.jpg');
      await tempFile.writeAsBytes(watermarkedBytes);
      if (!mounted) return;

      // ═══════════════════════════════════════════════════
      // STEP 3: UPLOAD KE CLOUDINARY
      // ═══════════════════════════════════════════════════
      _updateStatus('☁️ Mengupload foto...');
      String? fotoUrl;
      int uploadAttempt = 0;

      while (uploadAttempt <= _maxRetries && fotoUrl == null) {
        try {
          uploadAttempt++;
          debugPrint('☁️ Upload attempt $uploadAttempt/$_maxRetries');
          
          final result = await _cloudinaryService
              .uploadFoto(
                photoFile: tempFile,
                fileName: uniqueId,
                lemburId: _overtimeItem!.id,
              )
              .timeout(const Duration(seconds: 60));

          if (result['success'] == true) {
            fotoUrl = result['url'] as String;
            debugPrint('✅ Upload success: $fotoUrl');
          } else {
            throw Exception(result['message'] ?? 'Upload gagal');
          }
        } on TimeoutException {
          debugPrint('⏳ Upload timeout on attempt $uploadAttempt');
          if (uploadAttempt > _maxRetries) {
            throw TimeoutException('Upload gagal setelah $_maxRetries kali percobaan');
          }
          _updateStatus('⏳ Upload lambat, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
        } catch (e) {
          debugPrint('❌ Upload error on attempt $uploadAttempt: $e');
          if (uploadAttempt > _maxRetries) rethrow;
          _updateStatus('⏳ Error, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
        }
      }

      if (fotoUrl == null) throw Exception('Gagal upload foto');
      if (!mounted) return;

      // ═══════════════════════════════════════════════════
      // STEP 4: SUBMIT ABSENSI VIA SERVICE
      // ═══════════════════════════════════════════════════
      _updateStatus('📝 Menyimpan data absensi...');
      
      final result = await _absensiService.submitAbsensi(
        docId: _overtimeItem!.id,
        fotoUrl: fotoUrl,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'Mitra',
      );

      debugPrint('📝 Hasil submit: ${result['success']}');
      debugPrint('   Message: ${result['message']}');
      debugPrint('   Status: ${result['absensiStatus']}');

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = '✅ Absensi berhasil!';
          _errorDetail = result['message'] ?? 'Absensi berhasil disimpan';
        });
        
        _showSnackBar('✅ Absensi berhasil disimpan!', Colors.green);
        
        // Reset form setelah 2 detik
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _capturedImage = null;
              _previewFile = null;
              _locationValid = false;
              _canConfirm = false;
            });
          }
        });
      } else {
        // Hapus foto dari Cloudinary jika submit gagal
        if (result['publicId'] != null) {
          await _cloudinaryService.deleteFoto(result['publicId']);
        }
        throw Exception(result['message'] ?? 'Gagal menyimpan data');
      }
      
    } on TimeoutException catch (e) {
      debugPrint('❌ Submit timeout: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _updateStatus('Koneksi timeout', errorDetail: 'Periksa koneksi internet Anda');
      _showSnackBar('Upload timeout', Colors.red);
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _updateStatus('Gagal submit absensi', errorDetail: e.toString().replaceAll('Exception: ', ''));
      _showSnackBar('Terjadi kesalahan', Colors.red);
    } finally {
      // Cleanup temp file
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to cleanup temp file: $e');
      }
    }
  }


  // SUBMIT KONFIRMASI KETERLAMBATAN


  /// Submit form konfirmasi keterlambatan
  /// 
  /// Dua skenario:
  /// - melakukanLembur = true → Upload foto bukti + submit
  /// - melakukanLembur = false → Cukup alasan
  Future<void> _submitKonfirmasi() async {
    // Validasi
    if (_melakukanLembur == null) {
      _showSnackBar('Pilih apakah Anda melakukan lembur atau tidak', Colors.orange);
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      _showSnackBar('Alasan wajib diisi', Colors.orange);
      return;
    }
    if (_melakukanLembur == true && _buktiFotoTerlambat == null) {
      _showSnackBar('Upload foto bukti wajib jika menyatakan tetap lembur', Colors.orange);
      return;
    }

    debugPrint('📝 AbsensiPage: Submit konfirmasi keterlambatan...');
    debugPrint('   Melakukan Lembur: $_melakukanLembur');
    debugPrint('   Alasan: ${_alasanController.text.trim()}');

    setState(() => _isSubmitting = true);
    
    try {
      // Upload foto bukti jika ada
      String? fotoUrl;
      if (_buktiFotoTerlambat != null) {
        debugPrint('☁️ Upload foto bukti...');
        final uploadResult = await _cloudinaryService.uploadFoto(
          photoFile: _buktiFotoTerlambat!,
          fileName: 'bukti_terlambat_${DateTime.now().millisecondsSinceEpoch}',
          lemburId: _overtimeItem!.id,
        );
        if (uploadResult['success'] == true) {
          fotoUrl = uploadResult['url'] as String;
          debugPrint('✅ Foto bukti terupload: $fotoUrl');
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Submit via service
      final result = await _absensiService.konfirmasiKeterlambatan(
        lemburId: _overtimeItem!.id,
        userId: currentUser?.uid ?? '',
        userName: currentUser?.displayName ?? 'Mitra',
        melakukanLembur: _melakukanLembur!,
        alasan: _alasanController.text.trim(),
        buktiFotoUrl: fotoUrl,
      );

      debugPrint('📝 Hasil konfirmasi: ${result['success']}');
      debugPrint('   Message: ${result['message']}');

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar('✅ ${result['message']}', Colors.green);
        setState(() {
          _isSubmitting = false;
          _showKonfirmasiForm = false;
          _melakukanLembur = null;
          _alasanController.clear();
          _buktiFotoTerlambat = null;
          _canConfirm = false;
          _statusMessage = '✅ Konfirmasi berhasil!';
          _errorDetail = result['message'] ?? '';
        });
      } else {
        setState(() => _isSubmitting = false);
        _showSnackBar(result['message'] ?? 'Gagal menyimpan konfirmasi', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ _submitKonfirmasi error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar('Gagal: $e', Colors.red);
      }
    }
  }


  // UI HELPERS


  /// Tampilkan snackbar
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Update status message
  void _updateStatus(String message, {String? errorDetail}) {
    if (!mounted) return;
    debugPrint('📱 Status: $message ${errorDetail != null ? "| Error: $errorDetail" : ""}');
    setState(() {
      _statusMessage = message;
      _errorDetail = errorDetail;
    });
  }


  // BUILD MAIN UI


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Main content
          Expanded(child: _buildBody()),
          // Bottom Navigation
          const MitraBottomNav(currentIndex: 1),
        ],
      ),
    );
  }

  /// App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Absensi Lembur',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: _goBack, tooltip: 'Tutup'),
      ],
    );
  }

  /// Main body dengan 3 state: Loading, No Data, Content
  Widget _buildBody() {
    // ─────────────────────────────────────────────────────────────────
    // STATE 1: LOADING
    // ─────────────────────────────────────────────────────────────────
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            const SizedBox(height: 16),
            Text('Memuat data...', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // STATE 2: TIDAK ADA LEMBUR
    // ─────────────────────────────────────────────────────────────────
    if (_overtimeItem == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Tidak Ada Jadwal Lembur',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
              ),
              if (_errorDetail != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorDetail!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade400),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOvertimeData,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat Ulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // STATE 3: CHECKING STATUS
    // ─────────────────────────────────────────────────────────────────
    if (_isCheckingStatus) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            const SizedBox(height: 16),
            Text('Mengecek status absensi...', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // STATE 4: CONTENT (FORM ABSENSI ATAU FORM KONFIRMASI)
    // ─────────────────────────────────────────────────────────────────
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card detail lembur
          _buildInfoCard(),
          const SizedBox(height: 16),

          // Banner keterlambatan (jika bisa konfirmasi)
          if (_canConfirm && !_showKonfirmasiForm) _buildLateBanner(),
          
          // Form konfirmasi ATAU form absensi normal
          if (_showKonfirmasiForm)
            _buildKonfirmasiForm()
          else ...[
            // Step indicator
            _buildStepIndicator(),
            const SizedBox(height: 24),
            // Status card (lokasi, dll)
            _buildStatusCard(),
            const SizedBox(height: 20),
            // Preview foto
            if (_capturedImage != null) _buildPhotoPreview(),
            if (_capturedImage != null) const SizedBox(height: 20),
            // Loading location
            if (_isLoadingLocation)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
              ),
            // Action buttons
            if (!_isLoadingLocation && !_isCheckingStatus) _buildActionButtons(),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  // WIDGET: INFO CARD DETAIL LEMBUR


  Widget _buildInfoCard() {
    final l = _overtimeItem!;
    final lokasi = l.lokasi is Map ? l.lokasi : <String, dynamic>{};
    final alamatLokasi = lokasi['alamat'] ?? lokasi['nama_lokasi'] ?? 'Kantor';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Detail Lembur',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRowWhite(Icons.calendar_today, DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(l.tanggal)),
          _infoRowWhite(Icons.access_time, '${l.jamMulai} - ${l.jamSelesai} (${l.totalJam.toStringAsFixed(1)} jam)'),
          _infoRowWhite(Icons.location_on, alamatLokasi),
          _infoRowWhite(Icons.person, l.namaMitra ?? l.namaPengawas ?? 'Tidak diketahui'),
        ],
      ),
    );
  }

  Widget _infoRowWhite(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // WIDGET: LATE BANNER


  Widget _buildLateBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Anda belum melakukan absensi!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sudah melewati batas waktu absensi normal.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade600),
          ),
          if (_errorDetail != null) ...[
            const SizedBox(height: 4),
            Text(_errorDetail!, style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showKonfirmasiForm = true),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Konfirmasi Keterlambatan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // WIDGET: FORM KONFIRMASI KETERLAMBATAN


  Widget _buildKonfirmasiForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📋 Konfirmasi Keterlambatan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Apakah Anda tetap melakukan lembur?', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          
          // Opsi Ya/Tidak
          Row(
            children: [
              Expanded(child: _optionCard('✅ Ya, Saya Lembur', Icons.check_circle, Colors.green, _melakukanLembur == true, () => setState(() => _melakukanLembur = true))),
              const SizedBox(width: 10),
              Expanded(child: _optionCard('❌ Tidak Lembur', Icons.cancel, Colors.red, _melakukanLembur == false, () => setState(() => _melakukanLembur = false))),
            ],
          ),
          const SizedBox(height: 14),
          
          // Input alasan
          TextField(
            controller: _alasanController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis alasan keterlambatan (minimal 10 karakter)...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A237E))),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          
          // Foto bukti (jika Ya)
          if (_melakukanLembur == true) ...[
            const SizedBox(height: 12),
            if (_buktiFotoTerlambat != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.file(_buktiFotoTerlambat!, height: 150, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _buktiFotoTerlambat = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickBuktiFoto,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: Text(_buktiFotoTerlambat != null ? '📸 Ganti Foto Bukti' : '📸 Ambil Foto Bukti', style: GoogleFonts.poppins(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
                side: const BorderSide(color: Color(0xFF1A237E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitKonfirmasi,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Kirim Konfirmasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() { _showKonfirmasiForm = false; _melakukanLembur = null; _alasanController.clear(); _buktiFotoTerlambat = null; }),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Kembali ke absensi normal'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }


  // WIDGET: OPTION CARD (YA/TIDAK)


  Widget _optionCard(String title, IconData icon, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }


  // WIDGET: STEP INDICATOR (1. Lokasi → 2. Selfie → 3. Submit)


  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: _buildStepItem('1', 'Lokasi', _locationValid, _isLoadingLocation)),
          _buildStepDivider(_locationValid),
          Expanded(child: _buildStepItem('2', 'Selfie', _capturedImage != null, _isTakingPhoto)),
          _buildStepDivider(_capturedImage != null),
          Expanded(child: _buildStepItem('3', 'Submit', false, _isSubmitting)),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String label, bool isComplete, bool isActive) {
    Color bgColor = isComplete ? Colors.green : isActive ? const Color(0xFF1976D2) : Colors.grey.shade300;
    Color textColor = isComplete ? Colors.green : isActive ? const Color(0xFF1976D2) : Colors.grey.shade500;
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bgColor,
          child: isComplete ? const Icon(Icons.check, color: Colors.white, size: 18) : Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: textColor, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStepDivider(bool isComplete) {
    return Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20), color: isComplete ? Colors.green : Colors.grey.shade300));
  }


  // WIDGET: STATUS CARD


  Widget _buildStatusCard() {
    final isValid = _locationValid;
    final Color bgColor = isValid ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08);
    final Color borderColor = isValid ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2);
    final Color iconColor = isValid ? Colors.green : Colors.orange;
    final IconData statusIcon = isValid ? Icons.check_circle : _isLoadingLocation ? Icons.location_searching : Icons.location_off;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          _isLoadingLocation
              ? const SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3))
              : Icon(statusIcon, size: 42, color: iconColor),
          const SizedBox(height: 14),
          Text(_statusMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
          if (_errorDetail != null && _errorDetail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
              child: Text(_errorDetail!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700)),
            ),
          ],
          const SizedBox(height: 14),
          if (_currentPosition != null) _infoRow(Icons.pin_drop, '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'),
          if (_distanceInMeters != null) _infoRow(Icons.straighten, 'Jarak: ${_distanceInMeters!.toStringAsFixed(0)} meter'),
          if (_maxRadius != null) _infoRow(Icons.circle_outlined, 'Radius maks: ${_maxRadius!.toStringAsFixed(0)} meter'),
          if (_currentAddress != null && _currentAddress!.isNotEmpty) _infoRow(Icons.location_city, _currentAddress!),
        ],
      ),
    );
  }


  // WIDGET: PHOTO PREVIEW


  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Image.file(
              _previewFile!,
              width: double.infinity, height: 260, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 260, color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('Gagal memuat foto', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: _isSubmitting ? null : _takeSelfie,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // WIDGET: ACTION BUTTONS


  Widget _buildActionButtons() {
    // Button: Verifikasi Lokasi (jika belum valid)
    if (!_locationValid) {
      return Column(
        children: [
          _buildButton(
            text: _hasAttemptedRetry ? '🔄 Coba Verifikasi Lagi' : '📍 Verifikasi Lokasi',
            icon: Icons.refresh,
            color: Colors.orange,
            loading: _isLoadingLocation,
            onPressed: () { _hasAttemptedRetry = true; _startLocationVerification(); },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoadingLocation ? null : _loadOvertimeData,
            child: Text('Muat Ulang', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
        ],
      );
    }

    // Button: Ambil Selfie
    if (_capturedImage == null) {
      return _buildButton(
        text: '📸 Ambil Selfie',
        icon: Icons.camera_alt,
        color: const Color(0xFF1976D2),
        loading: _isTakingPhoto,
        onPressed: _takeSelfie,
      );
    }

    // Button: Submit + Ambil Ulang
    return Column(
      children: [
        _buildButton(
          text: '✅ Submit Absensi',
          icon: Icons.check_circle,
          color: Colors.green,
          loading: _isSubmitting,
          onPressed: _submitAbsensi,
        ),
        if (!_isSubmitting) ...[
          const SizedBox(height: 12),
          _buildButton(
            text: '📸 Ambil Ulang',
            icon: Icons.refresh,
            color: Colors.grey.shade700,
            loading: _isTakingPhoto,
            onPressed: _takeSelfie,
          ),
        ],
      ],
    );
  }


  // WIDGET: BUTTON (REUSABLE)


  Widget _buildButton({
    required String text,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 20),
        label: Text(loading ? 'Memproses...' : text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }


  // WIDGET: INFO ROW


  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700, height: 1.4)),
          ),
        ],
      ),
    );
  }
}