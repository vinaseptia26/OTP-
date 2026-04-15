// FILE: lib/dashboard/manager/lembur/approval_lembur_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// APPROVAL LEMBUR SCREEN - FIXED VERSION WITH DEBUGGING
// ============================================================================
class ApprovalLemburScreen extends StatefulWidget {
  final VoidCallback? onApprovalComplete;

  const ApprovalLemburScreen({super.key, this.onApprovalComplete});

  @override
  State<ApprovalLemburScreen> createState() => _ApprovalLemburScreenState();
}

class _ApprovalLemburScreenState extends State<ApprovalLemburScreen>
    with TickerProviderStateMixin {
  
  // ============== SERVICES ==============
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============== ANIMATION ==============
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ============== STATE ==============
  bool _isLoading = true;
  bool _isDarkMode = false;
  String? _fungsiManager;
  String? _namaManager;
  String? _managerId;
  String? _userRole;
  String? _userEmail;

  // ============== FILTER ==============
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ============== SELECTION ==============
  String? _selectedGroupId;
  Map<String, dynamic>? _selectedPengajuan;
  bool _isDetailLoading = false;

  // ============== STATISTICS ==============
  int _totalPending = 0;
  int _totalApproved = 0;
  int _totalRejected = 0;
  double _totalEstimasiBiaya = 0;
  double _totalJamBulanIni = 0;

  // ============== VALID FUNGSI ==============
  final List<String> validFungsi = [
    'operation',
    'lab',
    'maintenance',
    'hsse',
    'gpr',
    'bs'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ============== INITIALIZATION ==============
  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _loadUserData();
      await _loadStatistics();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _managerId = user.uid;
    _userEmail = user.email;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _userRole = data['role']?.toString().toLowerCase() ?? '';
          _fungsiManager = data['fungsi']?.toString().toLowerCase() ?? '';
          _namaManager = data['nama_lengkap']?.toString() ?? user.email ?? 'Manager';

          debugPrint('👤 User Data Loaded:');
          debugPrint('   - Role: $_userRole');
          debugPrint('   - Fungsi: $_fungsiManager');
          debugPrint('   - Nama: $_namaManager');
          debugPrint('   - Email: $user.email');
          debugPrint('   - UID: $user.uid');

          if (!validFungsi.contains(_fungsiManager) && _userRole == 'manager') {
            debugPrint('⚠️ Fungsi manager tidak valid: $_fungsiManager');
          }
        }
      } else {
        debugPrint('⚠️ Dokumen user tidak ditemukan untuk UID: ${user.uid}');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      _namaManager = user.email ?? 'User';
    }
  }

  Future<void> _loadStatistics() async {
    if (_fungsiManager == null || _fungsiManager!.isEmpty) {
      if (mounted) {
        setState(() {
          _totalPending = 0;
          _totalApproved = 0;
          _totalRejected = 0;
          _totalEstimasiBiaya = 0;
          _totalJamBulanIni = 0;
        });
      }
      return;
    }

    try {
      // Hitung total pending
      final pendingSnapshot = await _firestore
          .collection('lembur')
          .where('is_group_leader', isEqualTo: true)
          .where('status', isEqualTo: 'pending')
          .where('pengawas_fungsi', isEqualTo: _fungsiManager)
          .get();

      // Hitung total approved
      final approvedSnapshot = await _firestore
          .collection('lembur')
          .where('is_group_leader', isEqualTo: true)
          .where('status', isEqualTo: 'disetujui')
          .where('pengawas_fungsi', isEqualTo: _fungsiManager)
          .get();

      // Hitung total rejected
      final rejectedSnapshot = await _firestore
          .collection('lembur')
          .where('is_group_leader', isEqualTo: true)
          .where('status', isEqualTo: 'ditolak')
          .where('pengawas_fungsi', isEqualTo: _fungsiManager)
          .get();

      // Hitung total estimasi biaya untuk bulan ini
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final biayaSnapshot = await _firestore
          .collection('lembur')
          .where('is_group_leader', isEqualTo: true)
          .where('status', isEqualTo: 'disetujui')
          .where('pengawas_fungsi', isEqualTo: _fungsiManager)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      double totalBiaya = 0;
      double totalJam = 0;
      
      for (var doc in biayaSnapshot.docs) {
        final data = doc.data();
        totalBiaya += (data['estimasi_biaya_total'] as num?)?.toDouble() ?? 0;
        totalJam += (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalPending = pendingSnapshot.docs.length;
          _totalApproved = approvedSnapshot.docs.length;
          _totalRejected = rejectedSnapshot.docs.length;
          _totalEstimasiBiaya = totalBiaya;
          _totalJamBulanIni = totalJam;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
      
      if (e.toString().contains('index')) {
        _showErrorSnackbar(
          'Database perlu diindex. Hubungi administrator.',
        );
      }
    }
  }

  // ============== HELPER METHODS ==============
  String _safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  double _safeDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  String _formatRupiahCompact(double value) {
    if (value >= 1000000) {
      final juta = value / 1000000;
      return 'Rp ${juta.toStringAsFixed(1)} Jt';
    } else if (value >= 1000) {
      final ribu = value / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    } else {
      return 'Rp ${value.toStringAsFixed(0)}';
    }
  }

  String _formatJam(double jam) {
    if (jam % 1 == 0) {
      return '${jam.toInt()} jam';
    } else {
      return '${jam.toStringAsFixed(1)} jam';
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(date);
  }

  String _formatDateOnly(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  String _formatTimeOfDay(String timeStr) {
    return timeStr;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      case 'selesai':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'disetujui':
        return Icons.check_circle;
      case 'ditolak':
        return Icons.cancel;
      case 'selesai':
        return Icons.done_all;
      default:
        return Icons.help;
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
        return const Color(0xFF757575);
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

  // ============== SHOW DETAIL DIALOG ==============
  Future<void> _showDetailDialog(String groupId) async {
    if (!mounted) return;

    setState(() {
      _selectedGroupId = groupId;
      _isDetailLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('lembur')
          .where('group_id', isEqualTo: groupId)
          .get();

      if (snapshot.docs.isEmpty) {
        _showErrorSnackbar('Data tidak ditemukan');
        setState(() => _isDetailLoading = false);
        return;
      }

      // Cari group leader
      Map<String, dynamic>? groupData;
      List<Map<String, dynamic>> mitraList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isGroupLeader = data['is_group_leader'] == true;
        
        if (isGroupLeader) {
          groupData = {
            'id': doc.id,
            ...data,
          };
        } else {
          mitraList.add({
            'id': doc.id,
            'mitra_id': data['mitra_id'],
            'nama_mitra': data['nama_mitra'] ?? 'Unknown',
            'fungsi_mitra': data['fungsi_mitra'] ?? '',
            'no_hp_mitra': data['no_hp_mitra'] ?? '',
            'email_mitra': data['email_mitra'] ?? '',
            'is_override': data['is_override'] ?? false,
            'jam_lembur_bulan_ini_sebelumnya': data['jam_lembur_bulan_ini_sebelumnya'] ?? 0,
          });
        }
      }

      if (groupData == null) {
        _showErrorSnackbar('Data group leader tidak ditemukan');
        setState(() => _isDetailLoading = false);
        return;
      }

      final totalJam = _safeDouble(groupData['total_jam_desimal']);
      
      // Tambahkan data tambahan untuk setiap mitra
      for (var mitra in mitraList) {
        final jamSebelum = _safeDouble(mitra['jam_lembur_bulan_ini_sebelumnya']);
        mitra['jam_lembur_setelah'] = jamSebelum + totalJam;
        mitra['persentase'] = ((mitra['jam_lembur_setelah'] / 60) * 100).clamp(0, 100);
      }

      setState(() {
        _selectedPengajuan = {
          ...groupData!,
          'mitra_list': mitraList,
        };
        _isDetailLoading = false;
      });

      _showDetailBottomSheet();
    } catch (e) {
      debugPrint('❌ Error loading detail: $e');
      setState(() {
        _isDetailLoading = false;
        _selectedGroupId = null;
        _selectedPengajuan = null;
      });
      _showErrorSnackbar('Gagal memuat detail: ${e.toString()}');
    }
  }

  void _showDetailBottomSheet() {
    if (_selectedPengajuan == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailBottomSheet(),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedGroupId = null;
          _selectedPengajuan = null;
        });
      }
    });
  }

  Widget _buildDetailBottomSheet() {
    final data = _selectedPengajuan!;
    final status = _safeString(data['status']);
    final isPending = status == 'pending';
    final urgensi = _safeString(data['urgensi']);
    final isUrgent = urgensi == 'kritis';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';
    final isOutside = data['lokasi']?['is_outside_radius'] ?? false;

    // Data lokasi lengkap
    final lokasi = data['lokasi'] ?? {};
    final alamatLokasi = _safeString(lokasi['alamat']);
    final jarak = (lokasi['distance_from_kantor'] as num?)?.toDouble() ?? 0;
    final sourceLokasi = _safeString(lokasi['source']);
    final latitude = (lokasi['latitude'] as num?)?.toDouble();
    final longitude = (lokasi['longitude'] as num?)?.toDouble();
    final pilihanLokasi = _safeString(lokasi['pilihan']);
    final proyekTerpilih = _safeString(lokasi['proyek']);

    // Data waktu
    final tanggal = data['tanggal'] as Timestamp?;
    final jamMulai = _safeString(data['jam_mulai']);
    final jamSelesai = _safeString(data['jam_selesai']);
    final totalJam = _safeDouble(data['total_jam_desimal']);

    // Data biaya
    final biayaPerMitra = _safeDouble(data['estimasi_biaya_per_mitra']);
    final biayaTotal = _safeDouble(data['estimasi_biaya_total']);
    final totalMitra = _safeInt(data['total_mitra'], defaultValue: 1);

    // Data rate snapshot (untuk audit)
    final rateSnapshot = data['rate_snapshot'] ?? {};
    final ratePerHour = _safeDouble(rateSnapshot['rate_per_hour']);
    final baseSalary = _safeDouble(rateSnapshot['base_salary']);

    // Data limit per mitra
    final mitraList = data['mitra_list'] as List? ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pengajuan Lembur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'ID: ${data['group_id']?.toString().substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
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
          ),

          // Status Badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  label: _getStatusText(status),
                  color: _getStatusColor(status),
                ),
                _buildStatusChip(
                  label: _getUrgensiLabel(urgensi),
                  color: _getUrgensiColor(urgensi),
                ),
                if (isWeekend)
                  _buildStatusChip(
                    label: 'HARI LIBUR',
                    color: Colors.purple,
                  ),
                if (isOverride)
                  _buildStatusChip(
                    label: 'OVERRIDE',
                    color: Colors.orange,
                  ),
                if (isOutside)
                  _buildStatusChip(
                    label: 'LUAR RADIUS',
                    color: Colors.orange,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Pengawas
                  _buildDetailSection(
                    title: 'Informasi Pengawas',
                    icon: Icons.person,
                    color: Colors.blue,
                    child: Column(
                      children: [
                        _buildDetailRow(
                          label: 'Nama',
                          value: _safeString(data['nama_pengawas']),
                          icon: Icons.badge,
                        ),
                        _buildDetailRow(
                          label: 'Fungsi',
                          value: _getFungsiLabel(_safeString(data['pengawas_fungsi'])),
                          icon: Icons.work,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Waktu
                  _buildDetailSection(
                    title: 'Waktu Lembur',
                    icon: Icons.access_time,
                    color: Colors.green,
                    child: Column(
                      children: [
                        _buildDetailRow(
                          label: 'Tanggal',
                          value: tanggal != null ? _formatDateOnly(tanggal) : '-',
                          icon: Icons.calendar_today,
                        ),
                        _buildDetailRow(
                          label: 'Jam',
                          value: '$jamMulai - $jamSelesai',
                          icon: Icons.schedule,
                        ),
                        _buildDetailRow(
                          label: 'Durasi',
                          value: _formatJam(totalJam),
                          icon: Icons.timer,
                          isBold: true,
                        ),
                        _buildDetailRow(
                          label: 'Jenis',
                          value: isWeekend ? 'Hari Libur' : 'Hari Kerja',
                          icon: Icons.work_outline,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Lokasi (LENGKAP)
                  _buildDetailSection(
                    title: 'Lokasi Lembur',
                    icon: Icons.location_on,
                    color: Colors.purple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Alamat
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.place, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      alamatLokasi.isNotEmpty ? alamatLokasi : 'Alamat tidak tersedia',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isDarkMode ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              // Detail lokasi
                              _buildLokasiDetailRow('Pilihan', _getLokasiPilihanLabel(pilihanLokasi)),
                              if (pilihanLokasi == 'proyek' && proyekTerpilih.isNotEmpty)
                                _buildLokasiDetailRow('Proyek', proyekTerpilih),
                              _buildLokasiDetailRow('Sumber', sourceLokasi.toUpperCase()),
                              if (latitude != null && longitude != null)
                                _buildLokasiDetailRow(
                                  'Koordinat', 
                                  '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
                                ),
                              
                              const SizedBox(height: 8),

                              // Jarak dan status radius
                              if (jarak > 0)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isOutside 
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isOutside ? Icons.warning : Icons.check_circle,
                                        size: 16,
                                        color: isOutside ? Colors.orange : Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isOutside
                                              ? '⚠️ Lokasi di luar radius kantor (${jarak.toStringAsFixed(0)} m)'
                                              : '✅ Dalam radius kantor (${jarak.toStringAsFixed(0)} m)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isOutside ? Colors.orange : Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Daftar Mitra dengan LIMIT INFO (LENGKAP)
                  _buildDetailSection(
                    title: 'Daftar Mitra ($totalMitra)',
                    icon: Icons.people,
                    color: Colors.orange,
                    child: Column(
                      children: mitraList.map((mitra) {
                        final jamSebelum = _safeDouble(mitra['jam_lembur_bulan_ini_sebelumnya']);
                        final jamTambahan = totalJam;
                        final jamSetelah = jamSebelum + jamTambahan;
                        final persentase = (jamSetelah / 60 * 100).clamp(0, 100);
                        final isMitraOverLimit = jamSetelah > 60;
                        final isMitraNearLimit = jamSetelah > 48 && jamSetelah <= 60;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: isMitraOverLimit
                                ? Border.all(color: Colors.red, width: 1.5)
                                : isMitraNearLimit
                                    ? Border.all(color: Colors.orange, width: 1)
                                    : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getFungsiColor(mitra['fungsi_mitra'] ?? '')
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: _getFungsiColor(mitra['fungsi_mitra'] ?? ''),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _safeString(mitra['nama_mitra']),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (mitra['is_override'] == true)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'OVERRIDE',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          _getFungsiLabel(mitra['fungsi_mitra']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Progress bar limit
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Limit 60 jam/bulan:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '${_formatJam(jamSebelum)} + ${_formatJam(jamTambahan)} = ${_formatJam(jamSetelah)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isMitraOverLimit
                                              ? Colors.red
                                              : isMitraNearLimit
                                                  ? Colors.orange
                                                  : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: persentase / 100,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isMitraOverLimit
                                            ? Colors.red
                                            : isMitraNearLimit
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${persentase.toStringAsFixed(0)}% dari batas maksimal',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (mitra['no_hp_mitra']?.toString().isNotEmpty == true || 
                                  mitra['email_mitra']?.toString().isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (mitra['no_hp_mitra']?.toString().isNotEmpty == true) ...[
                                      Icon(Icons.phone, size: 10, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        mitra['no_hp_mitra'].toString(),
                                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                      ),
                                    ],
                                    if (mitra['email_mitra']?.toString().isNotEmpty == true) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.email, size: 10, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          mitra['email_mitra'].toString(),
                                          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Estimasi Biaya dengan detail rate
                  _buildDetailSection(
                    title: 'Estimasi Biaya',
                    icon: Icons.payments,
                    color: Colors.green,
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                          // Rate info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Gaji Pokok',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                _formatRupiah(baseSalary),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rate/Jam (173 jam)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                _formatRupiahCompact(ratePerHour),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white30, height: 1),
                          const SizedBox(height: 8),
                          
                          // Biaya per mitra
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Per Mitra',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                _formatRupiah(biayaPerMitra),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          // Multiplier info (untuk transparansi)
                          if (!isWeekend) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '• Jam pertama: 1.5x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                                Text(
                                  '• Jam berikutnya: 2x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '• 8 jam pertama: 2x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                                Text(
                                  '• Jam ke-9: 3x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '• Jam ke-10+: 4x',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white30, height: 1),
                          const SizedBox(height: 8),
                          
                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total ($totalMitra mitra)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _formatRupiah(biayaTotal),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Alasan
                  _buildDetailSection(
                    title: 'Alasan Lembur',
                    icon: Icons.description,
                    color: Colors.teal,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _safeString(data['alasan']),
                            style: TextStyle(
                              fontSize: 12,
                              color: _isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          if (data['catatan_tambahan']?.toString().isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'Catatan Tambahan:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _safeString(data['catatan_tambahan']),
                              style: TextStyle(
                                fontSize: 12,
                                color: _isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timeline
                  _buildDetailSection(
                    title: 'Timeline',
                    icon: Icons.timeline,
                    color: Colors.grey,
                    child: Column(
                      children: [
                        _buildTimelineItem(
                          title: 'Dibuat oleh ${_safeString(data['nama_pengawas'])}',
                          time: _formatDate(data['created_at'] as Timestamp?),
                          icon: Icons.create,
                          isFirst: true,
                        ),
                        if (data['approved_at'] != null)
                          _buildTimelineItem(
                            title: 'Disetujui oleh ${_safeString(data['approved_by'])}',
                            time: _formatDate(data['approved_at'] as Timestamp?),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                        if (data['rejected_at'] != null)
                          _buildTimelineItem(
                            title: 'Ditolak oleh ${_safeString(data['rejected_by'])}',
                            time: _formatDate(data['rejected_at'] as Timestamp?),
                            icon: Icons.cancel,
                            color: Colors.red,
                            notes: data['rejected_reason']?.toString(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Rate Snapshot (untuk audit)
                  if (rateSnapshot.isNotEmpty)
                    _buildDetailSection(
                      title: 'Informasi Tarif (Saat Pengajuan)',
                      icon: Icons.lock_clock,
                      color: Colors.grey,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              label: 'Gaji Pokok',
                              value: _formatRupiah(baseSalary),
                              icon: Icons.attach_money,
                            ),
                            _buildDetailRow(
                              label: 'Last Updated',
                              value: rateSnapshot['last_updated'] != null
                                  ? _formatDate(rateSnapshot['last_updated'] as Timestamp?)
                                  : '-',
                              icon: Icons.update,
                            ),
                            _buildDetailRow(
                              label: 'Updated By',
                              value: _safeString(rateSnapshot['updated_by']),
                              icon: Icons.person,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Action Buttons (hanya untuk pending)
          if (isPending && _userRole == 'manager')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(),
                      icon: const Icon(Icons.check),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildLokasiDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: _isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String time,
    required IconData icon,
    Color color = Colors.grey,
    bool isFirst = false,
    String? notes,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            if (!isFirst)
              Container(
                width: 1,
                height: 20,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============== APPROVAL ACTIONS ==============
  void _showApproveDialog() {
    final data = _selectedPengajuan!;
    final isUrgent = _safeString(data['urgensi']) == 'kritis';
    final isOverride = data['is_override'] ?? false;
    
    final mitraList = data['mitra_list'] as List? ?? [];
    final totalJam = _safeDouble(data['total_jam_desimal']);
    
    final mitraOverLimit = mitraList.where((m) {
      final jamSebelum = _safeDouble(m['jam_lembur_bulan_ini_sebelumnya']);
      final jamSetelah = jamSebelum + totalJam;
      return jamSetelah > 60;
    }).toList();
    
    final TextEditingController catatanController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Setujui Pengajuan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUrgent || isOverride || mitraOverLimit.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (isUrgent)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pengajuan ini bersifat KRITIS',
                                  style: TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isOverride)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Menggunakan OVERRIDE (melebihi 60 jam/bulan)',
                                  style: TextStyle(fontSize: 12, color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (mitraOverLimit.isNotEmpty)
                        Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mitra berikut akan melebihi limit:',
                                    style: TextStyle(fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...mitraOverLimit.take(3).map((m) => Padding(
                              padding: const EdgeInsets.only(left: 28, bottom: 4),
                              child: Text(
                                '• ${m['nama_mitra']}',
                                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                              ),
                            )),
                            if (mitraOverLimit.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: Text(
                                  '• dan ${mitraOverLimit.length - 3} lainnya',
                                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Apakah Anda yakin ingin menyetujui pengajuan lembur ini?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: catatanController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Tambahkan catatan approval...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => _processApproval(true, notes: catatanController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final TextEditingController alasanController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berikan alasan penolakan:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: alasanController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan *',
                hintText: 'Jelaskan mengapa ditolak...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (alasanController.text.trim().isEmpty) {
                _showErrorSnackbar('Alasan penolakan wajib diisi');
                return;
              }
              _processApproval(false, notes: alasanController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  // ============== PROCESS APPROVAL WITH DEBUGGING ==============
  Future<void> _processApproval(bool isApprove, {String notes = ''}) async {
    if (_selectedPengajuan == null || !mounted) return;

    // Tutup dialog konfirmasi
    Navigator.pop(context);

    setState(() => _isDetailLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      debugPrint('\n========== START APPROVAL PROCESS ==========');
      debugPrint('👤 User ID: ${user.uid}');
      debugPrint('👤 User Email: ${user.email}');
      debugPrint('👤 User Role: $_userRole');
      debugPrint('👤 User Fungsi: $_fungsiManager');

      final data = _selectedPengajuan!;
      final groupId = data['group_id'];
      
      if (groupId == null) {
        throw Exception('Group ID tidak ditemukan');
      }

      debugPrint('📄 Group ID: $groupId');
      debugPrint('📄 Status Pengajuan: ${data['status']}');
      debugPrint('📄 Pengawas Fungsi: ${data['pengawas_fungsi']}');
      debugPrint('📄 Apakah action approve? $isApprove');

      // Validasi apakah manager berhak
      if (_userRole != 'manager') {
        throw Exception('Hanya manager yang dapat melakukan approval');
      }

      if (_fungsiManager != data['pengawas_fungsi']) {
        throw Exception('Anda tidak berhak menyetujui pengajuan dari fungsi ${data['pengawas_fungsi']}');
      }

      if (data['status'] != 'pending') {
        throw Exception('Pengajuan sudah diproses sebelumnya');
      }

      // Ambil data user untuk field yang lengkap
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (!userData.exists) {
        throw Exception('Data user tidak ditemukan di Firestore');
      }
      
      final userDataMap = userData.data() ?? {};
      final userName = userDataMap['nama_lengkap'] ?? user.email ?? 'Manager';
      
      debugPrint('👤 Nama Manager: $userName');

      // Ambil semua dokumen dalam group
      final snapshot = await _firestore
          .collection('lembur')
          .where('group_id', isEqualTo: groupId)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Tidak ada dokumen lembur ditemukan');
      }

      debugPrint('📄 Total dokumen dalam group: ${snapshot.docs.length}');

      // 🔥 FIX: Update SATU PER SATU (BUKAN BATCH) untuk debugging
      int successCount = 0;
      int failCount = 0;

      for (var doc in snapshot.docs) {
        final docRef = _firestore.collection('lembur').doc(doc.id);
        final docData = doc.data();
        final isGroupLeader = docData['is_group_leader'] == true;
        
        debugPrint('\n🔄 Mencoba update dokumen: ${doc.id}');
        debugPrint('   - is_group_leader: $isGroupLeader');
        debugPrint('   - status sekarang: ${docData['status']}');
        
        try {
          if (isApprove) {
            if (isGroupLeader) {
              // Update group leader dengan field lengkap
              await docRef.update({
                'status': 'disetujui',
                'approved_by': user.email,
                'approved_by_id': user.uid,
                'approved_by_name': userName,
                'approved_by_email': user.email,
                'approved_at': FieldValue.serverTimestamp(),
                'approved_notes': notes,
                'approval_note': notes,
                'updated_at': FieldValue.serverTimestamp(),
              });
              debugPrint('   ✅ Berhasil update GROUP LEADER dengan field lengkap');
            } else {
              // Update dokumen mitra hanya status dasar
              await docRef.update({
                'status': 'disetujui',
                'approved_by': user.email,
                'approved_by_id': user.uid,
                'approved_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
              });
              debugPrint('   ✅ Berhasil update MITRA dengan field dasar');
            }
          } else {
            if (isGroupLeader) {
              // Reject group leader dengan field lengkap
              await docRef.update({
                'status': 'ditolak',
                'rejected_by': user.email,
                'rejected_by_id': user.uid,
                'rejected_by_name': userName,
                'rejected_by_email': user.email,
                'rejected_at': FieldValue.serverTimestamp(),
                'rejected_reason': notes,
                'rejected_notes': notes,
                'updated_at': FieldValue.serverTimestamp(),
              });
              debugPrint('   ✅ Berhasil reject GROUP LEADER dengan field lengkap');
            } else {
              // Reject dokumen mitra hanya status dasar
              await docRef.update({
                'status': 'ditolak',
                'rejected_by': user.email,
                'rejected_by_id': user.uid,
                'rejected_at': FieldValue.serverTimestamp(),
                'rejected_reason': notes,
                'updated_at': FieldValue.serverTimestamp(),
              });
              debugPrint('   ✅ Berhasil reject MITRA dengan field dasar');
            }
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('   ❌ Gagal update dokumen ${doc.id}: $e');
          if (e is FirebaseException) {
            debugPrint('      - Code: ${e.code}');
            debugPrint('      - Message: ${e.message}');
          }
          // Lanjutkan ke dokumen berikutnya
        }
      }

      debugPrint('\n========== HASIL UPDATE ==========');
      debugPrint('✅ Sukses: $successCount dokumen');
      debugPrint('❌ Gagal: $failCount dokumen');
      
      if (failCount > 0 && successCount == 0) {
        throw Exception('Gagal mengupdate semua dokumen');
      }

      if (successCount > 0) {
        debugPrint('✅ Sebagian update berhasil untuk group: $groupId');
        
        // Kirim notifikasi
        try {
          await _sendNotificationToPengawas(isApprove, notes);
        } catch (e) {
          debugPrint('⚠️ Gagal kirim notifikasi ke pengawas: $e');
        }
        
        if (isApprove) {
          try {
            await _sendNotificationAndCreateSchedule();
          } catch (e) {
            debugPrint('⚠️ Gagal kirim notifikasi ke mitra: $e');
          }
        }

        await _loadStatistics();

        if (widget.onApprovalComplete != null) {
          widget.onApprovalComplete!();
        }

        if (mounted) {
          // Tutup bottom sheet
          try {
            Navigator.pop(context);
          } catch (_) {}
          
          // Tampilkan pesan sukses
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              String message;
              if (failCount > 0) {
                message = isApprove
                    ? '⚠️ Sebagian berhasil disetujui ($successCount/${snapshot.docs.length} dokumen)'
                    : '⚠️ Sebagian berhasil ditolak ($successCount/${snapshot.docs.length} dokumen)';
              } else {
                message = isApprove
                    ? '✅ Pengajuan lembur berhasil disetujui'
                    : '❌ Pengajuan lembur ditolak';
              }
              _showSuccessSnackbar(message);
            }
          });
        }
      } else {
        throw Exception('Tidak ada dokumen yang berhasil diupdate');
      }
      
      debugPrint('========== SELESAI ==========\n');
      
    } catch (e) {
      debugPrint('\n❌❌❌ ERROR PROCESSING APPROVAL ❌❌❌');
      debugPrint('Error: $e');
      
      if (e is FirebaseException) {
        debugPrint('Firebase Error Code: ${e.code}');
        debugPrint('Firebase Error Message: ${e.message}');
      }
      
      if (mounted) {
        // Tutup bottom sheet jika masih terbuka
        try {
          Navigator.pop(context);
        } catch (_) {}
        
        _showErrorSnackbar('Gagal memproses: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isDetailLoading = false);
      }
    }
  }

  // 🔥 NOTIFIKASI KE PENGAWAS
  Future<void> _sendNotificationToPengawas(bool isApprove, String notes) async {
    try {
      final data = _selectedPengajuan!;
      final pengawasId = data['pengawas_id'];

      if (pengawasId == null) return;

      final tanggal = data['tanggal'] as Timestamp?;
      final tanggalStr = tanggal != null ? DateFormat('dd/MM/yyyy').format(tanggal.toDate()) : '-';
      final tanggalFull = tanggal != null ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal.toDate()) : '-';
      final jamStr = '${data['jam_mulai']} - ${data['jam_selesai']}';

      final notificationRef = _firestore
          .collection('notifications')
          .doc(pengawasId)
          .collection('items')
          .doc();

      if (isApprove) {
        await notificationRef.set({
          'type': 'lembur_approved',
          'title': '✅ Pengajuan Lembur Disetujui',
          'body': '''
Halo ${data['nama_pengawas']},

Pengajuan lembur Anda untuk:
📅 $tanggalFull
⏰ $jamStr

telah DISETUJUI oleh Manager.

${notes.isNotEmpty ? 'Catatan: $notes' : ''}

✅ Notifikasi jadwal telah dikirim ke ${data['total_mitra']} mitra.
''',
          'data': {
            'group_id': data['group_id'],
            'status': 'disetujui',
            'tanggal': tanggal?.toDate().toIso8601String(),
            'jam_mulai': data['jam_mulai'],
            'jam_selesai': data['jam_selesai'],
            'notes': notes,
            'total_mitra': data['total_mitra'],
          },
          'read': false,
          'created_at': FieldValue.serverTimestamp(),
          'priority': 1,
        });
      } else {
        await notificationRef.set({
          'type': 'lembur_rejected',
          'title': '❌ Pengajuan Lembur Ditolak',
          'body': '''
Halo ${data['nama_pengawas']},

Pengajuan lembur Anda untuk:
📅 $tanggalFull
⏰ $jamStr

DITOLAK oleh Manager.

Alasan: $notes

Silakan ajukan ulang dengan perbaikan yang diperlukan.
''',
          'data': {
            'group_id': data['group_id'],
            'status': 'ditolak',
            'tanggal': tanggal?.toDate().toIso8601String(),
            'jam_mulai': data['jam_mulai'],
            'jam_selesai': data['jam_selesai'],
            'alasan': notes,
          },
          'read': false,
          'created_at': FieldValue.serverTimestamp(),
          'priority': 1,
        });
      }

      debugPrint('✅ Notifikasi terkirim ke pengawas: $pengawasId');
    } catch (e) {
      debugPrint('❌ Error sending notification to pengawas: $e');
    }
  }

  // 🔥 NOTIFIKASI KE MITRA + PEMBUATAN JADWAL OTOMATIS
  Future<void> _sendNotificationAndCreateSchedule() async {
    try {
      final data = _selectedPengajuan!;
      final mitraListDynamic = data['mitra_list'] as List? ?? [];
      
      if (mitraListDynamic.isEmpty) return;

      // Konversi List<dynamic> ke List<Map<String, dynamic>>
      final List<Map<String, dynamic>> mitraList = [];
      for (var item in mitraListDynamic) {
        if (item is Map<String, dynamic>) {
          mitraList.add(item);
        }
      }

      final tanggal = data['tanggal'] as Timestamp?;
      if (tanggal == null) return;
      
      final tanggalFull = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal.toDate());
      final tanggalShort = DateFormat('dd/MM/yyyy').format(tanggal.toDate());
      final jamStr = '${data['jam_mulai']} - ${data['jam_selesai']}';
      
      final lokasi = data['lokasi'] ?? {};
      String lokasiStr;
      if (lokasi['pilihan'] == 'kantor') {
        lokasiStr = 'Kantor PGE Kamojang';
      } else if (lokasi['pilihan'] == 'proyek' && lokasi['proyek'] != null) {
        lokasiStr = 'Proyek: ${lokasi['proyek']}';
      } else {
        lokasiStr = lokasi['alamat'] ?? 'Kantor PGE Kamojang';
      }

      // BUAT JADWAL LEMBUR OTOMATIS
      await _createLemburSchedule(data, mitraList, tanggal, lokasiStr);

      int successCount = 0;
      
      for (var mitra in mitraList) {
        final mitraId = mitra['mitra_id'];
        if (mitraId == null) continue;
        
        try {
          // Kirim notifikasi ke Firestore
          final notificationRef = _firestore
              .collection('notifications')
              .doc(mitraId)
              .collection('items')
              .doc();
          
          await notificationRef.set({
            'type': 'lembur_scheduled',
            'title': '📋 Jadwal Lembur Baru',
            'body': '''
Halo ${mitra['nama_mitra'] ?? 'Mitra'},

Anda dijadwalkan lembur pada:
📅 $tanggalFull
⏰ $jamStr
📍 $lokasiStr

👤 Pengawas: ${data['nama_pengawas']} (${_getFungsiLabel(data['pengawas_fungsi'])})
📞 Kontak Pengawas: ${data['no_hp_pengawas'] ?? 'Tidak tersedia'}

⚠️ Hadir 15 menit sebelum jadwal.
📱 Buka aplikasi untuk melakukan absensi.
❓ Hubungi pengawas jika ada kendala.

Terima kasih.
''',
            'data': {
              'group_id': data['group_id'],
              'mitra_id': mitraId,
              'tanggal': tanggal.toDate().toIso8601String(),
              'tanggal_display': tanggalFull,
              'jam_mulai': data['jam_mulai'],
              'jam_selesai': data['jam_selesai'],
              'lokasi': lokasiStr,
              'pengawas_nama': data['nama_pengawas'],
              'pengawas_id': data['pengawas_id'],
              'pengawas_fungsi': data['pengawas_fungsi'],
              'pengawas_phone': data['no_hp_pengawas'] ?? '',
              'status': 'scheduled',
            },
            'read': false,
            'created_at': FieldValue.serverTimestamp(),
            'priority': 1,
          });

          // Kirim notifikasi WhatsApp (simulasi)
          if (mitra['no_hp_mitra']?.toString().isNotEmpty == true) {
            debugPrint('''
📱 WA ke ${mitra['nama_mitra']} (${mitra['no_hp_mitra']}):
*JADWAL LEMBUR*
Tanggal: $tanggalFull
Jam: $jamStr
Lokasi: $lokasiStr
Pengawas: ${data['nama_pengawas']}
            
⚠️ Hadir 15 menit sebelum jadwal.
''');
          }

          // Kirim email (simulasi)
          if (mitra['email_mitra']?.toString().isNotEmpty == true) {
            debugPrint('📧 Email ke ${mitra['email_mitra']}: Jadwal lembur $tanggalShort');
          }
          
          successCount++;
        } catch (e) {
          debugPrint('❌ Error sending to mitra $mitraId: $e');
        }
      }
      
      debugPrint('✅ Notifikasi terkirim ke $successCount/${mitraList.length} mitra');
      
      // Simpan log pengiriman
      try {
        await _firestore.collection('notifications_log').add({
          'type': 'lembur_approved_bulk',
          'group_id': data['group_id'],
          'total_mitra': mitraList.length,
          'success_count': successCount,
          'tanggal': Timestamp.fromDate(tanggal.toDate()),
          'sent_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ Gagal menyimpan log: $e');
      }
      
    } catch (e) {
      debugPrint('❌ Error sending notification to mitra: $e');
    }
  }

  // 🔥 MEMBUAT JADWAL LEMBUR OTOMATIS
  Future<void> _createLemburSchedule(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> mitraList,
    Timestamp tanggal,
    String lokasiStr,
  ) async {
    try {
      final groupId = data['group_id'];
      final batch = _firestore.batch();
      final now = DateTime.now();

      // 1. Buat dokumen jadwal utama di koleksi 'lembur_schedules'
      final scheduleRef = _firestore.collection('lembur_schedules').doc(groupId);
      
      batch.set(scheduleRef, {
        'group_id': groupId,
        'tanggal': tanggal,
        'tanggal_string': DateFormat('yyyy-MM-dd').format(tanggal.toDate()),
        'tanggal_display': DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal.toDate()),
        'jam_mulai': data['jam_mulai'],
        'jam_selesai': data['jam_selesai'],
        'total_jam': data['total_jam_desimal'],
        'jenis_lembur': data['jenis_lembur'],
        'urgensi': data['urgensi'],
        'alasan': data['alasan'],
        'catatan_tambahan': data['catatan_tambahan'] ?? '',
        'lokasi': data['lokasi'],
        'lokasi_string': lokasiStr,
        
        // Data pengawas
        'pengawas_id': data['pengawas_id'],
        'pengawas_nama': data['nama_pengawas'],
        'pengawas_fungsi': data['pengawas_fungsi'],
        'pengawas_email': data['email_pengawas'] ?? '',
        'pengawas_phone': data['no_hp_pengawas'] ?? '',
        
        // Data approval
        'approved_by': data['approved_by'],
        'approved_by_id': data['approved_by_id'],
        'approved_at': FieldValue.serverTimestamp(),
        'approved_notes': data['approved_notes'] ?? '',
        
        // Status dan statistik
        'status': 'scheduled',
        'total_mitra': mitraList.length,
        'hadir_count': 0,
        'tidak_hadir_count': 0,
        'pending_count': mitraList.length,
        
        // Metadata
        'created_at': FieldValue.serverTimestamp(),
        'created_by': _managerId,
        'updated_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });

      // 2. Buat subkoleksi untuk setiap mitra
      for (var mitra in mitraList) {
        final mitraId = mitra['mitra_id'];
        if (mitraId == null) continue;

        final mitraScheduleRef = scheduleRef.collection('mitra').doc(mitraId);
        
        batch.set(mitraScheduleRef, {
          'mitra_id': mitraId,
          'nama_mitra': mitra['nama_mitra'],
          'fungsi_mitra': mitra['fungsi_mitra'],
          'no_hp_mitra': mitra['no_hp_mitra'] ?? '',
          'email_mitra': mitra['email_mitra'] ?? '',
          'is_override': mitra['is_override'] ?? false,
          'jam_sebelumnya': mitra['jam_lembur_bulan_ini_sebelumnya'] ?? 0,
          
          // Status absensi
          'status_absen': 'pending', // pending, hadir, tidak_hadir, selesai
          'check_in_time': null,
          'check_out_time': null,
          'check_in_location': null,
          'check_out_location': null,
          'check_in_photo': null,
          'check_out_photo': null,
          'keterangan': null,
          'catatan_absensi': null,
          
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // 3. Juga simpan ke koleksi per-user untuk akses cepat di dashboard mitra
        final userScheduleRef = _firestore
            .collection('users')
            .doc(mitraId)
            .collection('lembur_schedules')
            .doc(groupId);

        batch.set(userScheduleRef, {
          'group_id': groupId,
          'tanggal': tanggal,
          'tanggal_string': DateFormat('yyyy-MM-dd').format(tanggal.toDate()),
          'tanggal_display': DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal.toDate()),
          'jam_mulai': data['jam_mulai'],
          'jam_selesai': data['jam_selesai'],
          'total_jam': data['total_jam_desimal'],
          'lokasi': lokasiStr,
          'pengawas_id': data['pengawas_id'],
          'pengawas_nama': data['nama_pengawas'],
          'pengawas_fungsi': data['pengawas_fungsi'],
          'pengawas_phone': data['no_hp_pengawas'] ?? '',
          'status': 'scheduled',
          'status_absen': 'pending',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // 4. Buat reminder otomatis (H-1 dan H-2 jam)
      await _createReminders(groupId, tanggal.toDate(), mitraList);

      await batch.commit();
      debugPrint('✅ Jadwal lembur otomatis dibuat untuk group: $groupId');
      
    } catch (e) {
      debugPrint('❌ Error creating schedule: $e');
    }
  }

  // 🔥 MEMBUAT REMINDER OTOMATIS
  Future<void> _createReminders(
    String groupId,
    DateTime tanggalLembur,
    List<Map<String, dynamic>> mitraList,
  ) async {
    try {
      final now = DateTime.now();
      final reminderTimes = [
        tanggalLembur.subtract(const Duration(days: 1)), // H-1 (pagi)
        tanggalLembur.subtract(const Duration(hours: 2)), // H-2 jam
      ];

      final reminderTypes = ['reminder_h-1', 'reminder_h-2'];
      
      // Ambil mitra_ids dengan aman
      final List<String> mitraIds = [];
      for (var mitra in mitraList) {
        final id = mitra['mitra_id'];
        if (id != null && id is String) {
          mitraIds.add(id);
        }
      }
      
      final batch = _firestore.batch();
      int reminderCount = 0;

      for (int i = 0; i < reminderTimes.length; i++) {
        final reminderTime = reminderTimes[i];
        if (reminderTime.isAfter(now)) {
          final reminderRef = _firestore
              .collection('reminders')
              .doc('${groupId}_${reminderTime.millisecondsSinceEpoch}');

          batch.set(reminderRef, {
            'group_id': groupId,
            'type': reminderTypes[i],
            'scheduled_for': Timestamp.fromDate(reminderTime),
            'tanggal_lembur': Timestamp.fromDate(tanggalLembur),
            'mitra_list': mitraIds,
            'processed': false,
            'created_at': FieldValue.serverTimestamp(),
            'created_by': _managerId,
          });
          reminderCount++;
        }
      }

      if (reminderCount > 0) {
        await batch.commit();
        debugPrint('✅ $reminderCount reminder otomatis dibuat untuk group: $groupId');
      }
      
    } catch (e) {
      debugPrint('❌ Error creating reminders: $e');
    }
  }

  // ============== UI BUILDERS ==============
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari pengawas, group ID...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3C72)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1E3C72),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _isDarkMode ? Colors.white70 : Colors.grey[600],
        tabs: const [
          Tab(text: 'Menunggu'),
          Tab(text: 'Disetujui'),
          Tab(text: 'Ditolak'),
        ],
      ),
    );
  }

  Widget _buildLemburList(String status) {
    if (_userRole != 'manager') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Akses Terbatas',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Halaman ini hanya untuk Manager',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_fungsiManager == null || _fungsiManager!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Fungsi manager tidak ditemukan',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('lembur')
          .where('is_group_leader', isEqualTo: true)
          .where('status', isEqualTo: status)
          .where('pengawas_fungsi', isEqualTo: _fungsiManager)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          String errorMessage = 'Terjadi kesalahan';
          if (snapshot.error.toString().contains('index')) {
            errorMessage = 'Database perlu diindex. Hubungi administrator.';
          } else if (snapshot.error.toString().contains('permission-denied')) {
            errorMessage = 'Izin akses ditolak. Hubungi administrator.';
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[200]),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadStatistics,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada data',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  'Belum ada pengajuan dengan status ini',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;

          final data = doc.data() as Map<String, dynamic>;
          final pengawasNama = data['nama_pengawas']?.toString().toLowerCase() ?? '';
          final groupId = data['group_id']?.toString().toLowerCase() ?? '';

          return pengawasNama.contains(_searchQuery) || groupId.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ditemukan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final isUrgent = data['urgensi'] == 'kritis';
            final isOverride = data['is_override'] ?? false;
            final lokasi = data['lokasi'] ?? {};
            final isOutside = lokasi['is_outside_radius'] ?? false;
            final isWeekend = data['jenis_lembur'] == 'hari_libur';

            return GestureDetector(
              onTap: () => _showDetailDialog(data['group_id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isUrgent
                      ? Border.all(color: Colors.red, width: 2)
                      : isOverride
                          ? Border.all(color: Colors.orange, width: 1.5)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _safeString(data['nama_pengawas']),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  if (isUrgent)
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
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _buildInfoChip(
                                    label: _getFungsiLabel(data['pengawas_fungsi']),
                                    color: Colors.blue,
                                  ),
                                  _buildInfoChip(
                                    label: '${data['total_mitra']} mitra',
                                    color: Colors.purple,
                                  ),
                                  _buildInfoChip(
                                    label: _formatJam(_safeDouble(data['total_jam_desimal'])),
                                    color: Colors.green,
                                  ),
                                  if (isWeekend)
                                    _buildInfoChip(
                                      label: 'LIBUR',
                                      color: Colors.purple,
                                    ),
                                  if (isOverride)
                                    _buildInfoChip(
                                      label: 'OVERRIDE',
                                      color: Colors.orange,
                                    ),
                                  if (isOutside)
                                    _buildInfoChip(
                                      label: 'LUAR RADIUS',
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(
                                      (data['tanggal'] as Timestamp).toDate(),
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${data['jam_mulai']} - ${data['jam_selesai']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.attach_money, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatRupiahCompact(
                                        _safeDouble(data['estimasi_biaya_total'])),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      lokasi['alamat']!.toString().length > 30
                                          ? '${lokasi['alamat'].toString().substring(0, 30)}...'
                                          : (lokasi['alamat']?.toString() ?? 'Kantor PGE'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (data['alasan'] != null && data['alasan'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['alasan'],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ============== SNACKBARS ==============
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
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(
          'Approval Lembur',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          // Statistik Total
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_totalPending',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: Colors.white30),
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_totalApproved',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _isDarkMode = !_isDarkMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadStatistics();
              setState(() {});
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _namaManager ?? 'Loading...',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getFungsiColor(_fungsiManager ?? '').withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getFungsiLabel(_fungsiManager).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1E3C72)),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat data...',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSearchField(),
                ),
                _buildTabBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLemburList('pending'),
                        _buildLemburList('disetujui'),
                        _buildLemburList('ditolak'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}