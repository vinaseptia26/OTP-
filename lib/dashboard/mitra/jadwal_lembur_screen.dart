// lib/dashboard/mitra/jadwal_lembur_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/services/overtime_service.dart';

var logger = Logger();

class JadwalLemburScreen extends StatefulWidget {
  const JadwalLemburScreen({super.key});

  @override
  State<JadwalLemburScreen> createState() => _JadwalLemburScreenState();
}

class _JadwalLemburScreenState extends State<JadwalLemburScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeService _overtimeService = OvertimeService();

  // ==================== USER DATA ====================
  Map<String, dynamic>? userData;
  String? userId;
  String? userRole;
  String? userName;
  String? userFungsi;

  // ==================== CALENDAR DATA ====================
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<OvertimeEvent>> _events = {};
  Set<DateTime> _holidays = {};

  // ==================== OVERTIME DATA ====================
  List<OvertimeHistory> allOvertime = [];
  List<OvertimeHistory> filteredOvertime = [];
  Map<String, List<OvertimeHistory>> overtimeByDate = {};

  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isRefreshing = false;
  OvertimeHistory? selectedOvertime;
  String searchQuery = '';
  String filterStatus = 'semua';
  String executionFilter = 'semua';
  DateTime? filterStartDate;
  DateTime? filterEndDate;

  // ==================== TIMER ====================
  Timer? _clockTimer;

  // ==================== RATES ====================
  Map<String, dynamic>? _rates;
  bool _isHolidayContext = false;

  // ==================== STREAM SUBSCRIPTIONS ====================
  StreamSubscription? _overtimeSubscription;

  // ==================== ROLE PERMISSIONS ====================
  bool get isMitra => userRole == 'mitra';
  bool get isPengawas => userRole == 'pengawas';
  bool get isManager => userRole == 'manager';
  bool get isSuperAdmin => userRole == 'superadmin';

  bool get canSeeAllOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canApproveOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canCreateOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canCancelOvertime => isSuperAdmin || isPengawas || isManager;
  bool get canRestoreOvertime => isSuperAdmin;

  // ==================== FILTERED DATA ====================
  List<OvertimeHistory> get displayedOvertime {
    List<OvertimeHistory> result = List.from(filteredOvertime);

    if (searchQuery.isNotEmpty) {
      result = result.where((item) {
        final nama = item.namaMitra?.toLowerCase() ?? '';
        final fungsi = item.fungsiMitra?.toLowerCase() ?? '';
        final pengawas = item.namaPengawas?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return nama.contains(query) ||
            fungsi.contains(query) ||
            pengawas.contains(query);
      }).toList();
    }

    return result;
  }

  // ==================== INDONESIAN HOLIDAYS ====================
  final Map<int, List<Map<String, String>>> _indonesianHolidays = {
    2024: [
      {'date': '2024-01-01', 'name': 'Tahun Baru 2024'},
      {'date': '2024-02-08', 'name': 'Isra Miraj'},
      {'date': '2024-02-10', 'name': 'Tahun Baru Imlek'},
      {'date': '2024-03-11', 'name': 'Hari Raya Nyepi'},
      {'date': '2024-03-29', 'name': 'Wafat Isa Almasih'},
      {'date': '2024-04-10-11', 'name': 'Idul Fitri'},
      {'date': '2024-05-01', 'name': 'Hari Buruh'},
      {'date': '2024-05-09', 'name': 'Kenaikan Isa Almasih'},
      {'date': '2024-05-23', 'name': 'Hari Raya Waisak'},
      {'date': '2024-06-01', 'name': 'Hari Lahir Pancasila'},
      {'date': '2024-06-17', 'name': 'Idul Adha'},
      {'date': '2024-07-07', 'name': 'Tahun Baru Islam'},
      {'date': '2024-08-17', 'name': 'HUT RI'},
      {'date': '2024-09-16', 'name': 'Maulid Nabi'},
      {'date': '2024-12-25', 'name': 'Hari Raya Natal'},
    ],
    2025: [
      {'date': '2025-01-01', 'name': 'Tahun Baru 2025'},
      {'date': '2025-01-27', 'name': 'Isra Miraj'},
      {'date': '2025-01-29', 'name': 'Tahun Baru Imlek'},
      {'date': '2025-03-29', 'name': 'Hari Raya Nyepi'},
      {'date': '2025-03-31', 'name': 'Idul Fitri'},
      {'date': '2025-04-01', 'name': 'Idul Fitri'},
      {'date': '2025-04-18', 'name': 'Wafat Isa Almasih'},
      {'date': '2025-05-01', 'name': 'Hari Buruh'},
      {'date': '2025-05-29', 'name': 'Kenaikan Isa Almasih'},
      {'date': '2025-05-12', 'name': 'Hari Raya Waisak'},
      {'date': '2025-06-01', 'name': 'Hari Lahir Pancasila'},
      {'date': '2025-06-06', 'name': 'Idul Adha'},
      {'date': '2025-06-27', 'name': 'Tahun Baru Islam'},
      {'date': '2025-08-17', 'name': 'HUT RI'},
      {'date': '2025-09-05', 'name': 'Maulid Nabi'},
      {'date': '2025-12-25', 'name': 'Hari Raya Natal'},
    ],
    2026: [
      {'date': '2026-01-01', 'name': 'Tahun Baru 2026'},
      {'date': '2026-02-17', 'name': 'Tahun Baru Imlek'},
      {'date': '2026-03-20', 'name': 'Idul Fitri'},
      {'date': '2026-05-01', 'name': 'Hari Buruh'},
      {'date': '2026-05-27', 'name': 'Idul Adha'},
      {'date': '2026-08-17', 'name': 'HUT RI'},
      {'date': '2026-12-25', 'name': 'Hari Raya Natal'},
    ],
  };

  // ==================== INIT STATE ====================
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserData();
    _loadRates();
    _startClockTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _overtimeSubscription?.cancel();
    super.dispose();
  }

  // ==================== LOAD RATES ====================
  Future<void> _loadRates() async {
    try {
      _rates = await _overtimeService.loadOvertimeRates();
      if (mounted) setState(() {});
    } catch (e) {
      logger.e('Error loading rates: $e');
    }
  }

  // ==================== CLOCK TIMER ====================
  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // ==================== USER DATA ====================
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
            userName =
                data['nama_lengkap'] ?? data['email']?.split('@')[0] ?? 'Pengguna';
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

    _setupRealTimeListeners();
    await _loadOvertimeData();
    _initCalendarEvents();

    setState(() {
      isLoading = false;
    });
  }

  // ==================== REAL-TIME LISTENERS ====================
  void _setupRealTimeListeners() {
    if (userId == null || userRole == null) return;

    _overtimeSubscription?.cancel();

    try {
      _overtimeSubscription = _overtimeService
          .getOvertimeHistoryStream(
            userRole: userRole!,
            userFungsi: userFungsi,
            userId: userId,
          )
          .listen((overtimeList) {
        _processOvertimeList(overtimeList);
      });
    } catch (e) {
      logger.e('Error setting up overtime listener: $e');
    }
  }

  void _processOvertimeList(List<OvertimeHistory> overtimeList) {
    final Map<String, List<OvertimeHistory>> byDate = {};

    for (var overtime in overtimeList) {
      final dateKey = DateFormat('yyyy-MM-dd').format(overtime.tanggal);
      if (!byDate.containsKey(dateKey)) {
        byDate[dateKey] = [];
      }
      byDate[dateKey]!.add(overtime);
    }

    if (mounted) {
      setState(() {
        allOvertime = overtimeList;
        overtimeByDate = byDate;
        _applyAllFilters();
        _updateCalendarEvents();
      });
    }
  }

  // ==================== LOAD OVERTIME DATA ====================
  Future<void> _loadOvertimeData() async {
    if (userId == null || userRole == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final overtimeList = await _overtimeService
          .getOvertimeHistoryStream(
            userRole: userRole!,
            userFungsi: userFungsi,
            userId: userId,
          )
          .first;

      _processOvertimeList(overtimeList);
    } catch (e) {
      logger.e('Error loading overtime: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==================== CALENDAR EVENTS ====================
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
            final dateStr = holiday['date']!;
            if (dateStr.contains('-')) {
              final parts = dateStr.split('-');
              if (parts.length == 3) {
                holidays.add(DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                ));
              }
            }
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

  void _updateCalendarEvents() {
    final Map<DateTime, List<OvertimeEvent>> events = {};

    for (var overtime in allOvertime) {
      final dateKey = DateTime(
        overtime.tanggal.year,
        overtime.tanggal.month,
        overtime.tanggal.day,
      );
      if (!events.containsKey(dateKey)) {
        events[dateKey] = [];
      }

      final status = _getOvertimeExecutionStatus(overtime);
      events[dateKey]!.add(OvertimeEvent(
        id: overtime.id,
        title: overtime.namaMitra ?? 'Lembur',
        jamMulai: overtime.jamMulai,
        jamSelesai: overtime.jamSelesai,
        status: status,
      ));
    }

    setState(() {
      _events = events;
    });
  }

  bool _isHoliday(DateTime date) {
    return _holidays
        .contains(DateTime(date.year, date.month, date.day));
  }

  String? _getHolidayName(DateTime date) {
    final year = date.year;
    if (_indonesianHolidays.containsKey(year)) {
      for (var holiday in _indonesianHolidays[year]!) {
        try {
          final dateStr = holiday['date']!;
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final holidayDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            if (holidayDate.year == date.year &&
                holidayDate.month == date.month &&
                holidayDate.day == date.day) {
              return holiday['name'];
            }
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  // ==================== EXECUTION STATUS ====================
  String _getOvertimeExecutionStatus(OvertimeHistory overtime) {
    final status = overtime.status.toLowerCase();
    final tanggal = overtime.tanggal;
    final absensiStatus = overtime.absensiStatus;
    final now = DateTime.now();

    if (status == 'dibatalkan') return 'dibatalkan';
    if (status == 'kadaluarsa') return 'expired';
    if (status == 'ditolak') return 'ditolak';

    if (status != 'disetujui' && status != 'selesai') {
      return status;
    }

    final isUpcoming = tanggal.isAfter(now);
    final isPast =
        tanggal.isBefore(DateTime(now.year, now.month, now.day));
    final isToday = isSameDay(tanggal, now);

    if (isUpcoming) {
      final daysDifference = tanggal.difference(now).inDays;
      if (daysDifference <= 7) return 'upcoming_soon';
      return 'upcoming';
    }

    if (isPast) {
      if (status == 'selesai') return 'completed';
      if (absensiStatus == 'selesai') return 'completed_with_attendance';
      if (absensiStatus == 'check_in') return 'incomplete_checkout';
      return 'late';
    }

    if (isToday) {
      if (status == 'selesai') return 'completed';
      if (absensiStatus == 'selesai') return 'completed_with_attendance';

      final jamMulaiParts = overtime.jamMulai.split(':');
      final jamSelesaiParts = overtime.jamSelesai.split(':');

      final jamMulai = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(jamMulaiParts[0]),
        int.parse(jamMulaiParts[1]),
      );
      final jamSelesai = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(jamSelesaiParts[0]),
        int.parse(jamSelesaiParts[1]),
      );

      final hasCheckin =
          absensiStatus == 'check_in' || absensiStatus == 'selesai';

      if (now.isAfter(jamMulai)) {
        if (!hasCheckin) return 'late_today';
        if (absensiStatus == 'check_in' && now.isAfter(jamSelesai)) {
          return 'incomplete_checkout';
        }
      }

      return 'today_ongoing';
    }

    return status;
  }

  String _getExecutionStatusText(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return 'Jadwal Mendatang';
      case 'upcoming_soon':
        return 'Jadwal Segera';
      case 'completed':
        return 'Terselesaikan';
      case 'completed_with_attendance':
        return 'Terselesaikan ✓';
      case 'late':
        return 'Terlambat ✗';
      case 'late_today':
        return 'Belum Check In';
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
      case 'expired':
        return 'Kadaluarsa';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return executionStatus;
    }
  }

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
        return Colors.amber;
      case 'disetujui':
        return Colors.lightBlue;
      case 'ditolak':
        return Colors.redAccent;
      case 'expired':
        return Colors.brown;
      case 'dibatalkan':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

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
      case 'expired':
        return Icons.timer_off_rounded;
      case 'dibatalkan':
        return Icons.block_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  // ==================== FILTERS ====================
  void _applyAllFilters() {
    List<OvertimeHistory> filtered = List.from(allOvertime);

    // Filter by status
    if (filterStatus != 'semua') {
      if (filterStatus == 'need_absensi') {
        filtered = filtered
            .where((item) =>
                item.status == 'disetujui' && item.absensiStatus != 'selesai')
            .toList();
      } else {
        filtered = filtered
            .where((item) => item.status == filterStatus)
            .toList();
      }
    }

    // Filter by execution status
    if (executionFilter != 'semua') {
      filtered = filtered.where((item) {
        final execStatus = _getOvertimeExecutionStatus(item);
        switch (executionFilter) {
          case 'upcoming':
            return execStatus == 'upcoming' || execStatus == 'upcoming_soon';
          case 'completed':
            return execStatus == 'completed' ||
                execStatus == 'completed_with_attendance';
          case 'late':
            return execStatus == 'late' || execStatus == 'late_today';
          case 'ongoing':
            return execStatus == 'today_ongoing';
          case 'cancelled':
            return execStatus == 'dibatalkan';
          default:
            return false;
        }
      }).toList();
    }

    // Filter by date range
    if (filterStartDate != null) {
      filtered = filtered.where((item) {
        return item.tanggal
            .isAfter(filterStartDate!.subtract(const Duration(days: 1)));
      }).toList();
    }

    if (filterEndDate != null) {
      filtered = filtered.where((item) {
        return item.tanggal
            .isBefore(filterEndDate!.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      filteredOvertime = filtered;
    });
  }

  // ==================== REFRESH ====================
  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadOvertimeData();
    await _loadRates();
    setState(() => isRefreshing = false);
  }

  // ==================== APPROVE / REJECT / COMPLETE ====================
  Future<void> _approveOvertime(String overtimeId) async {
    try {
      await _overtimeService.updateOvertimeStatus(
        docId: overtimeId,
        status: 'disetujui',
      );

      if (mounted) {
        _showSuccessSnackbar('Lembur berhasil disetujui ✅');
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
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Tolak Pengajuan Lembur',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak pengajuan lembur ini?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan Penolakan',
                hintText: 'Masukkan alasan penolakan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _overtimeService.updateOvertimeStatus(
                  docId: overtimeId,
                  status: 'ditolak',
                  note: reasonController.text.isNotEmpty
                      ? reasonController.text
                      : null,
                );

                if (mounted) {
                  _showSuccessSnackbar('Lembur berhasil ditolak');
                  _refreshData();
                  Navigator.pop(context);
                }
              } catch (e) {
                logger.e('Error rejecting overtime: $e');
                if (mounted) _showErrorSnackbar('Gagal menolak lembur');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOvertime(String overtimeId) async {
    try {
      await _overtimeService.updateOvertimeStatus(
        docId: overtimeId,
        status: 'selesai',
      );

      if (mounted) {
        _showSuccessSnackbar('Lembur telah diselesaikan 🎉');
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      logger.e('Error completing overtime: $e');
      if (mounted) _showErrorSnackbar('Gagal menyelesaikan lembur');
    }
  }

  // ==================== CANCEL OVERTIME ====================
  Future<void> _cancelOvertime(String overtimeId) async {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Batalkan Pengajuan Lembur',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan pengajuan lembur ini?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan Pembatalan',
                hintText: 'Masukkan alasan pembatalan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _overtimeService.cancelOvertime(
                  docId: overtimeId,
                  alasanPembatalan: reasonController.text.isNotEmpty
                      ? reasonController.text
                      : 'Dibatalkan oleh $userName',
                );

                if (mounted) {
                  _showSuccessSnackbar('Pengajuan lembur berhasil dibatalkan');
                  _refreshData();
                  Navigator.pop(context);
                }
              } catch (e) {
                logger.e('Error cancelling overtime: $e');
                if (mounted) {
                  _showErrorSnackbar('Gagal membatalkan lembur: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  // ==================== RESTORE OVERTIME ====================
  Future<void> _restoreOvertime(String overtimeId) async {
    try {
      await _overtimeService.restoreCancelledOvertime(
        docId: overtimeId,
        catatanRestore: 'Direstore oleh $userName',
      );

      if (mounted) {
        _showSuccessSnackbar('Pengajuan lembur berhasil direstore 🔄');
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      logger.e('Error restoring overtime: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal merestore lembur: $e');
      }
    }
  }

  // ==================== CREATE OVERTIME DIALOG ====================
  void _showCreateOvertimeDialog() {
    final TextEditingController tanggalController = TextEditingController();
    final TextEditingController jamMulaiController =
        TextEditingController(text: '19:00');
    final TextEditingController jamSelesaiController =
        TextEditingController(text: '22:00');
    final TextEditingController alasanController = TextEditingController();
    final TextEditingController catatanController = TextEditingController();
    String jenisLembur = 'hari_kerja';
    String urgensi = 'normal';
    String? selectedMitraId;
    List<Map<String, dynamic>> mitraList = [];
    DateTime? selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Kalkulasi estimasi biaya
          double estimasiBiaya = 0;
          double totalJam = 0;
          if (_rates != null &&
              jamMulaiController.text.isNotEmpty &&
              jamSelesaiController.text.isNotEmpty) {
            try {
              final mulaiParts = jamMulaiController.text.split(':');
              final selesaiParts = jamSelesaiController.text.split(':');
              final startHour = int.parse(mulaiParts[0]);
              final startMin = int.parse(mulaiParts[1]);
              final endHour = int.parse(selesaiParts[0]);
              final endMin = int.parse(selesaiParts[1]);

              totalJam =
                  (endHour + endMin / 60.0) - (startHour + startMin / 60.0);
              if (totalJam < 0) totalJam += 24;

              final isHoliday = jenisLembur == 'hari_libur';
              estimasiBiaya = _overtimeService.calculateOvertimeCost(
                totalHours: totalJam,
                isHoliday: isHoliday,
                rates: _rates!,
              );
            } catch (e) {
              // ignore
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2B4C), Color(0xFF2A3F66)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.add_task_rounded, color: Colors.white),
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
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pilih Mitra (untuk pengawas/manager/superadmin)
                    if (isPengawas || isManager || isSuperAdmin) ...[
                      FutureBuilder<QuerySnapshot>(
                        future: _firestore
                            .collection('users')
                            .where('role', isEqualTo: 'mitra')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            mitraList = snapshot.data!.docs.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              data['id'] = doc.id;
                              return data;
                            }).toList();
                          }

                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Pilih Mitra',
                              labelStyle: GoogleFonts.poppins(fontSize: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: mitraList.map((mitra) {
                              return DropdownMenuItem<String>(
                                value: mitra['id'],
                                child: Text(
                                  mitra['nama_lengkap'] ?? mitra['email'] ?? '',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
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
                      const SizedBox(height: 14),
                    ],

                    // Tanggal
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF1A2B4C),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                            tanggalController.text =
                                DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Color(0xFF1A2B4C), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              selectedDate != null
                                  ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                      .format(selectedDate!)
                                  : 'Pilih Tanggal',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: selectedDate != null
                                    ? const Color(0xFF1A2B4C)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Jam Mulai & Selesai
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: jamMulaiController,
                            decoration: InputDecoration(
                              labelText: 'Jam Mulai',
                              labelStyle: GoogleFonts.poppins(fontSize: 13),
                              hintText: '19:00',
                              prefixIcon: const Icon(Icons.login_rounded,
                                  color: Color(0xFF1A2B4C)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: Colors.grey),
                        ),
                        Expanded(
                          child: TextField(
                            controller: jamSelesaiController,
                            decoration: InputDecoration(
                              labelText: 'Jam Selesai',
                              labelStyle: GoogleFonts.poppins(fontSize: 13),
                              hintText: '22:00',
                              prefixIcon: const Icon(Icons.logout_rounded,
                                  color: Color(0xFF1A2B4C)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Jenis Lembur
                    DropdownButtonFormField<String>(
                      initialValue: jenisLembur,
                      decoration: InputDecoration(
                        labelText: 'Jenis Lembur',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'hari_kerja', child: Text('Hari Kerja')),
                        DropdownMenuItem(
                            value: 'hari_libur', child: Text('Hari Libur')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          jenisLembur = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Urgensi
                    DropdownButtonFormField<String>(
                      initialValue: urgensi,
                      decoration: InputDecoration(
                        labelText: 'Urgensi',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'rendah', child: Text('Rendah')),
                        DropdownMenuItem(
                            value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'tinggi', child: Text('Tinggi')),
                        DropdownMenuItem(value: 'kritis', child: Text('Kritis')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          urgensi = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Alasan
                    TextField(
                      controller: alasanController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Alasan Lembur',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        hintText: 'Jelaskan alasan lembur...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Catatan Tambahan
                    TextField(
                      controller: catatanController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan Tambahan (Opsional)',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        hintText: 'Catatan tambahan...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Estimasi Biaya
                    if (_rates != null && totalJam > 0)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_rounded,
                                    color: Color(0xFF1A2B4C), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Estimasi Biaya Lembur',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: const Color(0xFF1A2B4C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildEstimasiRow(
                                'Total Jam', '${totalJam.toStringAsFixed(1)} Jam'),
                            _buildEstimasiRow(
                              'Rate/Jam',
                              _overtimeService.formatRupiah(
                                  _overtimeService.getRatePerHour(_rates!)),
                            ),
                            _buildEstimasiRow(
                                'Jenis', jenisLembur == 'hari_libur' ? 'Hari Libur' : 'Hari Kerja'),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Estimasi Total',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: const Color(0xFF1A2B4C),
                                  ),
                                ),
                                Text(
                                  _overtimeService.formatRupiah(estimasiBiaya),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (selectedDate == null) {
                    _showErrorSnackbar('Tanggal harus dipilih');
                    return;
                  }
                  if (jamMulaiController.text.isEmpty ||
                      jamSelesaiController.text.isEmpty) {
                    _showErrorSnackbar('Jam mulai dan selesai harus diisi');
                    return;
                  }

                  final targetMitraId = isMitra ? userId : selectedMitraId;
                  if (targetMitraId == null) {
                    _showErrorSnackbar('Mitra harus dipilih');
                    return;
                  }

                  try {
                    final mitraDoc = await _firestore
                        .collection('users')
                        .doc(targetMitraId)
                        .get();
                    if (!mitraDoc.exists) {
                      _showErrorSnackbar('Data mitra tidak ditemukan');
                      return;
                    }

                    final mitraData = mitraDoc.data()!;

                    final mulaiParts = jamMulaiController.text.split(':');
                    final selesaiParts = jamSelesaiController.text.split(':');
                    final startHour = int.parse(mulaiParts[0]);
                    final startMin = int.parse(mulaiParts[1]);
                    final endHour = int.parse(selesaiParts[0]);
                    final endMin = int.parse(selesaiParts[1]);

                    double totalJam =
                        (endHour + endMin / 60.0) - (startHour + startMin / 60.0);
                    if (totalJam < 0) totalJam += 24;

                    final isHoliday = jenisLembur == 'hari_libur';
                    final rates = await _overtimeService.loadOvertimeRates();
                    final estimasiBiaya = _overtimeService.calculateOvertimeCost(
                      totalHours: totalJam,
                      isHoliday: isHoliday,
                      rates: rates,
                    );

                    final groupId =
                        '${DateTime.now().millisecondsSinceEpoch}_${targetMitraId.hashCode}';

                    await _firestore.collection('lembur_mitra').add({
                      'group_id': groupId,
                      'pengawas_id':
                          isPengawas || isManager || isSuperAdmin ? userId : null,
                      'nama_pengawas':
                          isPengawas || isManager || isSuperAdmin ? userName : null,
                      'pengawas_fungsi':
                          isPengawas || isManager || isSuperAdmin ? userFungsi : null,
                      'mitra_id': targetMitraId,
                      'nama_mitra':
                          mitraData['nama_lengkap'] ?? mitraData['email'],
                      'fungsi_mitra': mitraData['fungsi'],
                      'no_hp_mitra': mitraData['no_hp'],
                      'tanggal': Timestamp.fromDate(selectedDate!),
                      'tahun_bulan':
                          DateFormat('yyyy-MM').format(selectedDate!),
                      'jam_mulai': jamMulaiController.text,
                      'jam_selesai': jamSelesaiController.text,
                      'total_jam_desimal': totalJam,
                      'jenis_lembur': jenisLembur,
                      'lokasi': {},
                      'urgensi': urgensi,
                      'alasan': alasanController.text,
                      'catatan_tambahan': catatanController.text,
                      'estimasi_biaya_per_mitra': estimasiBiaya,
                      'estimasi_biaya_total': estimasiBiaya,
                      'total_mitra': 1,
                      'is_multiple': false,
                      'is_override': false,
                      'status': 'pending',
                      'absensi_status': 'belum_absen',
                      'rate_snapshot': rates,
                      'created_at': FieldValue.serverTimestamp(),
                      'updated_at': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(ctx);
                    _showSuccessSnackbar(
                        'Jadwal lembur berhasil dibuat 🎉');
                    _refreshData();
                  } catch (e) {
                    logger.e('Error creating overtime: $e');
                    _showErrorSnackbar('Gagal membuat jadwal lembur');
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  'Simpan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B4C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEstimasiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
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

  // ==================== DETAIL BOTTOM SHEET ====================
  void _showOvertimeDetail(OvertimeHistory overtime) {
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final isHoliday = _isHoliday(overtime.tanggal);
    final holidayName = _getHolidayName(overtime.tanggal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getExecutionStatusColor(executionStatus)
                                    .withValues(alpha: 0.15),
                                _getExecutionStatusColor(executionStatus)
                                    .withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _getExecutionStatusIcon(executionStatus),
                            color:
                                _getExecutionStatusColor(executionStatus),
                            size: 30,
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A2B4C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                overtime.namaMitra ?? 'Mitra',
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
                  ),

                  const SizedBox(height: 20),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildDetailRow(
                          Icons.calendar_today_rounded,
                          'Tanggal Lembur',
                          _overtimeService.formatTanggal(overtime.tanggal),
                        ),
                        if (isHoliday) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            Icons.celebration_rounded,
                            'Hari Libur',
                            holidayName ?? 'Hari Libur Nasional',
                            color: Colors.red,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.access_time_rounded,
                          'Waktu Lembur',
                          '${overtime.jamMulai} - ${overtime.jamSelesai} WIB',
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.timer_rounded,
                          'Total Jam',
                          '${overtime.totalJam.toStringAsFixed(1)} Jam',
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.monetization_on_rounded,
                          'Estimasi Biaya',
                          _overtimeService
                              .formatRupiah(overtime.estimasiBiayaPerMitra),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.work_rounded,
                          'Fungsi',
                          _overtimeService
                              .getFungsiLabel(overtime.fungsiMitra),
                          color: _overtimeService
                              .getFungsiColor(overtime.fungsiMitra),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.label_rounded,
                          'Jenis Lembur',
                          _overtimeService
                              .getJenisLemburLabel(overtime.jenisLembur),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.priority_high_rounded,
                          'Urgensi',
                          _overtimeService
                              .getUrgensiLabel(overtime.urgensi),
                          color: _overtimeService
                              .getUrgensiColor(overtime.urgensi),
                        ),
                        if (overtime.alasan.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            Icons.description_rounded,
                            'Alasan',
                            overtime.alasan,
                          ),
                        ],
                        if (overtime.catatanTambahan.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            Icons.note_rounded,
                            'Catatan',
                            overtime.catatanTambahan,
                          ),
                        ],
                        if (overtime.namaPengawas != null) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            Icons.verified_user_rounded,
                            'Diajukan Oleh',
                            overtime.namaPengawas!,
                          ),
                        ],
                        if (overtime.isCancelled) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            Icons.block_rounded,
                            'Dibatalkan Oleh',
                            overtime.dibatalkanOlehNama ?? '-',
                            subtitle:
                                overtime.alasanPembatalan ?? 'Dibatalkan',
                            color: Colors.red,
                          ),
                        ],

                        const Divider(height: 28),

                        // Status Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getExecutionStatusColor(executionStatus)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getExecutionStatusColor(
                                      executionStatus)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getExecutionStatusIcon(
                                        executionStatus),
                                    size: 22,
                                    color: _getExecutionStatusColor(
                                        executionStatus),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Status Eksekusi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A2B4C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getExecutionStatusDescription(
                                    executionStatus),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                              if (executionStatus == 'late' ||
                                  executionStatus == 'late_today')
                                _buildWarningBox(
                                  Icons.warning_amber_rounded,
                                  Colors.red,
                                  executionStatus == 'late_today'
                                      ? 'Anda belum melakukan check in untuk jadwal lembur hari ini.'
                                      : 'Lembur TIDAK BERJALAN karena tidak ada absensi tercatat.',
                                ),
                              if (executionStatus ==
                                  'incomplete_checkout')
                                _buildWarningBox(
                                  Icons.logout_rounded,
                                  Colors.deepOrange,
                                  'Anda sudah check in namun belum check out.',
                                ),
                              if (executionStatus ==
                                  'completed_with_attendance')
                                _buildWarningBox(
                                  Icons.check_circle_rounded,
                                  Colors.green,
                                  'Lembur terselesaikan dengan absensi lengkap.',
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        if (canApproveOvertime &&
                            overtime.status == 'pending') ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.check_circle_rounded,
                                  label: 'Setujui',
                                  color: Colors.green,
                                  onPressed: () =>
                                      _approveOvertime(overtime.id),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.cancel_rounded,
                                  label: 'Tolak',
                                  color: Colors.red,
                                  onPressed: () =>
                                      _rejectOvertime(overtime.id),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (overtime.status == 'disetujui' &&
                            overtime.absensiStatus != 'selesai')
                          _buildActionButton(
                            icon: Icons.task_alt_rounded,
                            label: 'Selesaikan Lembur',
                            color: const Color(0xFF1A2B4C),
                            onPressed: () =>
                                _completeOvertime(overtime.id),
                            fullWidth: true,
                          ),

                        if (canCancelOvertime &&
                            overtime.canBeCancelled) ...[
                          const SizedBox(height: 12),
                          _buildActionButton(
                            icon: Icons.block_rounded,
                            label: 'Batalkan Pengajuan',
                            color: Colors.red,
                            onPressed: () =>
                                _cancelOvertime(overtime.id),
                            fullWidth: true,
                            outlined: true,
                          ),
                        ],

                        if (canRestoreOvertime &&
                            overtime.isCancelled) ...[
                          const SizedBox(height: 12),
                          _buildActionButton(
                            icon: Icons.restore_rounded,
                            label: 'Restore Pengajuan',
                            color: Colors.blue,
                            onPressed: () =>
                                _restoreOvertime(overtime.id),
                            fullWidth: true,
                          ),
                        ],

                        const SizedBox(height: 16),
                        _buildActionButton(
                          icon: Icons.close_rounded,
                          label: 'Tutup',
                          color: Colors.grey,
                          onPressed: () => Navigator.pop(context),
                          fullWidth: true,
                          outlined: true,
                        ),

                        const SizedBox(height: 30),
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

  Widget _buildWarningBox(IconData icon, Color color, String message) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool fullWidth = false,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  String _getExecutionStatusDescription(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming':
        return 'Jadwal lembur yang akan datang. Pastikan Anda mempersiapkan diri.';
      case 'upcoming_soon':
        return 'Jadwal lembur dalam waktu dekat (kurang dari 7 hari).';
      case 'completed':
        return 'Lembur telah selesai.';
      case 'completed_with_attendance':
        return 'Lembur telah terselesaikan dengan bukti absensi lengkap.';
      case 'late':
        return 'Lembur TIDAK BERJALAN - tidak ada absensi tercatat.';
      case 'late_today':
        return 'Segera lakukan check in melalui halaman absensi.';
      case 'incomplete_checkout':
        return 'Segera lakukan check out setelah selesai lembur.';
      case 'today_ongoing':
        return 'Lembur hari ini dalam jadwal.';
      case 'expired':
        return 'Lembur telah kadaluarsa karena tidak ada absensi.';
      case 'dibatalkan':
        return 'Pengajuan lembur ini telah dibatalkan.';
      case 'ditolak':
        return 'Pengajuan lembur ini telah ditolak.';
      default:
        return 'Status lembur sedang dalam proses.';
    }
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    String? subtitle,
    Color? color,
  }) {
    final effectiveColor = color ?? const Color(0xFF1A2B4C);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: effectiveColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[400],
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

  Widget _buildExecutionStatusBadge(String executionStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            _getExecutionStatusColor(executionStatus).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _getExecutionStatusColor(executionStatus).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getExecutionStatusIcon(executionStatus),
            size: 14,
            color: _getExecutionStatusColor(executionStatus),
          ),
          const SizedBox(width: 5),
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

  // ==================== HELPER METHODS ====================
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return DateFormat('HH:mm:ss').format(now);
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
  }

  // ==================== SNACKBARS ====================
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== MAIN BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1A2B4C),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleInfoCard(),
                    const SizedBox(height: 16),
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterSection(),
                    const SizedBox(height: 12),
                    _buildExecutionStatusFilter(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(),
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
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Buat Lembur',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            color: Colors.white.withValues(alpha: 0.2),
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
          tooltip: 'Refresh',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildRoleInfoCard() {
    String roleText = '';
    String roleDescription = '';
    IconData roleIcon = Icons.person_rounded;
    List<Color> gradientColors = const [Color(0xFF1A2B4C), Color(0xFF2A3F66)];

    if (isMitra) {
      roleText = 'Mitra';
      roleDescription = 'Anda hanya dapat melihat jadwal lembur Anda sendiri';
      roleIcon = Icons.person_rounded;
    } else if (isPengawas) {
      roleText = 'Pengawas';
      roleDescription =
          'Mengelola jadwal lembur tim ${_overtimeService.getFungsiLabel(userFungsi)}';
      roleIcon = Icons.visibility_rounded;
      gradientColors = const [Color(0xFF0D47A1), Color(0xFF1976D2)];
    } else if (isManager) {
      roleText = 'Manager';
      roleDescription = 'Mengelola semua jadwal lembur sesuai fungsi';
      roleIcon = Icons.manage_accounts_rounded;
      gradientColors = const [Color(0xFF1B5E20), Color(0xFF388E3C)];
    } else if (isSuperAdmin) {
      roleText = 'Super Admin';
      roleDescription = 'Akses penuh ke seluruh jadwal lembur';
      roleIcon = Icons.admin_panel_settings_rounded;
      gradientColors = const [Color(0xFF4A148C), Color(0xFF7B1FA2)];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(roleIcon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleText,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
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
            color: Colors.grey.withValues(alpha: 0.08),
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
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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

                final dateKey =
                    DateFormat('yyyy-MM-dd').format(selectedDay);
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
                final isSelected = isSameDay(date, _selectedDay);

                return Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : isHoliday
                            ? Colors.red.shade50
                            : hasEvent
                                ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
                                : null,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : isHoliday
                            ? Border.all(
                                color: Colors.red.shade200, width: 1)
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
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : isHoliday
                                        ? Colors.red
                                        : hasEvent
                                            ? const Color(0xFFFF6B35)
                                            : Colors.grey[800],
                              ),
                            ),
                            if (isHoliday && holidayName != null)
                              Text(
                                holidayName.length > 6
                                    ? '${holidayName.substring(0, 6)}..'
                                    : holidayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 7,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasEvent && !isSelected && !isHoliday)
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            width: 7,
                            height: 7,
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
                final isSelected = isSameDay(date, _selectedDay);
                return Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF1A2B4C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: const Color(0xFF1A2B4C)
                                .withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A2B4C),
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
              leftChevronIcon: const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF1A2B4C)),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF1A2B4C)),
              formatButtonTextStyle: GoogleFonts.poppins(
                color: const Color(0xFF1A2B4C),
                fontWeight: FontWeight.w500,
              ),
            ),
            calendarStyle: CalendarStyle(
              weekendTextStyle: GoogleFonts.poppins(color: Colors.red),
              outsideDaysVisible: false,
              todayDecoration: const BoxDecoration(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(const Color(0xFFFF6B35), 'Ada Lembur'),
              _buildLegendItem(Colors.red, 'Hari Libur'),
              _buildLegendItem(const Color(0xFF1A2B4C), 'Hari Ini'),
              _buildLegendItem(Colors.green, 'Terselesaikan'),
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
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari mitra, fungsi, atau pengawas...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF1A2B4C)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
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
                  initialValue: filterStatus,
                  decoration: InputDecoration(
                    labelText: 'Status Pengajuan',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                  items: const [
                    DropdownMenuItem(
                        value: 'semua', child: Text('Semua Status')),
                    DropdownMenuItem(
                        value: 'pending', child: Text('⏳ Menunggu')),
                    DropdownMenuItem(
                        value: 'disetujui', child: Text('✅ Disetujui')),
                    DropdownMenuItem(
                        value: 'ditolak', child: Text('❌ Ditolak')),
                    DropdownMenuItem(
                        value: 'selesai', child: Text('🎉 Selesai')),
                    DropdownMenuItem(
                        value: 'dibatalkan',
                        child: Text('🚫 Dibatalkan')),
                    DropdownMenuItem(
                        value: 'need_absensi',
                        child: Text('📸 Butuh Absensi')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filterStatus = value!;
                      _applyAllFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Reset Filter Button
              if (filterStatus != 'semua' ||
                  filterStartDate != null ||
                  filterEndDate != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      filterStatus = 'semua';
                      executionFilter = 'semua';
                      filterStartDate = null;
                      filterEndDate = null;
                      searchQuery = '';
                      _applyAllFilters();
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded,
                      color: Colors.red),
                  tooltip: 'Reset Filter',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
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
                        _applyAllFilters();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded,
                            size: 18, color: Color(0xFF1A2B4C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filterStartDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(filterStartDate!)
                                : 'Dari Tanggal',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: filterStartDate != null
                                  ? const Color(0xFF1A2B4C)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        if (filterStartDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                filterStartDate = null;
                                _applyAllFilters();
                              });
                            },
                            child:
                                const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                        _applyAllFilters();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded,
                            size: 18, color: Color(0xFF1A2B4C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filterEndDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(filterEndDate!)
                                : 'Sampai Tanggal',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: filterEndDate != null
                                  ? const Color(0xFF1A2B4C)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        if (filterEndDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                filterEndDate = null;
                                _applyAllFilters();
                              });
                            },
                            child:
                                const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('📋 Semua', 'semua'),
          const SizedBox(width: 8),
          _buildFilterChip('📅 Mendatang', 'upcoming'),
          const SizedBox(width: 8),
          _buildFilterChip('✅ Terselesaikan', 'completed'),
          const SizedBox(width: 8),
          _buildFilterChip('⚠️ Terlambat', 'late'),
          const SizedBox(width: 8),
          _buildFilterChip('🔄 Berlangsung', 'ongoing'),
          const SizedBox(width: 8),
          _buildFilterChip('🚫 Dibatalkan', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterValue) {
    final isSelected = executionFilter == filterValue;

    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          executionFilter = selected ? filterValue : 'semua';
          _applyAllFilters();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1A2B4C),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF1A2B4C) : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Daftar Lembur',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A2B4C),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2B4C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${displayedOvertime.length} Data',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeCard(OvertimeHistory overtime) {
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final isHoliday = _isHoliday(overtime.tanggal);

    return GestureDetector(
      onTap: () => _showOvertimeDetail(overtime),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: overtime.isCancelled
              ? Border.all(color: Colors.grey.shade300, width: 1)
              : null,
        ),
        child: Opacity(
          opacity: overtime.isCancelled ? 0.65 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon Container
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getExecutionStatusColor(executionStatus)
                                .withValues(alpha: 0.2),
                            _getExecutionStatusColor(executionStatus)
                                .withValues(alpha: 0.05),
                          ],
                        ),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  overtime.namaMitra ?? 'Mitra',
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
                          const SizedBox(height: 5),
                          Text(
                            _overtimeService
                                .formatTanggal(overtime.tanggal),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${overtime.jamMulai} - ${overtime.jamSelesai}',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.timer_rounded,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${overtime.totalJam.toStringAsFixed(1)} jam',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.monetization_on_rounded,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                _overtimeService.formatRupiahCompact(
                                    overtime.estimasiBiayaPerMitra),
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          if (isHoliday) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.celebration_rounded,
                                    size: 12, color: Colors.red),
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
                // Quick Action Buttons
                if (canApproveOvertime &&
                    overtime.status == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _approveOvertime(overtime.id),
                          icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 16),
                          label: const Text('Setujui'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(
                                color: Colors.green
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _rejectOvertime(overtime.id),
                          icon: const Icon(Icons.cancel_rounded,
                              size: 16),
                          label: const Text('Tolak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(
                                color: Colors.red
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak Ada Jadwal Lembur',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            canCreateOvertime
                ? 'Klik tombol + di bawah untuk membuat\njadwal lembur baru'
                : 'Belum ada jadwal lembur yang tersedia\nuntuk ditampilkan',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1A2B4C),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat jadwal lembur...',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== OvertimeEvent Model ====================
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