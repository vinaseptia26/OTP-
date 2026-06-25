// lib/features/pengawas/lembur/ajukan_lembur_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '/core/services/overtime_service.dart';
import '/core/services/notification_service.dart';
import '/core/services/location_service.dart';
import '/core/services/mitra_limit_service.dart';
import '/widgets/rate_info_card.dart';
import '/widgets/ajukan_lembur/header_profile_card.dart';
import '/widgets/ajukan_lembur/progress_stepper.dart';
import '/widgets/ajukan_lembur/mitra_section.dart';
import '/widgets/ajukan_lembur/waktu_section.dart';
import '/widgets/ajukan_lembur/lokasi_section.dart';
import '/widgets/ajukan_lembur/alasan_section.dart';
import '/widgets/ajukan_lembur/urgensi_section.dart';
import '/widgets/ajukan_lembur/budget_breakdown_section.dart';
import '/widgets/ajukan_lembur/submit_button.dart';
import '/widgets/ajukan_lembur/map_picker_page.dart';
import '/widgets/ajukan_lembur/mitra_selection_dialog.dart';
import '/widgets/ajukan_lembur/preview_dialog.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';

class AjukanLemburPage extends StatefulWidget {
  const AjukanLemburPage({super.key});

  @override
  State<AjukanLemburPage> createState() => _AjukanLemburPageState();
}

class _AjukanLemburPageState extends State<AjukanLemburPage>
    with SingleTickerProviderStateMixin {
  // ==================== SERVICES ====================
  final OvertimeService _overtimeService = OvertimeService();
  final MitraLimitService _mitraLimitService = MitraLimitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ANIMATION ====================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ==================== DATA STATE ====================
  bool isLoading = true;
  bool isCheckingDuplicates = false;
  Map<String, dynamic>? _overtimeRates;
  List<Map<String, dynamic>> selectedMiras = [];
  List<String> selectedMitraIds = [];
  Map<String, bool> mitraDuplicateStatus = {};
  Map<String, String> mitraDuplicateIds = {};

  // ==================== FORM DATA ====================
  DateTime? tanggalLembur;
  TimeOfDay? jamMulai;
  TimeOfDay? jamSelesai;
  double totalJam = 0.0;
  String urgensi = 'normal'; // 🔥 Default: normal
  String? fungsiPengawas;
  String? namaPengawas;
  String? photoProfileUrl;

  // ==================== BUDGET DATA ====================
  double biayaLemburPerMitra = 0.0;
  double totalBiayaLembur = 0.0;
  bool showBudgetBreakdown = false;

  // ==================== LOCATION DATA ====================
  String _locationType = 'kantor';
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();

  // ==================== CONTROLLERS ====================
  final alasanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // ==================== COMPUTED PROPERTIES ====================
  bool get _isOutsideRadius {
    if (_selectedLocation == null) return false;
    return LocationService.isOutsideRadius(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  bool get _hasDuplicateMitra =>
      mitraDuplicateStatus.values.any((isDuplicate) => isDuplicate);

  List<Map<String, dynamic>> get _validMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] != true).toList();

  List<Map<String, dynamic>> get _duplicateMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] == true).toList();

  // 🔥 PERBAIKAN: Tambah validasi urgensi
  bool _allDataComplete() {
    return selectedMiras.isNotEmpty &&
        _validMiras.isNotEmpty &&
        tanggalLembur != null &&
        jamMulai != null &&
        jamSelesai != null &&
        _selectedLocation != null &&
        alasanController.text.isNotEmpty &&
        alasanController.text.length >= 20 &&
        urgensi.isNotEmpty && // 🔥 Validasi urgensi
        !_hasDuplicateMitra;
  }

  double get _completionPercentage {
    int completed = 0;
    int total = 7; // 🔥 Tambah 1 untuk urgensi
    if (selectedMiras.isNotEmpty && _validMiras.isNotEmpty) completed++;
    if (tanggalLembur != null) completed++;
    if (jamMulai != null && jamSelesai != null) completed++;
    if (_selectedLocation != null) completed++;
    if (alasanController.text.length >= 20) completed++;
    if (urgensi.isNotEmpty) completed++; // 🔥 Urgensi
    return completed / total;
  }

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    alasanController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadUserData(), _loadOvertimeRates()]);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && mounted) {
      final data = userDoc.data();
      setState(() {
        fungsiPengawas = data?['fungsi']?.toString().toLowerCase() ?? '';
        namaPengawas = data?['nama_lengkap'] ?? 'Pengawas';
        photoProfileUrl = data?['photo_url'];
      });
    }
  }

  Future<void> _loadOvertimeRates() async {
    _overtimeRates = await _overtimeService.loadOvertimeRates();
    if (mounted) setState(() {});
  }

  // ==================== DUPLICATE CHECK ====================
  Future<void> _checkDuplicateLembur() async {
    if (tanggalLembur == null || selectedMiras.isEmpty) return;
    setState(() => isCheckingDuplicates = true);

    for (final mitra in selectedMiras) {
      final result = await _mitraLimitService.checkDuplicateLemburHarian(
        mitraId: mitra['id'],
        tanggal: tanggalLembur!,
      );
      if (mounted) {
        setState(() {
          mitraDuplicateStatus[mitra['id']] = result['is_duplicate'] ?? false;
          if (result['is_duplicate'] == true && result['existing_ids'] != null) {
            mitraDuplicateIds[mitra['id']] =
                (result['existing_ids'] as List).first.toString();
          }
        });
      }
    }
    if (mounted) setState(() => isCheckingDuplicates = false);
  }

  // ==================== CALCULATION ====================
  void _recalculateBiaya() {
    if (jamMulai == null || jamSelesai == null || 
        tanggalLembur == null || _overtimeRates == null) return;

    final isWeekend = tanggalLembur!.weekday == DateTime.saturday ||
        tanggalLembur!.weekday == DateTime.sunday;
    final startMinutes = jamMulai!.hour * 60 + jamMulai!.minute;
    final endMinutes = jamSelesai!.hour * 60 + jamSelesai!.minute;
    final diff = endMinutes - startMinutes;

    if (diff > 0) {
      totalJam = diff / 60.0;
      biayaLemburPerMitra = _overtimeService.calculateOvertimeCost(
        totalHours: totalJam,
        isHoliday: isWeekend,
        rates: _overtimeRates!,
      );
      totalBiayaLembur = biayaLemburPerMitra * _validMiras.length;
      
      setState(() => showBudgetBreakdown = true);
      _checkDuplicateLembur();
    }
  }

  // ==================== FORMAT HELPERS ====================
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTanggal(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ==================== MAP PICKER ====================
  void _showMapPicker() async {
    final initialLat = _selectedLocation?.latitude ?? LocationService.kantorLat;
    final initialLng = _selectedLocation?.longitude ?? LocationService.kantorLng;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: initialLat,
          initialLng: initialLng,
          isProjectLocation: _locationType == 'proyek', // 🔥 Kirim flag
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(
          (result['lat'] as num).toDouble(),
          (result['lng'] as num).toDouble(),
        );
        _selectedAddress = result['address'] ?? 'Lokasi dipilih dari peta';
      });
    }
  }

  // ==================== MITRA SELECTION ====================
  Future<void> _showMitraSelectionDialog() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => MitraSelectionDialog(
        fungsi: fungsiPengawas!,
        selectedIds: selectedMitraIds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedMiras = result;
        selectedMitraIds = result.map((m) => m['id'] as String).toList();
      });
      if (tanggalLembur != null) _checkDuplicateLembur();
      _recalculateBiaya();
    }
  }

  // ==================== 🔥 VALIDASI TERPUSAT (TAHAP 26-27) ====================
  
  /// Validasi seluruh data pengajuan lembur
  /// Returns null jika semua valid, atau pesan error jika ada yang tidak valid
  String? _validateAllData() {
    // 🔥 TAHAP 5-6: Cek TAD/Mitra dipilih
    if (selectedMiras.isEmpty) {
      return 'Pilih minimal satu TAD';
    }
    if (_validMiras.isEmpty) {
      return 'Hapus TAD yang sudah terdaftar lembur di tanggal ini';
    }
    
    // 🔥 TAHAP 8-9: Validasi waktu lembur
    if (tanggalLembur == null) {
      return 'Tanggal lembur harus diisi';
    }
    if (jamMulai == null || jamSelesai == null) {
      return 'Waktu lembur tidak valid';
    }
    if (totalJam <= 0) {
      return 'Jam selesai harus lebih besar dari jam mulai';
    }
    
    // 🔥 TAHAP 16: Validasi lokasi proyek
    if (_locationType == 'proyek' && _selectedLocation == null) {
      return 'Lokasi proyek tidak ditemukan. Silakan pilih lokasi';
    }
    if (_selectedLocation == null) {
      return 'Pilih lokasi lembur';
    }
    
    // 🔥 TAHAP 20: Validasi alasan
    if (alasanController.text.isEmpty) {
      return 'Alasan lembur harus diisi';
    }
    if (alasanController.text.length < 20) {
      return 'Alasan lembur minimal 20 karakter';
    }
    
    // 🔥 TAHAP 22-23: Validasi urgensi
    if (urgensi.isEmpty) {
      return 'Tingkat urgensi harus dipilih';
    }
    
    return null; // Semua valid
  }

  // ==================== 🔥 SUBMIT (DIPERBAIKI) ====================
  Future<void> _submit() async {
    // 🔥 TAHAP 26: Validasi seluruh data pengajuan lembur
    final validationError = _validateAllData();
    
    if (validationError != null) {
      // 🔥 TAHAP 27: Tampilkan pesan kesalahan
      if (mounted) {
        _showValidationError(validationError);
      }
      return;
    }

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();

    // 🔥 TAHAP 29-30: Check limit exceeded (akumulasi jam bulanan)
    bool hasLimitExceeded = false;
    final limitResults = <String, dynamic>{};

    for (final mitra in _validMiras) {
      final result = await _mitraLimitService.checkMitraLimit(
        mitraId: mitra['id'],
        tanggal: tanggalLembur!,
        tambahanJam: totalJam,
      );
      limitResults[mitra['id']] = result;
      if (result['is_exceeded']) hasLimitExceeded = true;
    }

    // 🔥 TAHAP 31-32: Peringatan batas lembur & konfirmasi
    if (hasLimitExceeded) {
      final confirmed = await _showLimitWarningDialog(limitResults);
      if (!confirmed) {
        // Pengawas memilih batal, kembali ke form
        return;
      }
    }

    // Show loading
    _showLoadingDialog();

    try {
      // 🔥 TAHAP 33: Simpan data ke database
      await _saveOvertimeData(hasLimitExceeded, groupId);
      
      // 🔥 TAHAP 34: Kirim notifikasi ke Manager
      if (mounted) {
        try {
          await NotificationService().sendManagerNotification(
            pengawasNama: namaPengawas ?? 'Pengawas',
            fungsi: fungsiPengawas ?? '',
            jumlahMitra: _validMiras.length,
            tanggal: tanggalLembur!,
            totalBiaya: totalBiayaLembur,
            urgensi: urgensi,
            isOutsideRadius: _isOutsideRadius,
            lemburIds: [groupId],
            overtimeRates: _overtimeRates!,
          );
        } catch (e) {
          debugPrint('⚠️ Gagal kirim notifikasi: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        // 🔥 TAHAP 35: Tampilkan notifikasi berhasil
        _showSuccessDialog(groupId);
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showValidationError('Gagal menyimpan: $e');
      }
    }
  }

  // ==================== SAVE DATA ====================
  Future<void> _saveOvertimeData(bool hasLimitExceeded, String groupId) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday ||
        tanggalLembur!.weekday == DateTime.sunday;
    final isOutside = _isOutsideRadius;

    String alamatLengkap = _selectedAddress ?? '';
    if (_locationType == 'proyek') {
      if (_rtController.text.trim().isNotEmpty) {
        alamatLengkap += ' RT ${_rtController.text.trim()}';
      }
      if (_rwController.text.trim().isNotEmpty) {
        alamatLengkap += ' RW ${_rwController.text.trim()}';
      }
    }

    // Save pengajuan
    final pengajuanRef = _firestore.collection('pengajuan_lembur').doc(groupId);
    batch.set(pengajuanRef, {
      'group_id': groupId,
      'tipe_dokumen': 'pengajuan',
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
      'pengawas_id': _auth.currentUser?.uid,
      'nama_pengawas': namaPengawas,
      'pengawas_fungsi': fungsiPengawas,
      'tanggal_lembur': Timestamp.fromDate(tanggalLembur!),
      'tahun_bulan': DateFormat('yyyy-MM').format(tanggalLembur!),
      'jam_mulai': _formatTime(jamMulai!),
      'jam_selesai': _formatTime(jamSelesai!),
      'total_jam_desimal': totalJam,
      'jenis_lembur': isWeekend ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_total': totalBiayaLembur,
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'total_mitra': _validMiras.length,
      'mitra_ids': _validMiras.map((m) => m['id'] as String).toList(),
      'detail_mitra': _validMiras
          .map((m) => {
                'id': m['id'],
                'nama': m['nama_lengkap'],
                'fungsi': m['fungsi'],
              })
          .toList(),
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'is_multiple': _validMiras.length > 1,
      'location_type': _locationType,
    });

    // Save individual mitra records
    final baseMitraData = {
      'group_id': groupId,
      'pengajuan_id': groupId,
      'tipe_dokumen': 'lembur_mitra',
      'pengawas_id': _auth.currentUser?.uid,
      'pengawas_fungsi': fungsiPengawas,
      'diajukan_oleh_id': _auth.currentUser?.uid,
      'diajukan_oleh_nama': namaPengawas,
      'tanggal': Timestamp.fromDate(tanggalLembur!),
      'tahun_bulan': DateFormat('yyyy-MM').format(tanggalLembur!),
      'jam_mulai': _formatTime(jamMulai!),
      'jam_selesai': _formatTime(jamSelesai!),
      'total_jam_desimal': totalJam,
      'jenis_lembur': isWeekend ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'estimasi_biaya': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'status': 'pending',
      'absensi_status': 'belum_absen',
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'created_at': now,
      'updated_at': now,
    };

    for (final mitra in _validMiras) {
      final docRef = _firestore
          .collection('lembur_mitra')
          .doc('${groupId}_${mitra['id']}');
      batch.set(docRef, {
        ...baseMitraData,
        'mitra_id': mitra['id'],
        'user_id': mitra['id'],
        'nama_mitra': mitra['nama_lengkap'],
        'fungsi_mitra': mitra['fungsi'],
      });
    }

    await batch.commit();
    debugPrint('✅ Data tersimpan untuk group: $groupId');
  }

  // ==================== DIALOGS ====================
  
  // 🔥 TAMBAHAN: Method untuk menampilkan error validasi (TAHAP 27)
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1976D2)),
                SizedBox(height: 24),
                Text('Menyimpan Pengajuan...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Mohon tunggu sebentar',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showLimitWarningDialog(Map<String, dynamic> limitResults) async {
    final mitraOver = <String>[];
    limitResults.forEach((mitraId, info) {
      if (info['is_exceeded']) {
        final mitra = _validMiras.firstWhere((m) => m['id'] == mitraId);
        mitraOver.add(
          '• ${mitra['nama_lengkap']}: ${info['total_jam_bulan_ini'].toStringAsFixed(1)} jam + ${info['tambahan_jam'].toStringAsFixed(1)} jam',
        );
      }
    });

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Melebihi Batas Lembur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beberapa TAD akan melebihi batas maksimal 60 jam/bulan:'),
            const SizedBox(height: 12),
            ...mitraOver.map((m) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(m, style: const TextStyle(fontSize: 13)),
                )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pengajuan ini akan ditandai sebagai OVERRIDE dan memerlukan persetujuan khusus.',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          // 🔥 TAHAP 32: Opsi BATAL (kembali memilih TAD)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          // 🔥 TAHAP 32: Opsi TETAP AJUKAN
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('TETAP AJUKAN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String groupId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            SizedBox(height: 12),
            Text('Berhasil!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pengajuan lembur berhasil dikirim.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('ID Pengajuan: ${groupId.substring(0, 8)}...',
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 8),
            Text('${_validMiras.length} TAD telah didaftarkan',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SELESAI'),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => PreviewDialog(
        namaPengawas: namaPengawas,
        fungsiPengawas: fungsiPengawas,
        validMiras: _validMiras,
        tanggalLembur: tanggalLembur,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        totalJam: totalJam,
        locationType: _locationType,
        selectedAddress: _selectedAddress,
        rtController: _rtController,
        rwController: _rwController,
        urgensi: urgensi,
        biayaLemburPerMitra: biayaLemburPerMitra,
        totalBiayaLembur: totalBiayaLembur,
        alasan: alasanController.text,
        formatTime: _formatTime,
        formatTanggal: _formatTanggal,
        formatRupiah: _overtimeService.formatRupiah,
        onConfirmed: () {
          Navigator.pop(context);
          _submit();
        },
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF1976D2),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Memuat data...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu sebentar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
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

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = 65.0;
    final extraPadding = bottomPadding + bottomNavHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_alarm_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Pengajuan Lembur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_rounded,
                size: 18, color: Colors.white),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Colors.white),
            ),
            onPressed: () async {
              _overtimeService.clearCache();
              await _loadOvertimeRates();
            },
          ),
          if (_completionPercentage > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(_completionPercentage * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16, 16, 16, extraPadding + 8),
              child: Column(
                children: [
                  HeaderProfileCard(
                    namaPengawas: namaPengawas,
                    fungsiPengawas: fungsiPengawas,
                    photoProfileUrl: photoProfileUrl,
                  ),
                  const SizedBox(height: 16),
                  ProgressStepper(
                    completionPercentage: _completionPercentage,
                    hasMitra: _validMiras.isNotEmpty,
                    hasTanggal: tanggalLembur != null,
                    hasWaktu: jamMulai != null && jamSelesai != null,
                    hasLokasi: _selectedLocation != null,
                    hasAlasan: alasanController.text.length >= 20,
                  ),
                  const SizedBox(height: 16),
                  if (_overtimeRates != null)
                    RateInfoCard(rates: _overtimeRates!),
                  const SizedBox(height: 16),
                  MitraSection(
                    selectedMiras: selectedMiras,
                    validMiras: _validMiras,
                    duplicateMiras: _duplicateMiras,
                    mitraDuplicateStatus: mitraDuplicateStatus,
                    hasDuplicateMitra: _hasDuplicateMitra,
                    isCheckingDuplicates: isCheckingDuplicates,
                    fungsiPengawas: fungsiPengawas,
                    tanggalLembur: tanggalLembur,
                    onAddMitra: _showMitraSelectionDialog,
                    onRemoveMitra: (mitra) {
                      setState(() {
                        selectedMiras.removeWhere((m) => m['id'] == mitra['id']);
                        selectedMitraIds.remove(mitra['id']);
                        mitraDuplicateStatus.remove(mitra['id']);
                      });
                      _recalculateBiaya();
                    },
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  WaktuSection(
                    tanggalLembur: tanggalLembur,
                    jamMulai: jamMulai,
                    jamSelesai: jamSelesai,
                    totalJam: totalJam,
                    onTanggalChanged: (date) {
                      setState(() {
                        tanggalLembur = date;
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                      });
                    },
                    onJamMulaiChanged: (time) {
                      setState(() {
                        jamMulai = time;
                        jamSelesai = null;
                        totalJam = 0;
                      });
                    },
                    onJamSelesaiChanged: (time) {
                      setState(() => jamSelesai = time);
                      _recalculateBiaya();
                    },
                    onClear: () {
                      setState(() {
                        tanggalLembur = null;
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                        showBudgetBreakdown = false;
                      });
                    },
                    formatTime: _formatTime,
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  LokasiSection(
                    locationType: _locationType,
                    selectedLocation: _selectedLocation,
                    selectedAddress: _selectedAddress,
                    isOutsideRadius: _isOutsideRadius,
                    rtController: _rtController,
                    rwController: _rwController,
                    onLocationTypeChanged: (type) {
                      setState(() {
                        _locationType = type;
                        if (type == 'kantor') {
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _selectedLocation = null;
                          _selectedAddress = null;
                        }
                      });
                    },
                    onPickMap: _showMapPicker,
                  ),
                  const SizedBox(height: 16),
                  AlasanSection(
                    controller: alasanController,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  UrgensiSection(
                    urgensi: urgensi,
                    onUrgensiChanged: (value) {
                      setState(() {
                        urgensi = value;
                        if (value == 'normal') {
                          _locationType = 'kantor';
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _locationType = 'proyek';
                        }
                      });
                    },
                  ),
                  if (showBudgetBreakdown && totalJam > 0 && _validMiras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    BudgetBreakdownSection(
                      totalJam: totalJam,
                      validMirasCount: _validMiras.length,
                      biayaLemburPerMitra: biayaLemburPerMitra,
                      totalBiayaLembur: totalBiayaLembur,
                      formatRupiah: _overtimeService.formatRupiah,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SubmitButton(
                    isComplete: _allDataComplete(),
                    hasDuplicateMitra: _hasDuplicateMitra,
                    completionPercentage: _completionPercentage,
                    onPressed: () => _showPreviewDialog(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PengawasBottomNav(
        currentIndex: 1,
      ),
    );
  }
}