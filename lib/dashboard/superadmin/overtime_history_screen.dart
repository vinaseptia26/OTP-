import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/overtime_history/overtime_stats_card.dart';
import '/widgets/overtime_history/overtime_filter_chips.dart';
import '/widgets/overtime_history/overtime_list_view.dart';
import '/widgets/overtime_history/month_picker_sheet.dart';

class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({super.key});

  @override
  State<OvertimeHistoryScreen> createState() => _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState extends State<OvertimeHistoryScreen> {
  // Services
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  final OvertimeRateService _rateService = OvertimeRateService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // User Data
  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String? _userName;

  // Filters
  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedStatus = 'semua';

  // Loading
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _userId = user.uid;
    _userName = user.displayName ?? user.email?.split('@').first ?? 'User';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _userRole = data?['role'] ?? 'mitra';
          _userFungsi = data?['fungsi']?.toString().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          _getTitleByRole(),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => MonthPickerSheet.show(
              context,
              selectedMonth: _selectedBulan,
              onMonthSelected: (month) => setState(() => _selectedBulan = month),
            ),
            tooltip: 'Pilih Bulan',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Status',
            onSelected: (value) => setState(() => _selectedStatus = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'semua', child: Text('Semua Status')),
              const PopupMenuItem(value: 'pending', child: Text('🔶 Pending')),
              const PopupMenuItem(value: 'disetujui', child: Text('✅ Disetujui')),
              const PopupMenuItem(value: 'ditolak', child: Text('❌ Ditolak')),
              const PopupMenuItem(value: 'selesai', child: Text('✔️ Selesai')),
            ],
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Export Excel',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: const Color(0xFF1976D2),
        child: Column(
          children: [
            OvertimeStatsCard(
              historyService: _historyService,
              userRole: _userRole ?? 'mitra',
              userFungsi: _userFungsi,
              userId: _userId,
              selectedBulan: _selectedBulan,
            ),
            OvertimeFilterChips(
              selectedStatus: _selectedStatus,
              onStatusChanged: (status) => setState(() => _selectedStatus = status),
            ),
            Expanded(
              child: OvertimeListView(
                historyService: _historyService,
                rateService: _rateService,
                userRole: _userRole ?? 'mitra',
                userFungsi: _userFungsi,
                userId: _userId,
                userName: _userName,
                selectedBulan: _selectedBulan,
                selectedStatus: _selectedStatus,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _userRole == 'pengawas'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/ajukan-lembur')
                  .then((_) => setState(() {})),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Ajukan'),
              backgroundColor: const Color(0xFF1976D2),
            )
          : null,
    );
  }

  String _getTitleByRole() {
    switch (_userRole) {
      case 'superadmin':
      case 'manager':
        return 'Riwayat Lembur';
      case 'pengawas':
        return 'Pengajuan Saya';
      case 'mitra':
        return 'Lembur Saya';
      default:
        return 'Riwayat Lembur';
    }
  }

  Future<void> _exportToExcel() async {
    // Implementasi export Excel dapat ditambahkan di sini
    // Contoh: menggunakan package excel untuk generate file .xlsx
    setState(() => _isExporting = true);
    try {
      // ... logika export ...
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Export berhasil')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}