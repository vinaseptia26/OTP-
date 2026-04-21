// FILE: lib/screens/overtime/overtime_history_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

var logger = Logger();

class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({super.key});

  @override
  State<OvertimeHistoryScreen> createState() => _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState extends State<OvertimeHistoryScreen>
    with SingleTickerProviderStateMixin {
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String? _userName;
  String? _userJabatan;
  String? _userEmail;
  String? _userPhotoUrl;

  bool get isSuperadmin => _userRole == 'superadmin';
  bool get isManager => _userRole == 'manager';
  bool get isPengawas => _userRole == 'pengawas';
  bool get isMitra => _userRole == 'mitra';

  String _selectedFilter = 'semua';
  String _selectedFungsi = 'semua';
  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedUrgensi = 'semua';
  String _selectedJenis = 'semua';
  String _selectedLokasi = 'semua';
  String _sortBy = 'tanggal_desc';
  
  // ==================== SEARCH ====================
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isDarkMode = false;
  bool isGridView = false;
  final int _itemsPerPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  // Cache untuk data
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs = [];
  bool _isUsingCache = false;
  Timer? _cacheTimer;

  // ==================== ANIMATION ====================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ==================== CONTROLLERS ====================
  final ScrollController _scrollController = ScrollController();

  // ==================== COLOR PALETTE ====================
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color secondaryBlue = const Color(0xFF2A4F8C);
  final Color accentBlue = const Color(0xFF1976D2);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color softBlue = const Color(0xFFBBDEFB);
  final Color gradientStart = const Color(0xFF1E3C72);
  final Color gradientEnd = const Color(0xFF2E5A9C);
  final Color expiredColor = const Color(0xFF9E9E9E);

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
    {"value": "semua", "label": "Semua", "icon": Icons.list, "color": Colors.grey},
    {"value": "pending", "label": "Pending", "icon": Icons.pending, "color": Color(0xFFFF9800)},
    {"value": "disetujui", "label": "Disetujui", "icon": Icons.check_circle, "color": Color(0xFF4CAF50)},
    {"value": "ditolak", "label": "Ditolak", "icon": Icons.cancel, "color": Color(0xFFF44336)},
    {"value": "selesai", "label": "Selesai", "icon": Icons.task_alt, "color": Color(0xFF2196F3)},
    {"value": "kadaluarsa", "label": "Kadaluarsa", "icon": Icons.timer_off, "color": Color(0xFF9E9E9E)},
    {"value": "dibatalkan", "label": "Dibatalkan", "icon": Icons.cancel_outlined, "color": Colors.grey},
  ];

  // ==================== URGENSI LIST ====================
  final List<Map<String, dynamic>> urgensiList = const [
    {"value": "semua", "label": "Semua Urgensi", "icon": Icons.filter_list, "color": Colors.grey},
    {"value": "rendah", "label": "Rendah", "icon": Icons.arrow_downward, "color": Color(0xFF4CAF50)},
    {"value": "normal", "label": "Normal", "icon": Icons.remove, "color": Color(0xFF2196F3)},
    {"value": "tinggi", "label": "Tinggi", "icon": Icons.arrow_upward, "color": Color(0xFFFF9800)},
    {"value": "kritis", "label": "Kritis", "icon": Icons.warning, "color": Color(0xFFF44336)},
  ];

  // ==================== JENIS LIST ====================
  final List<Map<String, dynamic>> jenisList = const [
    {"value": "semua", "label": "Semua Jenis", "icon": Icons.work, "color": Colors.grey},
    {"value": "hari_kerja", "label": "Hari Kerja", "icon": Icons.business_center, "color": Color(0xFF2196F3)},
    {"value": "hari_libur", "label": "Hari Libur", "icon": Icons.celebration, "color": Color(0xFF9C27B0)},
  ];

  // ==================== LOKASI LIST ====================
  final List<Map<String, dynamic>> lokasiList = const [
    {"value": "semua", "label": "Semua Lokasi", "icon": Icons.map, "color": Colors.grey},
    {"value": "kantor", "label": "Kantor", "icon": Icons.business, "color": Color(0xFF2196F3)},
    {"value": "proyek", "label": "Proyek", "icon": Icons.location_city, "color": Color(0xFFFF9800)},
    {"value": "custom", "label": "Luar Radius", "icon": Icons.warning, "color": Color(0xFFF44336)},
  ];

  // ==================== SORT OPTIONS ====================
  final List<Map<String, dynamic>> sortOptions = const [
    {"value": "tanggal_desc", "label": "Terbaru", "icon": Icons.arrow_downward},
    {"value": "tanggal_asc", "label": "Terlama", "icon": Icons.arrow_upward},
    {"value": "biaya_desc", "label": "Biaya Tertinggi", "icon": Icons.attach_money},
    {"value": "durasi_desc", "label": "Durasi Terlama", "icon": Icons.timer},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _scrollController.addListener(_onScroll);
    _startCacheTimer();
  }

  void _startCacheTimer() {
    _cacheTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        setState(() {
          _isUsingCache = false;
          _cachedDocs.clear();
        });
      }
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cacheTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final query = _buildOptimizedQuery();
      final snapshot = await query
          .startAfterDocument(_lastDocument!)
          .limit(_itemsPerPage)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        if (snapshot.docs.length < _itemsPerPage) {
          _hasMoreData = false;
        }
        
        setState(() {
          _cachedDocs.addAll(snapshot.docs);
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

  // ==================== LOAD USER DATA & ROLE ====================
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
      _userJabatan = userData['jabatan'] ?? '';

      logger.i('User $_userRole with fungsi $_userFungsi accessing overtime history');

      if (!isSuperadmin && !isManager) {
        _selectedFungsi = _userFungsi ?? '';
      }

      await _loadInitialData();
      await _checkExpiredOvertime();

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackbar('Gagal memuat data user');
      }
    }
  }

  Future<void> _checkExpiredOvertime() async {
    try {
      final now = DateTime.now();
      
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');
      
      if (isMitra) {
        query = query.where('mitra_ids', arrayContains: _userId);
      } else if (isPengawas) {
        query = query.where('pengawas_id', isEqualTo: _userId);
      }
      
      final snapshot = await query
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', isNotEqualTo: 'selesai')
          .get();
      
      final batch = _firestore.batch();
      bool hasExpired = false;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
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
        
        if (now.isAfter(batasWaktu)) {
          batch.update(doc.reference, {
            'status': 'kadaluarsa',
            'absensi_status': 'expired',
            'expired_at': FieldValue.serverTimestamp(),
            'expired_reason': 'Tidak melakukan absensi hingga batas waktu',
            'updated_at': FieldValue.serverTimestamp(),
          });
          hasExpired = true;
        }
      }
      
      if (hasExpired) {
        await batch.commit();
        if (mounted) {
          _showInfoSnackbar('Ada jadwal lembur yang sudah kadaluarsa karena tidak diabsensi');
        }
      }
    } catch (e) {
      logger.e('Error checking expired overtime: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final query = _buildOptimizedQuery().limit(_itemsPerPage);
      final snapshot = await query.get();
      
      setState(() {
        _cachedDocs = snapshot.docs;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMoreData = snapshot.docs.length == _itemsPerPage;
        _applyFilters();
        _isUsingCache = true;
      });
    } catch (e) {
      logger.e('Error loading initial data: $e');
    }
  }

  Query<Map<String, dynamic>> _buildOptimizedQuery() {
    Query<Map<String, dynamic>> query = _firestore.collection('lembur');

    if (isSuperadmin) {
      // Superadmin lihat semua
    } else if (isManager) {
      query = query.where('is_group_leader', isEqualTo: true);
      if (_selectedFungsi != 'semua' && _selectedFungsi.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: _selectedFungsi);
      }
    } else if (isPengawas) {
      query = query.where('pengawas_id', isEqualTo: _userId);
    } else if (isMitra) {
      query = query.where('mitra_ids', arrayContains: _userId);
    }

    if (_selectedBulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: _selectedBulan);
    }

    switch (_sortBy) {
      case 'tanggal_asc':
        return query.orderBy('tanggal', descending: false);
      case 'biaya_desc':
        return query.orderBy('estimasi_biaya_total', descending: true);
      case 'durasi_desc':
        return query.orderBy('total_jam_desimal', descending: true);
      case 'tanggal_desc':
      default:
        return query.orderBy('tanggal', descending: true);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDocs = _cachedDocs.where((doc) {
        final data = doc.data();
        
        if (_selectedFilter != 'semua' && data['status'] != _selectedFilter) {
          return false;
        }
        
        if (_selectedUrgensi != 'semua' && data['urgensi'] != _selectedUrgensi) {
          return false;
        }
        
        if (_selectedJenis != 'semua' && data['jenis_lembur'] != _selectedJenis) {
          return false;
        }
        
        if (_selectedLokasi != 'semua') {
          final lokasi = data['lokasi'] ?? {};
          if (_selectedLokasi == 'custom') {
            if (lokasi['is_outside_radius'] != true) return false;
          } else {
            if (lokasi['pilihan'] != _selectedLokasi) return false;
          }
        }
        
        if (_searchQuery.isNotEmpty) {
          final namaMitra = (data['nama_mitra'] ?? '').toString().toLowerCase();
          final namaPengawas = (data['nama_pengawas'] ?? '').toString().toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          
          if (!namaMitra.contains(query) && 
              !namaPengawas.contains(query) && 
              !groupId.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      _sortFilteredDocs();
    });
  }

  void _sortFilteredDocs() {
    _filteredDocs.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();
      
      switch (_sortBy) {
        case 'tanggal_asc':
          final tglA = (dataA['tanggal'] as Timestamp).toDate();
          final tglB = (dataB['tanggal'] as Timestamp).toDate();
          return tglA.compareTo(tglB);
        case 'biaya_desc':
          final biayaA = (dataA['estimasi_biaya_total'] ?? 0).toDouble();
          final biayaB = (dataB['estimasi_biaya_total'] ?? 0).toDouble();
          return biayaB.compareTo(biayaA);
        case 'durasi_desc':
          final durasiA = (dataA['total_jam_desimal'] ?? 0).toDouble();
          final durasiB = (dataB['total_jam_desimal'] ?? 0).toDouble();
          return durasiB.compareTo(durasiA);
        case 'tanggal_desc':
        default:
          final tglA = (dataA['tanggal'] as Timestamp).toDate();
          final tglB = (dataB['tanggal'] as Timestamp).toDate();
          return tglB.compareTo(tglA);
      }
    });
  }

  Future<Map<String, dynamic>> _getStatsData() async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');

      if (isSuperadmin) {
        // No filter
      } else if (isManager) {
        query = query.where('is_group_leader', isEqualTo: true);
        if (_selectedFungsi != 'semua' && _selectedFungsi.isNotEmpty) {
          query = query.where('pengawas_fungsi', isEqualTo: _selectedFungsi);
        }
      } else if (isPengawas) {
        query = query.where('pengawas_id', isEqualTo: _userId);
      } else if (isMitra) {
        query = query.where('mitra_ids', arrayContains: _userId);
      }

      if (_selectedBulan.isNotEmpty) {
        query = query.where('tahun_bulan', isEqualTo: _selectedBulan);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      int total = docs.length;
      int pending = docs.where((d) => d.data()['status'] == 'pending').length;
      int approved = docs.where((d) => d.data()['status'] == 'disetujui').length;
      int completed = docs.where((d) => d.data()['status'] == 'selesai').length;
      int rejected = docs.where((d) => d.data()['status'] == 'ditolak').length;
      int expired = docs.where((d) => d.data()['status'] == 'kadaluarsa').length;
      int needAbsensi = docs.where((d) => 
        d.data()['status'] == 'disetujui' && 
        d.data()['absensi_status'] != 'selesai'
      ).length;

      double totalJam = 0;
      double totalBiaya = 0;
      int totalMitra = 0;

      for (var doc in docs) {
        final data = doc.data();
        if (data['status'] == 'selesai') {
          totalJam += (data['total_jam_desimal'] ?? 0).toDouble();
          totalBiaya += (data['estimasi_biaya_total'] ?? 0).toDouble();
        }
        totalMitra += (data['total_mitra'] as int? ?? 1);
      }

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'rejected': rejected,
        'expired': expired,
        'needAbsensi': needAbsensi,
        'totalJam': totalJam,
        'totalBiaya': totalBiaya,
        'totalMitra': totalMitra,
      };
    } catch (e) {
      logger.e('Error getting stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'expired': 0,
        'needAbsensi': 0,
        'totalJam': 0,
        'totalBiaya': 0,
        'totalMitra': 0,
      };
    }
  }

  // ==================== UI BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F9FF),
      appBar: _buildAppBar(),
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
                            _buildQuickActions(),
                            _buildFilterSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildLemburList(),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastDocument = null;
      _hasMoreData = true;
      _isUsingCache = false;
      _cachedDocs.clear();
    });
    await _loadInitialData();
    await _checkExpiredOvertime();
  }

  // ==================== HEADER WIDGET ====================
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
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
                      'Halo,',
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRoleIcon(),
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRoleDisplayName(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _getStatsData(),
                    builder: (context, snapshot) {
                      final pendingCount = snapshot.data?['pending'] ?? 0;
                      final expiredCount = snapshot.data?['expired'] ?? 0;
                      return Text(
                        _getWelcomeMessage(pendingCount, expiredCount),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      );
                    },
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

  String _getRoleDisplayName() {
    if (isSuperadmin) return 'SUPERADMIN';
    if (isManager) return 'MANAGER';
    if (isPengawas) return 'PENGAWAS';
    if (isMitra) return 'MITRA';
    return 'USER';
  }

  IconData _getRoleIcon() {
    if (isSuperadmin) return Icons.admin_panel_settings;
    if (isManager) return Icons.manage_accounts;
    if (isPengawas) return Icons.supervisor_account;
    if (isMitra) return Icons.person;
    return Icons.person_outline;
  }

  String _getWelcomeMessage(int pendingCount, int expiredCount) {
    if (isSuperadmin) {
      return 'Anda memiliki akses penuh ke semua data lembur.';
    } else if (isManager) {
      return 'Manager - Fungsi ${_getFungsiLabel(_userFungsi)}. Menunggu persetujuan: $pendingCount';
    } else if (isPengawas) {
      if (expiredCount > 0) {
        return 'Ada $expiredCount jadwal yang kadaluarsa karena tidak diabsensi.';
      }
      return 'Pantau status pengajuan lembur Anda di sini.';
    } else if (isMitra) {
      if (expiredCount > 0) {
        return 'Ada $expiredCount jadwal lembur yang kadaluarsa. Segera absen sebelum batas waktu!';
      }
      return 'Lihat jadwal lembur dan lakukan absensi.';
    }
    return '';
  }

  AppBar _buildAppBar() {
    String title = 'Riwayat Lembur';
    if (isMitra) {
      title = 'Riwayat Lembur Saya';
    } else if (isPengawas) {
      title = 'Riwayat Pengajuan Saya';
    } else if (isManager) {
      title = 'Persetujuan & Riwayat';
    } else if (isSuperadmin) {
      title = 'Semua Riwayat Lembur';
    }

    return AppBar(
      title: Text(
        title,
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
      actions: _buildAppBarActions(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
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
      IconButton(
        icon: Icon(
          isGridView ? Icons.view_list : Icons.grid_view,
          color: Colors.white,
        ),
        onPressed: () => setState(() => isGridView = !isGridView),
      ),
      if (isSuperadmin || isManager)
        IconButton(
          icon: const Icon(Icons.download, color: Colors.white),
          onPressed: _showExportDialog,
        ),
    ];
  }

  Widget _buildFloatingActionButton() {
    if (!isPengawas) return const SizedBox();

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(context, '/ajukan-lembur').then((_) {
          _refreshData();
        });
      },
      backgroundColor: accentBlue,
      icon: const Icon(Icons.add),
      label: Text(
        'Ajukan Lembur',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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

  // ==================== STATS CARD ====================
  Widget _buildStatsCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStatsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatsCardSkeleton();
        }

        if (snapshot.hasError) {
          return _buildStatsCardSkeleton();
        }

        final stats = snapshot.data ?? {};

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
                  _buildStatItem('Total', stats['total'].toString(), Icons.work_history),
                  _buildStatItem('Pending', stats['pending'].toString(), Icons.pending),
                  _buildStatItem('Disetujui', stats['approved'].toString(), Icons.check_circle),
                  _buildStatItem('Selesai', stats['completed'].toString(), Icons.task_alt),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryStat(
                      'Ditolak',
                      stats['rejected'].toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildSecondaryStat(
                      'Kadaluarsa',
                      stats['expired'].toString(),
                      Icons.timer_off,
                      Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: _buildSecondaryStat(
                      'Perlu Absen',
                      stats['needAbsensi'].toString(),
                      Icons.camera_alt,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
              
              const Divider(color: Colors.white30, height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Jam',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${(stats['totalJam'] ?? 0).toStringAsFixed(1)} jam',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                          'Total Biaya',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _formatRupiah(stats['totalBiaya'] ?? 0),
                          style: GoogleFonts.poppins(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
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
                        '*Perhitungan biaya hanya untuk lembur yang sudah selesai (status Selesai)',
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
      },
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) => 
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
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

  Widget _buildSecondaryStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Aksi Cepat',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionButton(
                  'Semua',
                  Icons.list,
                  _selectedFilter == 'semua',
                  () => setState(() {
                    _selectedFilter = 'semua';
                    _applyFilters();
                  }),
                ),
                _buildQuickActionButton(
                  'Pending',
                  Icons.pending,
                  _selectedFilter == 'pending',
                  () => setState(() {
                    _selectedFilter = 'pending';
                    _applyFilters();
                  }),
                  color: Colors.orange,
                ),
                _buildQuickActionButton(
                  'Disetujui',
                  Icons.check_circle,
                  _selectedFilter == 'disetujui',
                  () => setState(() {
                    _selectedFilter = 'disetujui';
                    _applyFilters();
                  }),
                  color: Colors.green,
                ),
                _buildQuickActionButton(
                  'Kadaluarsa',
                  Icons.timer_off,
                  _selectedFilter == 'kadaluarsa',
                  () => setState(() {
                    _selectedFilter = 'kadaluarsa';
                    _applyFilters();
                  }),
                  color: Colors.grey,
                ),
                _buildQuickActionButton(
                  'Perlu Absen',
                  Icons.camera_alt,
                  false,
                  _showNeedAbsensiFilter,
                  color: Colors.blue,
                ),
                if (isSuperadmin || isManager)
                  _buildQuickActionButton(
                    'Export',
                    Icons.download,
                    false,
                    _showExportDialog,
                    color: Colors.purple,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected 
            ? (color ?? accentBlue) 
            : (color?.withValues(alpha: 0.1) ?? Colors.grey[100]),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : (color ?? Colors.grey[700]),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isSelected ? Colors.white : (color ?? Colors.grey[700]),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNeedAbsensiFilter() {
    setState(() {
      _selectedFilter = 'disetujui';
      _applyFilters();
    });
    _showInfoSnackbar('Menampilkan data yang perlu absensi');
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
                  'Status',
                  Icons.filter_alt,
                  _selectedFilter != 'semua',
                  () => _showFilterBottomSheet('status'),
                ),
                const SizedBox(width: 8),
                if (isSuperadmin || isManager)
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
                  'Urgensi',
                  Icons.priority_high,
                  _selectedUrgensi != 'semua',
                  () => _showFilterBottomSheet('urgensi'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Jenis',
                  Icons.work,
                  _selectedJenis != 'semua',
                  () => _showFilterBottomSheet('jenis'),
                ),
                const SizedBox(width: 8),
                _buildFilterChipWithIcon(
                  'Lokasi',
                  Icons.location_on,
                  _selectedLokasi != 'semua',
                  () => _showFilterBottomSheet('lokasi'),
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
                      if (_selectedFilter != 'semua')
                        _buildActiveFilterChip(
                          'Status: ${_getStatusLabel(_selectedFilter)}',
                          () => setState(() {
                            _selectedFilter = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_selectedFungsi != 'semua')
                        _buildActiveFilterChip(
                          'Fungsi: ${_getFungsiLabel(_selectedFungsi)}',
                          () => setState(() {
                            _selectedFungsi = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_selectedUrgensi != 'semua')
                        _buildActiveFilterChip(
                          'Urgensi: ${_getUrgensiLabel(_selectedUrgensi)}',
                          () => setState(() {
                            _selectedUrgensi = 'semua';
                            _applyFilters();
                          }),
                        ),
                      if (_selectedJenis != 'semua')
                        _buildActiveFilterChip(
                          'Jenis: ${_getJenisLemburLabel(_selectedJenis)}',
                          () => setState(() {
                            _selectedJenis = 'semua';
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
                      _buildActiveFilterChip(
                        'Bulan: ${_formatMonth(_selectedBulan)}',
                        () => setState(() {
                          _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
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
    return _selectedFilter != 'semua' ||
        _selectedFungsi != 'semua' ||
        _selectedUrgensi != 'semua' ||
        _selectedJenis != 'semua' ||
        _selectedLokasi != 'semua' ||
        _selectedBulan != DateFormat('yyyy-MM').format(DateTime.now());
  }

  void _resetAllFilters() {
    setState(() {
      _selectedFilter = 'semua';
      _selectedFungsi = isSuperadmin || isManager ? 'semua' : _userFungsi ?? '';
      _selectedUrgensi = 'semua';
      _selectedJenis = 'semua';
      _selectedLokasi = 'semua';
      _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
      _applyFilters();
    });
  }

  void _showFilterBottomSheet(String filterType) {
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
              
              if (filterType == 'status')
                ..._buildFilterListItems(statusList, (value) {
                  setState(() {
                    _selectedFilter = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'fungsi')
                ..._buildFilterListItems(fungsiList, (value) {
                  setState(() {
                    _selectedFungsi = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'urgensi')
                ..._buildFilterListItems(urgensiList, (value) {
                  setState(() {
                    _selectedUrgensi = value;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                }),
              
              if (filterType == 'jenis')
                ..._buildFilterListItems(jenisList, (value) {
                  setState(() {
                    _selectedJenis = value;
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
    return items.where((item) => item['value'] != 'semua').map((item) {
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

  String _getStatusLabel(String value) {
    final status = statusList.firstWhere(
      (s) => s['value'] == value,
      orElse: () => statusList[0],
    );
    return status['label'] as String;
  }

  String _getUrgensiLabel(String value) {
    final urgensi = urgensiList.firstWhere(
      (u) => u['value'] == value,
      orElse: () => urgensiList[1],
    );
    return urgensi['label'] as String;
  }

  String _getLokasiLabel(String value) {
    final lokasi = lokasiList.firstWhere(
      (l) => l['value'] == value,
      orElse: () => lokasiList[0],
    );
    return lokasi['label'] as String;
  }

  String _formatMonth(String yearMonth) {
    try {
      final date = DateTime.parse('$yearMonth-01');
      return DateFormat('MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return yearMonth;
    }
  }

  // ==================== MAIN LIST/GRID VIEW ====================
  Widget _buildLemburList() {
    if (_filteredDocs.isEmpty) {
      if (_cachedDocs.isEmpty && !_isUsingCache) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _buildOptimizedQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                child: _buildErrorState(snapshot.error.toString()),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            
            if (docs.isEmpty) {
              return SliverToBoxAdapter(child: _buildEmptyState());
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _cachedDocs = docs;
                _filteredDocs = _applyClientFiltersToList(docs);
                if (docs.isNotEmpty) {
                  _lastDocument = docs.last;
                }
                _hasMoreData = docs.length == _itemsPerPage;
                _isUsingCache = true;
              });
            });

            return _buildListFromDocs(_applyClientFiltersToList(docs));
          },
        );
      }
      
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return _buildListFromDocs(_filteredDocs);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyClientFiltersToList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      
      if (_selectedFilter != 'semua' && data['status'] != _selectedFilter) {
        return false;
      }
      
      if (_selectedUrgensi != 'semua' && data['urgensi'] != _selectedUrgensi) {
        return false;
      }
      
      if (_selectedJenis != 'semua' && data['jenis_lembur'] != _selectedJenis) {
        return false;
      }
      
      if (_selectedLokasi != 'semua') {
        final lokasi = data['lokasi'] ?? {};
        if (_selectedLokasi == 'custom') {
          if (lokasi['is_outside_radius'] != true) return false;
        } else {
          if (lokasi['pilihan'] != _selectedLokasi) return false;
        }
      }
      
      if (_searchQuery.isNotEmpty) {
        final namaMitra = (data['nama_mitra'] ?? '').toString().toLowerCase();
        final namaPengawas = (data['nama_pengawas'] ?? '').toString().toLowerCase();
        final groupId = (data['group_id'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        if (!namaMitra.contains(query) && 
            !namaPengawas.contains(query) && 
            !groupId.contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList()..sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();
      
      switch (_sortBy) {
        case 'tanggal_asc':
          final tglA = (dataA['tanggal'] as Timestamp).toDate();
          final tglB = (dataB['tanggal'] as Timestamp).toDate();
          return tglA.compareTo(tglB);
        case 'biaya_desc':
          final biayaA = (dataA['estimasi_biaya_total'] ?? 0).toDouble();
          final biayaB = (dataB['estimasi_biaya_total'] ?? 0).toDouble();
          return biayaB.compareTo(biayaA);
        case 'durasi_desc':
          final durasiA = (dataA['total_jam_desimal'] ?? 0).toDouble();
          final durasiB = (dataB['total_jam_desimal'] ?? 0).toDouble();
          return durasiB.compareTo(durasiA);
        case 'tanggal_desc':
        default:
          final tglA = (dataA['tanggal'] as Timestamp).toDate();
          final tglB = (dataB['tanggal'] as Timestamp).toDate();
          return tglB.compareTo(tglA);
      }
    });
  }

  SliverPadding _buildListFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _buildLemburGridCard(doc.id, data);
            },
            childCount: docs.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _buildLemburListCard(doc.id, data);
          },
          childCount: docs.length,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[200]),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: lightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 64,
                color: primaryBlue.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak ada data lembur',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada riwayat lembur yang ditemukan\nuntuk filter yang dipilih',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isPengawas)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/ajukan-lembur');
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajukan Lembur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
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

  Widget _buildLemburListCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final tanggal = (data['tanggal'] as Timestamp).toDate();
    final isGroup = data['is_multiple'] ?? false;
    final totalMitra = data['total_mitra'] ?? 1;
    final absensiStatus = data['absensi_status'] ?? 'belum_absen';
    final isNeedAbsensi = status == 'disetujui' && absensiStatus != 'selesai';
    final isExpired = status == 'kadaluarsa';
    final isWeekend = data['jenis_lembur'] == 'hari_libur';
    final isOverride = data['is_override'] ?? false;
    final lokasi = data['lokasi'] ?? {};
    final isOutside = lokasi['is_outside_radius'] ?? false;
    final urgensi = data['urgensi'] ?? 'normal';
    final isUrgent = urgensi == 'kritis' || urgensi == 'tinggi';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: primaryBlue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isExpired ? expiredColor : (isUrgent ? Colors.red : statusColor.withValues(alpha: 0.3)),
          width: isExpired ? 1 : (isUrgent ? 2 : 1),
        ),
      ),
      child: InkWell(
        onTap: () => _showLemburDetail(docId, data),
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
                      color: isExpired ? expiredColor.withValues(alpha: 0.2) : 
                          (isUrgent ? Colors.red.withValues(alpha: 0.2) : 
                          _getFungsiColor(data['pengawas_fungsi'] ?? '').withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: isGroup
                          ? Icon(isExpired ? Icons.timer_off : Icons.group, 
                                color: isExpired ? expiredColor : 
                                       (isUrgent ? Colors.red : 
                                       _getFungsiColor(data['pengawas_fungsi'] ?? '')), 
                                size: 28)
                          : Text(
                              _getInitials(data['nama_mitra'] ?? data['nama_pengawas'] ?? '?'),
                              style: GoogleFonts.poppins(
                                color: isExpired ? expiredColor : 
                                       (isUrgent ? Colors.red : 
                                       _getFungsiColor(data['pengawas_fungsi'] ?? '')),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                                isGroup ? 'Lembur Grup' : (data['nama_mitra'] ?? 'Unknown'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isExpired ? expiredColor : primaryBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUrgent && !isExpired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'URGENT',
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
                          '${_formatTanggal(tanggal)} • ${data['jam_mulai']} - ${data['jam_selesai']}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isGroup)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalMitra mitra',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: accentBlue,
                                fontWeight: FontWeight.w600,
                              ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(status),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isNeedAbsensi && !isExpired)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, size: 10, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                'BELUM ABSEN',
                                style: GoogleFonts.poppins(
                                  fontSize: 7,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.access_time,
                    '${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                    accentBlue,
                  ),
                  _buildInfoChip(
                    Icons.work,
                    _getJenisLemburLabel(data['jenis_lembur'] ?? 'hari_kerja'),
                    isWeekend ? Colors.purple : Colors.green,
                  ),
                  if (isOverride)
                    _buildInfoChip(
                      Icons.warning,
                      'Override',
                      Colors.orange,
                    ),
                  if (isOutside)
                    _buildInfoChip(
                      Icons.location_off,
                      'Luar Radius',
                      Colors.orange,
                    ),
                  if (absensiStatus == 'selesai')
                    _buildInfoChip(
                      Icons.check_circle,
                      'Sudah Absen',
                      Colors.green,
                    ),
                  if (isExpired)
                    _buildInfoChip(
                      Icons.timer_off,
                      'Kadaluarsa',
                      expiredColor,
                    ),
                  _buildInfoChip(
                    Icons.priority_high,
                    _getUrgensiLabel(urgensi),
                    _getUrgensiColor(urgensi),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.grey[100] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getLocationIcon(data),
                      size: 16,
                      color: _getLocationColor(data),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getLocationText(data),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
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
                        _formatRupiah((data['estimasi_biaya_total'] ?? 0).toDouble()),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? expiredColor : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  
                  if (data['approved_by_name'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'disetujui' ? Icons.check_circle : 
                            (status == 'kadaluarsa' ? Icons.timer_off : Icons.cancel),
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status == 'disetujui' ? 'Disetujui' : 
                            (status == 'kadaluarsa' ? 'Kadaluarsa' : 'Ditolak'),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (isNeedAbsensi && isMitra && !isExpired) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAbsensiDialog(docId, data),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Absen Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ],

              if (isExpired) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: expiredColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: expiredColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off, color: expiredColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Jadwal lembur ini sudah kadaluarsa karena tidak diabsensi hingga batas waktu.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: expiredColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isNeedAbsensi && isPengawas && !isExpired) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Menunggu absensi dari mitra. Anda akan mendapat notifikasi saat mitra sudah absen.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLemburGridCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final tanggal = (data['tanggal'] as Timestamp).toDate();
    final absensiStatus = data['absensi_status'] ?? 'belum_absen';
    final isNeedAbsensi = status == 'disetujui' && absensiStatus != 'selesai';
    final isExpired = status == 'kadaluarsa';
    final isUrgent = data['urgensi'] == 'kritis' || data['urgensi'] == 'tinggi';

    return Card(
      elevation: 3,
      shadowColor: primaryBlue.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isExpired ? expiredColor : (isUrgent ? Colors.red : statusColor.withValues(alpha: 0.3)),
          width: isExpired ? 1 : (isUrgent ? 2 : 1),
        ),
      ),
      child: InkWell(
        onTap: () => _showLemburDetail(docId, data),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(status),
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isNeedAbsensi && !isExpired) ...[
                    if (isMitra)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.blue),
                      ),
                    if (isPengawas)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time, size: 12, color: Colors.orange),
                      ),
                  ],
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: expiredColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.timer_off, size: 12, color: expiredColor),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getFungsiColor(data['pengawas_fungsi'] ?? '').withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getFungsiLabel(data['pengawas_fungsi'] ?? ''),
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    color: _getFungsiColor(data['pengawas_fungsi'] ?? ''),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _formatTanggalShort(tanggal),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isExpired ? expiredColor : primaryBlue,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                data['is_multiple'] == true
                    ? 'Grup (${data['total_mitra']} mitra)'
                    : (data['nama_mitra'] ?? 'Unknown'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isExpired ? expiredColor : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Text(
                'Pengawas: ${data['nama_pengawas'] ?? '-'}',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${data['jam_mulai']} - ${data['jam_selesai']}',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(Icons.timer, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: isExpired ? expiredColor : accentBlue,
                      fontWeight: FontWeight.w600,
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
                    _formatRupiahCompact((data['estimasi_biaya_total'] ?? 0).toDouble()),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? expiredColor : Colors.green[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              if (isUrgent && !isExpired)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 8, color: Colors.red),
                      const SizedBox(width: 2),
                      Text(
                        'URGENT',
                        style: GoogleFonts.poppins(
                          fontSize: 7,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
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

  // ==================== ABSENSI DIALOG ====================
  Future<void> _showAbsensiDialog(String docId, Map<String, dynamic> data) async {
    final isMultiple = data['is_multiple'] ?? false;
    final absensiStatus = data['absensi_status'] ?? 'belum_absen';
    final isAlreadyAbsen = absensiStatus == 'selesai';
    
    if (isAlreadyAbsen) {
      _showInfoSnackbar('Anda sudah melakukan absensi untuk lembur ini');
      return;
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return AbsensiDialog(
          docId: docId,
          data: data,
          isMultiple: isMultiple,
          isMitra: isMitra,
          userId: _userId,
          userName: _userName,
          userEmail: _userEmail,
          onSuccess: () {
            if (mounted) {
              _refreshData();
              _showSuccessSnackbar('Absensi berhasil direkam');
            }
          },
        );
      },
    );
  }

  // ==================== DETAIL VIEW ====================
  void _showLemburDetail(String docId, Map<String, dynamic> data) {
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
            return _LemburDetailContent(
              docId: docId,
              data: data,
              userRole: _userRole,
              userId: _userId,
              userName: _userName,
              userJabatan: _userJabatan,
              scrollController: scrollController,
              onStatusChanged: () {
                if (mounted) _refreshData();
              },
            );
          },
        );
      },
    );
  }

  // ==================== EXPORT FUNCTIONS (MOBILE ONLY) ====================
  
  Future<void> _exportToExcel() async {
    try {
      _showInfoSnackbar('Menyiapkan data untuk export...');

      final query = _buildOptimizedQuery();
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _showErrorSnackbar('Tidak ada data untuk diexport');
        return;
      }

      final filteredDocs = _applyClientFiltersToList(snapshot.docs);

      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['Lembur'];

      // Header
      sheet.appendRow([
        excel.TextCellValue('No'),
        excel.TextCellValue('Tanggal'),
        excel.TextCellValue('ID Group'),
        excel.TextCellValue('Nama Mitra'),
        excel.TextCellValue('Nama Pengawas'),
        excel.TextCellValue('Fungsi'),
        excel.TextCellValue('Jam Mulai'),
        excel.TextCellValue('Jam Selesai'),
        excel.TextCellValue('Durasi (Jam)'),
        excel.TextCellValue('Jenis'),
        excel.TextCellValue('Urgensi'),
        excel.TextCellValue('Status'),
        excel.TextCellValue('Lokasi'),
        excel.TextCellValue('Total Mitra'),
        excel.TextCellValue('Biaya per Mitra'),
        excel.TextCellValue('Total Biaya'),
        excel.TextCellValue('Absensi Status'),
        excel.TextCellValue('Alasan'),
        excel.TextCellValue('Catatan'),
        excel.TextCellValue('Approved By'),
        excel.TextCellValue('Approved At'),
        excel.TextCellValue('Created At'),
      ]);

      // Data
      for (var i = 0; i < filteredDocs.length; i++) {
        final doc = filteredDocs[i];
        final data = doc.data();
        final tanggal = (data['tanggal'] as Timestamp).toDate();
        final approvedAt = data['approved_at'] as Timestamp?;
        final createdAt = data['created_at'] as Timestamp?;

        sheet.appendRow([
          excel.TextCellValue((i + 1).toString()),
          excel.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(tanggal)),
          excel.TextCellValue(data['group_id'] ?? '-'),
          excel.TextCellValue(data['nama_mitra'] ?? (data['is_multiple'] == true ? 'Grup' : '-')),
          excel.TextCellValue(data['nama_pengawas'] ?? '-'),
          excel.TextCellValue(_getFungsiLabel(data['pengawas_fungsi'])),
          excel.TextCellValue(data['jam_mulai'] ?? '-'),
          excel.TextCellValue(data['jam_selesai'] ?? '-'),
          excel.TextCellValue((data['total_jam_desimal'] ?? 0).toString()),
          excel.TextCellValue(_getJenisLemburLabel(data['jenis_lembur'] ?? 'hari_kerja')),
          excel.TextCellValue(_getUrgensiLabel(data['urgensi'] ?? 'normal')),
          excel.TextCellValue(_getStatusText(data['status'] ?? 'pending')),
          excel.TextCellValue(_getLocationText(data)),
          excel.TextCellValue((data['total_mitra'] ?? 1).toString()),
          excel.TextCellValue(_formatRupiah((data['estimasi_biaya_per_mitra'] ?? 0).toDouble())),
          excel.TextCellValue(_formatRupiah((data['estimasi_biaya_total'] ?? 0).toDouble())),
          excel.TextCellValue(data['absensi_status'] ?? 'belum_absen'),
          excel.TextCellValue(data['alasan'] ?? '-'),
          excel.TextCellValue(data['catatan_tambahan'] ?? '-'),
          excel.TextCellValue(data['approved_by_name'] ?? '-'),
          excel.TextCellValue(approvedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(approvedAt.toDate()) : '-'),
          excel.TextCellValue(createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate()) : '-'),
        ]);
      }

      // Simpan ke file temporary dan share
      final dir = await getTemporaryDirectory();
      final fileName = 'Lembur_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excelFile.encode()!);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Data Lembur',
      );

      _showSuccessSnackbar('File Excel berhasil dibuat');
    } catch (e) {
      logger.e('Error exporting to Excel: $e');
      _showErrorSnackbar('Gagal export ke Excel: ${e.toString()}');
    }
  }

  Future<void> _exportToPDF() async {
    try {
      _showInfoSnackbar('Menyiapkan PDF...');

      final query = _buildOptimizedQuery();
      final snapshot = await query.get();
      final filteredDocs = _applyClientFiltersToList(snapshot.docs);

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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'Laporan Lembur',
              style: pw.TextStyle(
                font: boldTtf,
                fontSize: 24,
              ),
            ),
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
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Periode: ${_formatMonth(_selectedBulan)}',
                    style: pw.TextStyle(font: ttf, fontSize: 12),
                  ),
                  pw.Text(
                    'Total Data: ${filteredDocs.length}',
                    style: pw.TextStyle(font: ttf, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.Table.fromTextArray(
              headers: [
                'No',
                'Tanggal',
                'Mitra',
                'Pengawas',
                'Durasi',
                'Status',
                'Biaya',
              ],
              data: List.generate(filteredDocs.length, (index) {
                final doc = filteredDocs[index];
                final data = doc.data();
                final tanggal = (data['tanggal'] as Timestamp).toDate();
                
                return [
                  (index + 1).toString(),
                  DateFormat('dd/MM/yyyy').format(tanggal),
                  data['is_multiple'] == true 
                      ? 'Grup (${data['total_mitra']})' 
                      : (data['nama_mitra'] ?? '-'),
                  data['nama_pengawas'] ?? '-',
                  '${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                  _getStatusText(data['status'] ?? 'pending'),
                  _formatRupiah((data['estimasi_biaya_total'] ?? 0).toDouble()),
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
              cellHeight: 30,
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
                      pw.Text(
                        'Total Lembur: ${filteredDocs.length}',
                        style: pw.TextStyle(font: ttf),
                      ),
                      pw.Text(
                        'Total Jam: ${_calculateTotalJam(filteredDocs).toStringAsFixed(1)} jam',
                        style: pw.TextStyle(font: ttf),
                      ),
                      pw.Text(
                        'Total Biaya: ${_formatRupiah(_calculateTotalBiaya(filteredDocs))}',
                        style: pw.TextStyle(font: ttf),
                      ),
                      pw.Text(
                        '*Perhitungan hanya untuk lembur dengan status Selesai',
                        style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName = 'Lembur_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Lembur',
      );

      _showSuccessSnackbar('File PDF berhasil dibuat');
    } catch (e) {
      logger.e('Error exporting to PDF: $e');
      _showErrorSnackbar('Gagal export ke PDF: ${e.toString()}');
    }
  }

  double _calculateTotalJam(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double total = 0;
    for (var doc in docs) {
      final data = doc.data();
      if (data['status'] == 'selesai') {
        total += (data['total_jam_desimal'] ?? 0).toDouble();
      }
    }
    return total;
  }

  double _calculateTotalBiaya(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double total = 0;
    for (var doc in docs) {
      final data = doc.data();
      if (data['status'] == 'selesai') {
        total += (data['estimasi_biaya_total'] ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<void> _printData() async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();
          
          final query = _buildOptimizedQuery();
          final snapshot = await query.get();
          final filteredDocs = _applyClientFiltersToList(snapshot.docs);

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              build: (context) => [
                pw.Text('Laporan Lembur', style: const pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 20),
                pw.Text('Total Data: ${filteredDocs.length}'),
                pw.Text('*Perhitungan hanya untuk lembur dengan status Selesai'),
              ],
            ),
          );
          return pdf.save();
        },
      );
    } catch (e) {
      _showErrorSnackbar('Gagal mencetak: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  Color _getStatusColor(String status) {
    switch (status) {
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'selesai':
        return Colors.blue;
      case 'kadaluarsa':
        return expiredColor;
      case 'dibatalkan':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      case 'selesai':
        return 'Selesai';
      case 'kadaluarsa':
        return 'Kadaluarsa';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return const Color(0xFF1976D2);
      case 'lab':
        return const Color(0xFF4CAF50);
      case 'maintenance':
        return const Color(0xFFFF9800);
      case 'hsse':
        return const Color(0xFF9C27B0);
      case 'gpr':
        return const Color(0xFFF44336);
      case 'bs':
        return const Color(0xFF795548);
      default:
        return primaryBlue;
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

  String _getJenisLemburLabel(String jenis) {
    switch (jenis) {
      case 'hari_kerja':
        return 'Hari Kerja';
      case 'hari_libur':
        return 'Hari Libur';
      default:
        return jenis;
    }
  }

  IconData _getLocationIcon(Map<String, dynamic> data) {
    final lokasi = data['lokasi'] ?? {};
    final pilihan = lokasi['pilihan'] ?? 'kantor';

    if (pilihan == 'kantor') return Icons.business;
    if (pilihan == 'proyek') return Icons.location_city;
    return lokasi['is_outside_radius'] == true ? Icons.warning : Icons.location_on;
  }

  Color _getLocationColor(Map<String, dynamic> data) {
    final lokasi = data['lokasi'] ?? {};
    if (lokasi['is_outside_radius'] == true) return Colors.orange;
    return accentBlue;
  }

  String _getLocationText(Map<String, dynamic> data) {
    final lokasi = data['lokasi'] ?? {};
    final pilihan = lokasi['pilihan'] ?? 'kantor';

    if (pilihan == 'kantor') return 'Kantor PGE';
    if (pilihan == 'proyek') return lokasi['proyek'] ?? 'Proyek';
    return lokasi['is_outside_radius'] == true ? 'Luar Radius Kantor' : 'Dalam Radius Kantor';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatTanggal(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  String _formatTanggalShort(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
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

  // ==================== DIALOGS ====================

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: OvertimeSearchDelegate(
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
                  
                  Text('Status', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: statusList.map((item) {
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: _selectedFilter == item['value'],
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? item['value'] as String : 'semua';
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
                  
                  const SizedBox(height: 16),
                  
                  Text('Jenis Lembur', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: jenisList.map((item) {
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: _selectedJenis == item['value'],
                        onSelected: (selected) {
                          setState(() {
                            _selectedJenis = selected ? item['value'] as String : 'semua';
                          });
                        },
                        selectedColor: (item['color'] as Color).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                      );
                    }).toList(),
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

// ==================== ABSENSI DIALOG WIDGET ====================
class AbsensiDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isMultiple;
  final bool isMitra;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final VoidCallback onSuccess;

  const AbsensiDialog({
    super.key,
    required this.docId,
    required this.data,
    required this.isMultiple,
    required this.isMitra,
    this.userId,
    this.userName,
    this.userEmail,
    required this.onSuccess,
  });

  @override
  State<AbsensiDialog> createState() => _AbsensiDialogState();
}

class _AbsensiDialogState extends State<AbsensiDialog> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? _imageFile;
  XFile? _pickedFile;
  bool _isUploading = false;
  String? _uploadProgress;
  double _uploadProgressValue = 0;
  late AnimationController _pulseAnimation;

  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tanggal = (widget.data['tanggal'] as Timestamp).toDate();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
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

          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: accentBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Absensi Lembur',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    Text(
                      widget.isMultiple ? 'Lembur Grup' : 'Lembur Individual',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal),
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.data['jam_mulai']} - ${widget.data['jam_selesai']}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getLocationText(widget.data['lokasi']),
                        style: GoogleFonts.poppins(fontSize: 11),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, size: 20, color: accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isMultiple
                        ? 'Anda adalah bagian dari lembur grup. Setelah semua mitra absen, pengawas akan mendapat notifikasi.'
                        : 'Ambil foto selfie dengan latar belakang lokasi kerja sebagai bukti kehadiran.',
                    style: GoogleFonts.poppins(fontSize: 11, color: primaryBlue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_imageFile != null)
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _imageFile = null;
                        _pickedFile = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _takePhoto,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentBlue.withValues(alpha: 0.3 + _pulseAnimation.value * 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: accentBlue.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap untuk mengambil foto',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pastikan wajah dan lokasi terlihat jelas',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          if (_isUploading)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _uploadProgressValue,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                ),
                const SizedBox(height: 8),
                Text(
                  _uploadProgress ?? 'Mengupload...',
                  style: GoogleFonts.poppins(fontSize: 11, color: primaryBlue),
                ),
              ],
            ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _takePhoto,
                  icon: const Icon(Icons.camera),
                  label: const Text('Ambil Foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentBlue,
                    side: BorderSide(color: accentBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _imageFile == null || _isUploading ? null : _uploadAbsensi,
                  icon: const Icon(Icons.upload),
                  label: const Text('Kirim'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _getLocationText(Map<String, dynamic>? lokasi) {
    if (lokasi == null) return 'Kantor PGE';
    final pilihan = lokasi['pilihan'] ?? 'kantor';
    
    if (pilihan == 'kantor') return 'Kantor PGE';
    if (pilihan == 'proyek') return lokasi['proyek'] ?? 'Proyek';
    return lokasi['alamat'] ?? 'Lokasi Lain';
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedFile = pickedFile;
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAbsensi() async {
    if (_pickedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 'Mempersiapkan upload...';
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = widget.userId ?? 'unknown';
      final docId = widget.docId;
      final fileName = 'absensi/${widget.docId}_${userId}_$timestamp.jpg';

      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(File(_pickedFile!.path));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          _uploadProgressValue = progress;
          _uploadProgress = 'Mengupload ${(progress * 100).toStringAsFixed(0)}%';
        });
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      setState(() {
        _uploadProgress = 'Menyimpan data...';
      });

      final batch = _firestore.batch();

      final lemburRef = _firestore.collection('lembur').doc(docId);
      batch.update(lemburRef, {
        'absensi_status': 'selesai',
        'absensi_foto_url': downloadUrl,
        'absensi_waktu': FieldValue.serverTimestamp(),
        'absensi_oleh': userId,
        'absensi_nama': widget.userName,
        'absensi_email': widget.userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final absensiRef = _firestore.collection('absensi').doc();
      batch.set(absensiRef, {
        'lembur_id': docId,
        'group_id': widget.data['group_id'],
        'user_id': userId,
        'user_name': widget.userName,
        'user_email': widget.userEmail,
        'foto_url': downloadUrl,
        'waktu': FieldValue.serverTimestamp(),
        'lokasi': widget.data['lokasi'],
        'tanggal_lembur': widget.data['tanggal'],
        'is_multiple': widget.isMultiple,
        'metadata': {
          'device_info': 'Mobile App',
          'timestamp': timestamp,
        }
      });

      await batch.commit();

      // Kirim notifikasi ke pengawas dengan status progres
      if (widget.data['pengawas_id'] != null) {
        if (widget.isMultiple) {
          final absensiSnapshot = await _firestore
              .collection('absensi')
              .where('group_id', isEqualTo: widget.data['group_id'])
              .get();
          
          final totalMitra = widget.data['total_mitra'] ?? 1;
          final sudahAbsen = absensiSnapshot.docs.length;
          
          if (sudahAbsen >= totalMitra) {
            await _firestore.collection('notifications').add({
              'userId': widget.data['pengawas_id'],
              'title': '✅ Semua Mitra Sudah Absen',
              'body': 'Semua mitra telah melakukan absensi untuk lembur grup.',
              'type': 'all_mitra_absen',
              'data': {
                'lembur_id': docId,
                'group_id': widget.data['group_id'],
                'total_mitra': totalMitra,
              },
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            await _firestore.collection('notifications').add({
              'userId': widget.data['pengawas_id'],
              'title': '📸 Mitra Melakukan Absensi',
              'body': '${widget.userName} telah melakukan absensi. ($sudahAbsen/$totalMitra)',
              'type': 'mitra_absen',
              'data': {
                'lembur_id': docId,
                'group_id': widget.data['group_id'],
                'mitra_name': widget.userName,
                'progress': '$sudahAbsen/$totalMitra',
              },
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          await _firestore.collection('notifications').add({
            'userId': widget.data['pengawas_id'],
            'title': '📸 Absensi Lembur',
            'body': '${widget.userName} telah melakukan absensi.',
            'type': 'absensi_completed',
            'data': {
              'lembur_id': docId,
              'group_id': widget.data['group_id'],
              'mitra_name': widget.userName,
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ==================== DETAIL CONTENT WIDGET ====================
class _LemburDetailContent extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String? userRole;
  final String? userId;
  final String? userName;
  final String? userJabatan;
  final ScrollController scrollController;
  final VoidCallback onStatusChanged;

  const _LemburDetailContent({
    required this.docId,
    required this.data,
    this.userRole,
    this.userId,
    this.userName,
    this.userJabatan,
    required this.scrollController,
    required this.onStatusChanged,
  });

  @override
  State<_LemburDetailContent> createState() => __LemburDetailContentState();
}

class __LemburDetailContentState extends State<_LemburDetailContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isSuperadmin => widget.userRole == 'superadmin';
  bool get isManager => widget.userRole == 'manager';
  bool get isPengawas => widget.userRole == 'pengawas';
  bool get isMitra => widget.userRole == 'mitra';

  bool _canApprove = false;
  bool _isSubmitting = false;
  bool _isLoadingAbsensi = false;
  List<Map<String, dynamic>> _riwayatAbsensi = [];

  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);
  final Color expiredColor = const Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _checkApprovalPermission();
    _loadRiwayatAbsensi();
  }

  void _checkApprovalPermission() {
    if ((isManager || isSuperadmin) && widget.data['status'] == 'pending') {
      _canApprove = true;
    }
  }

  Future<void> _loadRiwayatAbsensi() async {
    if (!mounted) return;
    setState(() => _isLoadingAbsensi = true);

    try {
      final groupId = widget.data['group_id'];
      final snapshot = await _firestore
          .collection('absensi')
          .where('group_id', isEqualTo: groupId)
          .orderBy('waktu', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _riwayatAbsensi = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          _isLoadingAbsensi = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading absensi: $e');
      if (mounted) setState(() => _isLoadingAbsensi = false);
    }
  }

  bool _isCurrentUserSudahAbsen() {
    if (!isMitra) return false;
    return _riwayatAbsensi.any((a) => a['user_id'] == widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.data['status'] ?? 'pending';
    final statusColor = _getStatusColor(currentStatus);
    final tanggal = (widget.data['tanggal'] as Timestamp).toDate();
    final lokasi = widget.data['lokasi'] ?? {};
    final absensiStatus = widget.data['absensi_status'] ?? 'belum_absen';
    final isNeedAbsensi = currentStatus == 'disetujui' && absensiStatus != 'selesai';
    final isExpired = currentStatus == 'kadaluarsa';
    final isMultiple = widget.data['is_multiple'] ?? false;
    final totalMitra = widget.data['total_mitra'] ?? 1;
    final isUrgent = widget.data['urgensi'] == 'kritis' || widget.data['urgensi'] == 'tinggi';

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
                    color: _getFungsiColor(widget.data['pengawas_fungsi'] ?? '').withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.data['is_multiple'] == true ? Icons.group : Icons.person,
                    color: isExpired ? expiredColor : _getFungsiColor(widget.data['pengawas_fungsi'] ?? ''),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data['is_multiple'] == true
                            ? 'Lembur Grup'
                            : 'Lembur Individual',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? expiredColor : primaryBlue,
                        ),
                      ),
                      Text(
                        'ID: ${widget.docId.substring(0, 8)}...',
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _getStatusText(currentStatus),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUrgent && !isExpired)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'URGENT',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
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
                if (isMitra && _isCurrentUserSudahAbsen())
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anda sudah melakukan absensi',
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isExpired)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: expiredColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: expiredColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_off, color: expiredColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jadwal lembur ini sudah kadaluarsa karena tidak diabsensi hingga batas waktu.',
                            style: GoogleFonts.poppins(
                              color: expiredColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildStatusTimeline(currentStatus),
                const SizedBox(height: 20),

                _buildPengawasInfo(),
                const SizedBox(height: 16),

                if (isMultiple) _buildMitraList(totalMitra),
                const SizedBox(height: 16),

                _buildWaktuDetail(),
                const SizedBox(height: 16),

                _buildLokasiDetail(lokasi),
                const SizedBox(height: 16),

                _buildAlasanDetail(),
                const SizedBox(height: 16),

                _buildBiayaDetail(),
                const SizedBox(height: 16),

                if (widget.data['rate_snapshot'] != null) 
                  _buildRateSnapshot(),
                const SizedBox(height: 16),

                if (widget.data['approved_by'] != null) 
                  _buildApprovalInfo(),
                const SizedBox(height: 16),

                _buildRiwayatAbsensi(),
                const SizedBox(height: 16),

                _buildMetadata(),
                const SizedBox(height: 32),
              ],
            ),
          ),

          if (_canApprove) _buildApprovalButtons(),
          if (isNeedAbsensi && isMitra && !_isCurrentUserSudahAbsen() && !isExpired) _buildAbsensiButton(),
          if (isNeedAbsensi && isPengawas && !isExpired) _buildAbsensiReminderForPengawas(),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final List<Map<String, dynamic>> timelineSteps = [
      {
        'status': 'pending',
        'label': 'Diajukan',
        'time': widget.data['created_at'],
        'icon': Icons.send,
        'completed': true,
      },
      {
        'status': 'disetujui',
        'label': 'Disetujui',
        'time': widget.data['approved_at'],
        'icon': Icons.check_circle,
        'completed': currentStatus == 'disetujui' || currentStatus == 'selesai',
      },
      {
        'status': 'absensi',
        'label': isMitra ? 'Absensi' : 'Menunggu Absen Mitra',
        'time': widget.data['absensi_waktu'],
        'icon': isMitra ? Icons.camera_alt : Icons.access_time,
        'completed': widget.data['absensi_status'] == 'selesai',
      },
      {
        'status': 'selesai',
        'label': 'Selesai',
        'time': widget.data['completed_at'],
        'icon': Icons.task_alt,
        'completed': currentStatus == 'selesai',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: timelineSteps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = step['completed'] as bool;
          final isLast = index == timelineSteps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.grey[300],
                          shape: BoxShape.circle,
                          border: isCompleted ? null : Border.all(color: Colors.grey[400]!),
                        ),
                        child: Icon(
                          step['icon'] as IconData,
                          color: isCompleted ? Colors.white : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: isCompleted ? Colors.green : Colors.grey,
                          fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (step['time'] != null)
                        Text(
                          _formatTimestamp(step['time']),
                          style: GoogleFonts.poppins(
                            fontSize: 7,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? Colors.green : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPengawasInfo() {
    return _buildDetailSection('👤 Informasi Pengawas', Icons.person, Colors.blue, [
      _buildDetailRow('Nama', widget.data['nama_pengawas'] ?? '-'),
      _buildDetailRow('Fungsi', _getFungsiLabel(widget.data['pengawas_fungsi'] ?? '')),
      _buildDetailRow('ID', widget.data['pengawas_id'] ?? '-'),
      _buildDetailRow('Email', widget.data['email_pengawas'] ?? '-'),
      _buildDetailRow('No. HP', widget.data['no_hp_pengawas'] ?? '-'),
    ]);
  }

  Widget _buildMitraList(int totalMitra) {
    final mitraIds = widget.data['mitra_ids'] as List? ?? [];
    final mitraDetails = widget.data['mitra_details'] as List? ?? [];

    return _buildDetailSection('👥 Daftar Mitra ($totalMitra)', Icons.people, Colors.orange, [
      ...List.generate(mitraDetails.length, (index) {
        final mitra = mitraDetails[index] as Map<String, dynamic>? ?? {};
        
        final sudahAbsen = _riwayatAbsensi.any((a) => a['user_id'] == mitra['id']);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sudahAbsen ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getFungsiColor(mitra['fungsi'] ?? '').withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(mitra['nama'] ?? 'M'),
                        style: GoogleFonts.poppins(
                          color: _getFungsiColor(mitra['fungsi'] ?? ''),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mitra['nama'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _getFungsiLabel(mitra['fungsi']),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sudahAbsen)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 10, color: Colors.green),
                          const SizedBox(width: 2),
                          Text(
                            'Sudah',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mitra['no_hp'] ?? '-',
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.email, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mitra['email'] ?? '-',
                      style: GoogleFonts.poppins(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      if (mitraDetails.isEmpty)
        ...List.generate(
          mitraIds.length.clamp(0, 5).toInt(),
          (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mitra ID: ${mitraIds[index]}',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      if (mitraIds.length > 5)
        Text(
          '... dan ${mitraIds.length - 5} mitra lainnya',
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
        ),
    ]);
  }

  Widget _buildWaktuDetail() {
    final tanggal = (widget.data['tanggal'] as Timestamp).toDate();
    return _buildDetailSection('⏰ Detail Waktu', Icons.access_time, Colors.green, [
      _buildDetailRow('Tanggal', _formatTanggal(tanggal)),
      _buildDetailRow('Jam Mulai', widget.data['jam_mulai'] ?? '-'),
      _buildDetailRow('Jam Selesai', widget.data['jam_selesai'] ?? '-'),
      _buildDetailRow('Durasi', '${_safeDouble(widget.data['total_jam_desimal']).toStringAsFixed(1)} jam'),
      _buildDetailRow('Jenis', _getJenisLemburLabel(widget.data['jenis_lembur'] ?? 'hari_kerja')),
      _buildDetailRow('Tahun Bulan', widget.data['tahun_bulan'] ?? '-'),
    ]);
  }

  Widget _buildLokasiDetail(Map<String, dynamic> lokasi) {
    final isOutside = lokasi['is_outside_radius'] ?? false;
    final jarak = (lokasi['distance_from_kantor'] as num?)?.toDouble() ?? 0;
    final pilihan = lokasi['pilihan'] ?? 'kantor';
    final alamat = lokasi['alamat'] ?? '-';
    final latitude = lokasi['latitude'];
    final longitude = lokasi['longitude'];
    final source = lokasi['source'] ?? '-';

    return _buildDetailSection('📍 Detail Lokasi', Icons.location_on, Colors.purple, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildDetailRow('Pilihan', _getLokasiPilihanLabel(pilihan)),
            if (pilihan == 'proyek' && lokasi['proyek'] != null)
              _buildDetailRow('Proyek', lokasi['proyek'] as String),
            _buildDetailRow('Alamat', alamat, isLong: true),
            if (latitude != null && longitude != null)
              _buildDetailRow('Koordinat', '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'),
            _buildDetailRow('Sumber', source.toUpperCase()),
            if (jarak > 0)
              _buildDetailRow('Jarak', '${(jarak / 1000).toStringAsFixed(2)} km dari kantor'),
            _buildDetailRow('Status', isOutside ? 'Luar Radius' : 'Dalam Radius',
                color: isOutside ? Colors.orange : Colors.green),
          ],
        ),
      ),
    ]);
  }

  String _getLokasiPilihanLabel(String pilihan) {
    switch (pilihan) {
      case 'kantor':
        return 'Kantor PGE';
      case 'proyek':
        return 'Lokasi Proyek';
      case 'custom':
        return 'Lokasi Lain';
      default:
        return pilihan;
    }
  }

  Widget _buildAlasanDetail() {
    return _buildDetailSection('📝 Alasan & Catatan', Icons.description, Colors.teal, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildDetailRow('Alasan', widget.data['alasan'] ?? '-', isLong: true),
            if (widget.data['catatan_tambahan']?.toString().isNotEmpty == true)
              _buildDetailRow('Catatan', widget.data['catatan_tambahan'].toString(), isLong: true),
            _buildDetailRow('Urgensi', _getUrgensiLabel(widget.data['urgensi'] ?? 'normal'),
                color: _getUrgensiColor(widget.data['urgensi'] ?? 'normal')),
            if (widget.data['is_override'] == true)
              _buildDetailRow('Override', 'Ya (Melebihi batas)', color: Colors.orange),
          ],
        ),
      ),
    ]);
  }

  Widget _buildBiayaDetail() {
    final biayaPerMitra = _safeDouble(widget.data['estimasi_biaya_per_mitra']);
    final biayaTotal = _safeDouble(widget.data['estimasi_biaya_total']);
    final totalMitra = widget.data['total_mitra'] ?? 1;
    final jamLembur = _safeDouble(widget.data['total_jam_desimal']);
    final jenisLembur = widget.data['jenis_lembur'] ?? 'hari_kerja';
    final isWeekend = jenisLembur == 'hari_libur';

    double ratePerJam = 0;
    double jamPertama = 0;
    double jamBerikutnya = 0;

    if (widget.data['rate_snapshot'] != null) {
      final rates = widget.data['rate_snapshot'] as Map<String, dynamic>;
      ratePerJam = _safeDouble(rates['rate_per_hour']);

      if (isWeekend) {
        if (jamLembur <= 8) {
          jamPertama = jamLembur * 2;
        } else if (jamLembur <= 9) {
          jamPertama = 8 * 2;
          jamBerikutnya = 1 * 3;
        } else {
          jamPertama = 8 * 2;
          jamBerikutnya = 1 * 3 + (jamLembur - 9) * 4;
        }
      } else {
        if (jamLembur <= 1) {
          jamPertama = jamLembur * 1.5;
        } else {
          jamPertama = 1 * 1.5;
          jamBerikutnya = (jamLembur - 1) * 2;
        }
      }
    }

    return _buildDetailSection('💰 Rincian Biaya', Icons.attach_money, Colors.green, [
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
            _buildDetailRow('Rate per Jam', _formatRupiah(ratePerJam), textColor: Colors.white70),
            if (jamPertama > 0)
              _buildDetailRow('Jam Pertama', '${jamPertama.toStringAsFixed(1)}x', textColor: Colors.white70),
            if (jamBerikutnya > 0)
              _buildDetailRow('Jam Berikutnya', '${jamBerikutnya.toStringAsFixed(1)}x', textColor: Colors.white70),
            const Divider(color: Colors.white30, height: 16),
            _buildDetailRow('Biaya per Mitra', _formatRupiah(biayaPerMitra), 
                textColor: Colors.white, isBold: true),
            if (totalMitra > 1) ...[
              _buildDetailRow('Jumlah Mitra', '$totalMitra orang', textColor: Colors.white70),
              const Divider(color: Colors.white30, height: 16),
              _buildDetailRow('Total Biaya', _formatRupiah(biayaTotal),
                  textColor: Colors.amber, isBold: true),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _buildRateSnapshot() {
    final rates = widget.data['rate_snapshot'] as Map<String, dynamic>;
    final ratePerHour = _safeDouble(rates['rate_per_hour']);
    final baseSalary = _safeDouble(rates['base_salary']);
    final lastUpdated = rates['last_updated'] as Timestamp?;
    final updatedBy = rates['updated_by'] ?? '-';

    return _buildDetailSection('💵 Tarif Saat Pengajuan', Icons.lock_clock, Colors.grey, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildDetailRow('Gaji Pokok', _formatRupiah(baseSalary)),
            _buildDetailRow('Rate per Jam', _formatRupiah(ratePerHour)),
            if (rates['weekday_rate'] != null) ...[
              const Divider(height: 12),
              Text('🏢 Hari Kerja:',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _buildDetailRow('Jam 1',
                  '${((rates['weekday_rate'] as Map)['first_hour_multiplier'] ?? 1.5)}x'),
              _buildDetailRow('Jam 2+',
                  '${((rates['weekday_rate'] as Map)['next_hours_multiplier'] ?? 2.0)}x'),
            ],
            if (rates['holiday_rate'] != null) ...[
              const Divider(height: 12),
              Text('🎉 Hari Libur:',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _buildDetailRow('8 jam pertama',
                  '${((rates['holiday_rate'] as Map)['first_8_hours_multiplier'] ?? 2.0)}x'),
              _buildDetailRow('Jam ke-9',
                  '${((rates['holiday_rate'] as Map)['ninth_hour_multiplier'] ?? 3.0)}x'),
              _buildDetailRow('Jam ke-10+',
                  '${((rates['holiday_rate'] as Map)['tenth_plus_multiplier'] ?? 4.0)}x'),
            ],
            const Divider(height: 12),
            _buildDetailRow('Terakhir Update', 
                lastUpdated != null ? _formatTimestamp(lastUpdated) : '-'),
            _buildDetailRow('Diupdate oleh', updatedBy),
          ],
        ),
      ),
    ]);
  }

  Widget _buildApprovalInfo() {
    final approvedAt = widget.data['approved_at'] as Timestamp?;
    final approvedBy = widget.data['approved_by_name'] ?? widget.data['approved_by'] ?? '-';
    final approvalNote = widget.data['approval_note'] ?? widget.data['approved_notes'];
    
    return _buildDetailSection('✅ Informasi Persetujuan', Icons.verified, Colors.green, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            _buildDetailRow('Disetujui/Ditolak oleh', approvedBy as String),
            if (approvalNote != null && approvalNote.toString().isNotEmpty)
              _buildDetailRow('Catatan', approvalNote.toString(), isLong: true),
            if (approvedAt != null) _buildDetailRow('Waktu', _formatTimestamp(approvedAt)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildRiwayatAbsensi() {
    if (_isLoadingAbsensi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_riwayatAbsensi.isEmpty) {
      return const SizedBox();
    }

    return _buildDetailSection('📸 Riwayat Absensi', Icons.camera_alt, Colors.blue, 
      _riwayatAbsensi.map((absensi) {
        final waktu = absensi['waktu'] as Timestamp?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(absensi['foto_url'] as String),
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      absensi['user_name'] ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      waktu != null ? _formatTimestamp(waktu) : '-',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showFotoDialog(absensi['foto_url'] as String),
              ),
            ],
          ),
        );
      }).toList(),
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
                child: Image.network(
                  fotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: Text('Gagal memuat foto')),
                    );
                  },
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

  Widget _buildMetadata() {
    final createdAt = widget.data['created_at'] as Timestamp?;
    final updatedAt = widget.data['updated_at'] as Timestamp?;

    return _buildDetailSection('📋 Metadata', Icons.info, Colors.grey, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildDetailRow('Dibuat pada', _formatTimestamp(createdAt)),
            _buildDetailRow('Terakhir update', _formatTimestamp(updatedAt)),
            _buildDetailRow('Group ID', widget.data['group_id'] ?? '-'),
            _buildDetailRow('Dibuat oleh', widget.data['created_by'] ?? '-'),
          ],
        ),
      ),
    ]);
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

  Widget _buildApprovalButtons() {
    final TextEditingController noteController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => _rejectOvertime(noteController),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('TOLAK'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _approveOvertime,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text('SETUJUI'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsensiButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          final screenState = context.findAncestorStateOfType<_OvertimeHistoryScreenState>();
          screenState?._showAbsensiDialog(widget.docId, widget.data);
        },
        icon: const Icon(Icons.camera_alt, size: 20),
        label: const Text('ABSENSI SEKARANG'),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildAbsensiReminderForPengawas() {
    final totalMitra = widget.data['total_mitra'] ?? 1;
    final sudahAbsen = _riwayatAbsensi.length;
    final belumAbsen = totalMitra - sudahAbsen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status Absensi Mitra',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sudah Absen: $sudahAbsen/$totalMitra',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                    Text(
                      '${((sudahAbsen / totalMitra) * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: sudahAbsen / totalMitra,
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                const SizedBox(height: 12),
                if (belumAbsen > 0)
                  Text(
                    'Menunggu $belumAbsen mitra melakukan absensi. Anda akan mendapat notifikasi saat semua mitra sudah absen.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.orange[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (belumAbsen == 0)
                  Text(
                    'Semua mitra sudah melakukan absensi!',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (belumAbsen > 0)
            ElevatedButton.icon(
              onPressed: _sendAbsensiReminder,
              icon: const Icon(Icons.notifications_active, size: 18),
              label: Text('Kirim Pengingat ke Mitra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendAbsensiReminder() async {
    try {
      final mitraIds = widget.data['mitra_ids'] as List? ?? [];
      final user = _auth.currentUser;
      
      if (user == null) return;

      for (var mitraId in mitraIds) {
        final sudahAbsen = _riwayatAbsensi.any((a) => a['user_id'] == mitraId);
        
        if (!sudahAbsen) {
          await _firestore.collection('notifications').add({
            'userId': mitraId,
            'title': '📸 Pengingat Absensi Lembur',
            'body': 'Pengawas mengingatkan untuk segera melakukan absensi lembur tanggal ${_formatTanggal((widget.data['tanggal'] as Timestamp).toDate())}.',
            'type': 'absensi_reminder',
            'data': {
              'lembur_id': widget.docId,
              'group_id': widget.data['group_id'],
              'pengawas_name': widget.userName ?? 'Pengawas',
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengingat berhasil dikirim ke mitra'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Gagal mengirim pengingat: $e');
    }
  }

  Future<void> _approveOvertime() async {
    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('lembur').doc(widget.docId).update({
        'status': 'disetujui',
        'approved_by': user.uid,
        'approved_by_name': widget.userName ?? user.email,
        'approved_by_email': user.email,
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (widget.data['pengawas_id'] != null) {
        await _firestore.collection('notifications').add({
          'userId': widget.data['pengawas_id'],
          'title': '✅ Lembur Disetujui',
          'body': 'Pengajuan lembur tanggal ${_formatTanggal((widget.data['tanggal'] as Timestamp).toDate())} telah disetujui.',
          'type': 'overtime_approved',
          'data': {
            'lembur_id': widget.docId,
            'group_id': widget.data['group_id'],
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onStatusChanged();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lembur disetujui'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Gagal menyetujui: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _rejectOvertime(TextEditingController noteController) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tolak Lembur', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Berikan alasan penolakan:',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Alasan penolakan *',
                hintText: 'Jelaskan mengapa ditolak...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),
          ],
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Tolak', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (noteController.text.trim().isEmpty) {
      _showErrorSnackbar('Alasan penolakan wajib diisi');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('lembur').doc(widget.docId).update({
        'status': 'ditolak',
        'approved_by': user.uid,
        'approved_by_name': widget.userName ?? user.email,
        'approval_note': noteController.text.trim(),
        'rejected_reason': noteController.text.trim(),
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (widget.data['pengawas_id'] != null) {
        await _firestore.collection('notifications').add({
          'userId': widget.data['pengawas_id'],
          'title': '❌ Lembur Ditolak',
          'body': 'Pengajuan lembur tanggal ${_formatTanggal((widget.data['tanggal'] as Timestamp).toDate())} ditolak. Alasan: ${noteController.text.trim()}',
          'type': 'overtime_rejected',
          'data': {
            'lembur_id': widget.docId,
            'group_id': widget.data['group_id'],
            'reason': noteController.text.trim(),
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onStatusChanged();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lembur ditolak'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Gagal menolak: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'selesai':
        return Colors.blue;
      case 'kadaluarsa':
        return expiredColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      case 'selesai':
        return 'Selesai';
      case 'kadaluarsa':
        return 'Kadaluarsa';
      default:
        return status;
    }
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return const Color(0xFF1976D2);
      case 'lab':
        return const Color(0xFF4CAF50);
      case 'maintenance':
        return const Color(0xFFFF9800);
      case 'hsse':
        return const Color(0xFF9C27B0);
      case 'gpr':
        return const Color(0xFFF44336);
      case 'bs':
        return const Color(0xFF795548);
      default:
        return primaryBlue;
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

  String _getJenisLemburLabel(String jenis) {
    switch (jenis) {
      case 'hari_kerja':
        return 'Hari Kerja';
      case 'hari_libur':
        return 'Hari Libur';
      default:
        return jenis;
    }
  }

  String _getUrgensiLabel(String? urgensi) {
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
        return urgensi ?? 'Normal';
    }
  }

  Color _getUrgensiColor(String? urgensi) {
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatTanggal(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(timestamp.toDate());
    }
    return '-';
  }

  String _formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ==================== SEARCH DELEGATE ====================
class OvertimeSearchDelegate extends SearchDelegate {
  final String? userRole;
  final String? userFungsi;
  final String? userId;
  final Color accentBlue;
  final Color primaryBlue;
  final Function(String) onSearch;

  OvertimeSearchDelegate({
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
            final doc = docs[index];
            final data = doc.data();
            final isGroup = data['is_multiple'] ?? false;
            final status = data['status'] ?? 'pending';
            final tanggal = (data['tanggal'] as Timestamp).toDate();
            final absensiStatus = data['absensi_status'] ?? 'belum_absen';
            final needAbsen = status == 'disetujui' && absensiStatus != 'selesai';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isGroup ? Icons.group : Icons.work_history,
                        color: _getStatusColor(status),
                        size: 20,
                      ),
                    ),
                    if (needAbsen && status != 'kadaluarsa')
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  isGroup
                      ? 'Lembur Grup (${data['total_mitra']} mitra)'
                      : (data['nama_mitra'] ?? 'Unknown'),
                  style: GoogleFonts.poppins(),
                ),
                subtitle: Text(
                  '${_formatTanggal(tanggal)} • ${data['jam_mulai']} - ${data['jam_selesai']}',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {
                  close(context, doc.id);
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
      query = query.where('is_group_leader', isEqualTo: true);
      if (userFungsi != null && userFungsi!.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
      }
    } else if (userRole == 'pengawas') {
      query = query.where('pengawas_id', isEqualTo: userId);
    } else if (userRole == 'mitra') {
      query = query.where('mitra_ids', arrayContains: userId);
    }

    return query
        .orderBy('nama_mitra')
        .where('nama_mitra', isGreaterThanOrEqualTo: query)
        .where('nama_mitra', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'selesai':
        return Colors.blue;
      case 'kadaluarsa':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      case 'selesai':
        return 'Selesai';
      case 'kadaluarsa':
        return 'Kadaluarsa';
      default:
        return status;
    }
  }

  String _formatTanggal(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }
}