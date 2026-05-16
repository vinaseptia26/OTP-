import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/overtime_history_service.dart';
import '/widgets/absensi/absensi_stats_card.dart';
import '/widgets/absensi/absensi_filter_chips.dart';
import '/widgets/absensi/absensi_list_view.dart';
import '/widgets/absensi/month_picker_sheet.dart';

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

class _AbsensiHistoryScreenState extends State<AbsensiHistoryScreen> {
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String _userName = 'Mitra'; // ⬅️ tidak pakai email lagi
  String? _userPhotoUrl;

  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedStatus = 'semua';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _selectedStatus = widget.initialTab!;
    }
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _userId = user.uid;

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
          // ✅ Gunakan nama_lengkap dari Firestore, atau displayName dari auth (tanpa email)
          _userName = (data?['nama_lengkap'] ?? user.displayName) ?? 'Mitra';
          _userPhotoUrl = data?['photo_url'] ?? user.photoURL;
        });
      } else {
        // Jika dokumen tidak ada, gunakan displayName atau fallback aman
        setState(() {
          _userName = user.displayName ?? 'Mitra';
          _userPhotoUrl = user.photoURL;
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      // fallback
      setState(() {
        _userName = user.displayName ?? 'Mitra';
        _userPhotoUrl = user.photoURL;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _searchQuery = query.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: const Color(0xFF1976D2),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildUserHeader()),
            SliverToBoxAdapter(
              child: AbsensiStatsCard(
                historyService: _historyService,
                userRole: _userRole!,
                userFungsi: _userFungsi,
                userId: _userId,
                selectedBulan: _selectedBulan,
              ),
            ),
            SliverToBoxAdapter(
              child: AbsensiFilterChips(
                selectedStatus: _selectedStatus,
                onStatusChanged: (status) => setState(() => _selectedStatus = status),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverFillRemaining(
              child: AbsensiListView(
                userRole: _userRole!,
                userFungsi: _userFungsi,
                userId: _userId,
                selectedBulan: _selectedBulan,
                selectedStatus: _selectedStatus,
                searchQuery: _searchQuery,
                lemburIdHighlight: widget.lemburId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Riwayat Absensi',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      backgroundColor: const Color(0xFF1E3C72),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E3C72),
              const Color(0xFF1E3C72).withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month, size: 22),
          onPressed: () => MonthPickerSheet.show(
            context,
            selectedMonth: _selectedBulan,
            onMonthSelected: (month) => setState(() => _selectedBulan = month),
          ),
          tooltip: 'Pilih Bulan',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, size: 22),
          tooltip: 'Filter Status',
          onSelected: (value) => setState(() => _selectedStatus = value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'semua', child: Text('Semua Status')),
            const PopupMenuItem(
                value: 'belum_absen', child: Text('🔶 Belum Absen')),
            const PopupMenuItem(
                value: 'sudah_absen', child: Text('✅ Sudah Absen')),
            const PopupMenuItem(
                value: 'kadaluarsa', child: Text('⏰ Kadaluarsa')),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildUserHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3C72).withOpacity(0.9),
            const Color(0xFF2A4F8C).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(_userPhotoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                ? Center(
                    child: Text(
                      (_userName.isNotEmpty ? _userName[0] : '?').toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang,',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  _userName, // ⬅️ hanya nama, tidak ada email
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMMM yyyy', 'id_ID')
                          .format(DateTime.parse('$_selectedBulan-01')),
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userRole?.toUpperCase() ?? 'MITRA',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari mitra, pengawas, atau jam…',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}