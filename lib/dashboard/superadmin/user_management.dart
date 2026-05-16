// lib/features/superadmin/user_management_screen.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/core/services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  bool _isLoading = true;
  bool _isSearching = false;

  String? _currentUserRole;
  String? _currentUserId;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ================= FILTER STATE =================
  String _searchQuery = '';
  String _selectedRole = 'Semua';
  String _selectedStatus = 'Semua';
  String _selectedFungsi = 'Semua';
  bool _showFilterPanel = false;

  // ================= COLORS =================
  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color secondaryBlue = Color(0xFF283593);
  static const Color accentBlue = Color(0xFF3F51B5);
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);

  // Pre-computed opacity colors (biar gak pake .withOpacity di web)
  static Color _opacity(Color color, int alpha) {
    return Color.fromARGB(alpha, color.red, color.green, color.blue);
  }

  Color _statShadow(Color color) => _opacity(color, 20);  // 0.08
  Color _statBg(Color color) => _opacity(color, 26);       // 0.1
  Color _cardShadow() => _opacity(Colors.black, 10);        // 0.04
  Color _chipBg(Color color) => _opacity(color, 26);        // 0.1
  Color _chipBgLight(Color color) => _opacity(color, 20);   // 0.08
  Color _avatarBg(Color color) => _opacity(color, 51);      // 0.2
  Color _avatarBgLight(Color color) => _opacity(color, 13); // 0.05
  Color _infoChipBg(Color color) => _opacity(color, 20);    // 0.08
  Color _actionBg(Color color) => _opacity(color, 20);      // 0.08
  Color _statusBg(Color color) => _opacity(color, 26);      // 0.1
  Color _detailBg(Color color) => _opacity(color, 20);      // 0.08

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentUser();
    await _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ================= INIT =================
  Future<void> _getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      final data = await _authService.getUserById(user.uid);
      _currentUserRole = data?['role'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _users = await _authService.getAllUsers();
      _applyFilters();
    } catch (e) {
      _showMsg('Gagal memuat data user', true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  // ================= HELPERS =================
  String _sid() =>
      'session_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  bool get canAdd =>
      _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canEdit =>
      _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canDelete => _currentUserRole == 'superadmin';

  void _showMsg(String msg, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? dangerColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'superadmin': return 'Super Admin';
      case 'manager': return 'Manager';
      case 'pengawas': return 'Pengawas';
      case 'mitra': return 'Mitra';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin': return const Color(0xFF7C3AED);
      case 'manager': return const Color(0xFF2563EB);
      case 'pengawas': return const Color(0xFF059669);
      case 'mitra': return const Color(0xFFD97706);
      default: return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'superadmin': return Icons.admin_panel_settings_rounded;
      case 'manager': return Icons.manage_accounts_rounded;
      case 'pengawas': return Icons.verified_user_rounded;
      case 'mitra': return Icons.person_rounded;
      default: return Icons.person_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'Aktif';
      case 'inactive': return 'Nonaktif';
      case 'blocked': return 'Diblokir';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return successColor;
      case 'inactive': return warningColor;
      case 'blocked': return dangerColor;
      default: return Colors.grey;
    }
  }

  String _fungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operation';
      case 'lab': return 'Lab';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi;
    }
  }

  String _formatDate(dynamic t) {
    if (t == null) return '-';
    DateTime d;
    if (t is Timestamp) {
      d = t.toDate();
    } else if (t is DateTime) {
      d = t;
    } else {
      return '-';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ================= FILTER LOGIC =================
  void _onSearch() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final searchMatch = _searchQuery.isEmpty ||
            (user['nama_lengkap']?.toString().toLowerCase().contains(_searchQuery) == true) ||
            (user['email']?.toString().toLowerCase().contains(_searchQuery) == true) ||
            (user['phone']?.toString().toLowerCase().contains(_searchQuery) == true);

        final roleMatch = _selectedRole == 'Semua' || user['role'] == _selectedRole;
        final statusMatch = _selectedStatus == 'Semua' || user['status_akun'] == _selectedStatus;
        final fungsiMatch = _selectedFungsi == 'Semua' || user['fungsi'] == _selectedFungsi;

        return searchMatch && roleMatch && statusMatch && fungsiMatch;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedRole = 'Semua';
      _selectedStatus = 'Semua';
      _selectedFungsi = 'Semua';
      _searchController.clear();
      _searchQuery = '';
    });
    _applyFilters();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedRole != 'Semua') count++;
    if (_selectedStatus != 'Semua') count++;
    if (_selectedFungsi != 'Semua') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  // ================= CRUD =================
  Future<void> _createUser(Map<String, dynamic> data) async {
    final result = await _authService.createUser(
      nama: data['nama'],
      email: data['email'],
      phone: data['phone'],
      password: data['password'],
      role: data['role'],
      fungsi: data['fungsi'],
    );

    if (result.success) {
      // Tutup bottom sheet form
      if (mounted) Navigator.of(context).pop();
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _updateUser(Map<String, dynamic> data) async {
    final result = await _authService.updateUser(
      userId: data['id'],
      nama: data['nama'],
      email: data['email'],
      phone: data['phone'],
      password: data['password'],
      role: data['role'],
      fungsi: data['fungsi'],
      sessionId: _sid(),
    );

    if (result.success) {
      // Tutup bottom sheet form
      if (mounted) Navigator.of(context).pop();
      // Refresh data tapi tetap di halaman yang sama
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _deleteUser(String id, String name) async {
    // Tutup dialog konfirmasi
    if (mounted) Navigator.pop(context);
    
    final result = await _authService.deleteUser(userId: id, sessionId: _sid());
    if (result.success) {
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _toggleUserStatus(String id, String current) async {
    final newStatus = current == 'active' ? 'inactive' : 'active';
    final result = await _authService.toggleUserStatus(
      userId: id, newStatus: newStatus, sessionId: _sid(),
    );
    if (result.success) {
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      floatingActionButton: canAdd ? _buildFAB() : null,
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildSearchAndFilter(),
          if (_showFilterPanel) _buildFilterPanel(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryBlue, secondaryBlue],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
      ),
      title: Text('User Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20)),
      centerTitle: false,
      actions: [
        IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showForm(),
      backgroundColor: accentBlue,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Tambah User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      elevation: 8,
    );
  }

  // ================= STATS HEADER =================
  Widget _buildStatsHeader() {
    final activeCount = _users.where((e) => e['status_akun'] == 'active').length;
    final inactiveCount = _users.where((e) => e['status_akun'] == 'inactive').length;
    final blockedCount = _users.where((e) => e['status_akun'] == 'blocked').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _buildStatCard('Total', _users.length, Icons.people_rounded, accentBlue),
          const SizedBox(width: 8),
          _buildStatCard('Aktif', activeCount, Icons.check_circle_rounded, successColor),
          const SizedBox(width: 8),
          _buildStatCard('Nonaktif', inactiveCount, Icons.pause_circle_rounded, warningColor),
          const SizedBox(width: 8),
          _buildStatCard('Blokir', blockedCount, Icons.block_rounded, dangerColor),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _statShadow(color), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _statBg(color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(count.toString(),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ================= SEARCH & FILTER =================
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _cardShadow(), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari nama, email, atau nomor HP...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchController.clear(); _applyFilters(); },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _activeFilterCount > 0 ? accentBlue : cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _cardShadow(), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Stack(
              children: [
                IconButton(
                  onPressed: () => setState(() => _showFilterPanel = !_showFilterPanel),
                  icon: Icon(Icons.filter_list_rounded,
                      color: _activeFilterCount > 0 ? Colors.white : Colors.grey[700]),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: dangerColor, shape: BoxShape.circle),
                      child: Center(
                        child: Text(_activeFilterCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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

  // ================= FILTER PANEL =================
  Widget _buildFilterPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _cardShadow(), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Role Filter
          Row(children: [
            const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Role', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildFilterChip('Semua', _selectedRole == 'Semua', () { setState(() => _selectedRole = 'Semua'); _applyFilters(); }),
              const SizedBox(width: 6),
              _buildFilterChip('Super Admin', _selectedRole == 'superadmin', () { setState(() => _selectedRole = 'superadmin'); _applyFilters(); }, const Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              _buildFilterChip('Manager', _selectedRole == 'manager', () { setState(() => _selectedRole = 'manager'); _applyFilters(); }, const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              _buildFilterChip('Pengawas', _selectedRole == 'pengawas', () { setState(() => _selectedRole = 'pengawas'); _applyFilters(); }, const Color(0xFF059669)),
              const SizedBox(width: 6),
              _buildFilterChip('Mitra', _selectedRole == 'mitra', () { setState(() => _selectedRole = 'mitra'); _applyFilters(); }, const Color(0xFFD97706)),
            ]),
          ),
          const SizedBox(height: 14),
          // Status Filter
          Row(children: [
            const Icon(Icons.toggle_on_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Status', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildFilterChip('Semua', _selectedStatus == 'Semua', () { setState(() => _selectedStatus = 'Semua'); _applyFilters(); }),
              const SizedBox(width: 6),
              _buildFilterChip('Aktif', _selectedStatus == 'active', () { setState(() => _selectedStatus = 'active'); _applyFilters(); }, successColor),
              const SizedBox(width: 6),
              _buildFilterChip('Nonaktif', _selectedStatus == 'inactive', () { setState(() => _selectedStatus = 'inactive'); _applyFilters(); }, warningColor),
              const SizedBox(width: 6),
              _buildFilterChip('Blokir', _selectedStatus == 'blocked', () { setState(() => _selectedStatus = 'blocked'); _applyFilters(); }, dangerColor),
            ]),
          ),
          const SizedBox(height: 14),
          // Fungsi Filter
          Row(children: [
            const Icon(Icons.work_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Fungsi', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildFilterChip('Semua', _selectedFungsi == 'Semua', () { setState(() => _selectedFungsi = 'Semua'); _applyFilters(); }),
              const SizedBox(width: 6),
              _buildFilterChip('Operation', _selectedFungsi == 'operation', () { setState(() => _selectedFungsi = 'operation'); _applyFilters(); }, Colors.blue),
              const SizedBox(width: 6),
              _buildFilterChip('Lab', _selectedFungsi == 'lab', () { setState(() => _selectedFungsi = 'lab'); _applyFilters(); }, Colors.purple),
              const SizedBox(width: 6),
              _buildFilterChip('Maintenance', _selectedFungsi == 'maintenance', () { setState(() => _selectedFungsi = 'maintenance'); _applyFilters(); }, Colors.orange),
              const SizedBox(width: 6),
              _buildFilterChip('HSSE', _selectedFungsi == 'hsse', () { setState(() => _selectedFungsi = 'hsse'); _applyFilters(); }, Colors.green),
              const SizedBox(width: 6),
              _buildFilterChip('GPR', _selectedFungsi == 'gpr', () { setState(() => _selectedFungsi = 'gpr'); _applyFilters(); }, Colors.teal),
              const SizedBox(width: 6),
              _buildFilterChip('BS', _selectedFungsi == 'bs', () { setState(() => _selectedFungsi = 'bs'); _applyFilters(); }, Colors.brown),
            ]),
          ),
          const SizedBox(height: 12),
          if (_activeFilterCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text('Reset Filter'),
                style: TextButton.styleFrom(foregroundColor: dangerColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, [Color? color]) {
    final chipColor = color ?? accentBlue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _chipBg(chipColor) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? chipColor : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: isSelected ? chipColor : Colors.grey[600],
        )),
      ),
    );
  }

  // ================= BODY =================
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: _statBg(accentBlue), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: accentBlue, strokeWidth: 3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Memuat data...', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.people_outline_rounded, size: 60, color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _activeFilterCount > 0
                  ? 'Tidak ada user yang sesuai filter' : 'Belum ada user',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _activeFilterCount > 0
                  ? 'Coba ubah kata kunci atau reset filter' : 'Tambahkan user baru untuk mulai',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Reset Filter'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: accentBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredUsers.length,
        itemBuilder: (_, i) => FadeTransition(
          opacity: _fadeAnimation,
          child: _buildUserCard(_filteredUsers[i]),
        ),
      ),
    );
  }

  // ================= USER CARD =================
  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'mitra';
    final status = user['status_akun'] ?? 'active';
    final nama = user['nama_lengkap'] ?? '-';
    final email = user['email'] ?? '-';
    final fungsi = user['fungsi'] ?? '-';
    final phone = user['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _cardShadow(), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showUserDetail(user),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_avatarBg(_roleColor(role)), _avatarBgLight(_roleColor(role))],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_roleIcon(role), color: _roleColor(role), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nama, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(email, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBg(_statusColor(status)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(_statusLabel(status), style: TextStyle(
                        color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _infoChip(Icons.shield_rounded, _roleLabel(role), _roleColor(role)),
                const SizedBox(width: 6),
                _infoChip(Icons.work_rounded, _fungsiLabel(fungsi), Colors.purple),
                const Spacer(),
                Icon(Icons.phone_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  phone.isNotEmpty && phone.length >= 8
                      ? '${phone.substring(0, 4)}...${phone.substring(phone.length - 4)}' : phone,
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('🕐 ${_formatDate(user['created_at'])}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
                Row(children: [
                  if (canEdit && user['id'] != _currentUserId)
                    _actionButton(Icons.edit_rounded, Colors.blue, () => _showForm(user: user)),
                  if (canEdit && user['id'] != _currentUserId) const SizedBox(width: 6),
                  if (user['id'] != _currentUserId)
                    _actionButton(
                      status == 'active' ? Icons.block_rounded : Icons.check_circle_rounded,
                      status == 'active' ? warningColor : successColor,
                      () => _toggleUserStatus(user['id'], status),
                    ),
                  if (canDelete && user['id'] != _currentUserId) const SizedBox(width: 6),
                  if (canDelete && user['id'] != _currentUserId)
                    _actionButton(Icons.delete_rounded, dangerColor,
                        () => _confirmDelete(user['id'], user['nama_lengkap'])),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _infoChipBg(color), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: _actionBg(color), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ================= USER DETAIL =================
  void _showUserDetail(Map<String, dynamic> user) {
    final role = user['role'] ?? '-';
    final status = user['status_akun'] ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_avatarBg(_roleColor(role)), _avatarBgLight(_roleColor(role))],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_roleIcon(role), color: _roleColor(role), size: 30),
            )),
            const SizedBox(height: 12),
            Center(child: Text(user['nama_lengkap'] ?? '-',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold))),
            Center(child: Text(user['email'] ?? '-',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 20),
            _detailRow('Role', _roleLabel(role), _roleColor(role)),
            _detailRow('Status', _statusLabel(status), _statusColor(status)),
            _detailRow('Fungsi', _fungsiLabel(user['fungsi'] ?? '-'), Colors.purple),
            _detailRow('Phone', user['phone'] ?? '-', Colors.blue),
            _detailRow('Dibuat', _formatDate(user['created_at']), Colors.grey),
            if (user['last_login'] != null)
              _detailRow('Login Terakhir', _formatDate(user['last_login']), Colors.green),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _detailBg(color), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ),
      ]),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.delete_outline_rounded, size: 48, color: Colors.red),
        title: const Text('Hapus User'),
        content: Text('Yakin ingin menghapus "$name"?\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _deleteUser(id, name),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  // ================= FORM =================
  void _showForm({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final namaCtrl = TextEditingController(text: user?['nama_lengkap'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final passCtrl = TextEditingController();
    String role = user?['role'] ?? 'mitra';
    String fungsi = user?['fungsi'] ?? 'operation';
    bool loading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _statBg(accentBlue), shape: BoxShape.circle),
                child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: accentBlue, size: 28),
              ),
              const SizedBox(height: 12),
              Text(isEdit ? 'Edit User' : 'Tambah User Baru',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              _formField(namaCtrl, 'Nama Lengkap', Icons.person_rounded),
              const SizedBox(height: 12),
              _formField(emailCtrl, 'Email', Icons.email_rounded),
              const SizedBox(height: 12),
              _formField(phoneCtrl, 'No HP', Icons.phone_rounded),
              if (!isEdit) ...[
                const SizedBox(height: 12),
                _formField(passCtrl, 'Password', Icons.lock_rounded, obscure: true),
              ],
              const SizedBox(height: 12),
              _formDropdown('Role', role, ['superadmin', 'manager', 'pengawas', 'mitra'],
                  ['Super Admin', 'Manager', 'Pengawas', 'Mitra'], (v) => setModal(() => role = v)),
              const SizedBox(height: 12),
              _formDropdown('Fungsi', fungsi, ['operation', 'lab', 'maintenance', 'hsse', 'gpr', 'bs'],
                  ['Operation', 'Lab', 'Maintenance', 'HSSE', 'GPR', 'BS'], (v) => setModal(() => fungsi = v)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                  ),
                  onPressed: loading ? null : () async {
                    setModal(() => loading = true);
                    final data = {
                      'id': user?['id'], 'nama': namaCtrl.text.trim(), 'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(), 'password': passCtrl.text.trim(),
                      'role': role, 'fungsi': fungsi,
                    };
                    if (isEdit) { 
                      await _updateUser(data); 
                    } else { 
                      await _createUser(data); 
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update User' : 'Simpan User',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController c, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: c, obscureText: obscure,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label, labelStyle: GoogleFonts.poppins(fontSize: 12),
        prefixIcon: Icon(icon, size: 18),
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accentBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _formDropdown(String label, String value, List<String> items, List<String> labels, Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label, labelStyle: GoogleFonts.poppins(fontSize: 12),
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accentBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items.asMap().entries.map((e) => DropdownMenuItem(value: e.value, child: Text(labels[e.key]))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}