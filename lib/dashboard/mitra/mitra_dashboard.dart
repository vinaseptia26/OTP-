// screens/dashboard/mitra/mitra_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';

var logger = Logger();

class MitraDashboard extends StatefulWidget {
  const MitraDashboard({super.key});

  @override
  State<MitraDashboard> createState() => _MitraDashboardState();
}

class _MitraDashboardState extends State<MitraDashboard> with WidgetsBindingObserver, TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Data pengguna
  Map<String, dynamic>? userData;
  String? userId;
  String? userFungsi;
  String? userName;
  String? userPhotoUrl;
  
  // Data absensi
  Map<String, dynamic>? todayAbsensi;
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  DateTime? lastCheckIn;
  DateTime? lastCheckOut;
  Duration? workDuration;
  
  // Data lembur
  List<Map<String, dynamic>> overtimeRequests = [];
  Map<String, dynamic>? todayOvertime;
  Map<String, dynamic>? approvedOvertime;
  
  // ==================== DATA JADWAL LEMBUR BARU UNTUK KONFIRMASI ====================
  List<Map<String, dynamic>> pendingOvertimeRequests = []; // Lembur yang belum dikonfirmasi
  List<String> confirmedOvertimeIds = []; // ID lembur yang sudah dikonfirmasi
  
  // Data pengaturan lembur
  Map<String, dynamic>? overtimeSettings;
  
  // Statistik
  Map<String, dynamic> stats = {
    'totalLembur': 0,
    'totalJamLembur': 0,
    'sisaKuota': 60,
    'pending': 0,
    'disetujui': 0,
    'ditolak': 0,
    'selesai': 0,
    'kehadiran': 95,
    'totalIncome': 0.0,
  };
  
  // Jadwal lembur (dari collection lembur yang sudah disetujui manager)
  List<Map<String, dynamic>> schedules = [];
  
  // Notifikasi
  int unreadNotifications = 0;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // Stream subscriptions
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  
  // Loading state
  bool isLoading = true;
  bool isRefreshing = false;
  bool isProcessingConfirmation = false;
  
  // Timer for live clock
  Timer? _clockTimer;
  
  // Current location
  Position? _currentPosition;
  
  // Selected menu index
  int _selectedMenuIndex = 0;
  
  // Page controller untuk carousel
  late PageController _pageController;
  int _currentCarouselIndex = 0;
  
  // Dialog controller
  OverlayEntry? _overlayEntry;
  
  // List warna gradien untuk variasi
  final List<List<Color>> _gradientColors = [
    [const Color(0xFF4158D0), const Color(0xFFC850C0), const Color(0xFFFFCC70)],
    [const Color(0xFF0093E9), const Color(0xFF80D0C7)],
    [const Color(0xFF8EC5FC), const Color(0xFFE0C3FC)],
    [const Color(0xFFFBAB7E), const Color(0xFFF7CE68)],
    [const Color(0xFF85FFBD), const Color(0xFFFFFB7D)],
    [const Color(0xFFA9C9FF), const Color(0xFFFFBBEC)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _pageController = PageController();
    
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    
    _getCurrentUser();
    _setupRealTimeListeners();
    _slideController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    _progressController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Color _colorWithOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  // ==================== DATA INITIALIZATION ====================

  Future<void> _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
        userPhotoUrl = user.photoURL;
      });
      await _loadUserData();
      await _loadAbsensiData();
      await _loadOvertimeData();
      await _loadOvertimeSettings();
      await _loadScheduleData();
      await _loadPendingOvertimeRequests(); // Load pending lembur untuk dikonfirmasi
      await _loadNotificationsCount();
      await _getCurrentLocation();
      await _loadConfirmedOvertimeIds(); // Load ID lembur yang sudah dikonfirmasi
    }
  }

  Future<void> _loadUserData() async {
    if (userId == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          userData = data;
          userFungsi = data['fungsi'];
          userName = data['nama_lengkap'] ?? data['email']?.split('@')[0] ?? 'Mitra';
        });
      }
    } catch (e) {
      logger.e('Error loading user data: $e');
    }
  }

  // ==================== LOAD PENDING OVERTIME REQUESTS (JADWAL LEMBUR BARU UNTUK KONFIRMASI) ====================
  Future<void> _loadPendingOvertimeRequests() async {
    if (userId == null) return;
    
    try {
      final now = DateTime.now();
      
      // Ambil lembur yang statusnya 'pending' dan ditujukan untuk mitra ini
      final snapshot = await _firestore
          .collection('lembur')
          .where('status', isEqualTo: 'pending')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 1))))
          .orderBy('tanggal', descending: false)
          .get();
      
      final List<Map<String, dynamic>> pendingRequests = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tanggal = data['tanggal'] != null 
            ? (data['tanggal'] as Timestamp).toDate()
            : null;
        
        // Cek apakah lembur ini untuk mitra ini
        bool isForThisMitra = false;
        
        if (data['mitra_id'] != null && data['mitra_id'] == userId) {
          isForThisMitra = true;
        } else if (data['mitra_ids'] != null && data['mitra_ids'] is List) {
          final mitraIds = List<String>.from(data['mitra_ids']);
          isForThisMitra = mitraIds.contains(userId);
        }
        
        // Cek apakah lembur ini sudah dikonfirmasi
        final isConfirmed = confirmedOvertimeIds.contains(doc.id);
        
        if (isForThisMitra && !isConfirmed && tanggal != null && 
            tanggal.isAfter(now.subtract(const Duration(days: 2)))) {
          pendingRequests.add({
            'id': doc.id,
            'tanggal': data['tanggal'],
            'jam_mulai': data['jam_mulai'] ?? '19:00',
            'jam_selesai': data['jam_selesai'] ?? '22:00',
            'total_jam': data['total_jam'] ?? 3,
            'alasan': data['alasan'] ?? 'Lembur operasional',
            'pengawas_nama': data['nama_pengawas'] ?? 'Pengawas',
            'pengawas_id': data['pengawas_id'],
            'pengawas_fungsi': data['pengawas_fungsi'] ?? '',
            'urgensi': data['urgensi'] ?? 'normal',
            'jenis_lembur': data['jenis_lembur'] ?? 'hari_kerja',
            'lokasi': data['lokasi'] != null ? data['lokasi']['pilihan'] ?? 'kantor' : 'kantor',
            'estimasi_biaya': data['estimasi_biaya_per_mitra'] ?? 0,
          });
        }
      }
      
      setState(() {
        pendingOvertimeRequests = pendingRequests;
      });
      
      // Tampilkan popup jika ada jadwal lembur baru
      if (pendingOvertimeRequests.isNotEmpty && mounted) {
        _showPendingOvertimeDialog();
      }
      
      logger.i('✅ Loaded ${pendingRequests.length} pending overtime requests for confirmation');
      
    } catch (e) {
      logger.e('Error loading pending overtime: $e');
    }
  }

  Future<void> _loadConfirmedOvertimeIds() async {
    if (userId == null) return;
    
    try {
      final doc = await _firestore
          .collection('mitra_confirmations')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final confirmedIds = List<String>.from(data['confirmed_overtime_ids'] ?? []);
        setState(() {
          confirmedOvertimeIds = confirmedIds;
        });
      }
    } catch (e) {
      logger.e('Error loading confirmed overtime ids: $e');
    }
  }

  Future<void> _saveConfirmedOvertimeId(String overtimeId) async {
    if (userId == null) return;
    
    try {
      final updatedIds = [...confirmedOvertimeIds, overtimeId];
      setState(() {
        confirmedOvertimeIds = updatedIds;
      });
      
      await _firestore.collection('mitra_confirmations').doc(userId).set({
        'confirmed_overtime_ids': updatedIds,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      logger.e('Error saving confirmed overtime id: $e');
    }
  }

  Future<void> _loadOvertimeSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('overtime_rates').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          overtimeSettings = {
            'base_salary': (data['base_salary'] as num?)?.toInt() ?? 3000000,
            'first_8_hours_multiplier': (data['first_8_hours_multiplier'] as num?)?.toInt() ?? 2,
            'ninth_hour_multiplier': (data['ninth_hour_multiplier'] as num?)?.toInt() ?? 3,
            'tenth_plus_multiplier': (data['tenth_plus_multiplier'] as num?)?.toInt() ?? 4,
            'rate_per_hour': (data['rate_per_hour'] as num?)?.toDouble() ?? 17341.04,
          };
        });
      } else {
        setState(() {
          overtimeSettings = {
            'base_salary': 3000000,
            'first_8_hours_multiplier': 2,
            'ninth_hour_multiplier': 3,
            'tenth_plus_multiplier': 4,
            'rate_per_hour': 17341.04,
          };
        });
      }
    } catch (e) {
      logger.e('Error loading overtime settings: $e');
      setState(() {
        overtimeSettings = {
          'base_salary': 3000000,
          'first_8_hours_multiplier': 2,
          'ninth_hour_multiplier': 3,
          'tenth_plus_multiplier': 4,
          'rate_per_hour': 17341.04,
        };
      });
    }
  }

  double _calculateOvertimeIncome(int hours, Map<String, dynamic> settings) {
    if (settings.isEmpty) return 0.0;
    
    final ratePerHour = (settings['rate_per_hour'] as num?)?.toDouble() ?? 17341.04;
    final first8Multiplier = (settings['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (settings['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthPlusMultiplier = (settings['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;
    
    double totalIncome = 0.0;
    
    if (hours <= 8) {
      totalIncome = hours * ratePerHour * first8Multiplier;
    } else if (hours == 9) {
      totalIncome = (8 * ratePerHour * first8Multiplier) + (1 * ratePerHour * ninthMultiplier);
    } else {
      totalIncome = (8 * ratePerHour * first8Multiplier) + 
                    (1 * ratePerHour * ninthMultiplier) + 
                    ((hours - 9) * ratePerHour * tenthPlusMultiplier);
    }
    
    return totalIncome;
  }

  // ==================== KONFIRMASI LEMBUR OLEH MITRA ====================
  Future<void> _confirmOvertime(Map<String, dynamic> overtime) async {
    if (isProcessingConfirmation) return;
    setState(() => isProcessingConfirmation = true);
    
    try {
      final overtimeId = overtime['id'];
      
      // Simpan konfirmasi ke collection mitra_confirmations
      await _saveConfirmedOvertimeId(overtimeId);
      
      // Buat notifikasi untuk pengawas bahwa mitra sudah konfirmasi
      await _firestore.collection('notifications').add({
        'userId': overtime['pengawas_id'],
        'title': 'Konfirmasi Lembur',
        'body': '$userName telah mengkonfirmasi jadwal lembur',
        'type': 'lembur_confirmed',
        'lemburId': overtimeId,
        'mitraId': userId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Tampilkan popup validasi (menunggu approval manager)
      _showOvertimeValidationPopup(overtime, accepted: true, waitingForManager: true);
      
      // Refresh data
      await _refreshData();
      
      if (mounted) {
        _showSuccessSnackbar('Konfirmasi berhasil! Menunggu persetujuan Manager.');
      }
      
    } catch (e) {
      logger.e('Error confirming overtime: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal mengkonfirmasi jadwal lembur');
      }
    } finally {
      if (mounted) setState(() => isProcessingConfirmation = false);
    }
  }

  Future<void> _rejectOvertime(Map<String, dynamic> overtime, {String? reason}) async {
    if (isProcessingConfirmation) return;
    setState(() => isProcessingConfirmation = true);
    
    try {
      final overtimeId = overtime['id'];
      
      // Simpan penolakan
      await _saveConfirmedOvertimeId(overtimeId);
      
      // Buat notifikasi untuk pengawas
      await _firestore.collection('notifications').add({
        'userId': overtime['pengawas_id'],
        'title': 'Penolakan Lembur',
        'body': '$userName menolak jadwal lembur${reason != null ? ': $reason' : ''}',
        'type': 'lembur_rejected',
        'lemburId': overtimeId,
        'mitraId': userId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Tampilkan popup validasi ditolak
      _showOvertimeValidationPopup(overtime, accepted: false);
      
      // Refresh data
      await _refreshData();
      
      if (mounted) {
        _showSuccessSnackbar('Jadwal lembur ditolak');
      }
      
    } catch (e) {
      logger.e('Error rejecting overtime: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal menolak jadwal lembur');
      }
    } finally {
      if (mounted) setState(() => isProcessingConfirmation = false);
    }
  }

  // ==================== SHOW POPUP JADWAL LEMBUR BARU ====================
  void _showPendingOvertimeDialog() {
    if (pendingOvertimeRequests.isEmpty) return;
    
    // Hanya tampilkan satu per satu
    final overtime = pendingOvertimeRequests.first;
    final tanggal = (overtime['tanggal'] as Timestamp).toDate();
    final isToday = DateFormat('yyyy-MM-dd').format(tanggal) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
    final daysDiff = tanggal.difference(DateTime.now()).inDays;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A2B4C),
                const Color(0xFF2A3F66),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Jadwal Lembur Baru!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda mendapatkan jadwal lembur baru. Konfirmasi keikutsertaan Anda.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Detail card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                            color: const Color(0xFFFF6B35),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'HARI INI' : DateFormat('EEEE, dd MMM yyyy').format(tanggal),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A2B4C),
                                ),
                              ),
                              if (!isToday && daysDiff == 1)
                                Text(
                                  'Besok',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'Waktu Lembur',
                      '${overtime['jam_mulai']} - ${overtime['jam_selesai']} WIB',
                      const Color(0xFF1A2B4C),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      Icons.timer_rounded,
                      'Durasi',
                      '${overtime['total_jam']} Jam',
                      const Color(0xFF1A2B4C),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      Icons.person_outline_rounded,
                      'Pengawas',
                      overtime['pengawas_nama'],
                      const Color(0xFF1A2B4C),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      Icons.location_on_rounded,
                      'Lokasi',
                      overtime['lokasi'] == 'kantor' ? 'Kantor Pusat' : 
                      (overtime['lokasi'] == 'proyek' ? 'Lokasi Proyek' : overtime['lokasi']),
                      const Color(0xFF1A2B4C),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      Icons.money_rounded,
                      'Estimasi Pendapatan',
                      'Rp ${NumberFormat('#,###').format(overtime['estimasi_biaya'])}',
                      Colors.green,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildResponseButton(
                      label: 'Tolak',
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _showRejectionReasonDialog(overtime);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildResponseButton(
                      label: 'Konfirmasi',
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmOvertime(overtime);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Ingatkan Nanti',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildResponseButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionReasonDialog(Map<String, dynamic> overtime) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Alasan Penolakan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Berikan alasan mengapa Anda menolak jadwal lembur ini',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Contoh: Ada keperluan keluarga',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _rejectOvertime(overtime, reason: reasonController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Kirim Penolakan'),
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

  // ==================== POPUP JADWAL LEMBUR TERVALIDASI ====================
  void _showOvertimeValidationPopup(Map<String, dynamic> overtime, 
      {required bool accepted, bool waitingForManager = false}) {
    final tanggal = (overtime['tanggal'] as Timestamp).toDate();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: accepted
                  ? [Colors.green.shade700, Colors.green.shade500]
                  : [Colors.red.shade700, Colors.red.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                accepted 
                    ? (waitingForManager ? 'Konfirmasi Diterima!' : 'Lembur Tervalidasi!')
                    : 'Konfirmasi Ditolak',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                accepted
                    ? (waitingForManager 
                        ? 'Konfirmasi Anda telah direkam. Menunggu persetujuan Manager.'
                        : 'Jadwal lembur Anda telah dikonfirmasi dan disetujui Manager.')
                    : 'Jadwal lembur telah ditolak',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: accepted ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, dd MMM yyyy').format(tanggal),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${overtime['jam_mulai']} - ${overtime['jam_selesai']} WIB',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pengawas: ${overtime['pengawas_nama']}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (waitingForManager && accepted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Menunggu persetujuan Manager. Button check-in akan muncul setelah lembur disetujui.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              if (!waitingForManager && accepted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFFF6B35), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Button Check-in akan muncul di dashboard pada hari lembur',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFFF6B35),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accepted ? Colors.green : Colors.red,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LOAD OVERTIME DATA ====================
  Future<void> _loadOvertimeData() async {
    if (userId == null) return;
    
    try {
      final now = DateTime.now();
      final tahunBulan = DateFormat('yyyy-MM').format(now);
      
      // Ambil lembur yang sudah disetujui manager (status disetujui) untuk mitra ini
      final snapshot = await _firestore
          .collection('lembur')
          .where('mitra_id', isEqualTo: userId)
          .orderBy('tanggal', descending: true)
          .limit(50)
          .get();
      
      final List<Map<String, dynamic>> requests = [];
      int totalApproved = 0;
      int totalPending = 0;
      int totalRejected = 0;
      int totalSelesai = 0;
      int totalJamLembur = 0;
      double totalIncome = 0.0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        requests.add(data);
        
        final status = data['status'] ?? 'pending';
        final absensiStatus = data['absensi_status'];
        final isCompleted = status == 'selesai';
        final hasValidAttendance = 
            absensiStatus == 'check_out' || 
            absensiStatus == 'selesai' ||
            (data['absensi_waktu'] != null && data['absensi_checkout_waktu'] != null);
        
        if (status == 'selesai' && hasValidAttendance) {
          totalSelesai++;
          if (data['tahun_bulan'] == tahunBulan) {
            final totalJam = (data['actual_total_jam'] as num?)?.toInt() ?? 
                            (data['total_jam'] as num?)?.toInt() ?? 0;
            totalJamLembur += totalJam;
            
            if (data['income_amount'] != null) {
              totalIncome += (data['income_amount'] as num?)?.toDouble() ?? 0.0;
            } else if (overtimeSettings != null) {
              final income = _calculateOvertimeIncome(totalJam, overtimeSettings!);
              totalIncome += income;
              
              await _firestore.collection('lembur').doc(doc.id).update({
                'income_amount': income,
                'is_income_calculated': true,
                'income_calculated_at': FieldValue.serverTimestamp(),
              });
            }
          }
        } else if (status == 'disetujui') {
          totalApproved++;
        } else if (status == 'pending') {
          totalPending++;
        } else if (status == 'ditolak') {
          totalRejected++;
        }
      }
      
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);
      
      Map<String, dynamic>? todayOvertimeData;
      for (var r in requests) {
        final tanggal = r['tanggal'] != null 
            ? (r['tanggal'] as Timestamp).toDate() 
            : null;
        final status = r['status'] ?? '';
        if (tanggal != null && 
            DateFormat('yyyy-MM-dd').format(tanggal) == todayDateStr &&
            status == 'disetujui') {
          todayOvertimeData = r;
          break;
        }
      }
      
      final List<Map<String, dynamic>> approvedFuture = [];
      for (var r in requests) {
        final status = r['status'] ?? '';
        final tanggal = r['tanggal'] != null 
            ? (r['tanggal'] as Timestamp).toDate() 
            : null;
        if (status == 'disetujui' && 
            tanggal != null && 
            tanggal.isAfter(now.subtract(const Duration(hours: 12)))) {
          approvedFuture.add(r);
        }
      }
      
      approvedFuture.sort((a, b) {
        final dateA = (a['tanggal'] as Timestamp).toDate();
        final dateB = (b['tanggal'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });
      
      final sisaKuota = 60 - totalJamLembur;
      
      setState(() {
        overtimeRequests = requests;
        todayOvertime = todayOvertimeData;
        approvedOvertime = approvedFuture.isNotEmpty ? approvedFuture.first : null;
        stats = {
          ...stats,
          'totalLembur': totalApproved + totalSelesai,
          'totalJamLembur': totalJamLembur,
          'sisaKuota': sisaKuota > 0 ? sisaKuota : 0,
          'pending': totalPending,
          'disetujui': totalApproved,
          'ditolak': totalRejected,
          'selesai': totalSelesai,
          'totalIncome': totalIncome,
        };
      });
    } catch (e) {
      logger.e('Error loading overtime: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==================== LOAD SCHEDULE DARI LEMBUR YANG DISETUJUI MANAGER ====================
  Future<void> _loadScheduleData() async {
    if (userId == null) return;
    
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      // AMBIL DATA DARI COLLECTION LEMBUR YANG STATUSNYA DISETUJUI (oleh manager)
      final snapshot = await _firestore
          .collection('lembur')
          .where('mitra_id', isEqualTo: userId)
          .where('status', isEqualTo: 'disetujui')
          .orderBy('tanggal', descending: false)
          .get();
      
      final List<Map<String, dynamic>> lemburSchedules = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tanggal = data['tanggal'] != null 
            ? (data['tanggal'] as Timestamp).toDate()
            : null;
        
        if (tanggal != null && 
            tanggal.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            tanggal.isBefore(endOfWeek.add(const Duration(days: 1)))) {
          
          lemburSchedules.add({
            'id': doc.id,
            'tanggal': data['tanggal'],
            'shift': 'Lembur',
            'jam_mulai': data['jam_mulai'] ?? '19:00',
            'jam_selesai': data['jam_selesai'] ?? '22:00',
            'jenis': 'lembur',
            'status': data['status'],
            'absensi_status': data['absensi_status'] ?? 'belum_absen',
            'pengawas_nama': data['nama_pengawas'],
            'fungsi_pengawas': data['pengawas_fungsi'],
            'total_jam': data['total_jam_desimal'] ?? data['total_jam'] ?? 0,
          });
        }
      }
      
      lemburSchedules.sort((a, b) {
        final dateA = (a['tanggal'] as Timestamp).toDate();
        final dateB = (b['tanggal'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });
      
      setState(() {
        schedules = lemburSchedules;
      });
      
      if (lemburSchedules.isNotEmpty) {
        logger.i('✅ Loaded ${lemburSchedules.length} schedule(s) from lembur collection (approved by manager)');
      }
      
    } catch (e) {
      logger.e('Error loading schedule from lembur: $e');
    }
  }

  Future<void> _loadAbsensiData() async {
    if (userId == null) return;
    
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snapshot = await _firestore
          .collection('absensi')
          .where('user_id', isEqualTo: userId)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('waktu', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          todayAbsensi = data;
          
          if (data['waktu'] != null) {
            lastCheckIn = (data['waktu'] as Timestamp).toDate();
            isCheckedIn = true;
          }
          
          if (data['waktu_checkout'] != null) {
            lastCheckOut = (data['waktu_checkout'] as Timestamp).toDate();
            isCheckedOut = true;
          }
          
          if (lastCheckIn != null) {
            final endTime = lastCheckOut ?? DateTime.now();
            workDuration = endTime.difference(lastCheckIn!);
          }
        });
      }
    } catch (e) {
      logger.e('Error loading absensi: $e');
    }
  }

  Future<void> _loadNotificationsCount() async {
    if (userId == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      
      setState(() {
        unreadNotifications = snapshot.count ?? 0;
      });
    } catch (e) {
      logger.e('Error loading notifications count: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      logger.e('Error getting location: $e');
    }
  }

  void _setupRealTimeListeners() {
    if (userId == null) return;
    
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final absensiSub = _firestore
          .collection('absensi')
          .where('user_id', isEqualTo: userId)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('waktu', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          setState(() {
            todayAbsensi = data;
            isCheckedIn = data['waktu'] != null;
            isCheckedOut = data['waktu_checkout'] != null;
            if (data['waktu'] != null) {
              lastCheckIn = (data['waktu'] as Timestamp).toDate();
            }
            if (data['waktu_checkout'] != null) {
              lastCheckOut = (data['waktu_checkout'] as Timestamp).toDate();
            }
            if (lastCheckIn != null) {
              final endTime = lastCheckOut ?? DateTime.now();
              workDuration = endTime.difference(lastCheckIn!);
            }
          });
        } else {
          setState(() {
            todayAbsensi = null;
            isCheckedIn = false;
            isCheckedOut = false;
            lastCheckIn = null;
            lastCheckOut = null;
            workDuration = null;
          });
        }
      });
      _subscriptions.add(absensiSub);
    } catch (e) {
      logger.e('Error setting up absensi listener: $e');
    }
    
    try {
      final overtimeSub = _firestore
          .collection('lembur')
          .where('mitra_id', isEqualTo: userId)
          .orderBy('tanggal', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        _loadOvertimeData();
        _loadScheduleData();
      });
      _subscriptions.add(overtimeSub);
    } catch (e) {
      logger.e('Error setting up overtime listener: $e');
    }
    
    // Listener untuk pending overtime baru
    try {
      final pendingSub = _firestore
          .collection('lembur')
          .where('status', isEqualTo: 'pending')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
          .snapshots()
          .listen((snapshot) {
        _loadPendingOvertimeRequests();
      });
      _subscriptions.add(pendingSub);
    } catch (e) {
      logger.e('Error setting up pending overtime listener: $e');
    }
    
    try {
      final settingsSub = _firestore
          .collection('settings')
          .doc('overtime_rates')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          setState(() {
            overtimeSettings = {
              'base_salary': (data['base_salary'] as num?)?.toInt() ?? 3000000,
              'first_8_hours_multiplier': (data['first_8_hours_multiplier'] as num?)?.toInt() ?? 2,
              'ninth_hour_multiplier': (data['ninth_hour_multiplier'] as num?)?.toInt() ?? 3,
              'tenth_plus_multiplier': (data['tenth_plus_multiplier'] as num?)?.toInt() ?? 4,
              'rate_per_hour': (data['rate_per_hour'] as num?)?.toDouble() ?? 17341.04,
            };
          });
          _loadOvertimeData();
        }
      });
      _subscriptions.add(settingsSub);
    } catch (e) {
      logger.e('Error setting up settings listener: $e');
    }
    
    try {
      final notifSub = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          unreadNotifications = snapshot.docs.length;
        });
      });
      _subscriptions.add(notifSub);
    } catch (e) {
      logger.e('Error setting up notifications listener: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadUserData();
    await _loadAbsensiData();
    await _loadOvertimeData();
    await _loadOvertimeSettings();
    await _loadScheduleData();
    await _loadPendingOvertimeRequests();
    await _loadNotificationsCount();
    await _getCurrentLocation();
    setState(() => isRefreshing = false);
  }

  // ==================== ABSENSI LEMBUR ====================

  Future<void> _checkInLembur(String lemburId) async {
    if (_currentPosition == null) {
      if (mounted) {
        _showErrorSnackbar('Aktifkan lokasi untuk melakukan absensi');
      }
      return;
    }

    try {
      final lemburDoc = await _firestore.collection('lembur').doc(lemburId).get();
      if (!lemburDoc.exists) {
        if (mounted) {
          _showErrorSnackbar('Data lembur tidak ditemukan');
        }
        return;
      }

      final lemburData = lemburDoc.data()!;
      
      if (lemburData['absensi_status'] == 'check_in' || lemburData['absensi_status'] == 'check_out') {
        if (mounted) {
          _showErrorSnackbar('Anda sudah melakukan absensi untuk lembur ini');
        }
        return;
      }

      final absensiData = {
        'lembur_id': lemburId,
        'user_id': userId,
        'user_name': userName,
        'foto_url': '',
        'waktu': FieldValue.serverTimestamp(),
        'tanggal_lembur': lemburData['tanggal'],
        'pengawas_id': lemburData['pengawas_id'],
        'created_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('lembur').doc(lemburId).update({
        'absensi_status': 'check_in',
        'absensi_waktu': FieldValue.serverTimestamp(),
        'absensi_foto_url': '',
        'absensi_oleh': userId,
        'absensi_nama': userName,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('absensi').add(absensiData);

      await _firestore.collection('notifications').add({
        'userId': lemburData['pengawas_id'],
        'title': 'Absensi Lembur',
        'body': '$userName telah check-in lembur',
        'type': 'lembur_checkin',
        'lemburId': lemburId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _refreshData();
      if (mounted) {
        _showSuccessSnackbar('Berhasil check-in lembur');
      }
    } catch (e) {
      logger.e('Error checking in lembur: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal check-in lembur');
      }
    }
  }

  Future<void> _checkOutLembur(String lemburId) async {
    if (_currentPosition == null) {
      if (mounted) {
        _showErrorSnackbar('Aktifkan lokasi untuk melakukan absensi');
      }
      return;
    }

    try {
      final lemburDoc = await _firestore.collection('lembur').doc(lemburId).get();
      if (!lemburDoc.exists) {
        if (mounted) {
          _showErrorSnackbar('Data lembur tidak ditemukan');
        }
        return;
      }

      final lemburData = lemburDoc.data()!;
      
      if (lemburData['absensi_status'] == 'check_out' || lemburData['absensi_status'] == 'selesai') {
        if (mounted) {
          _showErrorSnackbar('Anda sudah check-out untuk lembur ini');
        }
        return;
      }

      final absensiQuery = await _firestore
          .collection('absensi')
          .where('lembur_id', isEqualTo: lemburId)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (absensiQuery.docs.isEmpty) {
        if (mounted) {
          _showErrorSnackbar('Data absensi tidak ditemukan');
        }
        return;
      }

      final absensiDoc = absensiQuery.docs.first;
      final checkInTime = (lemburData['absensi_waktu'] as Timestamp).toDate();
      final checkOutTime = DateTime.now();
      
      final actualDuration = checkOutTime.difference(checkInTime);
      final actualHours = actualDuration.inMinutes / 60.0;
      
      double actualIncome = 0.0;
      if (overtimeSettings != null && actualHours > 0) {
        actualIncome = _calculateOvertimeIncome(actualHours.ceil(), overtimeSettings!);
      }
      
      await _firestore.collection('lembur').doc(lemburId).update({
        'absensi_status': 'selesai',
        'absensi_checkout_waktu': FieldValue.serverTimestamp(),
        'absensi_checkout_foto_url': '',
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
        'actual_total_jam': actualHours,
        'actual_income': actualIncome,
        'income_amount': actualIncome,
        'is_income_calculated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('absensi').doc(absensiDoc.id).update({
        'waktu_checkout': FieldValue.serverTimestamp(),
        'foto_checkout_url': '',
        'actual_duration': actualDuration.inMinutes,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'userId': lemburData['pengawas_id'],
        'title': 'Lembur Selesai',
        'body': '$userName telah menyelesaikan lembur (${actualHours.toStringAsFixed(1)} jam)',
        'type': 'lembur_completed',
        'lemburId': lemburId,
        'income': actualIncome,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _refreshData();
      if (mounted) {
        _showSuccessSnackbar('Berhasil check-out lembur! Pendapatan: Rp ${NumberFormat('#,###').format(actualIncome)}');
      }
    } catch (e) {
      logger.e('Error checking out lembur: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal check-out lembur');
      }
    }
  }

  // ==================== HELPER METHODS ====================

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '-';
    
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return '-';
    }
    
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00:00';
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatTimeOfDay(DateTime? time) {
    if (time == null) return '-:-';
    return DateFormat('HH:mm').format(time);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
      case 'selesai':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'check_in':
        return Colors.blue;
      case 'check_out':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu';
      case 'ditolak':
        return 'Ditolak';
      case 'selesai':
        return 'Selesai';
      case 'check_in':
        return 'Check In';
      case 'check_out':
        return 'Check Out';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'disetujui':
      case 'selesai':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'ditolak':
        return Icons.cancel;
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      default:
        return Icons.info;
    }
  }

  double _getWorkProgress() {
    if (!isCheckedIn || isCheckedOut) return 0;
    if (lastCheckIn == null) return 0;
    
    final now = DateTime.now();
    final targetEnd = DateTime(now.year, now.month, now.day, 17, 0);
    
    if (now.isAfter(targetEnd)) return 1.0;
    
    final totalWork = targetEnd.difference(lastCheckIn!).inMinutes;
    final worked = now.difference(lastCheckIn!).inMinutes;
    
    if (totalWork <= 0) return 0;
    return (worked / totalWork).clamp(0.0, 1.0);
  }

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

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showIncomeDetails() {
    final totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalHours = (stats['totalJamLembur'] as num?)?.toInt() ?? 0;
    final totalSelesai = (stats['selesai'] as num?)?.toInt() ?? 0;
    
    final completedOvertime = overtimeRequests.where((o) => 
      o['status'] == 'selesai' && 
      (o['absensi_status'] == 'selesai' || 
       (o['absensi_waktu'] != null && o['absensi_checkout_waktu'] != null))
    ).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2B4C).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_rounded,
                          color: Color(0xFF1A2B4C),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Pendapatan Lembur',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A2B4C),
                              ),
                            ),
                            Text(
                              '$totalSelesai Lembur Terselesaikan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Pendapatan',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Rp ${NumberFormat('#,###').format(totalIncome)}',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dari $totalHours Jam Lembur',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (completedOvertime.isNotEmpty) ...[
                    Text(
                      'Rincian Lembur Terselesaikan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2B4C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: completedOvertime.length,
                        itemBuilder: (context, index) {
                          final item = completedOvertime[index];
                          final tanggal = (item['tanggal'] as Timestamp).toDate();
                          final actualHours = (item['actual_total_jam'] as num?)?.toDouble() ?? 
                                              (item['total_jam'] as num?)?.toInt() ?? 0;
                          final income = (item['actual_income'] as num?)?.toDouble() ??
                                        (item['income_amount'] as num?)?.toDouble() ?? 0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(tanggal),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1A2B4C),
                                        ),
                                      ),
                                      Text(
                                        '${actualHours.toStringAsFixed(1)} jam',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rp ${NumberFormat('#,###').format(income)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  if (completedOvertime.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada lembur yang terselesaikan',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Lakukan check-in dan check-out untuk mendapatkan pendapatan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2B4C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final now = DateTime.now();
    final currentHour = now.hour;
    final greeting = _getGreeting(currentHour);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Halo, $userName!',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A2B4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _showDrawerMenu(context),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () => _showNotifications(context),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _colorWithOpacity(Colors.white, 0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPosition != null
                        ? 'Lokasi: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                        : 'Aktifkan lokasi untuk absensi',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1A2B4C),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildWelcomeCard(user, greeting, now),
                    ),
                    const SizedBox(height: 16),
                    
                    // Badge notifikasi untuk pending overtime (perlu dikonfirmasi)
                    if (pendingOvertimeRequests.isNotEmpty)
                      _buildPendingOvertimeBadge(),
                    
                    const SizedBox(height: 16),
                    
                    _buildQuickStats(),
                    const SizedBox(height: 20),
                    
                    _buildIncomeCard(),
                    const SizedBox(height: 20),
                    
                    // Tampilkan card lembur hari ini dengan button check-in/check-out
                    // Hanya jika lembur sudah disetujui oleh manager
                    if (todayOvertime != null) ...[
                      _buildTodayOvertimeCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    _buildAbsensiCard(),
                    const SizedBox(height: 20),
                    
                    _buildFeatureCarousel(),
                    const SizedBox(height: 20),
                    
                    _buildQuickActionsGrid(),
                    const SizedBox(height: 20),
                    
                    if (approvedOvertime != null && approvedOvertime != todayOvertime) ...[
                      _buildUpcomingOvertimeCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Jadwal Lembur Hari Ini (dari data lembur yang sudah disetujui manager)
                    _buildTodayLemburSchedule(),
                    const SizedBox(height: 20),
                    
                    if (overtimeRequests.isNotEmpty) ...[
                      _buildRecentOvertime(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Jadwal Lembur Minggu Ini (dari data lembur yang sudah disetujui manager)
                    _buildWeeklyLemburSchedule(),
                    const SizedBox(height: 20),
                    
                    _buildCompanyFeatures(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPendingOvertimeBadge() {
    return GestureDetector(
      onTap: () {
        if (pendingOvertimeRequests.isNotEmpty) {
          _showPendingOvertimeDialog();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ada ${pendingOvertimeRequests.length} Jadwal Lembur Baru!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Klik untuk melihat dan konfirmasi keikutsertaan Anda',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + (value * 0.5),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2B4C), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          Text(
            'Memuat Dashboard...',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Mohon tunggu sebentar',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Widget _buildWelcomeCard(User? user, String greeting, DateTime now) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A2B4C),
            const Color(0xFF2A3F66),
            _colorWithOpacity(const Color(0xFF3A5290), 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFFF6B35)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _colorWithOpacity(const Color(0xFFFF6B35), 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: userPhotoUrl != null
                      ? NetworkImage(userPhotoUrl!)
                      : null,
                  child: userPhotoUrl == null
                      ? Text(
                          userName?[0].toUpperCase() ?? 'M',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1A2B4C),
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName ?? 'Mitra',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work_rounded,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            userData?['fungsi_label']?.toString() ?? 
                            userData?['fungsi']?.toString().toUpperCase() ?? 
                            'MITRA',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCheckedIn 
                          ? (isCheckedOut ? Colors.grey : Colors.green)
                          : const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _colorWithOpacity(isCheckedIn 
                              ? (isCheckedOut ? Colors.grey : Colors.green)
                              : const Color(0xFFFF6B35), 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCheckedIn
                              ? (isCheckedOut ? Icons.check_circle : Icons.access_time)
                              : Icons.schedule,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCheckedIn
                              ? (isCheckedOut ? 'Selesai' : 'Aktif')
                              : 'Belum Absen',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      DateFormat('dd MMM').format(now),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final sisaKuota = ((stats['sisaKuota'] ?? 0) as num).clamp(0, 60).toInt();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time_rounded,
            value: '${(stats['totalJamLembur'] ?? 0)}',
            label: 'Jam Lembur',
            color: Colors.blue,
            gradient: const [Color(0xFF4158D0), Color(0xFFC850C0)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.hourglass_bottom_rounded,
            value: '$sisaKuota',
            label: 'Sisa Kuota',
            color: Colors.orange,
            gradient: const [Color(0xFFFF6B35), Color(0xFFFF8A5C)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions_rounded,
            value: '${(stats['pending'] ?? 0)}',
            label: 'Pending',
            color: Colors.purple,
            gradient: const [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeCard() {
    final totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalSelesai = (stats['selesai'] as num?)?.toInt() ?? 0;
    
    return GestureDetector(
      onTap: _showIncomeDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _colorWithOpacity(Colors.green, 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pendapatan Lembur',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Rp ${NumberFormat('#,###').format(totalIncome)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalSelesai Lembur terselesaikan',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(color, 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOvertimeCard() {
    if (todayOvertime == null) return const SizedBox();
    
    final jamMulai = todayOvertime!['jam_mulai'] ?? '19:00';
    final jamSelesai = todayOvertime!['jam_selesai'] ?? '22:00';
    final status = todayOvertime!['absensi_status'] ?? 'belum_absen';
    final isCheckedInLembur = status == 'check_in';
    final isCheckedOutLembur = status == 'check_out' || status == 'selesai';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCheckedOutLembur
              ? [Colors.green.shade700, Colors.green.shade500]
              : isCheckedInLembur
                  ? [Colors.orange.shade700, Colors.orange.shade500]
                  : [const Color(0xFFFF6B35), const Color(0xFFFF8A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(isCheckedOutLembur 
                ? Colors.green 
                : isCheckedInLembur 
                    ? Colors.orange 
                    : const Color(0xFFFF6B35), 0.3),
            blurRadius: 15,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckedOutLembur
                      ? Icons.check_circle
                      : isCheckedInLembur
                          ? Icons.access_time
                          : Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckedOutLembur
                          ? 'Lembur Selesai!'
                          : isCheckedInLembur
                              ? 'Sedang Lembur'
                              : 'Jadwal Lembur Hari Ini!',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isCheckedOutLembur
                          ? 'Anda telah menyelesaikan lembur'
                          : isCheckedInLembur
                              ? 'Anda sedang dalam sesi lembur'
                              : 'Jangan lupa check-in tepat waktu',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$jamMulai - $jamSelesai WIB',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isCheckedOutLembur)
                  Row(
                    children: [
                      if (!isCheckedInLembur)
                        GestureDetector(
                          onTap: () => _checkInLembur(todayOvertime!['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  color: const Color(0xFFFF6B35),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Check In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (isCheckedInLembur && !isCheckedOutLembur) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _checkOutLembur(todayOvertime!['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.orange.shade700,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Check Out',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsensiCard() {
    final progress = _getWorkProgress();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(Colors.grey, 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jam Kerja Hari Ini',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A2B4C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF1A2B4C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '08:00 - 17:00 WIB',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? (isCheckedOut ? _colorWithOpacity(Colors.grey, 0.1) : _colorWithOpacity(Colors.green, 0.1))
                      : _colorWithOpacity(const Color(0xFFFF6B35), 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCheckedIn
                        ? (isCheckedOut ? Colors.grey : Colors.green)
                        : const Color(0xFFFF6B35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCheckedIn
                          ? (isCheckedOut ? Icons.check_circle : Icons.access_time_rounded)
                          : Icons.schedule_rounded,
                      color: isCheckedIn
                          ? (isCheckedOut ? Colors.grey : Colors.green)
                          : const Color(0xFFFF6B35),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCheckedIn
                          ? (isCheckedOut ? 'Selesai' : 'Sedang Bekerja')
                          : 'Belum Check In',
                      style: GoogleFonts.poppins(
                        color: isCheckedIn
                            ? (isCheckedOut ? Colors.grey : Colors.green)
                            : const Color(0xFFFF6B35),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (isCheckedIn && !isCheckedOut) ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress Kerja',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2B4C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A2B4C)),
                        minHeight: 10,
                      ),
                    ),
                    if (progress > 0)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _colorWithOpacity(const Color(0xFF1A2B4C), 0.5),
                                Colors.transparent,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check In',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimeOfDay(lastCheckIn),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A2B4C),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 14,
                            color: const Color(0xFF1A2B4C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(workDuration),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A2B4C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Check In',
                  icon: Icons.login_rounded,
                  time: lastCheckIn,
                  isActive: !isCheckedIn,
                  color: Colors.green,
                  onTap: () => _navigateToAbsensi(context, initialTab: 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Check Out',
                  icon: Icons.logout_rounded,
                  time: lastCheckOut,
                  isActive: isCheckedIn && !isCheckedOut,
                  color: Colors.orange,
                  onTap: () => _navigateToAbsensi(context, initialTab: 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    DateTime? time,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [color, _colorWithOpacity(color, 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.grey.shade300,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _colorWithOpacity(color, 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade400,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isActive ? Colors.white : Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(time),
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white70 : Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCarousel() {
    final features = [
      {
        'title': 'Cek Jadwal Lembur',
        'description': 'Lihat jadwal lembur mingguan',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.green,
        'route': '/jadwal-lembur-menu',
      },
      {
        'title': 'Riwayat Absensi',
        'description': 'Lihat riwayat kehadiran',
        'icon': Icons.history_rounded,
        'color': Colors.orange,
        'route': '/overtime-data',
      },
      {
        'title': 'Profil',
        'description': 'Kelola data diri',
        'icon': Icons.person_rounded,
        'color': Colors.purple,
        'route': '/profile',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Fitur Unggulan',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, feature['route'] as String);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradientColors[index % _gradientColors.length],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: _colorWithOpacity(feature['color'] as Color, 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              feature['title'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature['description'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            features.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentCarouselIndex == index
                    ? const Color(0xFF1A2B4C)
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final menuItems = [
      {'icon': Icons.calendar_month_rounded, 'label': 'Jadwal Lembur', 'color': Colors.blue, 'route': '/jadwal-lembur-menu', 'action': null},
      {'icon': Icons.fingerprint_rounded, 'label': 'Absensi', 'color': Colors.green, 'route': '/mitra/absensi', 'action': null},
      {'icon': Icons.history_rounded, 'label': 'Riwayat', 'color': Colors.orange, 'route': '/overtime-data', 'action': null},
      {'icon': Icons.receipt_rounded, 'label': 'Pendapatan', 'color': Colors.teal, 'route': null, 'action': 'income'},
      {'icon': Icons.person_rounded, 'label': 'Profil', 'color': Colors.purple, 'route': '/profile', 'action': null},
      {'icon': Icons.help_rounded, 'label': 'Bantuan', 'color': Colors.red, 'route': '/help', 'action': null},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Menu Cepat',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _buildMenuItem(
              icon: item['icon'] as IconData,
              label: item['label'] as String,
              color: item['color'] as Color,
              onTap: () {
                if (item['action'] == 'income') {
                  _showIncomeDetails();
                } else if (item['label'] == 'Absensi') {
                  _navigateToAbsensi(context);
                } else if (item['route'] != null) {
                  Navigator.pushNamed(context, item['route'] as String);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, _colorWithOpacity(color, 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _colorWithOpacity(color, 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingOvertimeCard() {
    if (approvedOvertime == null) return const SizedBox();
    
    final tanggal = (approvedOvertime!['tanggal'] as Timestamp).toDate();
    final jamMulai = approvedOvertime!['jam_mulai'] ?? '19:00';
    final jamSelesai = approvedOvertime!['jam_selesai'] ?? '22:00';
    final isToday = DateFormat('yyyy-MM-dd').format(tanggal) == 
                   DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (isToday) return const SizedBox();
    
    final daysDiff = tanggal.difference(DateTime.now()).inDays;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF834d9b), Color(0xFFa56cc0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(const Color(0xFF834d9b), 0.3),
            blurRadius: 15,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jadwal Lembur Mendatang',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      daysDiff == 1 
                          ? 'Besok' 
                          : 'Dalam $daysDiff hari',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
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
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMM').format(tanggal),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$jamMulai - $jamSelesai',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  // ==================== JADWAL LEMBUR HARI INI ====================
  Widget _buildTodayLemburSchedule() {
    final now = DateTime.now();
    Map<String, dynamic>? todaySchedule;
    
    for (var s in schedules) {
      final tanggal = (s['tanggal'] as Timestamp).toDate();
      if (DateFormat('yyyy-MM-dd').format(tanggal) == 
          DateFormat('yyyy-MM-dd').format(now)) {
        todaySchedule = s;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(Colors.grey, 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: Color(0xFF1A2B4C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Jadwal Lembur Hari Ini',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A2B4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (todaySchedule == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.beach_access_rounded,
                      size: 50,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada jadwal lembur hari ini',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tidak ada lembur yang dijadwalkan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('dd').format(now),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lembur',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A2B4C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${todaySchedule['jam_mulai'] ?? '19:00'} - ${todaySchedule['jam_selesai'] ?? '22:00'} WIB',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (todaySchedule['pengawas_nama'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pengawas: ${todaySchedule['pengawas_nama']}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _colorWithOpacity(const Color(0xFFFF6B35), 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colorWithOpacity(const Color(0xFFFF6B35), 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lembur',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFFFF6B35),
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
    );
  }

  Widget _buildRecentOvertime() {
    if (overtimeRequests.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A2B4C),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/overtime-data'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B35),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...overtimeRequests.take(3).map((overtime) {
          final tanggal = (overtime['tanggal'] as Timestamp).toDate();
          final jamMulai = overtime['jam_mulai'] ?? '19:00';
          final jamSelesai = overtime['jam_selesai'] ?? '22:00';
          final status = overtime['status'] ?? 'pending';
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);
          
          final isCompleted = status == 'selesai';
          final hasValidAttendance = 
              overtime['absensi_status'] == 'selesai' ||
              (overtime['absensi_waktu'] != null && overtime['absensi_checkout_waktu'] != null);
          
          double income = 0.0;
          int totalJam = 0;
          
          if (isCompleted && hasValidAttendance) {
            totalJam = (overtime['actual_total_jam'] as num?)?.toInt() ?? 
                       (overtime['total_jam'] as num?)?.toInt() ?? 0;
            income = (overtime['actual_income'] as num?)?.toDouble() ??
                     (overtime['income_amount'] as num?)?.toDouble() ?? 0;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _colorWithOpacity(Colors.grey, 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMM yyyy').format(tanggal),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2B4C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$jamMulai - $jamSelesai WIB',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (isCompleted && hasValidAttendance) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.money_rounded,
                                  size: 12,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Rp ${NumberFormat('#,###').format(income)} (${totalJam} jam)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status == 'disetujui' && 
                    overtime['absensi_status'] != 'check_in' &&
                    overtime['absensi_status'] != 'check_out') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lembur disetujui, namun belum melakukan absensi. Lakukan check-in dan check-out untuk mendapatkan pendapatan.',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==================== JADWAL LEMBUR MINGGU INI ====================
  Widget _buildWeeklyLemburSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Jadwal Lembur Minggu Ini',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _colorWithOpacity(Colors.grey, 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: schedules.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada jadwal lembur',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Belum ada jadwal lembur yang disetujui Manager',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: schedules.map((schedule) {
                    final tanggal = (schedule['tanggal'] as Timestamp).toDate();
                    final jamMulai = schedule['jam_mulai'] ?? '19:00';
                    final jamSelesai = schedule['jam_selesai'] ?? '22:00';
                    final absensiStatus = schedule['absensi_status'] ?? 'belum_absen';
                    
                    final isToday = DateFormat('yyyy-MM-dd').format(tanggal) == 
                                   DateFormat('yyyy-MM-dd').format(DateTime.now());
                    
                    String statusText = '';
                    Color statusColor = Colors.grey;
                    
                    if (absensiStatus == 'check_in') {
                      statusText = 'Check In';
                      statusColor = Colors.blue;
                    } else if (absensiStatus == 'check_out') {
                      statusText = 'Check Out';
                      statusColor = Colors.purple;
                    } else if (absensiStatus == 'selesai') {
                      statusText = 'Selesai';
                      statusColor = Colors.green;
                    } else if (isToday) {
                      statusText = 'Hari Ini';
                      statusColor = const Color(0xFFFF6B35);
                    } else if (tanggal.isBefore(DateTime.now())) {
                      statusText = 'Terlewat';
                      statusColor = Colors.red;
                    } else {
                      statusText = 'Mendatang';
                      statusColor = Colors.orange;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: isToday
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF1A2B4C), Color(0xFF2A3F66)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                DateFormat('dd').format(tanggal),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(tanggal),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                    color: isToday ? const Color(0xFFFF6B35) : const Color(0xFF1A2B4C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$jamMulai - $jamSelesai WIB',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
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
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCompanyFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(Colors.grey, 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Perusahaan',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip(Icons.assignment_rounded, 'Kebijakan Lembur', const Color(0xFF1A2B4C)),
              _buildFeatureChip(Icons.calendar_today_rounded, 'Kalender Kerja', const Color(0xFF4158D0)),
              _buildFeatureChip(Icons.contact_support_rounded, 'Bantuan', const Color(0xFFFF6B35)),
              _buildFeatureChip(Icons.description_rounded, 'Dokumen', const Color(0xFF2E7D32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: _colorWithOpacity(color, 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colorWithOpacity(color, 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(Colors.grey, 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedMenuIndex,
        onTap: (index) {
          setState(() {
            _selectedMenuIndex = index;
          });
          
          if (index == 1) {
            _navigateToAbsensi(context);
          } else if (index == 2) {
            Navigator.pushNamed(context, '/overtime-data');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF1A2B4C),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint_rounded),
            label: 'Absensi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  void _navigateToAbsensi(BuildContext context, {int initialTab = 0}) {
    Navigator.pushNamed(
      context,
      '/mitra/absensi',
      arguments: {'initialTab': initialTab},
    ).then((_) => _refreshData());
  }

  void _showDrawerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF1A2B4C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Menu Navigasi',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A2B4C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDrawerItem(Icons.dashboard_rounded, 'Beranda', () {
                Navigator.pop(context);
              }, isSelected: true),
              _buildDrawerItem(Icons.fingerprint_rounded, 'Absensi', () {
                Navigator.pop(context);
                _navigateToAbsensi(context);
              }),
              _buildDrawerItem(Icons.calendar_month_rounded, 'Jadwal Lembur', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/jadwal-lembur-menu');
              }),
              _buildDrawerItem(Icons.history_rounded, 'Riwayat', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/overtime-data');
              }),
              _buildDrawerItem(Icons.receipt_rounded, 'Pendapatan', () {
                Navigator.pop(context);
                _showIncomeDetails();
              }),
              _buildDrawerItem(Icons.person_rounded, 'Profil', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              }),
              _buildDrawerItem(Icons.logout_rounded, 'Logout', () async {
                Navigator.pop(context);
                _showLogoutDialog();
              }, color: Colors.red),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap, {Color? color, bool isSelected = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _colorWithOpacity(color ?? const Color(0xFF1A2B4C), 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? const Color(0xFF1A2B4C),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isSelected ? const Color(0xFF1A2B4C) : Colors.grey[800]),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF1A2B4C), size: 18) : null,
      onTap: onTap,
    );
  }

  void _showNotifications(BuildContext context) {
    if (userId == null) return;
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _colorWithOpacity(const Color(0xFF1A2B4C), 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Color(0xFF1A2B4C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Notifikasi',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (unreadNotifications > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$unreadNotifications Baru',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('notifications')
                          .where('userId', isEqualTo: userId)
                          .orderBy('createdAt', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final notifs = snapshot.data!.docs;
                        
                        if (notifs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada notifikasi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notifikasi akan muncul di sini',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: notifs.length,
                          itemBuilder: (context, index) {
                            final doc = notifs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final isRead = data['isRead'] ?? false;
                            
                            return GestureDetector(
                              onTap: () async {
                                if (!isRead && mounted) {
                                  await _firestore.collection('notifications').doc(doc.id).update({
                                    'isRead': true,
                                    'readAt': FieldValue.serverTimestamp(),
                                  });
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.transparent : _colorWithOpacity(const Color(0xFF1A2B4C), 0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead ? Colors.grey.shade200 : _colorWithOpacity(const Color(0xFF1A2B4C), 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _colorWithOpacity(_getNotifColor(data['type']), 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getNotifIcon(data['type']),
                                        color: _getNotifColor(data['type']),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['title'] ?? 'Notifikasi',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              color: const Color(0xFF1A2B4C),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            data['body'] ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getTimeAgo(data['createdAt']),
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B35),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _colorWithOpacity(const Color(0xFFFF6B35), 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Konfirmasi Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case 'lembur_approved':
        return Colors.green;
      case 'lembur_rejected':
        return Colors.red;
      case 'lembur_pending':
        return Colors.orange;
      case 'lembur_checkin':
        return Colors.blue;
      case 'lembur_checkout':
        return Colors.purple;
      case 'lembur_completed':
        return Colors.green;
      case 'lembur_confirmed':
        return Colors.blue;
      case 'system':
        return const Color(0xFF1A2B4C);
      default:
        return Colors.grey;
    }
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'lembur_approved':
        return Icons.check_circle_rounded;
      case 'lembur_rejected':
        return Icons.cancel_rounded;
      case 'lembur_pending':
        return Icons.pending_rounded;
      case 'lembur_checkin':
        return Icons.login_rounded;
      case 'lembur_checkout':
        return Icons.logout_rounded;
      case 'lembur_completed':
        return Icons.task_alt_rounded;
      case 'lembur_confirmed':
        return Icons.check_circle_outline_rounded;
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}