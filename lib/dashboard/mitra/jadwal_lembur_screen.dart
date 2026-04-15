// screens/dashboard/jadwal_lembur_menu.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';

var logger = Logger();

class JadwalLemburMenu extends StatefulWidget {
  const JadwalLemburMenu({super.key});

  @override
  State<JadwalLemburMenu> createState() => _JadwalLemburMenuState();
}

class _JadwalLemburMenuState extends State<JadwalLemburMenu> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // User data
  Map<String, dynamic>? userData;
  String? userId;
  String? userRole;
  String? userName;
  String? userFungsi;
  
  // Calendar data
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<OvertimeEvent>> _events = {};
  Set<DateTime> _holidays = {};
  
  // Overtime data
  List<Map<String, dynamic>> allOvertime = [];
  List<Map<String, dynamic>> filteredOvertime = [];
  Map<String, List<Map<String, dynamic>>> overtimeByDate = {};
  
  // Loading state
  bool isLoading = true;
  bool isRefreshing = false;
  
  // Selected overtime for detail
  Map<String, dynamic>? selectedOvertime;
  
  // Search and filter
  String searchQuery = '';
  String filterStatus = 'semua';
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  
  // Timer for real-time clock
  Timer? _clockTimer;
  
  // Role permissions
  bool get isMitra => userRole == 'mitra';
  bool get isPengawas => userRole == 'pengawas';
  bool get isManager => userRole == 'manager';
  bool get isSuperAdmin => userRole == 'superadmin';
  
  // Visibility based on role
  bool get canSeeAllOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canSeeTeamOvertime => isMitra || isPengawas || isManager;
  bool get canApproveOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canCreateOvertime => isPengawas || isManager || isSuperAdmin;
  
  // Filtered data based on role
  List<Map<String, dynamic>> get displayedOvertime {
    List<Map<String, dynamic>> result = filteredOvertime;
    
    if (searchQuery.isNotEmpty) {
      result = result.where((item) {
        final nama = item['nama_mitra']?.toString().toLowerCase() ?? '';
        final fungsi = item['fungsi_mitra']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return nama.contains(query) || fungsi.contains(query);
      }).toList();
    }
    
    return result;
  }
  
  // Indonesian holidays 2024-2030
  final Map<int, List<Map<String, String>>> _indonesianHolidays = {
    // ... (keep your existing holidays data)
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserData();
    _setupRealTimeListeners();
    _initCalendarEvents();
    _startClockTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Fungsi untuk menentukan status lembur berdasarkan absensi dan tanggal
  String _getOvertimeExecutionStatus(Map<String, dynamic> overtime) {
    final status = overtime['status']?.toString().toLowerCase() ?? 'pending';
    final tanggal = overtime['tanggal'] != null 
        ? (overtime['tanggal'] as Timestamp).toDate()
        : null;
    final absensiStatus = overtime['absensi_status']?.toString();
    final absensiCheckin = overtime['absensi_waktu'];
    final absensiCheckout = overtime['absensi_checkout_waktu'];
    final now = DateTime.now();
    
    // Jika status pengajuan belum disetujui, kembalikan status pengajuan
    if (status != 'disetujui' && status != 'selesai') {
      return status;
    }
    
    // Jika tanggal tidak ada
    if (tanggal == null) {
      return 'invalid';
    }
    
    // Cek apakah ini jadwal mendatang (lebih dari hari ini)
    final isUpcoming = tanggal.isAfter(now);
    
    // Cek apakah jadwal sudah lewat dari hari ini
    final isPast = tanggal.isBefore(now) && !isSameDay(tanggal, now);
    
    // Cek apakah jadwal hari ini
    final isToday = isSameDay(tanggal, now);
    
    // Jadwal mendatang
    if (isUpcoming) {
      // Cek apakah jadwal dekat (dalam 7 hari ke depan)
      final daysDifference = tanggal.difference(now).inDays;
      if (daysDifference <= 7) {
        return 'upcoming_soon';
      }
      return 'upcoming';
    }
    
    // Jadwal sudah lewat (hari kemarin atau sebelumnya)
    if (isPast) {
      // Cek apakah sudah selesai (status selesai)
      if (status == 'selesai') {
        return 'completed';
      }
      
      // Cek apakah sudah check in dan checkout
      final hasCheckin = absensiCheckin != null;
      final hasCheckout = absensiCheckout != null;
      
      if (hasCheckin && hasCheckout) {
        return 'completed_with_attendance';
      } else if (hasCheckin && !hasCheckout) {
        return 'incomplete_checkout';
      } else if (!hasCheckin && !hasCheckout) {
        return 'late';
      }
      return 'late';
    }
    
    // Jadwal hari ini
    if (isToday) {
      // Cek apakah sudah selesai
      if (status == 'selesai') {
        return 'completed';
      }
      
      // Dapatkan jam lembur
      final jamMulaiStr = overtime['jam_mulai'] ?? '19:00';
      final jamSelesaiStr = overtime['jam_selesai'] ?? '22:00';
      
      final jamMulaiParts = jamMulaiStr.split(':');
      final jamSelesaiParts = jamSelesaiStr.split(':');
      
      final jamMulai = DateTime(
        now.year, now.month, now.day,
        int.parse(jamMulaiParts[0]),
        int.parse(jamMulaiParts[1])
      );
      final jamSelesai = DateTime(
        now.year, now.month, now.day,
        int.parse(jamSelesaiParts[0]),
        int.parse(jamSelesaiParts[1])
      );
      
      // Cek apakah sudah check in dan checkout
      final hasCheckin = absensiCheckin != null;
      final hasCheckout = absensiCheckout != null;
      
      if (hasCheckin && hasCheckout) {
        return 'completed_with_attendance';
      }
      
      // Cek apakah sudah melewati jam mulai
      if (now.isAfter(jamMulai)) {
        // Belum check in, terlambat
        if (!hasCheckin) {
          return 'late_today';
        }
        // Sudah check in tapi belum check out dan sudah melewati jam selesai
        if (hasCheckin && !hasCheckout && now.isAfter(jamSelesai)) {
          return 'incomplete_checkout';
        }
      }
      
      // Belum waktunya lembur atau masih dalam proses
      return 'today_ongoing';
    }
    
    return status;
  }
  
  // Fungsi untuk mendapatkan teks status eksekusi
  String _getExecutionStatusText(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return 'Jadwal Mendatang';
      case 'upcoming_soon':
        return 'Jadwal Mendatang (Segera)';
      case 'completed':
        return 'Terselesaikan';
      case 'completed_with_attendance':
        return 'Terselesaikan ✓';
      case 'late':
        return 'Terlambat ✗';
      case 'late_today':
        return 'Terlambat (Belum Check In)';
      case 'incomplete_checkout':
        return 'Belum Check Out';
      case 'today_ongoing':
        return 'Sedang Berlangsung';
      case 'pending':
        return 'Menunggu Persetujuan';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      default:
        return executionStatus;
    }
  }
  
  // Fungsi untuk mendapatkan warna status eksekusi
  Color _getExecutionStatusColor(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return Colors.blue;
      case 'upcoming_soon':
        return Colors.orange;
      case 'completed':
      case 'completed_with_attendance':
        return Colors.green;
      case 'late':
      case 'late_today':
        return Colors.red;
      case 'incomplete_checkout':
        return Colors.deepOrange;
      case 'today_ongoing':
        return Colors.purple;
      case 'pending':
        return Colors.grey;
      case 'disetujui':
        return Colors.lightBlue;
      case 'ditolak':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
  
  // Fungsi untuk mendapatkan icon status eksekusi
  IconData _getExecutionStatusIcon(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return Icons.event_available_rounded;
      case 'upcoming_soon':
        return Icons.notifications_active_rounded;
      case 'completed':
      case 'completed_with_attendance':
        return Icons.check_circle_rounded;
      case 'late':
      case 'late_today':
        return Icons.warning_amber_rounded;
      case 'incomplete_checkout':
        return Icons.logout_rounded;
      case 'today_ongoing':
        return Icons.access_time_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'disetujui':
        return Icons.thumb_up_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }
  
  // Fungsi untuk mendapatkan badge status eksekusi
  Widget _buildExecutionStatusBadge(String executionStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getExecutionStatusColor(executionStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getExecutionStatusIcon(executionStatus),
            size: 12,
            color: _getExecutionStatusColor(executionStatus),
          ),
          const SizedBox(width: 4),
          Text(
            _getExecutionStatusText(executionStatus),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getExecutionStatusColor(executionStatus),
            ),
          ),
        ],
      ),
    );
  }
  
  // Fungsi untuk memfilter berdasarkan status eksekusi
  void _filterByExecutionStatus(String filter) {
    if (filter == 'semua') {
      _filterOvertime();
      return;
    }
    
    List<Map<String, dynamic>> filtered = [];
    
    for (var overtime in allOvertime) {
      final executionStatus = _getOvertimeExecutionStatus(overtime);
      
      if (filter == 'upcoming' && (executionStatus == 'upcoming' || executionStatus == 'upcoming_soon')) {
        filtered.add(overtime);
      } else if (filter == 'completed' && (executionStatus == 'completed' || executionStatus == 'completed_with_attendance')) {
        filtered.add(overtime);
      } else if (filter == 'late' && (executionStatus == 'late' || executionStatus == 'late_today')) {
        filtered.add(overtime);
      } else if (filter == 'ongoing' && executionStatus == 'today_ongoing') {
        filtered.add(overtime);
      }
    }
    
    setState(() {
      filteredOvertime = filtered;
    });
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      
      try {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            userData = data;
            userRole = data['role'] ?? 'mitra';
            userName = data['nama_lengkap'] ?? data['email']?.split('@')[0] ?? 'Pengguna';
            userFungsi = data['fungsi'];
          });
        } else {
          setState(() {
            userRole = 'mitra';
            userName = 'Mitra';
          });
        }
      } catch (e) {
        logger.e('Error loading user data: $e');
        setState(() {
          userRole = 'mitra';
          userName = 'Mitra';
        });
      }
    }
    
    await _loadOvertimeData();
    setState(() {
      isLoading = false;
    });
  }

  void _setupRealTimeListeners() {
    if (userId == null) return;
    
    try {
      Query query = _firestore.collection('lembur');
      
      if (isMitra) {
        query = query.where('mitra_id', isEqualTo: userId);
      } else if (isPengawas || isManager) {
        if (userFungsi != null && userFungsi!.isNotEmpty) {
          query = query.where('fungsi_mitra', isEqualTo: userFungsi);
        }
      }
      
      final overtimeSub = query
          .orderBy('tanggal', descending: true)
          .snapshots()
          .listen((snapshot) {
        _processOvertimeSnapshot(snapshot);
      });
      
    } catch (e) {
      logger.e('Error setting up overtime listener: $e');
    }
  }

  void _processOvertimeSnapshot(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> overtime = [];
    final Map<String, List<Map<String, dynamic>>> byDate = {};
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      overtime.add(data);
      
      final tanggal = data['tanggal'] != null 
          ? (data['tanggal'] as Timestamp).toDate()
          : null;
      
      if (tanggal != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(tanggal);
        if (!byDate.containsKey(dateKey)) {
          byDate[dateKey] = [];
        }
        byDate[dateKey]!.add(data);
      }
    }
    
    setState(() {
      allOvertime = overtime;
      overtimeByDate = byDate;
      _filterOvertime();
      _updateCalendarEvents();
    });
  }

  void _filterOvertime() {
    List<Map<String, dynamic>> filtered = List.from(allOvertime);
    
    if (filterStatus != 'semua') {
      filtered = filtered.where((item) {
        final status = item['status']?.toString().toLowerCase() ?? '';
        return status == filterStatus;
      }).toList();
    }
    
    if (filterStartDate != null) {
      filtered = filtered.where((item) {
        final tanggal = item['tanggal'] != null 
            ? (item['tanggal'] as Timestamp).toDate()
            : null;
        if (tanggal == null) return false;
        return tanggal.isAfter(filterStartDate!.subtract(const Duration(days: 1)));
      }).toList();
    }
    
    if (filterEndDate != null) {
      filtered = filtered.where((item) {
        final tanggal = item['tanggal'] != null 
            ? (item['tanggal'] as Timestamp).toDate()
            : null;
        if (tanggal == null) return false;
        return tanggal.isBefore(filterEndDate!.add(const Duration(days: 1)));
      }).toList();
    }
    
    setState(() {
      filteredOvertime = filtered;
    });
  }

  void _updateCalendarEvents() {
    final Map<DateTime, List<OvertimeEvent>> events = {};
    
    for (var overtime in allOvertime) {
      final tanggal = overtime['tanggal'] != null 
          ? (overtime['tanggal'] as Timestamp).toDate()
          : null;
      
      if (tanggal != null) {
        final dateKey = DateTime(tanggal.year, tanggal.month, tanggal.day);
        if (!events.containsKey(dateKey)) {
          events[dateKey] = [];
        }
        
        final status = _getOvertimeExecutionStatus(overtime);
        events[dateKey]!.add(OvertimeEvent(
          id: overtime['id'],
          title: overtime['nama_mitra'] ?? 'Lembur',
          jamMulai: overtime['jam_mulai'] ?? '19:00',
          jamSelesai: overtime['jam_selesai'] ?? '22:00',
          status: status,
        ));
      }
    }
    
    setState(() {
      _events = events;
    });
  }

  Future<void> _loadOvertimeData() async {
    if (userId == null) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      Query query = _firestore.collection('lembur');
      
      if (isMitra) {
        query = query.where('mitra_id', isEqualTo: userId);
      } else if (isPengawas || isManager) {
        if (userFungsi != null && userFungsi!.isNotEmpty) {
          query = query.where('fungsi_mitra', isEqualTo: userFungsi);
        }
      }
      
      final snapshot = await query
          .orderBy('tanggal', descending: true)
          .limit(100)
          .get();
      
      _processOvertimeSnapshot(snapshot);
    } catch (e) {
      logger.e('Error loading overtime: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initCalendarEvents() {
    _loadHolidays();
    _updateCalendarEvents();
  }

  void _loadHolidays() {
    final now = DateTime.now();
    final currentYear = now.year;
    final Set<DateTime> holidays = {};
    
    for (int year = currentYear; year <= currentYear + 5; year++) {
      if (_indonesianHolidays.containsKey(year)) {
        for (var holiday in _indonesianHolidays[year]!) {
          try {
            final date = DateTime.parse(holiday['date']!);
            holidays.add(date);
          } catch (e) {
            logger.e('Error parsing holiday date: $e');
          }
        }
      }
    }
    
    setState(() {
      _holidays = holidays;
    });
  }

  bool _isHoliday(DateTime date) {
    return _holidays.contains(DateTime(date.year, date.month, date.day));
  }

  String? _getHolidayName(DateTime date) {
    final year = date.year;
    if (_indonesianHolidays.containsKey(year)) {
      for (var holiday in _indonesianHolidays[year]!) {
        try {
          final holidayDate = DateTime.parse(holiday['date']!);
          if (holidayDate.year == date.year &&
              holidayDate.month == date.month &&
              holidayDate.day == date.day) {
            return holiday['name'];
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return DateFormat('HH:mm:ss').format(now);
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadOvertimeData();
    setState(() => isRefreshing = false);
  }

  void _showOvertimeDetail(Map<String, dynamic> overtime) {
    setState(() {
      selectedOvertime = overtime;
    });
    
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final tanggal = overtime['tanggal'] != null 
        ? (overtime['tanggal'] as Timestamp).toDate()
        : null;
    final isHoliday = tanggal != null ? _isHoliday(tanggal) : false;
    final holidayName = tanggal != null ? _getHolidayName(tanggal) : null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
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
                          color: _getExecutionStatusColor(executionStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getExecutionStatusIcon(executionStatus),
                          color: _getExecutionStatusColor(executionStatus),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Lembur',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A2B4C),
                              ),
                            ),
                            Text(
                              overtime['nama_mitra'] ?? 'Mitra',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildExecutionStatusBadge(executionStatus),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildDetailRow(
                          Icons.calendar_today_rounded,
                          'Tanggal Lembur',
                          tanggal != null 
                              ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal)
                              : '-',
                        ),
                        if (isHoliday) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.celebration_rounded,
                            'Catatan',
                            'Hari Libur: $holidayName',
                            color: Colors.red,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.access_time_rounded,
                          'Waktu Lembur',
                          '${overtime['jam_mulai'] ?? '19:00'} - ${overtime['jam_selesai'] ?? '22:00'} WIB',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.timer_rounded,
                          'Total Jam',
                          '${overtime['total_jam'] ?? 0} Jam',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.work_rounded,
                          'Fungsi',
                          overtime['fungsi_mitra'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.person_rounded,
                          'Dilakukan Oleh',
                          overtime['nama_mitra'] ?? '-',
                          subtitle: overtime['mitra_id'],
                        ),
                        if (overtime['pengawas_nama'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.verified_rounded,
                            'Disetujui Oleh',
                            overtime['pengawas_nama'],
                            subtitle: overtime['pengawas_id'],
                          ),
                        ],
                        if (overtime['keterangan'] != null && overtime['keterangan'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.description_rounded,
                            'Keterangan',
                            overtime['keterangan'],
                          ),
                        ],
                        
                        const Divider(height: 24),
                        
                        // Bagian Status Eksekusi Lembur
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getExecutionStatusColor(executionStatus).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getExecutionStatusColor(executionStatus).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getExecutionStatusIcon(executionStatus),
                                    size: 20,
                                    color: _getExecutionStatusColor(executionStatus),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Status Eksekusi Lembur',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A2B4C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getExecutionStatusDescription(executionStatus),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (executionStatus == 'upcoming_soon')
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.notifications_active, size: 16, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Jadwal lembur mendatang dalam waktu dekat. Pastikan Anda siap.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (executionStatus == 'late' || executionStatus == 'late_today')
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning, size: 16, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          executionStatus == 'late_today'
                                              ? 'Anda belum melakukan check in untuk jadwal lembur hari ini. Segera lakukan check in melalui halaman absensi.'
                                              : 'Jadwal lembur ini telah lewat namun tidak ada absensi yang tercatat. Lembur dinyatakan TIDAK BERJALAN.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.red[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (executionStatus == 'incomplete_checkout')
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.logout, size: 16, color: Colors.deepOrange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Anda sudah check in namun belum check out. Segera lakukan check out untuk menyelesaikan lembur.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.deepOrange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (executionStatus == 'completed_with_attendance')
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Lembur telah terselesaikan dengan baik. Check in dan check out telah tercatat.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        if (overtime['absensi_status'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            overtime['absensi_status'] == 'check_in' 
                                ? Icons.login_rounded 
                                : overtime['absensi_status'] == 'check_out'
                                    ? Icons.logout_rounded
                                    : Icons.access_time_rounded,
                            'Status Absensi',
                            _getAbsensiStatusText(overtime['absensi_status']),
                            color: _getAbsensiStatusColor(overtime['absensi_status']),
                          ),
                        ],
                        if (overtime['absensi_waktu'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.login_rounded,
                            'Waktu Check In',
                            _formatTimestamp(overtime['absensi_waktu']),
                          ),
                        ],
                        if (overtime['absensi_checkout_waktu'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.logout_rounded,
                            'Waktu Check Out',
                            _formatTimestamp(overtime['absensi_checkout_waktu']),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        if (canApproveOvertime && 
                            (overtime['status'] == 'pending' || overtime['status'] == 'disetujui')) ...[
                          Row(
                            children: [
                              if (overtime['status'] == 'pending')
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approveOvertime(overtime['id']),
                                    icon: const Icon(Icons.check_circle_rounded),
                                    label: const Text('Setujui'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              if (overtime['status'] == 'pending') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _rejectOvertime(overtime['id']),
                                    icon: const Icon(Icons.cancel_rounded),
                                    label: const Text('Tolak'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (overtime['status'] == 'disetujui' && 
                                  overtime['absensi_status'] != 'selesai')
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _completeOvertime(overtime['id']),
                                    icon: const Icon(Icons.task_alt_rounded),
                                    label: const Text('Selesaikan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A2B4C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Tutup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
      },
    );
  }
  
  // Fungsi untuk mendapatkan deskripsi status eksekusi
  String _getExecutionStatusDescription(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return 'Jadwal lembur yang akan datang. Pastikan Anda mempersiapkan diri.';
      case 'upcoming_soon':
        return 'Jadwal lembur dalam waktu dekat (kurang dari 7 hari). Jangan lupa untuk melakukan absensi check in dan check out pada hari H.';
      case 'completed':
        return 'Lembur telah selesai dan dinyatakan BERJALAN dengan baik.';
      case 'completed_with_attendance':
        return 'Lembur telah terselesaikan dengan bukti absensi check in dan check out yang lengkap.';
      case 'late':
        return 'Lembur TIDAK BERJALAN karena tidak ada absensi check in dan check out yang tercatat.';
      case 'late_today':
        return 'Lembur hari ini belum dimulai. Segera lakukan check in melalui halaman absensi.';
      case 'incomplete_checkout':
        return 'Lembur sedang berlangsung namun belum check out. Segera lakukan check out setelah selesai.';
      case 'today_ongoing':
        return 'Lembur hari ini dalam jadwal. Tunggu waktu mulai untuk melakukan absensi.';
      default:
        return 'Status lembur sedang dalam proses.';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? subtitle, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? const Color(0xFF1A2B4C)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color ?? const Color(0xFF1A2B4C)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color ?? const Color(0xFF1A2B4C),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveOvertime(String overtimeId) async {
    try {
      await _firestore.collection('lembur').doc(overtimeId).update({
        'status': 'disetujui',
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': userId,
        'approved_by_name': userName,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      final doc = await _firestore.collection('lembur').doc(overtimeId).get();
      if (doc.exists) {
        final data = doc.data()!;
        await _firestore.collection('notifications').add({
          'userId': data['mitra_id'],
          'title': 'Pengajuan Lembur Disetujui',
          'body': 'Pengajuan lembur Anda telah disetujui',
          'type': 'lembur_approved',
          'lemburId': overtimeId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        _showSuccessSnackbar('Lembur berhasil disetujui');
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      logger.e('Error approving overtime: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal menyetujui lembur');
      }
    }
  }

  Future<void> _rejectOvertime(String overtimeId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Tolak Pengajuan Lembur'),
        content: const Text('Apakah Anda yakin ingin menolak pengajuan lembur ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('lembur').doc(overtimeId).update({
                  'status': 'ditolak',
                  'rejected_at': FieldValue.serverTimestamp(),
                  'rejected_by': userId,
                  'rejected_by_name': userName,
                  'updated_at': FieldValue.serverTimestamp(),
                });
                
                final doc = await _firestore.collection('lembur').doc(overtimeId).get();
                if (doc.exists) {
                  final data = doc.data()!;
                  await _firestore.collection('notifications').add({
                    'userId': data['mitra_id'],
                    'title': 'Pengajuan Lembur Ditolak',
                    'body': 'Pengajuan lembur Anda telah ditolak',
                    'type': 'lembur_rejected',
                    'lemburId': overtimeId,
                    'isRead': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
                
                if (mounted) {
                  _showSuccessSnackbar('Lembur berhasil ditolak');
                  _refreshData();
                }
              } catch (e) {
                logger.e('Error rejecting overtime: $e');
                if (mounted) {
                  _showErrorSnackbar('Gagal menolak lembur');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOvertime(String overtimeId) async {
    try {
      await _firestore.collection('lembur').doc(overtimeId).update({
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSuccessSnackbar('Lembur telah selesai');
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      logger.e('Error completing overtime: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal menyelesaikan lembur');
      }
    }
  }

  void _showCreateOvertimeDialog() {
    final TextEditingController tanggalController = TextEditingController();
    final TextEditingController jamMulaiController = TextEditingController();
    final TextEditingController jamSelesaiController = TextEditingController();
    final TextEditingController keteranganController = TextEditingController();
    String? selectedMitraId;
    List<Map<String, dynamic>> mitraList = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B4C).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_task_rounded,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Buat Jadwal Lembur',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPengawas || isManager || isSuperAdmin) ...[
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore
                          .collection('users')
                          .where('role', isEqualTo: 'mitra')
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          mitraList = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['id'] = doc.id;
                            return data;
                          }).toList();
                        }
                        
                        return DropdownButtonFormField<String>(
                          value: selectedMitraId,
                          decoration: InputDecoration(
                            labelText: 'Pilih Mitra',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: mitraList.map((mitra) {
                            return DropdownMenuItem<String>(
                              value: mitra['id'],
                              child: Text(mitra['nama_lengkap'] ?? mitra['email']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMitraId = value;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: tanggalController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Lembur',
                      hintText: 'Pilih tanggal',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: jamMulaiController,
                          decoration: InputDecoration(
                            labelText: 'Jam Mulai',
                            hintText: '19:00',
                            prefixIcon: const Icon(Icons.access_time_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: jamSelesaiController,
                          decoration: InputDecoration(
                            labelText: 'Jam Selesai',
                            hintText: '22:00',
                            prefixIcon: const Icon(Icons.access_time_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keteranganController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Keterangan',
                      hintText: 'Alasan lembur...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                onPressed: () async {
                  if (tanggalController.text.isEmpty) {
                    _showErrorSnackbar('Tanggal harus diisi');
                    return;
                  }
                  if (jamMulaiController.text.isEmpty || jamSelesaiController.text.isEmpty) {
                    _showErrorSnackbar('Jam mulai dan selesai harus diisi');
                    return;
                  }
                  
                  final targetMitraId = isMitra ? userId : selectedMitraId;
                  if (targetMitraId == null) {
                    _showErrorSnackbar('Mitra harus dipilih');
                    return;
                  }
                  
                  final mitraDoc = await _firestore.collection('users').doc(targetMitraId).get();
                  if (!mitraDoc.exists) {
                    _showErrorSnackbar('Data mitra tidak ditemukan');
                    return;
                  }
                  
                  final mitraData = mitraDoc.data()!;
                  
                  final jamMulai = jamMulaiController.text.split(':');
                  final jamSelesai = jamSelesaiController.text.split(':');
                  final startHour = int.parse(jamMulai[0]);
                  final endHour = int.parse(jamSelesai[0]);
                  int totalJam = endHour - startHour;
                  if (totalJam < 0) totalJam += 24;
                  
                  await _firestore.collection('lembur').add({
                    'mitra_id': targetMitraId,
                    'nama_mitra': mitraData['nama_lengkap'] ?? mitraData['email'],
                    'fungsi_mitra': mitraData['fungsi'],
                    'tanggal': Timestamp.fromDate(DateTime.parse(tanggalController.text)),
                    'tahun_bulan': DateFormat('yyyy-MM').format(DateTime.parse(tanggalController.text)),
                    'jam_mulai': jamMulaiController.text,
                    'jam_selesai': jamSelesaiController.text,
                    'total_jam': totalJam,
                    'keterangan': keteranganController.text,
                    'status': 'pending',
                    'pengawas_id': isPengawas || isManager || isSuperAdmin ? userId : null,
                    'pengawas_nama': isPengawas || isManager || isSuperAdmin ? userName : null,
                    'created_at': FieldValue.serverTimestamp(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                  
                  Navigator.pop(context);
                  _showSuccessSnackbar('Jadwal lembur berhasil dibuat');
                  _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B4C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buat Jadwal'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'selesai':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return Icons.check_circle_rounded;
      case 'selesai':
        return Icons.task_alt_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
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
      default:
        return status;
    }
  }

  String _getAbsensiStatusText(String? status) {
    switch (status) {
      case 'check_in':
        return 'Sudah Check In';
      case 'check_out':
        return 'Sudah Check Out';
      case 'selesai':
        return 'Selesai';
      default:
        return 'Belum Absen';
    }
  }

  Color _getAbsensiStatusColor(String? status) {
    switch (status) {
      case 'check_in':
        return Colors.blue;
      case 'check_out':
        return Colors.purple;
      case 'selesai':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
    }
    return '-';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jadwal Lembur',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              _getCurrentDate(),
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2B4C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  _getCurrentTime(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canCreateOvertime)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _showCreateOvertimeDialog,
            ),
          IconButton(
            icon: isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 1,
            color: Colors.white24,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1A2B4C),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleInfoCard(),
                    const SizedBox(height: 16),
                    
                    _buildCalendar(),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(),
                    const SizedBox(height: 16),
                    
                    _buildExecutionStatusFilter(),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Lembur',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A2B4C),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2B4C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${displayedOvertime.length} Data',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1A2B4C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    displayedOvertime.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayedOvertime.length,
                            itemBuilder: (context, index) {
                              final overtime = displayedOvertime[index];
                              return _buildOvertimeCard(overtime);
                            },
                          ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
      floatingActionButton: canCreateOvertime
          ? FloatingActionButton.extended(
              onPressed: _showCreateOvertimeDialog,
              backgroundColor: const Color(0xFFFF6B35),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Buat Lembur',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1A2B4C),
          ),
          const SizedBox(height: 20),
          Text(
            'Memuat jadwal lembur...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExecutionStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildExecutionFilterChip('Semua', 'semua'),
            const SizedBox(width: 8),
            _buildExecutionFilterChip('Mendatang', 'upcoming'),
            const SizedBox(width: 8),
            _buildExecutionFilterChip('Terselesaikan', 'completed'),
            const SizedBox(width: 8),
            _buildExecutionFilterChip('Terlambat', 'late'),
            const SizedBox(width: 8),
            _buildExecutionFilterChip('Sedang Berlangsung', 'ongoing'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExecutionFilterChip(String label, String filterValue) {
    final isSelected = filterValue == 'semua' 
        ? (filterStatus == 'semua' && searchQuery.isEmpty && filterStartDate == null && filterEndDate == null)
        : false; // This is simplified, you may want to track execution filter separately
    
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12),
      ),
      selected: isSelected,
      onSelected: (selected) {
        _filterByExecutionStatus(filterValue);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1A2B4C).withOpacity(0.1),
      checkmarkColor: const Color(0xFF1A2B4C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildRoleInfoCard() {
    String roleText = '';
    String roleDescription = '';
    
    if (isMitra) {
      roleText = 'Mitra';
      roleDescription = 'Anda hanya dapat melihat jadwal lembur Anda sendiri';
    } else if (isPengawas) {
      roleText = 'Pengawas';
      roleDescription = 'Anda dapat melihat dan mengelola jadwal lembur tim ${userFungsi ?? ''}';
    } else if (isManager) {
      roleText = 'Manager';
      roleDescription = 'Anda dapat melihat dan mengelola semua jadwal lembur sesuai fungsi';
    } else if (isSuperAdmin) {
      roleText = 'Super Admin';
      roleDescription = 'Anda dapat melihat dan mengelola seluruh jadwal lembur';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2B4C), Color(0xFF2A3F66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isMitra
                  ? Icons.person_rounded
                  : isPengawas
                      ? Icons.visibility_rounded
                      : isManager
                          ? Icons.manage_accounts_rounded
                          : Icons.admin_panel_settings_rounded,
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
                  roleText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  roleDescription,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TableCalendar<OvertimeEvent>(
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                
                final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
                if (overtimeByDate.containsKey(dateKey)) {
                  filteredOvertime = overtimeByDate[dateKey]!;
                } else {
                  filteredOvertime = [];
                }
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, _) {
                final isHoliday = _isHoliday(date);
                final holidayName = _getHolidayName(date);
                final events = _events[date] ?? [];
                final hasEvent = events.isNotEmpty;
                
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isHoliday
                        ? Colors.red.shade50
                        : hasEvent
                            ? const Color(0xFFFF6B35).withOpacity(0.1)
                            : null,
                    borderRadius: BorderRadius.circular(12),
                    border: isSameDay(date, _selectedDay)
                        ? Border.all(color: const Color(0xFFFF6B35), width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isSameDay(date, _selectedDay)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isHoliday
                                    ? Colors.red
                                    : hasEvent
                                        ? const Color(0xFFFF6B35)
                                        : Colors.grey[800],
                              ),
                            ),
                            if (isHoliday && holidayName != null)
                              Text(
                                holidayName.length > 5
                                    ? holidayName.substring(0, 5)
                                    : holidayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasEvent && !isHoliday)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              todayBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A2B4C), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2B4C),
                      ),
                    ),
                  ),
                );
              },
            ),
            eventLoader: (date) => _events[date] ?? [],
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A2B4C),
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded),
            ),
            calendarStyle: CalendarStyle(
              weekendTextStyle: GoogleFonts.poppins(color: Colors.red),
              outsideDaysVisible: false,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(const Color(0xFFFF6B35), 'Ada Lembur'),
              _buildLegendItem(Colors.red, 'Hari Libur'),
              _buildLegendItem(const Color(0xFF1A2B4C), 'Hari Ini'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filterStatus,
                  decoration: InputDecoration(
                    labelText: 'Status Pengajuan',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'semua', child: Text('Semua')),
                    DropdownMenuItem(value: 'pending', child: Text('Menunggu')),
                    DropdownMenuItem(value: 'disetujui', child: Text('Disetujui')),
                    DropdownMenuItem(value: 'ditolak', child: Text('Ditolak')),
                    DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filterStatus = value!;
                      _filterOvertime();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: filterStartDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        filterStartDate = picked;
                        _filterOvertime();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filterStartDate != null
                                ? DateFormat('dd/MM/yyyy').format(filterStartDate!)
                                : 'Dari',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: filterStartDate != null
                                  ? const Color(0xFF1A2B4C)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (filterStartDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                filterStartDate = null;
                                _filterOvertime();
                              });
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: filterEndDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        filterEndDate = picked;
                        _filterOvertime();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filterEndDate != null
                                ? DateFormat('dd/MM/yyyy').format(filterEndDate!)
                                : 'Sampai',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: filterEndDate != null
                                  ? const Color(0xFF1A2B4C)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (filterEndDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                filterEndDate = null;
                                _filterOvertime();
                              });
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (searchQuery.isNotEmpty ||
                  filterStatus != 'semua' ||
                  filterStartDate != null ||
                  filterEndDate != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                      filterStatus = 'semua';
                      filterStartDate = null;
                      filterEndDate = null;
                      _filterOvertime();
                    });
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeCard(Map<String, dynamic> overtime) {
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final tanggal = overtime['tanggal'] != null 
        ? (overtime['tanggal'] as Timestamp).toDate()
        : null;
    final isHoliday = tanggal != null ? _isHoliday(tanggal) : false;
    final status = overtime['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    
    return GestureDetector(
      onTap: () => _showOvertimeDetail(overtime),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getExecutionStatusColor(executionStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      _getExecutionStatusIcon(executionStatus),
                      color: _getExecutionStatusColor(executionStatus),
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
                              overtime['nama_mitra'] ?? 'Mitra',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A2B4C),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildExecutionStatusBadge(executionStatus),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (tanggal != null)
                        Text(
                          DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggal),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
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
                            '${overtime['jam_mulai'] ?? '19:00'} - ${overtime['jam_selesai'] ?? '22:00'} WIB',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.timer_rounded,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${overtime['total_jam'] ?? 0} jam',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (isHoliday) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.celebration_rounded,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hari Libur',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (canApproveOvertime && status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _approveOvertime(overtime['id']),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Setujui'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectOvertime(overtime['id']),
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (executionStatus == 'late' || executionStatus == 'late_today') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        executionStatus == 'late_today'
                            ? 'Belum melakukan check in hari ini'
                            : 'Lembur tidak berjalan (tidak ada absensi)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Jadwal Lembur',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canCreateOvertime
                ? 'Klik tombol + untuk membuat jadwal lembur baru'
                : 'Belum ada jadwal lembur yang tersedia',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OvertimeEvent {
  final String id;
  final String title;
  final String jamMulai;
  final String jamSelesai;
  final String status;

  OvertimeEvent({
    required this.id,
    required this.title,
    required this.jamMulai,
    required this.jamSelesai,
    required this.status,
  });
}