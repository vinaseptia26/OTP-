// FILE: lib/screens/absensi/absensi_history_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import for web
import 'dart:html' as html;

var logger = Logger();

class AbsensiHistoryScreen extends StatefulWidget {
  final String? initialTab;
  final String? lemburId;
  final bool fromNotification;

  const AbsensiHistoryScreen({
    super.key,
    this.initialTab,
    this.lemburId,
    this.fromNotification = false,
  });

  @override
  State<AbsensiHistoryScreen> createState() => _AbsensiHistoryScreenState();
}

class _AbsensiHistoryScreenState extends State<AbsensiHistoryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ==================== USER DATA ====================
  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhotoUrl;
  String? _userFungsiLabel;

  bool get isSuperadmin => _userRole == 'superadmin';
  bool get isManager => _userRole == 'manager';
  bool get isPengawas => _userRole == 'pengawas';
  bool get isMitra => _userRole == 'mitra';

  // ==================== FILTERS ====================
  String _selectedTab = 'semua';
  String _selectedFungsi = 'semua';
  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedStatus = 'semua';
  String _selectedLokasi = 'semua';
  String _selectedUrgensi = 'semua';
  String _sortBy = 'tanggal_desc';
  String _selectedValidationStatus = 'semua';
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  
  // Date Range Filter
  DateTimeRange? _selectedDateRange;
  bool _useDateRange = false;

  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isDarkMode = false;
  bool isGridView = false;
  final int _itemsPerPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  // Data Collections
  List<Map<String, dynamic>> _absensiHistory = [];
  List<Map<String, dynamic>> _filteredAbsensi = [];
  List<Map<String, dynamic>> _onTimeAbsensi = [];
  List<Map<String, dynamic>> _pendingAbsensi = [];
  List<Map<String, dynamic>> _expiredAbsensi = [];
  List<Map<String, dynamic>> _validationInvalid = [];
  
  // Statistics
  Map<String, dynamic>? _statsData;
  bool _isLoadingStats = true;
  
  // Audit Trail
  List<Map<String, dynamic>> _auditTrail = [];

  // ==================== ANIMATIONS ====================
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ==================== CONTROLLERS ====================
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  // ==================== COLOR PALETTE ====================
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color secondaryBlue = const Color(0xFF2A4F8C);
  final Color accentBlue = const Color(0xFF1976D2);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color softBlue = const Color(0xFFBBDEFB);
  final Color gradientStart = const Color(0xFF1E3C72);
  final Color gradientEnd = const Color(0xFF2E5A9C);
  final Color lateColor = const Color(0xFFF44336);
  final Color onTimeColor = const Color(0xFF4CAF50);
  final Color expiredColor = const Color(0xFF9E9E9E);
  final Color earlyColor = const Color(0xFFFF9800);
  final Color pendingColor = const Color(0xFFFFA500);
  final Color invoiceColor = const Color(0xFF9C27B0);
  final Color validColor = const Color(0xFF4CAF50);
  final Color invalidColor = const Color(0xFFF44336);

  // ==================== FUNGSI LIST ====================
  final List<Map<String, dynamic>> fungsiList = const [
    {"value": "semua", "label": "Semua Fungsi", "icon": Icons.public, "color": Colors.grey},
    {"value": "operation", "label": "Operation", "icon": Icons.settings, "color": Color(0xFF1976D2)},
    {"value": "lab", "label": "Laboratorium", "icon": Icons.science, "color": Color(0xFF4CAF50)},
    {"value": "maintenance", "label": "Maintenance", "icon": Icons.build, "color": Color(0xFFFF9800)},
    {"value": "hsse", "label": "HSSE", "icon": Icons.shield, "color": Color(0xFF9C27B0)},
    {"value": "gpr", "label": "GPR", "icon": Icons.bar_chart, "color": Color(0xFFF44336)},
    {"value": "bs", "label": "BS", "icon": Icons.description, "color": Color(0xFF795548)},
  ];

  // ==================== STATUS LIST ====================
  final List<Map<String, dynamic>> statusList = const [
    {"value": "semua", "label": "Semua Status", "icon": Icons.list, "color": Colors.grey},
    {"value": "check_in", "label": "Check In", "icon": Icons.login, "color": Color(0xFF2196F3)},
    {"value": "check_out", "label": "Check Out", "icon": Icons.logout, "color": Color(0xFFFF9800)},
    {"value": "selesai", "label": "Selesai", "icon": Icons.task_alt, "color": Color(0xFF4CAF50)},
  ];

  // ==================== LOKASI LIST ====================
  final List<Map<String, dynamic>> lokasiList = const [
    {"value": "semua", "label": "Semua Lokasi", "icon": Icons.map, "color": Colors.grey},
    {"value": "kantor", "label": "Kantor", "icon": Icons.business, "color": Color(0xFF2196F3)},
    {"value": "proyek", "label": "Proyek", "icon": Icons.location_city, "color": Color(0xFFFF9800)},
    {"value": "luar_radius", "label": "Luar Radius", "icon": Icons.warning, "color": Color(0xFFF44336)},
  ];

  // ==================== URGENSI LIST ====================
  final List<Map<String, dynamic>> urgensiList = const [
    {"value": "semua", "label": "Semua Urgensi", "icon": Icons.filter_list, "color": Colors.grey},
    {"value": "rendah", "label": "Rendah", "icon": Icons.arrow_downward, "color": Color(0xFF4CAF50)},
    {"value": "normal", "label": "Normal", "icon": Icons.remove, "color": Color(0xFF2196F3)},
    {"value": "tinggi", "label": "Tinggi", "icon": Icons.arrow_upward, "color": Color(0xFFFF9800)},
    {"value": "kritis", "label": "Kritis", "icon": Icons.warning, "color": Color(0xFFF44336)},
  ];

  // ==================== SORT OPTIONS ====================
  final List<Map<String, dynamic>> sortOptions = const [
    {"value": "tanggal_desc", "label": "Terbaru", "icon": Icons.arrow_downward},
    {"value": "tanggal_asc", "label": "Terlama", "icon": Icons.arrow_upward},
    {"value": "durasi_desc", "label": "Durasi Terlama", "icon": Icons.timer},
    {"value": "biaya_desc", "label": "Biaya Tertinggi", "icon": Icons.attach_money},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _loadUserData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshData();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  // ==================== LOAD USER DATA ====================
  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      _userId = user.uid;
      _userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      _userEmail = user.email;
      _userPhotoUrl = user.photoURL;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        _showErrorSnackbar('Data user tidak ditemukan');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      _userRole = userData['role'] ?? 'mitra';
      _userFungsi = userData['fungsi']?.toString().toLowerCase() ?? '';
      _userFungsiLabel = userData['fungsi_label'] ?? _getFungsiLabel(_userFungsi);

      logger.i('User $_userRole accessing absensi history');

      if (!isSuperadmin && !isManager && _userFungsi != null) {
        _selectedFungsi = _userFungsi!;
      }

      await _loadAbsensiFromOvertime();
      await _loadStats();

      if (widget.initialTab != null && mounted) {
        setState(() => _selectedTab = widget.initialTab!);
        _applyFilters();
      }

      if (widget.lemburId != null && mounted) {
        _highlightLembur(widget.lemburId!);
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackbar('Gagal memuat data user');
      }
    }
  }

  // ==================== AMBIL DATA DARI RIWAYAT LEMBUR ====================
  Future<void> _loadAbsensiFromOvertime() async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');

      if (isMitra) {
        query = query.where('mitra_ids', arrayContains: _userId);
      } else if (isPengawas) {
        query = query.where('pengawas_id', isEqualTo: _userId);
      } else if (isManager) {
        query = query.where('pengawas_fungsi', isEqualTo: _userFungsi);
      }

      if (_selectedBulan.isNotEmpty && !_useDateRange) {
        final startDate = DateTime.parse('$_selectedBulan-01');
        final endDate = DateTime(startDate.year, startDate.month + 1, 1);
        query = query
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('tanggal', isLessThan: Timestamp.fromDate(endDate));
      }

      if (_useDateRange && _selectedDateRange != null) {
        query = query
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end));
      }

      query = query.orderBy('tanggal', descending: true).limit(_itemsPerPage);
      
      final snapshot = await query.get();
      
      final absensiData = await _processOvertimeToAbsensi(snapshot.docs);
      
      setState(() {
        _absensiHistory = absensiData;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMoreData = snapshot.docs.length == _itemsPerPage;
        _applyFilters();
      });
    } catch (e) {
      logger.e('Error loading absensi from overtime: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _processOvertimeToAbsensi(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs
  ) async {
    final List<Map<String, dynamic>> result = [];
    
    for (var doc in docs) {
      final lemburData = doc.data();
      final lemburId = doc.id;
      
      final absensiSnapshot = await _firestore
          .collection('absensi')
          .where('lembur_id', isEqualTo: lemburId)
          .get();
      
      final sudahAbsen = absensiSnapshot.docs.isNotEmpty;
      DocumentSnapshot? absensiDoc;
      Map<String, dynamic>? absensiData;
      
      if (sudahAbsen) {
        absensiDoc = absensiSnapshot.docs.first;
        absensiData = absensiDoc.data() as Map<String, dynamic>?;
      }
      
      final lemburLokasi = (lemburData['lokasi'] as Map<String, dynamic>?) ?? {};
      final absensiLokasi = (absensiData?['lokasi'] as Map<String, dynamic>?) ?? {};
      
      Map<String, dynamic> validationResult = await _validateLocation(
        lemburLokasi: lemburLokasi,
        absensiLokasi: absensiLokasi,
        sudahAbsen: sudahAbsen,
      );
      
      final jamMulai = lemburData['jam_mulai'] ?? '00:00';
      final jamSelesai = lemburData['jam_selesai'] ?? '00:00';
      final targetDurasi = (lemburData['total_jam_desimal'] ?? 0.0).toDouble();
      
      DateTime? checkInTime;
      DateTime? checkOutTime;
      double actualDurasi = 0;
      
      if (sudahAbsen && absensiData != null) {
        final checkInTimestamp = absensiData['waktu_check_in'] as Timestamp?;
        final checkOutTimestamp = absensiData['waktu_check_out'] as Timestamp?;
        checkInTime = checkInTimestamp?.toDate();
        checkOutTime = checkOutTimestamp?.toDate();
        actualDurasi = (absensiData['durasi_jam'] ?? 0).toDouble();
      }
      
      String absensiStatus = lemburData['absensi_status'] ?? 'belum_absen';
      if (lemburData['status'] == 'kadaluarsa') {
        absensiStatus = 'expired';
      }
      
      String validationStatus = 'pending';
      Color validationColor = Colors.grey;
      String validationMessage = '';
      
      if (!sudahAbsen) {
        validationStatus = 'pending';
        validationColor = Colors.orange;
        validationMessage = 'Belum melakukan absensi';
      } else if (validationResult['is_valid'] == true) {
        validationStatus = 'valid';
        validationColor = validColor;
        validationMessage = 'Lokasi sesuai dengan pengajuan';
      } else {
        validationStatus = 'invalid';
        validationColor = invalidColor;
        validationMessage = validationResult['message'] ?? 'Lokasi tidak sesuai dengan pengajuan';
      }
      
      result.add({
        'id': lemburId,
        'lembur_id': lemburId,
        'lembur_data': lemburData,
        'absensi_data': absensiData,
        'absensi_doc_id': absensiDoc?.id,
        'sudah_absen': sudahAbsen,
        'absensi_status': absensiStatus,
        'user_id': isMitra ? _userId : lemburData['mitra_ids']?.first,
        'user_name': isMitra ? _userName : lemburData['nama_mitra'],
        'user_email': isMitra ? _userEmail : lemburData['email_mitra'],
        'fungsi': lemburData['pengawas_fungsi'],
        'fungsi_label': _getFungsiLabel(lemburData['pengawas_fungsi']),
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'foto_url': absensiData?['foto_url'],
        'lokasi_pengajuan': lemburLokasi,
        'lokasi_absensi': absensiLokasi,
        'distance_from_kantor': lemburLokasi['distance_from_kantor'] ?? 0,
        'is_outside_radius': lemburLokasi['is_outside_radius'] ?? false,
        'validation_status': validationStatus,
        'validation_color': validationColor,
        'validation_message': validationMessage,
        'validation_details': validationResult,
        'durasi_jam_target': targetDurasi,
        'durasi_jam_actual': actualDurasi,
        'durasi_menit_actual': (actualDurasi * 60).round(),
        'tanggal_lembur': lemburData['tanggal'] as Timestamp?,
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
        'nama_pengawas': lemburData['nama_pengawas'],
        'pengawas_id': lemburData['pengawas_id'],
        'pengawas_fungsi': lemburData['pengawas_fungsi'],
        'is_multiple': lemburData['is_multiple'] ?? false,
        'group_id': lemburData['group_id'],
        'urgensi': lemburData['urgensi'] ?? 'normal',
        'jenis_lembur': lemburData['jenis_lembur'] ?? 'hari_kerja',
        'is_holiday': lemburData['jenis_lembur'] == 'hari_libur',
        'alasan': lemburData['alasan'],
        'catatan': lemburData['catatan_tambahan'],
        'estimasi_biaya': lemburData['estimasi_biaya_total'] ?? 0,
        'total_mitra': lemburData['total_mitra'] ?? 1,
        'status_lembur': lemburData['status'],
        'is_expired': lemburData['status'] == 'kadaluarsa',
        'created_at': lemburData['created_at'] as Timestamp?,
        'updated_at': lemburData['updated_at'] as Timestamp?,
        'approved_at': lemburData['approved_at'] as Timestamp?,
        'absensi_waktu': absensiData?['waktu'] as Timestamp?,
      });
    }
    
    return result;
  }

  // ==================== VALIDASI LOKASI ====================
  Future<Map<String, dynamic>> _validateLocation({
    required Map<String, dynamic> lemburLokasi,
    required Map<String, dynamic> absensiLokasi,
    required bool sudahAbsen,
  }) async {
    if (!sudahAbsen) {
      return {
        'is_valid': false,
        'message': 'Belum melakukan absensi',
        'details': null,
      };
    }
    
    final lemburLat = lemburLokasi['latitude'] as double?;
    final lemburLng = lemburLokasi['longitude'] as double?;
    final absensiLat = absensiLokasi['latitude'] as double?;
    final absensiLng = absensiLokasi['longitude'] as double?;
    
    if (lemburLat == null || lemburLng == null) {
      return {
        'is_valid': true,
        'message': 'Tidak ada data koordinat pengajuan',
        'details': 'Lokasi pengajuan tidak memiliki koordinat yang valid',
      };
    }
    
    if (absensiLat == null || absensiLng == null) {
      return {
        'is_valid': false,
        'message': 'Tidak ada data koordinat saat absensi',
        'details': 'Sistem tidak dapat memverifikasi lokasi karena tidak ada koordinat',
      };
    }
    
    final distance = _calculateDistance(lemburLat, lemburLng, absensiLat, absensiLng);
    final tolerance = 100.0;
    final isWithinTolerance = distance <= tolerance;
    
    final lemburPilihan = lemburLokasi['pilihan'] ?? 'kantor';
    final absensiPilihan = absensiLokasi['pilihan'] ?? 'kantor';
    final isSameType = lemburPilihan == absensiPilihan;
    
    bool isSameAddress = true;
    if (lemburPilihan == 'custom' && absensiPilihan == 'custom') {
      final lemburAlamat = (lemburLokasi['alamat'] ?? '').toString().toLowerCase();
      final absensiAlamat = (absensiLokasi['alamat'] ?? '').toString().toLowerCase();
      isSameAddress = lemburAlamat == absensiAlamat || 
          lemburAlamat.contains(absensiAlamat) || 
          absensiAlamat.contains(lemburAlamat);
    }
    
    final isValid = isWithinTolerance && isSameType && isSameAddress;
    
    String message;
    if (isValid) {
      message = 'Lokasi sesuai dengan pengajuan (jarak ${distance.toStringAsFixed(0)}m)';
    } else {
      final List<String> reasons = [];
      if (!isWithinTolerance) {
        reasons.add('jarak ${distance.toStringAsFixed(0)}m (melebihi toleransi ${tolerance.toStringAsFixed(0)}m)');
      }
      if (!isSameType) {
        reasons.add('jenis lokasi berbeda (pengajuan: $lemburPilihan, absensi: $absensiPilihan)');
      }
      if (!isSameAddress && lemburPilihan == 'custom') {
        reasons.add('alamat berbeda');
      }
      message = 'Lokasi tidak sesuai: ${reasons.join(', ')}';
    }
    
    await _addAuditTrail(
      action: 'validasi_lokasi',
      description: 'Validasi lokasi absensi untuk lembur',
      data: {
        'lembur_location': {'lat': lemburLat, 'lng': lemburLng, 'type': lemburPilihan},
        'absensi_location': {'lat': absensiLat, 'lng': absensiLng, 'type': absensiPilihan},
        'distance': distance,
        'is_valid': isValid,
        'tolerance': tolerance,
      },
    );
    
    return {
      'is_valid': isValid,
      'message': message,
      'distance': distance,
      'tolerance': tolerance,
      'is_within_tolerance': isWithinTolerance,
      'is_same_type': isSameType,
      'is_same_address': isSameAddress,
    };
  }
  
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
  
  double _toRadians(double degrees) => degrees * math.pi / 180;
  
  // ==================== AUDIT TRAIL ====================
  Future<void> _addAuditTrail({
    required String action,
    required String description,
    Map<String, dynamic>? data,
  }) async {
    try {
      final auditData = {
        'user_id': _userId,
        'user_name': _userName,
        'user_role': _userRole,
        'action': action,
        'description': description,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'ip_address': 'client',
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
      };
      
      await _firestore.collection('audit_trail_absensi').add(auditData);
      
      if (mounted) {
        setState(() {
          _auditTrail.insert(0, {
            ...auditData,
            'timestamp_local': DateTime.now(),
          });
          if (_auditTrail.length > 100) {
            _auditTrail = _auditTrail.take(100).toList();
          }
        });
      }
    } catch (e) {
      logger.e('Error adding audit trail: $e');
    }
  }
  
  Future<void> _loadAuditTrail() async {
    try {
      final snapshot = await _firestore
          .collection('audit_trail_absensi')
          .where('user_id', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      if (mounted) {
        setState(() {
          _auditTrail = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'timestamp_local': (data['timestamp'] as Timestamp?)?.toDate(),
            };
          }).toList();
        });
      }
    } catch (e) {
      logger.e('Error loading audit trail: $e');
    }
  }

  // ==================== KONFIGURASI UNTUK SUPERADMIN ====================
  Future<void> _showInvoiceAdjustmentDialog(Map<String, dynamic> absensi) async {
    if (!isSuperadmin) return;
    
    final TextEditingController deductionController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    double currentDeduction = (absensi['penalty_amount'] ?? 0).toDouble();
    
    deductionController.text = currentDeduction.toString();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Atur Potongan Invoice',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Atur potongan untuk lembur ini',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Mitra', absensi['user_name'] ?? '-'),
                        _buildDetailRow('Tanggal', _formatTanggalFromTimestamp(absensi['tanggal_lembur'] as Timestamp?)),
                        _buildDetailRow('Estimasi Biaya', _formatRupiah((absensi['estimasi_biaya'] ?? 0).toDouble())),
                        const Divider(),
                        _buildDetailRow(
                          'Potongan Saat Ini', 
                          _formatRupiah(currentDeduction),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: deductionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Jumlah Potongan (Rp)',
                      hintText: 'Masukkan jumlah potongan',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      final newValue = double.tryParse(value) ?? 0;
                      setState(() {
                        currentDeduction = newValue;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Alasan Penyesuaian',
                      hintText: 'Masukkan alasan mengapa potongan diubah',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveInvoiceAdjustment(
                            absensi: absensi,
                            deduction: currentDeduction,
                            reason: reasonController.text,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Future<void> _saveInvoiceAdjustment({
    required Map<String, dynamic> absensi,
    required double deduction,
    required String reason,
  }) async {
    try {
      final lemburId = absensi['lembur_id'];
      final estimasiBiaya = (absensi['estimasi_biaya'] ?? 0).toDouble();
      final newNetBiaya = estimasiBiaya - deduction;
      
      await _firestore.collection('lembur').doc(lemburId).update({
        'manual_deduction': deduction,
        'manual_deduction_reason': reason,
        'manual_deduction_by': _userId,
        'manual_deduction_by_name': _userName,
        'manual_deduction_at': FieldValue.serverTimestamp(),
        'net_biaya': newNetBiaya,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      await _addAuditTrail(
        action: 'adjust_invoice',
        description: 'Superadmin menyesuaikan potongan invoice untuk lembur $lemburId',
        data: {
          'lembur_id': lemburId,
          'previous_deduction': absensi['penalty_amount'] ?? 0,
          'new_deduction': deduction,
          'reason': reason,
          'estimasi_biaya': estimasiBiaya,
          'new_net_biaya': newNetBiaya,
        },
      );
      
      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('Potongan invoice berhasil disimpan');
        _refreshData();
      }
    } catch (e) {
      _showErrorSnackbar('Gagal menyimpan: $e');
    }
  }

  // ==================== LOAD STATISTICS ====================
  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');
      
      if (isMitra) {
        query = query.where('mitra_ids', arrayContains: _userId);
      } else if (isPengawas) {
        query = query.where('pengawas_id', isEqualTo: _userId);
      } else if (isManager) {
        query = query.where('pengawas_fungsi', isEqualTo: _userFungsi);
      }
      
      query = query
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfMonth));
      
      final snapshot = await query.get();
      
      int total = 0;
      int totalSudahAbsen = 0;
      int totalBelumAbsen = 0;
      int totalExpired = 0;
      int totalValidationValid = 0;
      int totalValidationInvalid = 0;
      int totalOutsideRadius = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total++;
        
        final absensiStatus = data['absensi_status'] ?? 'belum_absen';
        if (absensiStatus == 'selesai') {
          totalSudahAbsen++;
        } else if (absensiStatus == 'expired') {
          totalExpired++;
        } else {
          totalBelumAbsen++;
        }
        
        if (data['is_outside_radius'] == true) {
          totalOutsideRadius++;
        }
        
        if (absensiStatus == 'selesai') {
          final absensiSnapshot = await _firestore
              .collection('absensi')
              .where('lembur_id', isEqualTo: doc.id)
              .limit(1)
              .get();
          
          if (absensiSnapshot.docs.isNotEmpty) {
            final absensiData = absensiSnapshot.docs.first.data();
            final lemburLokasi = (data['lokasi'] as Map<String, dynamic>?) ?? {};
            final absensiLokasi = (absensiData['lokasi'] as Map<String, dynamic>?) ?? {};
            
            final validation = await _validateLocation(
              lemburLokasi: lemburLokasi,
              absensiLokasi: absensiLokasi,
              sudahAbsen: true,
            );
            
            if (validation['is_valid'] == true) {
              totalValidationValid++;
            } else {
              totalValidationInvalid++;
            }
          }
        }
      }
      
      setState(() {
        _statsData = {
          'total': total,
          'total_sudah_absen': totalSudahAbsen,
          'total_belum_absen': totalBelumAbsen,
          'total_expired': totalExpired,
          'total_validation_valid': totalValidationValid,
          'total_validation_invalid': totalValidationInvalid,
          'total_outside_radius': totalOutsideRadius,
          'persentase_kehadiran': total > 0 ? (totalSudahAbsen / total * 100) : 0,
        };
        _isLoadingStats = false;
      });
    } catch (e) {
      logger.e('Error loading stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // ==================== APPLY FILTERS ====================
  void _applyFilters() {
    setState(() {
      _filteredAbsensi = _absensiHistory.where((absensi) {
        if (_selectedTab == 'belum_absen' && absensi['absensi_status'] != 'belum_absen') {
          return false;
        }
        if (_selectedTab == 'sudah_absen' && absensi['absensi_status'] != 'selesai') {
          return false;
        }
        if (_selectedTab == 'expired' && absensi['is_expired'] != true) {
          return false;
        }
        if (_selectedTab == 'valid' && absensi['validation_status'] != 'valid') {
          return false;
        }
        if (_selectedTab == 'invalid' && absensi['validation_status'] != 'invalid') {
          return false;
        }
        
        if (_selectedFungsi != 'semua' && absensi['fungsi'] != _selectedFungsi) {
          return false;
        }
        
        if (_selectedStatus != 'semua') {
          if (_selectedStatus == 'check_in' && absensi['absensi_status'] != 'check_in') {
            return false;
          }
          if (_selectedStatus == 'check_out' && absensi['absensi_status'] != 'check_out') {
            return false;
          }
          if (_selectedStatus == 'selesai' && absensi['absensi_status'] != 'selesai') {
            return false;
          }
        }
        
        if (_selectedLokasi != 'semua') {
          if (_selectedLokasi == 'luar_radius' && absensi['is_outside_radius'] != true) {
            return false;
          } else if (_selectedLokasi != 'luar_radius') {
            final lokasi = absensi['lokasi_pengajuan'] ?? {};
            if (lokasi['pilihan'] != _selectedLokasi) {
              return false;
            }
          }
        }
        
        if (_selectedUrgensi != 'semua' && absensi['urgensi'] != _selectedUrgensi) {
          return false;
        }
        
        if (_selectedValidationStatus != 'semua' && absensi['validation_status'] != _selectedValidationStatus) {
          return false;
        }
        
        if (_searchQuery.isNotEmpty) {
          final userName = (absensi['user_name'] ?? '').toString().toLowerCase();
          final pengawas = (absensi['nama_pengawas'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          
          if (!userName.contains(query) && !pengawas.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      _sortFilteredDocs();
      _categorizeData();
    });
  }

  void _categorizeData() {
    _onTimeAbsensi = _filteredAbsensi.where((a) => a['is_late_check_in'] != true && a['is_early_check_out'] != true).toList();
    _pendingAbsensi = _filteredAbsensi.where((a) => a['absensi_status'] == 'belum_absen').toList();
    _expiredAbsensi = _filteredAbsensi.where((a) => a['is_expired'] == true).toList();
    _validationInvalid = _filteredAbsensi.where((a) => a['validation_status'] == 'invalid').toList();
  }

  void _sortFilteredDocs() {
    _filteredAbsensi.sort((a, b) {
      switch (_sortBy) {
        case 'tanggal_asc':
          final aTime = a['tanggal_lembur'] as Timestamp?;
          final bTime = b['tanggal_lembur'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.toDate().compareTo(bTime.toDate());
        case 'durasi_desc':
          final aDurasi = (a['durasi_jam_target'] ?? 0).toDouble();
          final bDurasi = (b['durasi_jam_target'] ?? 0).toDouble();
          return bDurasi.compareTo(aDurasi);
        case 'biaya_desc':
          final aBiaya = (a['estimasi_biaya'] ?? 0).toDouble();
          final bBiaya = (b['estimasi_biaya'] ?? 0).toDouble();
          return bBiaya.compareTo(aBiaya);
        case 'tanggal_desc':
        default:
          final aTime = a['tanggal_lembur'] as Timestamp?;
          final bTime = b['tanggal_lembur'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.toDate().compareTo(aTime.toDate());
      }
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');
      
      if (isMitra) {
        query = query.where('mitra_ids', arrayContains: _userId);
      } else if (isPengawas) {
        query = query.where('pengawas_id', isEqualTo: _userId);
      } else if (isManager) {
        query = query.where('pengawas_fungsi', isEqualTo: _userFungsi);
      }
      
      if (_selectedBulan.isNotEmpty && !_useDateRange) {
        final startDate = DateTime.parse('$_selectedBulan-01');
        final endDate = DateTime(startDate.year, startDate.month + 1, 1);
        query = query
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('tanggal', isLessThan: Timestamp.fromDate(endDate));
      }
      
      query = query.orderBy('tanggal', descending: true);
      
      final snapshot = await query
          .startAfterDocument(_lastDocument!)
          .limit(_itemsPerPage)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        if (snapshot.docs.length < _itemsPerPage) {
          _hasMoreData = false;
        }
        
        final newAbsensi = await _processOvertimeToAbsensi(snapshot.docs);
        setState(() {
          _absensiHistory.addAll(newAbsensi);
          _applyFilters();
        });
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      logger.e('Error loading more data: $e');
    }
    
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _highlightLembur(String lemburId) {
    final index = _filteredAbsensi.indexWhere((a) => a['lembur_id'] == lemburId);
    if (index != -1 && mounted) {
      _scrollController.animateTo(
        index * 200.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F9FF),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: isLoading
          ? _buildLoadingIndicator()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: accentBlue,
              backgroundColor: Colors.white,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            _buildHeader(),
                            _buildStatsCard(),
                            _buildTabBar(),
                            _buildFilterSection(),
                            _buildQuickStats(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildAbsensiList(),
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        child: Column(
          children: [
            _buildDrawerHeader(),
            _buildDrawerMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _userPhotoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _userPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildAvatarPlaceholder();
                          },
                        ),
                      )
                    : _buildAvatarPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _userEmail ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getRoleDisplayName(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenu() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'semua');
            },
          ),
          _buildDrawerItem(
            icon: Icons.pending,
            title: 'Belum Absen',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'belum_absen');
            },
            color: pendingColor,
          ),
          _buildDrawerItem(
            icon: Icons.check_circle,
            title: 'Sudah Absen',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'sudah_absen');
            },
            color: onTimeColor,
          ),
          _buildDrawerItem(
            icon: Icons.verified,
            title: 'Validasi Valid',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'valid');
            },
            color: validColor,
          ),
          _buildDrawerItem(
            icon: Icons.warning,
            title: 'Validasi Invalid',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'invalid');
            },
            color: invalidColor,
          ),
          _buildDrawerItem(
            icon: Icons.timer_off,
            title: 'Kadaluarsa',
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'expired');
            },
            color: expiredColor,
          ),
          const Divider(height: 24),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Audit Trail',
            onTap: () => _showAuditTrailDialog(),
          ),
          _buildDrawerItem(
            icon: Icons.download,
            title: 'Export Data',
            onTap: _showExportDialog,
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Pengaturan',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(height: 24),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: _logout,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? primaryBlue),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: _userPhotoUrl != null
                ? ClipOval(
                    child: Image.network(
                      _userPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildAvatarPlaceholder();
                      },
                    ),
                  )
                : _buildAvatarPlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Absensi',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  _userName ?? 'User',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_userFungsiLabel != null)
                  Text(
                    _userFungsiLabel!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(_userName ?? 'User'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_isLoadingStats) {
      return _buildStatsCardSkeleton();
    }

    final stats = _statsData ?? {};
    final total = stats['total'] ?? 0;
    final totalSudahAbsen = stats['total_sudah_absen'] ?? 0;
    final totalBelumAbsen = stats['total_belum_absen'] ?? 0;
    final totalExpired = stats['total_expired'] ?? 0;
    final totalValid = stats['total_validation_valid'] ?? 0;
    final totalInvalid = stats['total_validation_invalid'] ?? 0;
    final persentaseKehadiran = stats['persentase_kehadiran'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', total.toString(), Icons.work_history),
              _buildStatItem('Hadir', totalSudahAbsen.toString(), Icons.check_circle, color: onTimeColor),
              _buildStatItem('Belum', totalBelumAbsen.toString(), Icons.pending, color: pendingColor),
              _buildStatItem('Kadaluarsa', totalExpired.toString(), Icons.timer_off, color: expiredColor),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tingkat Kehadiran',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: persentaseKehadiran / 100,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(onTimeColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${persentaseKehadiran.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Validasi Lokasi Valid',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$totalValid',
                            style: GoogleFonts.poppins(
                              color: validColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Validasi Lokasi Invalid',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$totalInvalid',
                            style: GoogleFonts.poppins(
                              color: invalidColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data absensi diambil dari jadwal lembur yang sudah disetujui. Validasi lokasi membandingkan lokasi pengajuan dengan lokasi saat absensi.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardSkeleton() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTabItem('Semua', 'semua', Icons.list, Colors.grey),
          const SizedBox(width: 8),
          _buildTabItem('Belum Absen', 'belum_absen', Icons.pending, pendingColor, badge: _pendingAbsensi.length),
          const SizedBox(width: 8),
          _buildTabItem('Sudah Absen', 'sudah_absen', Icons.check_circle, onTimeColor, badge: _onTimeAbsensi.length),
          const SizedBox(width: 8),
          _buildTabItem('Valid', 'valid', Icons.verified, validColor, badge: _filteredAbsensi.where((a) => a['validation_status'] == 'valid').length),
          const SizedBox(width: 8),
          _buildTabItem('Invalid', 'invalid', Icons.warning, invalidColor, badge: _validationInvalid.length),
          const SizedBox(width: 8),
          _buildTabItem('Kadaluarsa', 'expired', Icons.timer_off, expiredColor, badge: _expiredAbsensi.length),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, String value, IconData icon, Color color, {int? badge}) {
    final isSelected = _selectedTab == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isSelected ? color : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final stats = _statsData ?? {};
    final totalSudahAbsen = stats['total_sudah_absen'] ?? 0;
    final totalValid = stats['total_validation_valid'] ?? 0;
    final totalTotal = stats['total'] ?? 1;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickStatCard(
              title: 'Kehadiran',
              value: '${((totalSudahAbsen / totalTotal) * 100).toStringAsFixed(0)}%',
              subtitle: '$totalSudahAbsen dari $totalTotal',
              icon: Icons.people,
              color: onTimeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickStatCard(
              title: 'Validasi Valid',
              value: totalSudahAbsen > 0 ? '${((totalValid / totalSudahAbsen) * 100).toStringAsFixed(0)}%' : '0%',
              subtitle: '$totalValid dari $totalSudahAbsen',
              icon: Icons.verified,
              color: validColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickStatCard(
              title: 'Tingkat Kehadiran',
              value: '${((totalSudahAbsen / totalTotal) * 100).toStringAsFixed(0)}%',
              subtitle: 'target 100%',
              icon: Icons.trending_up,
              color: accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChipWithIcon(
                  'Fungsi',
                  Icons.business,
                  _selectedFungsi != 'semua',
                  () => _showFilterBottomSheet('fungsi'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Bulan',
                  Icons.calendar_month,
                  true,
                  () => _showMonthPicker(),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Status',
                  Icons.flag,
                  _selectedStatus != 'semua',
                  () => _showFilterBottomSheet('status'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Lokasi',
                  Icons.location_on,
                  _selectedLokasi != 'semua',
                  () => _showFilterBottomSheet('lokasi'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Validasi',
                  Icons.verified,
                  _selectedValidationStatus != 'semua',
                  () => _showFilterBottomSheet('validasi'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Date Range',
                  Icons.date_range,
                  _useDateRange,
                  _showDateRangePicker,
                ),
              ],
            ),
          ),

          if (_hasActiveFilters())
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, size: 14, color: primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Filter Aktif:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _resetAllFilters,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 30),
                        ),
                        child: Text(
                          'Reset',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedFungsi != 'semua')
                        _buildActiveFilterChip(
                          'Fungsi: ${_getFungsiLabel(_selectedFungsi)}',
                          () => setState(() {
                            _selectedFungsi = 'semua';
                            _applyFilters();
                          }),
                        ),
                      _buildActiveFilterChip(
                        'Bulan: ${_formatMonth(_selectedBulan)}',
                        () => setState(() {
                          _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
                          _refreshData();
                        }),
                      ),
                      if (_selectedStatus != 'semua')
                        _buildActiveFilterChip(
                          'Status: ${_getStatusLabel(_selectedStatus)}',
                          () => setState(() {
                            _selectedStatus = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_selectedLokasi != 'semua')
                        _buildActiveFilterChip(
                          'Lokasi: ${_getLokasiLabel(_selectedLokasi)}',
                          () => setState(() {
                            _selectedLokasi = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_selectedValidationStatus != 'semua')
                        _buildActiveFilterChip(
                          'Validasi: ${_getValidationStatusLabel(_selectedValidationStatus)}',
                          () => setState(() {
                            _selectedValidationStatus = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_useDateRange && _selectedDateRange != null)
                        _buildActiveFilterChip(
                          'Tanggal: ${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
                          () => setState(() {
                            _useDateRange = false;
                            _selectedDateRange = null;
                            _refreshData();
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChipWithIcon(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return Material(
      color: isActive ? accentBlue.withValues(alpha: 0.1) : Colors.grey[50],
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? accentBlue : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? accentBlue : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isActive ? accentBlue : Colors.grey[700],
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 12, color: accentBlue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: primaryBlue,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedFungsi != 'semua' ||
        _selectedBulan != DateFormat('yyyy-MM').format(DateTime.now()) ||
        _selectedStatus != 'semua' ||
        _selectedLokasi != 'semua' ||
        _selectedValidationStatus != 'semua' ||
        _selectedTab != 'semua' ||
        _useDateRange;
  }

  void _resetAllFilters() {
    setState(() {
      _selectedFungsi = isSuperadmin || isManager ? 'semua' : _userFungsi ?? '';
      _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
      _selectedStatus = 'semua';
      _selectedLokasi = 'semua';
      _selectedValidationStatus = 'semua';
      _selectedTab = 'semua';
      _useDateRange = false;
      _selectedDateRange = null;
      _applyFilters();
    });
    _refreshData();
  }

  void _showFilterBottomSheet(String filterType) {
    List<Map<String, dynamic>> items = [];
    
    switch (filterType) {
      case 'fungsi':
        items = fungsiList;
        break;
      case 'status':
        items = statusList;
        break;
      case 'lokasi':
        items = lokasiList;
        break;
      case 'validasi':
        items = const [
          {"value": "semua", "label": "Semua", "icon": Icons.list, "color": Colors.grey},
          {"value": "valid", "label": "Valid", "icon": Icons.verified, "color": Color(0xFF4CAF50)},
          {"value": "invalid", "label": "Invalid", "icon": Icons.warning, "color": Color(0xFFF44336)},
          {"value": "pending", "label": "Pending", "icon": Icons.pending, "color": Color(0xFFFFA500)},
        ];
        break;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Filter',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              
              if (filterType == 'fungsi')
                ..._buildFilterListItems(fungsiList, (value) {
                  setState(() {
                    _selectedFungsi = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'status')
                ..._buildFilterListItems(statusList, (value) {
                  setState(() {
                    _selectedStatus = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'lokasi')
                ..._buildFilterListItems(lokasiList, (value) {
                  setState(() {
                    _selectedLokasi = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'validasi')
                ..._buildFilterListItems([
                  {"value": "semua", "label": "Semua", "icon": Icons.list, "color": Colors.grey},
                  {"value": "valid", "label": "Valid", "icon": Icons.verified, "color": validColor},
                  {"value": "invalid", "label": "Invalid", "icon": Icons.warning, "color": invalidColor},
                  {"value": "pending", "label": "Pending", "icon": Icons.pending, "color": pendingColor},
                ], (value) {
                  setState(() {
                    _selectedValidationStatus = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFilterListItems(List<Map<String, dynamic>> items, Function(String) onTap) {
    return items.map((item) {
      return ListTile(
        leading: Icon(item['icon'] as IconData, color: item['color'] as Color),
        title: Text(item['label'] as String),
        onTap: () => onTap(item['value'] as String),
      );
    }).toList();
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pilih Bulan', style: GoogleFonts.poppins()),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 12,
              itemBuilder: (context, index) {
                final date = DateTime.now().subtract(Duration(days: 30 * index));
                final monthStr = DateFormat('yyyy-MM').format(date);
                final monthDisplay = DateFormat('MMMM yyyy', 'id_ID').format(date);
                
                return ListTile(
                  title: Text(monthDisplay),
                  selected: _selectedBulan == monthStr,
                  onTap: () {
                    setState(() {
                      _selectedBulan = monthStr;
                      _useDateRange = false;
                      _selectedDateRange = null;
                      _refreshData();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      locale: const Locale('id', 'ID'),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _useDateRange = true;
        _refreshData();
      });
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Riwayat Absensi',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: primaryBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: _showSearchDialog,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showAdvancedFilterDialog,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, color: Colors.white),
          onSelected: (value) {
            setState(() {
              _sortBy = value;
              _sortFilteredDocs();
            });
          },
          itemBuilder: (context) {
            return sortOptions.map((option) {
              return PopupMenuItem<String>(
                value: option['value'] as String,
                child: Row(
                  children: [
                    Icon(option['icon'] as IconData, size: 18, color: primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      option['label'] as String,
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
        if (isSuperadmin || isManager)
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _showExportDialog,
          ),
        IconButton(
          icon: Icon(
            isGridView ? Icons.view_list : Icons.grid_view,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              isGridView = !isGridView;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAbsensiList() {
    if (_filteredAbsensi.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    if (isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final absensi = _filteredAbsensi[index];
              return _buildAbsensiGridCard(absensi);
            },
            childCount: _filteredAbsensi.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final absensi = _filteredAbsensi[index];
            return _buildAbsensiCard(absensi);
          },
          childCount: _filteredAbsensi.length,
        ),
      ),
    );
  }

  Widget _buildAbsensiCard(Map<String, dynamic> absensi) {
    final sudahAbsen = absensi['sudah_absen'] ?? false;
    final isExpired = absensi['is_expired'] ?? false;
    final validationStatus = absensi['validation_status'];
    final validationColor = absensi['validation_color'] ?? Colors.grey;
    final validationMessage = absensi['validation_message'] ?? '';
    final isMultiple = absensi['is_multiple'] ?? false;
    final totalMitra = absensi['total_mitra'] ?? 1;
    final estimasiBiaya = (absensi['estimasi_biaya'] ?? 0).toDouble();
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isExpired) {
      statusColor = expiredColor;
      statusText = 'Kadaluarsa';
      statusIcon = Icons.timer_off;
    } else if (!sudahAbsen) {
      statusColor = pendingColor;
      statusText = 'Belum Absen';
      statusIcon = Icons.pending;
    } else if (validationStatus == 'valid') {
      statusColor = validColor;
      statusText = 'Validasi Valid';
      statusIcon = Icons.verified;
    } else if (validationStatus == 'invalid') {
      statusColor = invalidColor;
      statusText = 'Validasi Invalid';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.grey;
      statusText = 'Menunggu Validasi';
      statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: primaryBlue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showAbsensiDetail(absensi),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isMultiple ? 'Lembur Grup' : (absensi['user_name'] ?? 'Unknown'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMultiple)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$totalMitra mitra',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTanggalFromTimestamp(absensi['tanggal_lembur'] as Timestamp?),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (absensi['nama_pengawas'] != null)
                          Text(
                            'Pengawas: ${absensi['nama_pengawas']}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (sudahAbsen && absensi['check_in_time'] != null)
                        Text(
                          DateFormat('HH:mm').format(absensi['check_in_time']),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.access_time,
                    '${absensi['jam_mulai']} - ${absensi['jam_selesai']}',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.timer,
                    'Target: ${(absensi['durasi_jam_target'] ?? 0).toStringAsFixed(1)} jam',
                    Colors.orange,
                  ),
                  if (sudahAbsen)
                    _buildInfoChip(
                      Icons.check_circle,
                      'Absen: ${(absensi['durasi_jam_actual'] ?? 0).toStringAsFixed(1)} jam',
                      Colors.green,
                    ),
                  _buildInfoChip(
                    Icons.work,
                    absensi['is_holiday'] == true ? 'Hari Libur' : 'Hari Kerja',
                    absensi['is_holiday'] == true ? Colors.purple : Colors.teal,
                  ),
                  _buildInfoChip(
                    Icons.priority_high,
                    _getUrgensiLabel(absensi['urgensi']),
                    _getUrgensiColor(absensi['urgensi']),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: validationColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: validationColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      validationStatus == 'valid' ? Icons.verified : 
                      (validationStatus == 'invalid' ? Icons.warning : Icons.pending),
                      size: 16,
                      color: validationColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            validationStatus == 'valid' ? 'Lokasi Valid' : 
                            (validationStatus == 'invalid' ? 'Lokasi Tidak Valid' : 'Belum Divalidasi'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: validationColor,
                            ),
                          ),
                          if (validationMessage.isNotEmpty)
                            Text(
                              validationMessage,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: validationColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: absensi['is_outside_radius'] == true ? Colors.orange : accentBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getLocationText(absensi['lokasi_pengajuan']),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimasi Biaya',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        _formatRupiah(estimasiBiaya),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  
                  if (isSuperadmin && sudahAbsen && !isExpired)
                    TextButton.icon(
                      onPressed: () => _showInvoiceAdjustmentDialog(absensi),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(
                        'Atur Potongan',
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: accentBlue,
                      ),
                    ),
                  
                  if (absensi['foto_url'] != null)
                    TextButton.icon(
                      onPressed: () => _showFotoDialog(absensi['foto_url'] as String),
                      icon: const Icon(Icons.image, size: 16),
                      label: Text(
                        'Lihat Foto',
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: accentBlue,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbsensiGridCard(Map<String, dynamic> absensi) {
    final sudahAbsen = absensi['sudah_absen'] ?? false;
    final isExpired = absensi['is_expired'] ?? false;
    final validationStatus = absensi['validation_status'];
    
    Color statusColor;
    String statusText;
    
    if (isExpired) {
      statusColor = expiredColor;
      statusText = 'Kadaluarsa';
    } else if (!sudahAbsen) {
      statusColor = pendingColor;
      statusText = 'Belum Absen';
    } else if (validationStatus == 'valid') {
      statusColor = validColor;
      statusText = 'Valid';
    } else if (validationStatus == 'invalid') {
      statusColor = invalidColor;
      statusText = 'Invalid';
    } else {
      statusColor = Colors.grey;
      statusText = 'Pending';
    }

    return Card(
      elevation: 3,
      shadowColor: primaryBlue.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showAbsensiDetail(absensi),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      validationStatus == 'valid' ? Icons.verified : 
                      (validationStatus == 'invalid' ? Icons.warning : Icons.pending),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                absensi['user_name'] ?? 'Unknown',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              Text(
                _formatTanggalShort(absensi['tanggal_lembur'] as Timestamp?),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${absensi['jam_mulai']} - ${absensi['jam_selesai']}',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (sudahAbsen && absensi['check_in_time'] != null)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Absen: ${DateFormat('HH:mm').format(absensi['check_in_time'])}',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              const Divider(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biaya:',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    _formatRupiahCompact((absensi['estimasi_biaya'] ?? 0).toDouble()),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: lightBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.2 + _pulseController.value * 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.history,
                    size: 64,
                    color: primaryBlue.withValues(alpha: 0.5),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak ada data absensi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada jadwal lembur yang membutuhkan absensi\nuntuk filter yang dipilih',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_hasActiveFilters())
              TextButton.icon(
                onPressed: _resetAllFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: accentBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data...',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showAbsensiDetail(Map<String, dynamic> absensi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _AbsensiDetailContent(
              absensi: absensi,
              scrollController: scrollController,
              userRole: _userRole,
              userId: _userId,
              isSuperadmin: isSuperadmin,
              onAdjustInvoice: isSuperadmin ? () => _showInvoiceAdjustmentDialog(absensi) : null,
            );
          },
        );
      },
    );
  }

  void _showFotoDialog(String fotoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    fotoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: Text('Gagal memuat foto')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditTrailDialog() async {
    await _loadAuditTrail();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.history, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Audit Trail',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _auditTrail.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada aktivitas tercatat',
                              style: GoogleFonts.poppins(color: Colors.grey[500]),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _auditTrail.length,
                            itemBuilder: (context, index) {
                              final trail = _auditTrail[index];
                              final timestamp = trail['timestamp_local'] as DateTime?;
                              final action = trail['action'] ?? '';
                              final description = trail['description'] ?? '';
                              
                              IconData icon;
                              Color color;
                              switch (action) {
                                case 'validasi_lokasi':
                                  icon = Icons.location_on;
                                  color = Colors.blue;
                                  break;
                                case 'adjust_invoice':
                                  icon = Icons.attach_money;
                                  color = Colors.orange;
                                  break;
                                default:
                                  icon = Icons.info;
                                  color = Colors.grey;
                              }
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  title: Text(
                                    action.replaceAll('_', ' ').toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  subtitle: Text(
                                    description,
                                    style: GoogleFonts.poppins(fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    timestamp != null ? DateFormat('HH:mm dd/MM').format(timestamp) : '-',
                                    style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: AbsensiSearchDelegate(
        userRole: _userRole,
        userFungsi: _userFungsi,
        userId: _userId,
        accentBlue: accentBlue,
        primaryBlue: primaryBlue,
        onSearch: (query) {
          setState(() {
            _searchQuery = query;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showAdvancedFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter Lanjutan',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text('Fungsi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: fungsiList.map((item) {
                      final isDisabled = !isSuperadmin && !isManager && item['value'] != _userFungsi;
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: _selectedFungsi == item['value'],
                        onSelected: isDisabled ? null : (selected) {
                          setState(() {
                            _selectedFungsi = selected ? item['value'] as String : 'semua';
                          });
                        },
                        selectedColor: (item['color'] as Color).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                        backgroundColor: isDisabled ? Colors.grey[200] : null,
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text('Status Kehadiran', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('Semua', 'semua'),
                      _buildFilterChip('Belum Absen', 'belum_absen'),
                      _buildFilterChip('Sudah Absen', 'sudah_absen'),
                      _buildFilterChip('Kadaluarsa', 'expired'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text('Validasi Lokasi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _selectedValidationStatus == 'semua',
                        onSelected: (_) => setState(() => _selectedValidationStatus = 'semua'),
                      ),
                      ChoiceChip(
                        label: const Text('Valid'),
                        selected: _selectedValidationStatus == 'valid',
                        onSelected: (_) => setState(() => _selectedValidationStatus = 'valid'),
                        selectedColor: validColor.withValues(alpha: 0.2),
                      ),
                      ChoiceChip(
                        label: const Text('Invalid'),
                        selected: _selectedValidationStatus == 'invalid',
                        onSelected: (_) => setState(() => _selectedValidationStatus = 'invalid'),
                        selectedColor: invalidColor.withValues(alpha: 0.2),
                      ),
                      ChoiceChip(
                        label: const Text('Pending'),
                        selected: _selectedValidationStatus == 'pending',
                        onSelected: (_) => setState(() => _selectedValidationStatus = 'pending'),
                        selectedColor: pendingColor.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text('Lokasi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: lokasiList.map((item) {
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: _selectedLokasi == item['value'],
                        onSelected: (selected) {
                          setState(() {
                            _selectedLokasi = selected ? item['value'] as String : 'semua';
                          });
                        },
                        selectedColor: (item['color'] as Color).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text('Urgensi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: urgensiList.map((item) {
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: _selectedUrgensi == item['value'],
                        onSelected: (selected) {
                          setState(() {
                            _selectedUrgensi = selected ? item['value'] as String : 'semua';
                          });
                        },
                        selectedColor: (item['color'] as Color).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _resetAllFilters();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Reset Semua'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedTab == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedTab = value;
          _applyFilters();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: accentBlue.withValues(alpha: 0.2),
      checkmarkColor: accentBlue,
      labelStyle: GoogleFonts.poppins(
        fontSize: 11,
        color: isSelected ? accentBlue : Colors.grey[700],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Data', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: Text('Export ke Excel', style: GoogleFonts.poppins()),
              subtitle: Text('Format spreadsheet untuk analisis', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: Text('Export ke PDF', style: GoogleFonts.poppins()),
              subtitle: Text('Laporan lengkap dengan detail', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.print, color: Colors.blue),
              ),
              title: Text('Cetak', style: GoogleFonts.poppins()),
              subtitle: Text('Cetak langsung ke printer', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _printData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      _showInfoSnackbar('Menyiapkan data untuk export...');

      if (_filteredAbsensi.isEmpty) {
        _showErrorSnackbar('Tidak ada data untuk diexport');
        return;
      }

      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['Riwayat_Absensi'];

      final headers = [
        'No', 'Tanggal Lembur', 'Mitra', 'Fungsi', 'Pengawas',
        'Jam Mulai', 'Jam Selesai', 'Target Durasi (Jam)', 'Status Absensi',
        'Check In Time', 'Check Out Time', 'Durasi Aktual (Jam)',
        'Status Validasi', 'Pesan Validasi', 'Jarak (m)',
        'Lokasi Pengajuan', 'Lokasi Absensi', 'Luar Radius',
        'Jenis Lembur', 'Urgensi', 'Estimasi Biaya', 'Catatan'
      ];
      
      sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());

      for (var i = 0; i < _filteredAbsensi.length; i++) {
        final absensi = _filteredAbsensi[i];
        final tanggalLembur = absensi['tanggal_lembur'] as Timestamp?;
        final sudahAbsen = absensi['sudah_absen'] ?? false;
        final validationDetails = absensi['validation_details'] ?? {};
        
        String statusText = '';
        if (absensi['is_expired'] == true) {
          statusText = 'Kadaluarsa';
        } else if (!sudahAbsen) {
          statusText = 'Belum Absen';
        } else {
          statusText = 'Sudah Absen';
        }

        sheet.appendRow([
          excel.TextCellValue((i + 1).toString()),
          excel.TextCellValue(tanggalLembur != null ? DateFormat('yyyy-MM-dd').format(tanggalLembur.toDate()) : '-'),
          excel.TextCellValue(absensi['user_name'] ?? '-'),
          excel.TextCellValue(absensi['fungsi_label'] ?? '-'),
          excel.TextCellValue(absensi['nama_pengawas'] ?? '-'),
          excel.TextCellValue(absensi['jam_mulai'] ?? '-'),
          excel.TextCellValue(absensi['jam_selesai'] ?? '-'),
          excel.TextCellValue((absensi['durasi_jam_target'] ?? 0).toStringAsFixed(1)),
          excel.TextCellValue(statusText),
          excel.TextCellValue(absensi['check_in_time'] != null ? DateFormat('HH:mm:ss').format(absensi['check_in_time']) : '-'),
          excel.TextCellValue(absensi['check_out_time'] != null ? DateFormat('HH:mm:ss').format(absensi['check_out_time']) : '-'),
          excel.TextCellValue((absensi['durasi_jam_actual'] ?? 0).toStringAsFixed(1)),
          excel.TextCellValue(absensi['validation_status'] ?? '-'),
          excel.TextCellValue(absensi['validation_message'] ?? '-'),
          excel.TextCellValue(((validationDetails['distance'] ?? 0) / 1000).toStringAsFixed(2)),
          excel.TextCellValue(_getLocationText(absensi['lokasi_pengajuan'])),
          excel.TextCellValue(_getLocationText(absensi['lokasi_absensi'])),
          excel.TextCellValue(absensi['is_outside_radius'] == true ? 'Ya' : 'Tidak'),
          excel.TextCellValue(absensi['is_holiday'] == true ? 'Hari Libur' : 'Hari Kerja'),
          excel.TextCellValue(_getUrgensiLabel(absensi['urgensi'])),
          excel.TextCellValue(_formatRupiah((absensi['estimasi_biaya'] ?? 0).toDouble())),
          excel.TextCellValue(absensi['catatan'] ?? '-'),
        ]);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getTemporaryDirectory();
        final fileName = 'Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(excelFile.encode()!);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Data Riwayat Absensi Lembur',
        );
      } else if (kIsWeb) {
        final bytes = excelFile.encode();
        if (bytes != null) {
          final fileName = 'Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..target = 'blank'
            ..download = fileName;
          anchor.click();
          html.Url.revokeObjectUrl(url);
        }
      } else {
        final bytes = excelFile.encode();
        if (bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
          await file.writeAsBytes(bytes);
          await Share.shareXFiles([XFile(file.path)], text: 'Data Riwayat Absensi Lembur');
        }
      }

      _showSuccessSnackbar('File Excel berhasil dibuat');
      
      await _addAuditTrail(
        action: 'export_excel',
        description: 'User mengexport data riwayat absensi ke Excel',
        data: {'total_data': _filteredAbsensi.length},
      );
      
    } catch (e) {
      logger.e('Error exporting to Excel: $e');
      _showErrorSnackbar('Gagal export ke Excel: ${e.toString()}');
    }
  }

  Future<void> _exportToPDF() async {
    try {
      _showInfoSnackbar('Menyiapkan PDF...');

      final pdf = pw.Document();

      pw.Font? ttf;
      pw.Font? boldTtf;
      
      try {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
        
        final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        boldTtf = pw.Font.ttf(boldFontData);
      } catch (e) {
        ttf = pw.Font.helvetica();
        boldTtf = pw.Font.helveticaBold();
      }

      final stats = _statsData ?? {};
      final totalSudahAbsen = stats['total_sudah_absen'] ?? 0;
      final totalValid = stats['total_validation_valid'] ?? 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Laporan Riwayat Absensi Lembur',
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 24,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Periode: ${_formatMonth(_selectedBulan)}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Total Data: ${_filteredAbsensi.length}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'User: $_userName (${_getRoleDisplayName()})',
                style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: [
                'No', 'Tanggal', 'Mitra', 'Jam', 'Status', 'Validasi', 'Biaya',
              ],
              data: List.generate(_filteredAbsensi.length.clamp(0, 20).toInt(), (index) {
                final absensi = _filteredAbsensi[index];
                final tanggalLembur = absensi['tanggal_lembur'] as Timestamp?;
                
                String statusText = '';
                if (absensi['is_expired'] == true) {
                  statusText = 'Kadaluarsa';
                } else if (!(absensi['sudah_absen'] ?? false)) {
                  statusText = 'Belum Absen';
                } else {
                  statusText = 'Sudah Absen';
                }
                
                String validasiText = '';
                switch (absensi['validation_status']) {
                  case 'valid':
                    validasiText = '✓ Valid';
                    break;
                  case 'invalid':
                    validasiText = '✗ Invalid';
                    break;
                  default:
                    validasiText = '-';
                }
                
                return [
                  (index + 1).toString(),
                  tanggalLembur != null ? DateFormat('dd/MM/yyyy').format(tanggalLembur.toDate()) : '-',
                  absensi['user_name'] ?? '-',
                  '${absensi['jam_mulai'] ?? ''} - ${absensi['jam_selesai'] ?? ''}',
                  statusText,
                  validasiText,
                  _formatRupiah((absensi['estimasi_biaya'] ?? 0).toDouble()),
                ];
              }),
              border: pw.TableBorder.all(
                width: 0.5,
                color: PdfColors.grey,
              ),
              headerStyle: pw.TextStyle(
                font: boldTtf,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(
                font: ttf,
                fontSize: 9,
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            pw.Text(
              'Ringkasan:',
              style: pw.TextStyle(font: boldTtf, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Jadwal: ${_filteredAbsensi.length}', style: pw.TextStyle(font: ttf)),
                      pw.Text('Sudah Absen: $totalSudahAbsen', style: pw.TextStyle(font: ttf)),
                      pw.Text('Validasi Valid: $totalValid', style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Tingkat Kehadiran: ${((totalSudahAbsen / (_filteredAbsensi.length)) * 100).toStringAsFixed(1)}%', 
                          style: pw.TextStyle(font: ttf)),
                      pw.Text('Tingkat Validasi: ${totalSudahAbsen > 0 ? ((totalValid / totalSudahAbsen) * 100).toStringAsFixed(1) : '0'}%', 
                          style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                '*Validasi lokasi membandingkan lokasi pengajuan dengan lokasi saat absensi. Toleransi jarak 100 meter.\n'
                '*Data diambil dari jadwal lembur yang sudah disetujui.',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      );

      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getTemporaryDirectory();
        final fileName = 'Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Laporan Riwayat Absensi Lembur',
        );
      } else if (kIsWeb) {
        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName;
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Riwayat_Absensi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
        await file.writeAsBytes(await pdf.save());
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Riwayat Absensi Lembur');
      }

      _showSuccessSnackbar('File PDF berhasil dibuat');
      
      await _addAuditTrail(
        action: 'export_pdf',
        description: 'User mengexport data riwayat absensi ke PDF',
        data: {'total_data': _filteredAbsensi.length},
      );
      
    } catch (e) {
      logger.e('Error exporting to PDF: $e');
      _showErrorSnackbar('Gagal export ke PDF: ${e.toString()}');
    }
  }

  Future<void> _printData() async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();
          
          final stats = _statsData ?? {};
          final totalSudahAbsen = stats['total_sudah_absen'] ?? 0;

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              build: (context) => [
                pw.Text('Laporan Riwayat Absensi Lembur', style: const pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 20),
                pw.Text('Periode: ${_formatMonth(_selectedBulan)}'),
                pw.Text('Total Data: ${_filteredAbsensi.length}'),
                pw.Text('Sudah Absen: $totalSudahAbsen'),
                pw.Text('User: $_userName (${_getRoleDisplayName()})'),
                pw.Text('*Validasi lokasi membandingkan lokasi pengajuan dengan lokasi saat absensi'),
              ],
            ),
          );
          return pdf.save();
        },
      );
      
      await _addAuditTrail(
        action: 'print',
        description: 'User mencetak laporan riwayat absensi',
        data: {'total_data': _filteredAbsensi.length},
      );
      
    } catch (e) {
      _showErrorSnackbar('Gagal mencetak: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      _lastDocument = null;
      _hasMoreData = true;
      _absensiHistory.clear();
    });
    await Future.wait([
      _loadAbsensiFromOvertime(),
      _loadStats(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Logout', style: GoogleFonts.poppins()),
        content: Text('Apakah Anda yakin ingin logout?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // ==================== HELPER METHODS ====================
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getRoleDisplayName() {
    if (isSuperadmin) return 'SUPERADMIN';
    if (isManager) return 'MANAGER';
    if (isPengawas) return 'PENGAWAS';
    if (isMitra) return 'MITRA';
    return 'USER';
  }

  String _formatTanggalFromTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(timestamp.toDate());
  }

  String _formatTanggalShort(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(timestamp.toDate());
  }

  String _formatMonth(String yearMonth) {
    try {
      final date = DateTime.parse('$yearMonth-01');
      return DateFormat('MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return yearMonth;
    }
  }

  String _formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  String _formatRupiahCompact(double value) {
    if (value >= 1000000) {
      final juta = value / 1000000;
      return 'Rp ${juta.toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      final ribu = value / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)}rb';
    } else {
      return 'Rp ${value.toStringAsFixed(0)}';
    }
  }

  String _getFungsiLabel(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation':
        return 'Operation';
      case 'lab':
        return 'Laboratorium';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'BS';
      default:
        return fungsi ?? 'Unknown';
    }
  }

  String _getStatusLabel(String status) {
    final item = statusList.firstWhere(
      (s) => s['value'] == status,
      orElse: () => statusList[0],
    );
    return item['label'] as String;
  }

  String _getLokasiLabel(String lokasi) {
    final item = lokasiList.firstWhere(
      (l) => l['value'] == lokasi,
      orElse: () => lokasiList[0],
    );
    return item['label'] as String;
  }

  String _getValidationStatusLabel(String status) {
    switch (status) {
      case 'valid':
        return 'Valid';
      case 'invalid':
        return 'Invalid';
      case 'pending':
        return 'Pending';
      default:
        return 'Semua';
    }
  }

  String _getUrgensiLabel(String urgensi) {
    switch (urgensi) {
      case 'rendah':
        return 'Rendah';
      case 'normal':
        return 'Normal';
      case 'tinggi':
        return 'Tinggi';
      case 'kritis':
        return 'Kritis';
      default:
        return urgensi;
    }
  }

  Color _getUrgensiColor(String urgensi) {
    switch (urgensi) {
      case 'rendah':
        return Colors.green;
      case 'normal':
        return Colors.blue;
      case 'tinggi':
        return Colors.orange;
      case 'kritis':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getLocationText(Map<String, dynamic>? lokasi) {
    if (lokasi == null) return 'Kantor PGE';
    final pilihan = lokasi['pilihan'] ?? 'kantor';
    
    if (pilihan == 'kantor') return 'Kantor PGE';
    if (pilihan == 'proyek') return lokasi['proyek'] ?? 'Proyek';
    return lokasi['alamat'] ?? 'Lokasi Lain';
  }

  // ==================== DETAIL ROW HELPER ====================
  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SNACKBARS ====================
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ==================== ABSENSI DETAIL CONTENT ====================
class _AbsensiDetailContent extends StatefulWidget {
  final Map<String, dynamic> absensi;
  final ScrollController scrollController;
  final String? userRole;
  final String? userId;
  final bool isSuperadmin;
  final VoidCallback? onAdjustInvoice;

  const _AbsensiDetailContent({
    required this.absensi,
    required this.scrollController,
    this.userRole,
    this.userId,
    this.isSuperadmin = false,
    this.onAdjustInvoice,
  });

  @override
  State<_AbsensiDetailContent> createState() => __AbsensiDetailContentState();
}

class __AbsensiDetailContentState extends State<_AbsensiDetailContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);
  final Color validColor = const Color(0xFF4CAF50);
  final Color invalidColor = const Color(0xFFF44336);

  String _formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  String _formatTanggalFromTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(timestamp.toDate());
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(timestamp.toDate());
  }

  String _getLocationText(Map<String, dynamic>? lokasi) {
    if (lokasi == null) return 'Kantor PGE';
    final pilihan = lokasi['pilihan'] ?? 'kantor';
    
    if (pilihan == 'kantor') return 'Kantor PGE';
    if (pilihan == 'proyek') return lokasi['proyek'] ?? 'Proyek';
    return lokasi['alamat'] ?? 'Lokasi Lain';
  }

  String _getUrgensiLabel(String urgensi) {
    switch (urgensi) {
      case 'rendah':
        return 'Rendah';
      case 'normal':
        return 'Normal';
      case 'tinggi':
        return 'Tinggi';
      case 'kritis':
        return 'Kritis';
      default:
        return urgensi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final absensi = widget.absensi;
    final tanggalLembur = absensi['tanggal_lembur'] as Timestamp?;
    final sudahAbsen = absensi['sudah_absen'] ?? false;
    final isExpired = absensi['is_expired'] ?? false;
    final validationStatus = absensi['validation_status'];
    final validationMessage = absensi['validation_message'] ?? '';
    final validationDetails = absensi['validation_details'] ?? {};
    final distance = (validationDetails['distance'] ?? 0) / 1000;
    final tolerance = (validationDetails['tolerance'] ?? 100) / 1000;

    Color validationColor = Colors.grey;
    IconData validationIcon = Icons.pending;
    String validationTitle = 'Menunggu Validasi';
    
    if (validationStatus == 'valid') {
      validationColor = validColor;
      validationIcon = Icons.verified;
      validationTitle = 'Validasi Lokasi Valid';
    } else if (validationStatus == 'invalid') {
      validationColor = invalidColor;
      validationIcon = Icons.warning;
      validationTitle = 'Validasi Lokasi Invalid';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: validationColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(validationIcon, color: validationColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Absensi',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      Text(
                        absensi['user_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (absensi['fungsi_label'] != null)
                        Text(
                          absensi['fungsi_label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: validationColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: validationColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        validationTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: validationColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.isSuperadmin && sudahAbsen && !isExpired)
                      TextButton(
                        onPressed: widget.onAdjustInvoice,
                        child: Text(
                          'Atur Potongan',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: accentBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (validationMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: validationColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: validationColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(validationIcon, color: validationColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                validationMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: validationColor,
                                ),
                              ),
                              if (distance > 0)
                                Text(
                                  'Jarak: ${distance.toStringAsFixed(2)} km (toleransi ${tolerance.toStringAsFixed(2)} km)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: validationColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildDetailSection('📋 Informasi Lembur', Icons.work, Colors.orange, [
                  _buildDetailRow('Jenis Lembur', absensi['is_multiple'] == true ? 'Lembur Grup' : 'Lembur Individual'),
                  if (absensi['is_multiple'] == true)
                    _buildDetailRow('Total Mitra', '${absensi['total_mitra']} orang'),
                  _buildDetailRow('Tanggal Lembur', _formatTanggalFromTimestamp(tanggalLembur)),
                  _buildDetailRow('Jam Lembur', '${absensi['jam_mulai']} - ${absensi['jam_selesai']}'),
                  _buildDetailRow('Target Durasi', '${(absensi['durasi_jam_target'] ?? 0).toStringAsFixed(1)} jam'),
                  _buildDetailRow('Jenis', absensi['is_holiday'] == true ? 'Hari Libur' : 'Hari Kerja'),
                  _buildDetailRow('Urgensi', _getUrgensiLabel(absensi['urgensi'] ?? 'normal')),
                  if (absensi['alasan'] != null && absensi['alasan'].toString().isNotEmpty)
                    _buildDetailRow('Alasan', absensi['alasan'], isLong: true),
                  if (absensi['catatan'] != null && absensi['catatan'].toString().isNotEmpty)
                    _buildDetailRow('Catatan', absensi['catatan'], isLong: true),
                ]),
                const SizedBox(height: 16),

                _buildDetailSection('👤 Informasi Pengawas', Icons.supervisor_account, Colors.blue, [
                  _buildDetailRow('Nama', absensi['nama_pengawas'] ?? '-'),
                  _buildDetailRow('Fungsi', absensi['pengawas_fungsi'] ?? '-'),
                  if (absensi['pengawas_id'] != null)
                    _buildDetailRow('ID', absensi['pengawas_id']),
                ]),
                const SizedBox(height: 16),

                _buildDetailSection('⏰ Waktu Absensi', Icons.access_time, Colors.green, [
                  if (sudahAbsen) ...[
                    _buildDetailRow('Check In', absensi['check_in_time'] != null 
                        ? DateFormat('HH:mm:ss - dd MMM yyyy').format(absensi['check_in_time']) 
                        : '-'),
                    _buildDetailRow('Check Out', absensi['check_out_time'] != null 
                        ? DateFormat('HH:mm:ss - dd MMM yyyy').format(absensi['check_out_time']) 
                        : '-'),
                    _buildDetailRow('Durasi Aktual', '${(absensi['durasi_jam_actual'] ?? 0).toStringAsFixed(1)} jam'),
                    _buildDetailRow('Mode', absensi['is_live_absensi'] == true ? 'Live Absensi' : 'Manual'),
                  ] else if (isExpired) ...[
                    _buildDetailRow('Status', 'Kadaluarsa', color: Colors.red),
                    _buildDetailRow('Keterangan', 'Tidak melakukan absensi hingga batas waktu'),
                  ] else ...[
                    _buildDetailRow('Status', 'Belum Absen', color: Colors.orange),
                    _buildDetailRow('Batas Waktu', 'H+1 setelah jam selesai'),
                  ],
                ]),
                const SizedBox(height: 16),

                _buildDetailSection('📍 Lokasi Pengajuan', Icons.location_on, Colors.purple, [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Pilihan', _getLocationText(absensi['lokasi_pengajuan'])),
                        if (absensi['lokasi_pengajuan'] != null) ...[
                          _buildDetailRow('Alamat', absensi['lokasi_pengajuan']['alamat'] ?? '-', isLong: true),
                          _buildDetailRow('Koordinat', 
                              '${absensi['lokasi_pengajuan']['latitude']?.toStringAsFixed(6) ?? '-'}, ${absensi['lokasi_pengajuan']['longitude']?.toStringAsFixed(6) ?? '-'}'),
                          _buildDetailRow('Jarak dari Kantor', 
                              '${((absensi['lokasi_pengajuan']['distance_from_kantor'] ?? 0) / 1000).toStringAsFixed(2)} km'),
                          _buildDetailRow('Status Radius', 
                              absensi['is_outside_radius'] == true ? 'Luar Radius' : 'Dalam Radius',
                              color: absensi['is_outside_radius'] == true ? Colors.orange : Colors.green),
                        ],
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                if (sudahAbsen && absensi['lokasi_absensi'] != null)
                  _buildDetailSection('📍 Lokasi Absensi', Icons.location_on, Colors.orange, [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Pilihan', _getLocationText(absensi['lokasi_absensi'])),
                          _buildDetailRow('Alamat', absensi['lokasi_absensi']['alamat'] ?? '-', isLong: true),
                          _buildDetailRow('Koordinat', 
                              '${absensi['lokasi_absensi']['latitude']?.toStringAsFixed(6) ?? '-'}, ${absensi['lokasi_absensi']['longitude']?.toStringAsFixed(6) ?? '-'}'),
                          _buildDetailRow('Jarak dari Kantor', 
                              '${((absensi['lokasi_absensi']['distance_from_kantor'] ?? 0) / 1000).toStringAsFixed(2)} km'),
                        ],
                      ),
                    ),
                  ]),
                const SizedBox(height: 16),

                if (sudahAbsen && absensi['foto_url'] != null)
                  _buildDetailSection('📸 Foto Bukti', Icons.camera_alt, Colors.teal, [
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(absensi['foto_url'] as String),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _showFullFoto(absensi['foto_url'] as String),
                      icon: const Icon(Icons.fullscreen),
                      label: Text('Lihat Fullscreen', style: GoogleFonts.poppins()),
                    ),
                  ]),
                const SizedBox(height: 16),

                _buildDetailSection('💰 Estimasi Biaya', Icons.attach_money, Colors.green, [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Estimasi Biaya', _formatRupiah((absensi['estimasi_biaya'] ?? 0).toDouble()), 
                            textColor: Colors.white70),
                        if (absensi['manual_deduction'] != null)
                          _buildDetailRow('Potongan Manual', _formatRupiah((absensi['manual_deduction'] ?? 0).toDouble()),
                              textColor: Colors.red),
                        const Divider(color: Colors.white30, height: 16),
                        _buildDetailRow('Net Biaya', _formatRupiah(((absensi['estimasi_biaya'] ?? 0) - (absensi['manual_deduction'] ?? 0)).toDouble()),
                            textColor: Colors.amber, isBold: true),
                        if (absensi['manual_deduction_reason'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Catatan: ${absensi['manual_deduction_reason']}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                _buildDetailSection('📋 Metadata', Icons.info, Colors.grey, [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (absensi['created_at'] != null)
                          _buildDetailRow('Dibuat pada', _formatTimestamp(absensi['created_at'] as Timestamp?)),
                        if (absensi['updated_at'] != null)
                          _buildDetailRow('Terakhir update', _formatTimestamp(absensi['updated_at'] as Timestamp?)),
                        if (absensi['approved_at'] != null)
                          _buildDetailRow('Disetujui pada', _formatTimestamp(absensi['approved_at'] as Timestamp?)),
                        if (absensi['absensi_waktu'] != null)
                          _buildDetailRow('Absensi pada', _formatTimestamp(absensi['absensi_waktu'] as Timestamp?)),
                        if (absensi['group_id'] != null)
                          _buildDetailRow('Group ID', absensi['group_id']),
                        if (absensi['lembur_id'] != null)
                          _buildDetailRow('Lembur ID', absensi['lembur_id']),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isLong = false, Color? color, bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? color ?? Colors.black87,
              ),
              maxLines: isLong ? 5 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullFoto(String fotoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    fotoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: Text('Gagal memuat foto')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== SEARCH DELEGATE ====================
class AbsensiSearchDelegate extends SearchDelegate {
  final String? userRole;
  final String? userFungsi;
  final String? userId;
  final Color accentBlue;
  final Color primaryBlue;
  final Function(String) onSearch;

  AbsensiSearchDelegate({
    this.userRole,
    this.userFungsi,
    this.userId,
    required this.accentBlue,
    required this.primaryBlue,
    required this.onSearch,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch('');
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Ketik minimal 2 karakter untuk mencari',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildSearchQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[200]),
                const SizedBox(height: 16),
                Text(
                  'Terjadi kesalahan',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ditemukan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final tanggalLembur = data['tanggal'] as Timestamp?;
            final isExpired = data['status'] == 'kadaluarsa';
            final sudahAbsen = data['absensi_status'] == 'selesai';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sudahAbsen ? Colors.green.withValues(alpha: 0.1) : 
                           (isExpired ? Colors.grey.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sudahAbsen ? Icons.check_circle : 
                    (isExpired ? Icons.timer_off : Icons.pending),
                    color: sudahAbsen ? Colors.green : 
                           (isExpired ? Colors.grey : Colors.orange),
                    size: 20,
                  ),
                ),
                title: Text(
                  data['nama_mitra'] ?? 'Unknown',
                  style: GoogleFonts.poppins(),
                ),
                subtitle: Text(
                  tanggalLembur != null 
                      ? DateFormat('dd MMM yyyy', 'id_ID').format(tanggalLembur.toDate())
                      : '-',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sudahAbsen ? Colors.green.withValues(alpha: 0.1) : 
                           (isExpired ? Colors.grey.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sudahAbsen ? 'Sudah Absen' : 
                    (isExpired ? 'Kadaluarsa' : 'Belum Absen'),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: sudahAbsen ? Colors.green : 
                             (isExpired ? Colors.grey : Colors.orange),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {
                  close(context, docs[index].id);
                },
              ),
            );
          },
        );
      },
    );
  }

  Query<Map<String, dynamic>> _buildSearchQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('lembur');

    if (userRole == 'superadmin') {
      // No filter
    } else if (userRole == 'manager') {
      query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
    } else if (userRole == 'mitra') {
      query = query.where('mitra_ids', arrayContains: userId);
    } else if (userRole == 'pengawas') {
      query = query.where('pengawas_id', isEqualTo: userId);
    }

    return query
        .orderBy('nama_mitra')
        .where('nama_mitra', isGreaterThanOrEqualTo: query)
        .where('nama_mitra', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20);
  }
}