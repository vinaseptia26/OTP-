// ============================================================================
// lib/widgets/absensi/absensi_dialog.dart
// MOBILE OPTIMIZED + FULLY VALIDATED VERSION
// Last Updated: 2026-05-12
// ============================================================================
// FEATURES:
// ✅ Full mobile optimized
// ✅ SafeArea support
// ✅ Permission handling lengkap
// ✅ GPS validation with timeout
// ✅ Anti double submit
// ✅ Firebase upload with retry
// ✅ Mounted safety checks everywhere
// ✅ Temp file automatic cleanup
// ✅ Better loading states with messages
// ✅ Retry system for failed operations
// ✅ Camera fallback (front → rear → gallery)
// ✅ Image preview with error handling
// ✅ Better UX with step indicator
// ✅ Low-end device optimized (compressed images)
// ✅ Android/iOS ready
// ✅ Firebase Auth null safety
// ✅ Unique filename generation (anti-konflik)
// ✅ Consistent error logging
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/watermark_service.dart';
import '/widgets/absensi/location_validator.dart';

// ============================================================================
// ABSENSI DIALOG WIDGET
// ============================================================================

class AbsensiDialog extends StatefulWidget {
  final OvertimeHistory overtimeItem;

  const AbsensiDialog({
    super.key,
    required this.overtimeItem,
  });

  /// Show absensi dialog as modal bottom sheet
  /// Returns true if absensi berhasil, false if gagal, null if dibatalkan
  static Future<bool?> show(
    BuildContext context,
    OvertimeHistory overtimeItem,
  ) {
    // Validasi context
    if (!context.mounted) {
      debugPrint('AbsensiDialog: Context not mounted');
      return Future.value(null);
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => AbsensiDialog(
        overtimeItem: overtimeItem,
      ),
    );
  }

  @override
  State<AbsensiDialog> createState() => _AbsensiDialogState();
}

// ============================================================================
// STATE
// ============================================================================

class _AbsensiDialogState extends State<AbsensiDialog> {
  // ===========================================================================
  // SERVICES
  // ===========================================================================

  final ImagePicker _imagePicker = ImagePicker();
  final LocationValidator _locationValidator = LocationValidator();
  final WatermarkService _watermarkService = WatermarkService();
  final OvertimeHistoryService _historyService = OvertimeHistoryService();

  // ===========================================================================
  // STATES
  // ===========================================================================

  bool _isLoadingLocation = false;
  bool _isTakingPhoto = false;
  bool _isSubmitting = false;

  String _statusMessage = 'Memverifikasi lokasi...';
  String? _errorDetail;

  Position? _currentPosition;
  String? _currentAddress;

  XFile? _capturedImage;
  File? _previewFile;

  bool _locationValid = false;
  bool _hasAttemptedRetry = false;

  double? _distanceInMeters;
  double? _maxRadius;

  // Retry counter
  int _retryCount = 0;
  static const int _maxRetries = 2;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    
    // Delay sedikit untuk animasi sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startLocationVerification();
      }
    });
  }

  @override
  void dispose() {
    // Cleanup preview file jika ada
    _cleanupPreviewFile();
    super.dispose();
  }

  /// Hapus file preview untuk hemat storage
  Future<void> _cleanupPreviewFile() async {
    try {
      if (_previewFile != null && await _previewFile!.exists()) {
        await _previewFile!.delete();
        debugPrint('Absensi: Preview file cleaned up');
      }
    } catch (e) {
      debugPrint('Absensi: Failed to cleanup preview file: $e');
    }
  }

  // ===========================================================================
  // SAFE HELPERS
  // ===========================================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    // Clear existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                      ? Icons.error
                      : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _updateStatus(String message, {String? errorDetail}) {
    if (!mounted) return;
    
    setState(() {
      _statusMessage = message;
      _errorDetail = errorDetail;
    });
  }

  // ===========================================================================
  // LOCATION VERIFICATION
  // ===========================================================================

  Future<void> _startLocationVerification() async {
    // 🛡️ Anti double-tap
    if (_isLoadingLocation || _isSubmitting) {
      debugPrint('Absensi: Already processing, ignoring location request');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Memverifikasi lokasi Anda...';
      _errorDetail = null;
    });

    try {
      // -----------------------------------------------------------------------
      // CHECK GPS SERVICE
      // -----------------------------------------------------------------------
      
      _updateStatus('Memeriksa GPS...');
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        _updateStatus(
          'GPS tidak aktif',
          errorDetail: 'Aktifkan GPS di pengaturan perangkat Anda',
        );
        
        if (mounted) {
          _showRetryDialog(
            'GPS Tidak Aktif',
            'Aktifkan GPS terlebih dahulu untuk melakukan absensi.',
          );
        }
        return;
      }

      // -----------------------------------------------------------------------
      // CHECK PERMISSION
      // -----------------------------------------------------------------------
      
      _updateStatus('Memeriksa izin lokasi...');

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        _updateStatus('Meminta izin lokasi...');
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied) {
        _updateStatus(
          'Izin lokasi ditolak',
          errorDetail: 'Anda harus mengizinkan akses lokasi untuk absensi',
        );
        
        if (mounted) {
          _showRetryDialog(
            'Izin Lokasi Diperlukan',
            'Izinkan akses lokasi untuk memverifikasi posisi Anda.',
          );
        }
        return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        _updateStatus(
          'Izin lokasi ditolak permanen',
          errorDetail: 'Buka Pengaturan > Aplikasi > Izin > Lokasi',
        );
        
        if (mounted) {
          _showOpenSettingsDialog();
        }
        return;
      }

      // -----------------------------------------------------------------------
      // GET LOCATION WITH TIMEOUT
      // -----------------------------------------------------------------------
      
      _updateStatus('Mendapatkan lokasi...');

      final position = await _locationValidator
          .getCurrentLocation()
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              throw TimeoutException('Waktu mendapatkan lokasi habis');
            },
          );

      if (position == null) {
        _updateStatus(
          'Gagal mendapatkan lokasi',
          errorDetail: 'Pastikan Anda berada di area dengan sinyal GPS yang baik',
        );
        return;
      }

      _currentPosition = position;
      debugPrint('Absensi: Location obtained - ${position.latitude}, ${position.longitude}');

      // -----------------------------------------------------------------------
      // GET ADDRESS (OPTIONAL - NON-BLOCKING)
      // -----------------------------------------------------------------------
      
      _updateStatus('Mendapatkan alamat...');

      try {
        _currentAddress = await _locationValidator
            .getAddressFromCoordinates(
              position.latitude,
              position.longitude,
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Absensi: Address lookup failed: $e');
        _currentAddress = 'Alamat tidak tersedia';
        // Tidak throw error karena alamat opsional
      }

      // -----------------------------------------------------------------------
      // VALIDATE LOCATION AGAINST OVERTIME ITEM
      // -----------------------------------------------------------------------
      
      _updateStatus('Memvalidasi lokasi...');

      final validationResult = await _locationValidator
          .validateLocation(
            currentLat: position.latitude,
            currentLng: position.longitude,
            overtimeItem: widget.overtimeItem,
          )
          .timeout(const Duration(seconds: 15));

      _locationValid = validationResult['valid'] as bool? ?? false;
      _distanceInMeters = validationResult['distance'] as double?;
      _maxRadius = validationResult['max_radius'] as double?;

      debugPrint(
        'Absensi: Validation - valid: $_locationValid, '
        'distance: ${_distanceInMeters?.toStringAsFixed(0)}m, '
        'maxRadius: ${_maxRadius?.toStringAsFixed(0)}m',
      );

      if (!mounted) return;

      // Update status berdasarkan hasil validasi
      setState(() {
        _isLoadingLocation = false;
        
        if (_locationValid) {
          _statusMessage = '✅ Lokasi valid! Silakan ambil selfie.';
          _errorDetail = null;
          _retryCount = 0; // Reset retry counter
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
      debugPrint('Absensi: Location timeout: $e');
      
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      
      _updateStatus(
        'Waktu verifikasi habis',
        errorDetail: 'Koneksi lambat atau sinyal GPS lemah',
      );
      
      _showSnackBar(
        'Timeout. Silakan coba lagi dengan koneksi yang lebih baik.',
        Colors.orange,
      );
      
    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('Absensi: Location verification error');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingLocation = false;
        _statusMessage = 'Gagal verifikasi lokasi';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ===========================================================================
  // TAKE SELFIE (WITH FALLBACK)
  // ===========================================================================

  Future<void> _takeSelfie() async {
    // 🛡️ Anti double-tap
    if (_isTakingPhoto || _isSubmitting) {
      debugPrint('Absensi: Already taking photo or submitting');
      return;
    }

    // 🛡️ Validasi lokasi
    if (!_locationValid) {
      _showSnackBar(
        'Lokasi tidak valid. Silakan verifikasi ulang.',
        Colors.red,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isTakingPhoto = true;
      _statusMessage = 'Membuka kamera...';
    });

    try {
      XFile? photo;

      // -----------------------------------------------------------------------
      // ATTEMPT 1: Front Camera (Selfie)
      // -----------------------------------------------------------------------
      try {
        _updateStatus('Mengambil foto (kamera depan)...');
        
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60, // Kompresi untuk low-end devices
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (e) {
        debugPrint('Absensi: Front camera failed: $e');
        
        // -----------------------------------------------------------------------
        // ATTEMPT 2: Rear Camera (Fallback)
        // -----------------------------------------------------------------------
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
          debugPrint('Absensi: Rear camera also failed: $e2');
          
          // -----------------------------------------------------------------------
          // ATTEMPT 3: Gallery (Last Resort)
          // -----------------------------------------------------------------------
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

      // User cancelled
      if (photo == null) {
        setState(() {
          _isTakingPhoto = false;
          _statusMessage = _locationValid
              ? '✅ Lokasi valid! Silakan ambil selfie.'
              : _statusMessage;
        });
        
        _showSnackBar(
          'Pengambilan foto dibatalkan.',
          Colors.grey,
        );
        return;
      }

      // Validasi file exists
      final file = File(photo.path);
      if (!await file.exists()) {
        throw Exception('File foto tidak ditemukan setelah diambil');
      }

      // Validasi file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Ukuran foto terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maksimal 10MB.');
      }

      debugPrint('Absensi: Photo captured - size: ${(fileSize / 1024).toStringAsFixed(0)}KB');

      if (!mounted) return;

      // Cleanup foto lama jika ada
      await _cleanupPreviewFile();

      setState(() {
        _capturedImage = photo;
        _previewFile = file;
        _isTakingPhoto = false;
        _statusMessage = '📸 Foto berhasil! Silakan submit absensi.';
        _errorDetail = null;
      });

    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('Absensi: Photo capture error');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);

      if (!mounted) return;

      setState(() {
        _isTakingPhoto = false;
        _statusMessage = 'Gagal mengambil foto';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });

      _showSnackBar(
        'Gagal mengambil foto: ${e.toString().replaceAll('Exception: ', '')}',
        Colors.red,
      );
    }
  }

  // ===========================================================================
  // SUBMIT ABSENSI
  // ===========================================================================

  Future<void> _submitAbsensi() async {
    // 🛡️ Anti double submit
    if (_isSubmitting) {
      debugPrint('Absensi: Already submitting');
      return;
    }

    // 🛡️ Validasi foto
    if (_capturedImage == null) {
      _showSnackBar(
        'Silakan ambil foto terlebih dahulu.',
        Colors.orange,
      );
      return;
    }

    // 🛡️ Validasi lokasi
    if (_currentPosition == null) {
      _showSnackBar(
        'Lokasi tidak tersedia. Silakan verifikasi ulang.',
        Colors.red,
      );
      return;
    }

    // 🛡️ Validasi user login
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar(
        'Anda harus login terlebih dahulu.',
        Colors.red,
      );
      return;
    }

    File? tempFile;

    try {
      if (!mounted) return;

      setState(() {
        _isSubmitting = true;
        _statusMessage = '🔄 Menyiapkan upload...';
        _errorDetail = null;
      });

      // -----------------------------------------------------------------------
      // STEP 1: ADD WATERMARK
      // -----------------------------------------------------------------------
      
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
        debugPrint('Absensi: Watermark failed: $e');
        
        // Jika watermark gagal, gunakan foto original
        _updateStatus('⚠️ Watermark gagal, menggunakan foto original...');
        
        final originalFile = File(_capturedImage!.path);
        watermarkedBytes = await originalFile.readAsBytes();
      }

      if (watermarkedBytes.isEmpty) {
        throw Exception('Data foto kosong setelah processing');
      }

      debugPrint('Absensi: Image processed - ${watermarkedBytes.length} bytes');

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // STEP 2: CREATE TEMP FILE
      // -----------------------------------------------------------------------
      
      _updateStatus('💾 Menyimpan file sementara...');

      final tempDir = await getTemporaryDirectory();
      
      // Buat nama file unik untuk hindari konflik
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueId = '${currentUser.uid}_$timestamp';
      
      tempFile = File(
        '${tempDir.path}/absensi_$uniqueId.jpg',
      );
      
      await tempFile.writeAsBytes(watermarkedBytes);
      
      debugPrint('Absensi: Temp file created: ${tempFile.path}');

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // STEP 3: UPLOAD TO FIREBASE STORAGE
      // -----------------------------------------------------------------------
      
      _updateStatus('☁️ Mengupload ke server...');

      final storage = FirebaseStorage.instance;
      
      // Nama file unik dengan struktur folder yang rapi
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'absensi/${widget.overtimeItem.id}/$dateStr/$uniqueId.jpg';
      
      final ref = storage.ref().child(fileName);

      // Upload dengan retry
      String? fotoUrl;
      int uploadAttempt = 0;
      
      while (uploadAttempt <= _maxRetries && fotoUrl == null) {
        try {
          uploadAttempt++;
          
          final uploadTask = ref.putFile(
            tempFile,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
              'userId': currentUser.uid,
              'overtimeId': widget.overtimeItem.id ?? 'unknown',
              'timestamp': timestamp.toString(),
              'latitude': _currentPosition!.latitude.toString(),
              'longitude': _currentPosition!.longitude.toString(),
              },
            ),
          );

          // Track progress
          uploadTask.snapshotEvents.listen((snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            if (mounted && progress < 1.0) {
              setState(() {
                _statusMessage = '☁️ Mengupload... ${(progress * 100).toStringAsFixed(0)}%';
              });
            }
          });

          await uploadTask.timeout(const Duration(seconds: 45));
          
          fotoUrl = await ref.getDownloadURL();
          
          debugPrint('Absensi: Upload success on attempt $uploadAttempt');
          
        } on TimeoutException {
          debugPrint('Absensi: Upload timeout on attempt $uploadAttempt');
          
          if (uploadAttempt > _maxRetries) {
            throw TimeoutException(
              'Upload gagal setelah $_maxRetries kali percobaan',
            );
          }
          
          _updateStatus('⏳ Upload lambat, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
          
        } on FirebaseException catch (e) {
          debugPrint('Absensi: Firebase error on attempt $uploadAttempt: ${e.code}');
          
          if (e.code == 'quota-exceeded' || e.code == 'unauthenticated') {
            throw e; // Jangan retry untuk error permanen
          }
          
          if (uploadAttempt > _maxRetries) throw e;
          
          _updateStatus('⏳ Error server, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
        }
      }

      if (fotoUrl == null) {
        throw Exception('Gagal upload foto');
      }

      debugPrint('Absensi: Foto URL: $fotoUrl');

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // STEP 4: SAVE TO FIRESTORE
      // -----------------------------------------------------------------------
      
      _updateStatus('📝 Menyimpan data absensi...');

      final success = await _historyService
          .updateAbsensiStatus(
            lemburId: widget.overtimeItem.id,
            absensiStatus: 'selesai',
            fotoUrl: fotoUrl,
            absensiOleh: currentUser.uid,
            absensiNama: currentUser.displayName ?? 'Mitra',
            absensiWaktu: DateTime.now(),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (success == true) {
        debugPrint('Absensi: Absensi saved successfully!');
        
        // Tutup dialog
        Navigator.pop(context, true);

        // Tampilkan sukses setelah animasi
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _showSnackBar(
              '✅ Absensi berhasil disimpan!',
              Colors.green,
            );
          }
        });
      } else {
        // Hapus foto dari storage jika save gagal
        try {
          await ref.delete();
        } catch (_) {}
        
        throw Exception('Gagal menyimpan data absensi ke database');
      }

    } on TimeoutException catch (e) {
      debugPrint('Absensi: Submit timeout: $e');
      
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      _updateStatus(
        'Koneksi timeout',
        errorDetail: 'Periksa koneksi internet Anda dan coba lagi',
      );
      
      _showSnackBar(
        'Upload timeout. Periksa koneksi internet Anda.',
        Colors.red,
      );
      
    } on FirebaseException catch (e) {
      debugPrint('Absensi: Firebase error: ${e.code} - ${e.message}');
      
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      String message;
      switch (e.code) {
        case 'quota-exceeded':
          message = 'Kuota storage penuh. Hubungi admin.';
          break;
        case 'unauthenticated':
          message = 'Sesi login berakhir. Silakan login ulang.';
          break;
        case 'unauthorized':
          message = 'Anda tidak memiliki akses untuk upload.';
          break;
        default:
          message = 'Error server. Silakan coba lagi.';
      }
      
      _updateStatus('Upload gagal', errorDetail: message);
      _showSnackBar(message, Colors.red);
      
    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('Absensi: Submit error');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);
      
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      _updateStatus(
        'Gagal submit absensi',
        errorDetail: e.toString().replaceAll('Exception: ', ''),
      );
      
      _showSnackBar(
        'Terjadi kesalahan. Silakan coba lagi.',
        Colors.red,
      );
      
    } finally {
      // -----------------------------------------------------------------------
      // CLEANUP TEMP FILE
      // -----------------------------------------------------------------------
      
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          debugPrint('Absensi: Temp file cleaned up');
        }
      } catch (e) {
        debugPrint('Absensi: Failed to cleanup temp file: $e');
      }
    }
  }

  // ===========================================================================
  // DIALOG HELPERS
  // ===========================================================================

  void _showRetryDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Tutup absensi dialog
            },
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startLocationVerification();
            },
            child: Text('Coba Lagi', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Izin Lokasi Diperlukan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Buka Pengaturan > Aplikasi > Pilih Aplikasi > Izin > Lokasi > Izinkan',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Geolocator.openLocationSettings();
              } catch (e) {
                debugPrint('Absensi: Cannot open settings: $e');
              }
            },
            child: Text('Buka Pengaturan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return SafeArea(
      child: Container(
        height: mediaQuery.size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: IgnorePointer(
          ignoring: _isSubmitting,
          child: Column(
            children: [
              // ===============================================================
              // HANDLE BAR
              // ===============================================================
              
              const SizedBox(height: 12),
              
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // ===============================================================
              // HEADER
              // ===============================================================
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Absensi Lembur',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!_isSubmitting)
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              
              // ===============================================================
              // CONTENT
              // ===============================================================
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 20),
                  child: Column(
                    children: [
                      // -------------------------------------------------------
                      // STEP INDICATOR
                      // -------------------------------------------------------
                      
                      _buildStepIndicator(),
                      
                      const SizedBox(height: 24),
                      
                      // -------------------------------------------------------
                      // STATUS CARD
                      // -------------------------------------------------------
                      
                      _buildStatusCard(),
                      
                      const SizedBox(height: 20),
                      
                      // -------------------------------------------------------
                      // PHOTO PREVIEW
                      // -------------------------------------------------------
                      
                      if (_capturedImage != null)
                        _buildPhotoPreview(),
                      
                      if (_capturedImage != null)
                        const SizedBox(height: 20),
                      
                      // -------------------------------------------------------
                      // LOADING / BUTTONS
                      // -------------------------------------------------------
                      
                      if (_isLoadingLocation)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      
                      if (!_isLoadingLocation)
                        _buildActionButtons(),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP INDICATOR
  // ===========================================================================

  Widget _buildStepIndicator() {
    final step1Complete = _locationValid;
    final step2Complete = _capturedImage != null;
    final step3Active = _isSubmitting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStepItem(
              number: '1',
              label: 'Lokasi',
              isComplete: step1Complete,
              isActive: _isLoadingLocation,
            ),
          ),
          _buildStepDivider(step1Complete),
          Expanded(
            child: _buildStepItem(
              number: '2',
              label: 'Selfie',
              isComplete: step2Complete,
              isActive: _isTakingPhoto,
            ),
          ),
          _buildStepDivider(step2Complete),
          Expanded(
            child: _buildStepItem(
              number: '3',
              label: 'Submit',
              isComplete: false,
              isActive: step3Active,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String label,
    required bool isComplete,
    required bool isActive,
  }) {
    Color bgColor;
    Color textColor;
    IconData? icon;

    if (isComplete) {
      bgColor = Colors.green;
      textColor = Colors.green;
      icon = Icons.check;
    } else if (isActive) {
      bgColor = const Color(0xFF1976D2);
      textColor = const Color(0xFF1976D2);
    } else {
      bgColor = Colors.grey.shade300;
      textColor = Colors.grey.shade500;
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bgColor,
          child: isComplete
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: textColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isComplete) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isComplete ? Colors.green : Colors.grey.shade300,
      ),
    );
  }

  // ===========================================================================
  // STATUS CARD
  // ===========================================================================

  Widget _buildStatusCard() {
    final isValid = _locationValid;
    final Color bgColor = isValid
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.orange.withValues(alpha: 0.08);
    final Color borderColor = isValid
        ? Colors.green.withValues(alpha: 0.2)
        : Colors.orange.withValues(alpha: 0.2);
    final Color iconColor = isValid ? Colors.green : Colors.orange;
    final IconData statusIcon = isValid
        ? Icons.check_circle
        : _isLoadingLocation
            ? Icons.location_searching
            : Icons.location_off;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Status icon
          _isLoadingLocation
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(statusIcon, size: 42, color: iconColor),

          const SizedBox(height: 14),

          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),

          // Error detail
          if (_errorDetail != null && _errorDetail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorDetail!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Location details
          if (_currentPosition != null) ...[
            _infoRow(
              Icons.pin_drop,
              '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
            ),
          ],

          if (_distanceInMeters != null)
            _infoRow(
              Icons.straighten,
              'Jarak: ${_distanceInMeters!.toStringAsFixed(0)} meter dari lokasi',
            ),

          if (_maxRadius != null)
            _infoRow(
              Icons.circle_outlined,
              'Radius maksimal: ${_maxRadius!.toStringAsFixed(0)} meter',
            ),

          if (_currentAddress != null && _currentAddress!.isNotEmpty)
            _infoRow(
              Icons.location_city,
              _currentAddress!,
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PHOTO PREVIEW
  // ===========================================================================

  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            // Preview image
            Image.file(
              _previewFile!,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (_, error, __) {
                debugPrint('Absensi: Image preview error: $error');
                return Container(
                  height: 260,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gagal memuat foto',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Retake button overlay
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _isSubmitting ? null : _takeSelfie,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ACTION BUTTONS
  // ===========================================================================

  Widget _buildActionButtons() {
    // Case 1: Lokasi belum valid
    if (!_locationValid) {
      return Column(
        children: [
          _buildButton(
            text: _hasAttemptedRetry
                ? 'Coba Verifikasi Lagi'
                : 'Verifikasi Lokasi',
            icon: Icons.refresh,
            color: Colors.orange,
            loading: _isLoadingLocation,
            onPressed: () {
              _hasAttemptedRetry = true;
              _startLocationVerification();
            },
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: _isLoadingLocation
                ? null
                : () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    // Case 2: Belum ambil foto
    if (_capturedImage == null) {
      return _buildButton(
        text: '📸 Ambil Selfie',
        icon: Icons.camera_alt,
        color: const Color(0xFF1976D2),
        loading: _isTakingPhoto,
        onPressed: _takeSelfie,
      );
    }

    // Case 3: Siap submit
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
          
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  text: '📸 Ambil Ulang',
                  icon: Icons.refresh,
                  color: Colors.grey.shade700,
                  loading: _isTakingPhoto,
                  onPressed: _takeSelfie,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // BUTTON COMPONENT
  // ===========================================================================

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
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          loading ? 'Memproses...' : text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // INFO ROW COMPONENT
  // ===========================================================================

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}