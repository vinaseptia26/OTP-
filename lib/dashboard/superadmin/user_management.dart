// lib/features/superadmin/user_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/core/services/auth_service.dart';
import '../../core/services/superadmin_service.dart';
import '/core/utils/user_helpers.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';
import '../../widgets/user_management/user_stats_header.dart';
import '../../widgets/user_management/user_search_bar.dart';
import '../../widgets/user_management/user_filter_panel.dart';
import '../../widgets/user_management/user_card.dart';
import '../../widgets/user_management/user_detail_sheet.dart';
import '../../widgets/user_management/user_form_sheet.dart';
import '../../widgets/user_management/user_delete_dialog.dart';
import '../../widgets/user_management/user_status_dialog.dart'; // 🔥 Dialog baru untuk status

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  String? _currentUserRole;
  String? _currentUserId;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Filter State
  String _searchQuery = '';
  String _selectedRole = 'Semua';
  String _selectedStatus = 'Semua';
  String _selectedFungsi = 'Semua';
  bool _showFilterPanel = false;
  
  List<Map<String, dynamic>> _availableWorkers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentUser();
    await Future.wait([
      _loadUsers(),
      _loadAvailableWorkers(),
    ]);
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
      _showMsg('Gagal memuat data pengguna', true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.reset();
        _animationController.forward();
      }
    }
  }
  
  Future<void> _loadAvailableWorkers() async {
    try {
      final result = await _dashboardService.getWorkersList(limit: 500);
      _availableWorkers = List<Map<String, dynamic>>.from(result['workers']);
    } catch (e) {
      // Silent fail
    }
  }
  
  Future<Map<String, dynamic>?> _validateWorkerId(String idPekerja) async {
    if (idPekerja.trim().isEmpty) return null;
    return await _dashboardService.validateWorkerId(idPekerja.trim());
  }

  // ================= PERMISSIONS =================
  bool get canAdd => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canEdit => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canDelete => _currentUserRole == 'superadmin';

  // ================= SNACKBAR =================
  void _showMsg(String msg, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isError ? UserHelpers.accentRed : UserHelpers.accentGreen).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: isError ? UserHelpers.accentRed : UserHelpers.accentGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: UserHelpers.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: UserHelpers.surfaceWhite,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: UserHelpers.dividerColor),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
    );
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
            (user['phone']?.toString().toLowerCase().contains(_searchQuery) == true) ||
            (user['id_pekerja']?.toString().toLowerCase().contains(_searchQuery) == true);

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

  // ================= CRUD OPERATIONS =================
  Future<void> _createUser(Map<String, dynamic> data) async {
    final result = await _authService.createUser(
      nama: data['nama'],
      email: data['email'],
      phone: data['phone'],
      password: data['password'],
      role: data['role'],
      fungsi: data['fungsi'],
      idPekerja: data['id_pekerja'],
    );
    if (result.success) {
      if (mounted) context.pop();
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
      idPekerja: data['id_pekerja'],
      sessionId: UserHelpers.generateSessionId(),
    );
    if (result.success) {
      if (mounted) context.pop();
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  // 🔥 Hapus Pengguna dengan Konfirmasi
  Future<void> _deleteUser(String id, String name) async {
    // Tampilkan dialog konfirmasi
    final confirmed = await UserDeleteDialog.show(context, userName: name);
    
    if (confirmed != true) return; // Jika batal, kembali ke daftar pengguna
    
    // Tampilkan loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UserHelpers.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: UserHelpers.accentRed, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                'Menghapus pengguna...',
                style: GoogleFonts.inter(color: UserHelpers.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    // Proses penghapusan
    final result = await _authService.deleteUser(
      userId: id,
      sessionId: UserHelpers.generateSessionId(),
    );

    if (mounted) context.pop(); // Tutup loading

    if (result.success) {
      setState(() {
        _users.removeWhere((user) => user['id'] == id);
        _applyFilters();
      });
      _showMsg('Data pengguna berhasil dihapus');
    } else {
      _showMsg(result.message, true);
    }
  }

  // 🔥 Aktifkan/Nonaktifkan Pengguna dengan Konfirmasi
  Future<void> _toggleUserStatus(String id, String currentStatus, String userName) async {
    final isActivating = currentStatus != 'active';
    
    // Tampilkan dialog konfirmasi
    final confirmed = await UserStatusDialog.show(
      context,
      userName: userName,
      isActivating: isActivating,
    );
    
    if (confirmed != true) return; // Jika batal, kembali ke daftar pengguna
    
    final newStatus = isActivating ? 'active' : 'inactive';
    
    // Tampilkan loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UserHelpers.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: isActivating ? UserHelpers.accentGreen : UserHelpers.accentOrange,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                isActivating ? 'Mengaktifkan pengguna...' : 'Menonaktifkan pengguna...',
                style: GoogleFonts.inter(color: UserHelpers.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Proses perubahan status
    final result = await _authService.toggleUserStatus(
      userId: id,
      newStatus: newStatus,
      sessionId: UserHelpers.generateSessionId(),
    );
    
    if (mounted) context.pop(); // Tutup loading
    
    if (result.success) {
      setState(() {
        final index = _users.indexWhere((user) => user['id'] == id);
        if (index != -1) _users[index]['status_akun'] = newStatus;
        _applyFilters();
      });
      _showMsg(isActivating 
        ? 'Akun pengguna berhasil diaktifkan' 
        : 'Akun pengguna berhasil dinonaktifkan');
    } else {
      _showMsg(result.message, true);
    }
  }

  // ================= DIALOGS =================
  void _showForm({Map<String, dynamic>? user}) {
    UserFormSheet.show(
      context,
      user: user,
      availableWorkers: _availableWorkers,
      onValidateWorkerId: _validateWorkerId,
      onSubmit: user != null ? _updateUser : _createUser,
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    UserDetailSheet.show(
      context,
      user: user,
      canEdit: canEdit,
      isCurrentUser: user['id'] == _currentUserId,
      onEdit: () => _showForm(user: user),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final activeCount = _users.where((e) => e['status_akun'] == 'active').length;
    final inactiveCount = _users.where((e) => e['status_akun'] == 'inactive').length;
    final blockedCount = _users.where((e) => e['status_akun'] == 'blocked').length;

    return Scaffold(
      backgroundColor: UserHelpers.bgWhite,
      appBar: _buildAppBar(),
      floatingActionButton: canAdd ? _buildFAB() : null,
      body: Column(
        children: [
          UserStatsHeader(
            totalUsers: _users.length,
            activeCount: activeCount,
            inactiveCount: inactiveCount,
            blockedCount: blockedCount,
          ),
          UserSearchBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            activeFilterCount: _activeFilterCount,
            showFilterPanel: _showFilterPanel,
            onFilterToggle: () => setState(() => _showFilterPanel = !_showFilterPanel),
            onClearSearch: () {
              _searchController.clear();
              _applyFilters();
            },
          ),
          if (_showFilterPanel)
            UserFilterPanel(
              selectedRole: _selectedRole,
              selectedStatus: _selectedStatus,
              selectedFungsi: _selectedFungsi,
              onRoleChanged: (v) {
                setState(() => _selectedRole = v);
                _applyFilters();
              },
              onStatusChanged: (v) {
                setState(() => _selectedStatus = v);
                _applyFilters();
              },
              onFungsiChanged: (v) {
                setState(() => _selectedFungsi = v);
                _applyFilters();
              },
              onReset: _resetFilters,
            ),
          Expanded(child: _buildUserList()),
        ],
      ),
      bottomNavigationBar: const SuperAdminBottomNav(currentIndex: 1),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UserHelpers.headerBlue, Color(0xFF2A5298)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: UserHelpers.headerBlue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Kelola Pengguna', // 🔥 Diubah ke Bahasa Indonesia
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            tooltip: 'Muat Ulang',
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ================= FAB =================
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showForm(),
      backgroundColor: UserHelpers.headerBlue,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Tambah Pengguna', // 🔥 Diubah ke Bahasa Indonesia
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ================= USER LIST =================
  Widget _buildUserList() {
    if (_isLoading) return _buildLoadingState();
    if (_filteredUsers.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: UserHelpers.headerBlue,
      backgroundColor: UserHelpers.surfaceWhite,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredUsers.length,
        itemBuilder: (_, i) => FadeTransition(
          opacity: _fadeAnimation,
          child: UserCard(
            user: _filteredUsers[i],
            canEdit: canEdit,
            canDelete: canDelete,
            isCurrentUser: _filteredUsers[i]['id'] == _currentUserId,
            onTap: () => _showUserDetail(_filteredUsers[i]),
            onEdit: () => _showForm(user: _filteredUsers[i]),
            onToggleStatus: () => _toggleUserStatus(
              _filteredUsers[i]['id'],
              _filteredUsers[i]['status_akun'],
              _filteredUsers[i]['nama_lengkap'] ?? 'Pengguna', // 🔥 Kirim nama untuk dialog
            ),
            onDelete: () => _deleteUser( // 🔥 Langsung panggil delete dengan konfirmasi
              _filteredUsers[i]['id'],
              _filteredUsers[i]['nama_lengkap'] ?? 'Pengguna',
            ),
          ),
        ),
      ),
    );
  }

  // ================= LOADING STATE =================
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [UserHelpers.headerBlue, Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: UserHelpers.headerBlue.withOpacity(0.3), blurRadius: 20),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Memuat data pengguna...',
            style: GoogleFonts.inter(fontSize: 14, color: UserHelpers.textLight),
          ),
        ],
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: UserHelpers.headerBlue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: UserHelpers.headerBlue.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty || _activeFilterCount > 0
                ? 'Tidak ada pengguna yang sesuai filter'
                : 'Belum ada pengguna',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: UserHelpers.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _activeFilterCount > 0
                ? 'Coba sesuaikan pencarian atau filter'
                : 'Klik tombol di bawah untuk menambah pengguna',
            style: GoogleFonts.inter(color: UserHelpers.textHint, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Reset Filter'),
              style: TextButton.styleFrom(foregroundColor: UserHelpers.accentRed),
            ),
          ],
        ],
      ),
    );
  }
}