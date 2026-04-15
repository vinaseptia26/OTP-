// screens/user_management_screen.dart (FULL VERSION - FIXED)
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with TickerProviderStateMixin {
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Warna-warna
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color secondaryBlue = const Color(0xFF2A4F8C);
  final Color accentOrange = const Color(0xFFFF6B35);
  final Color softRed = const Color(0xFFE74C3C);
  final Color primaryGradientStart = const Color(0xFF4158D0);
  final Color primaryGradientEnd = const Color(0xFFC850C0);

  // Tab controller
  late TabController _tabController;

  // Animation controller
  late AnimationController _animationController;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'Semua';
  String _selectedStatusFilter = 'Semua';
  String _selectedFungsiFilter = 'Semua';
  bool _showFilters = false;

  // User data
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _currentUserRole;
  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;

  // Form controllers for add/edit user
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'mitra';
  String _selectedFungsi = 'operation';
  bool _sendEmailNotification = true;

  // Password visibility
  bool _hidePassword = true;

  // Password strength
  bool _showPasswordStrength = false;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "";
  Color _passwordStrengthColor = Colors.grey;

  // Edit mode
  bool _isEditMode = false;
  String? _editingUserId;

  // Delete confirmation
  bool _isDeleting = false;
  bool _isBulkAction = false;
  Set<String> _selectedUsers = {};

  // State untuk dialog
  bool _isDialogLoading = false;

  // Session ID untuk audit trail
  String _sessionId = '';

  // Daftar role
  final List<Map<String, dynamic>> _roleList = const [
    {
      'value': 'superadmin',
      'label': 'Super Admin',
      'icon': Icons.admin_panel_settings,
      'color': Color(0xFFE74C3C),
      'description': 'Akses penuh ke semua fitur'
    },
    {
      'value': 'manager',
      'label': 'Manager',
      'icon': Icons.manage_accounts,
      'color': Color(0xFF3498DB),
      'description': 'Mengelola tim dan approve lembur'
    },
    {
      'value': 'pengawas',
      'label': 'Pengawas',
      'icon': Icons.visibility,
      'color': Color(0xFF2ECC71),
      'description': 'Mengawasi kegiatan lapangan'
    },
    {
      'value': 'mitra',
      'label': 'Mitra',
      'icon': Icons.handshake,
      'color': Color(0xFFF39C12),
      'description': 'User biasa untuk pengajuan lembur'
    },
  ];

  // Daftar fungsi
  final List<Map<String, String>> _fungsiList = const [
    {"value": "operation", "label": "Operation", "icon": "⚙️", "description": "Operasional Lapangan"},
    {"value": "lab", "label": "Laboratorium", "icon": "🔬", "description": "Laboratorium & Pengujian"},
    {"value": "maintenance", "label": "Maintenance", "icon": "🔧", "description": "Perawatan & Perbaikan"},
    {"value": "hsse", "label": "HSSE", "icon": "🛡️", "description": "Keselamatan & K3"},
    {"value": "gpr", "label": "GPR", "icon": "📊", "description": "General Processing"},
    {"value": "bs", "label": "BS", "icon": "📋", "description": "Business Support"},
  ];

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _generateSessionId();
    _passwordController.addListener(_calculatePasswordStrength);
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getCurrentUserData();
        _loadUsers();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    _passwordController.removeListener(_calculatePasswordStrength);
    _passwordController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ================= SESSION ID GENERATION =================
  void _generateSessionId() {
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'session_$timestamp${random.nextInt(10000)}';
  }

  // ================= AMBIL DATA USER SAAT INI =================
  Future<void> _getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _currentUserData = userDoc.data();
          _currentUserRole = userDoc.data()?['role'];
        }
      }
    } catch (e) {
      logger.e('Error getting current user data: $e');
    }
  }

  // ================= CHECK PERMISSIONS =================
  bool get canAddUser => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canEditUser => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canDeleteUser => _currentUserRole == 'superadmin';
  bool get canChangeRole => _currentUserRole == 'superadmin';
  bool get canChangeStatus => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canResetPassword => _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canBulkAction => _currentUserRole == 'superadmin';

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterUsers();
      });
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            (user['nama_lengkap']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
            (user['email']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
            (user['phone']?.toString().contains(_searchQuery) ?? false);

        final matchesRole = _selectedRoleFilter == 'Semua' ||
            _getRoleValueFromLabel(_selectedRoleFilter) == user['role'];

        final status = user['status_akun'] ?? 'active';
        final matchesStatus = _selectedStatusFilter == 'Semua' ||
            (_selectedStatusFilter == 'Aktif' && status == 'active') ||
            (_selectedStatusFilter == 'Nonaktif' && status == 'inactive') ||
            (_selectedStatusFilter == 'Diblokir' && status == 'blocked');

        final fungsi = user['fungsi'] ?? '';
        final matchesFungsi = _selectedFungsiFilter == 'Semua' ||
            _selectedFungsiFilter == fungsi;

        return matchesSearch && matchesRole && matchesStatus && matchesFungsi;
      }).toList();

      _filteredUsers.sort((a, b) {
        final aDate = a['created_at'] as Timestamp?;
        final bDate = b['created_at'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    });
  }

  String _getRoleValueFromLabel(String label) {
    switch (label) {
      case 'Super Admin':
        return 'superadmin';
      case 'Manager':
        return 'manager';
      case 'Pengawas':
        return 'pengawas';
      case 'Mitra':
        return 'mitra';
      default:
        return '';
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      if (_auth.currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackbar('Anda harus login terlebih dahulu');
        }
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .orderBy('created_at', descending: true)
          .get();

      _users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      _users = _users.where((user) => user['id'] != null && user['id'].toString().isNotEmpty).toList();
      _filterUsers();

      logger.i('Successfully loaded ${_users.length} users');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      logger.e('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Gagal memuat data user';
        if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Anda tidak memiliki izin untuk melihat data user';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Gagal terhubung ke server. Periksa koneksi internet Anda';
        }
        
        _showErrorSnackbar(errorMessage);
      }
    }
  }

  // ================= PASSWORD STRENGTH =================
  void _calculatePasswordStrength() {
    if (!mounted) return;
    
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _showPasswordStrength = false;
        _passwordStrength = 0.0;
      });
      return;
    }

    setState(() {
      _showPasswordStrength = true;
      double strength = 0.0;

      if (password.length >= 8) strength += 0.25;
      if (password.length >= 10) strength += 0.15;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;

      _passwordStrength = strength.clamp(0.0, 1.0);

      if (_passwordStrength < 0.5) {
        _passwordStrengthText = "Lemah";
        _passwordStrengthColor = softRed;
      } else if (_passwordStrength < 0.8) {
        _passwordStrengthText = "Sedang";
        _passwordStrengthColor = accentOrange;
      } else {
        _passwordStrengthText = "Kuat";
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // ================= VALIDASI INPUT =================
  String? _validateNama(String? value) {
    if (value == null || value.isEmpty) return "Nama lengkap wajib diisi";
    if (value.length < 3) return "Nama terlalu pendek";
    if (value.length > 100) return "Nama terlalu panjang";
    if (!RegExp(r"^[a-zA-Z\s\.']+$").hasMatch(value)) {
      return "Nama hanya boleh mengandung huruf, spasi, titik, dan apostrof";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email wajib diisi";

    final emailRegex = RegExp(
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(value)) {
      return "Format email tidak valid";
    }

    // CEK DUPLIKAT EMAIL (hanya untuk create mode, atau jika email berubah di edit mode)
    if (!_isEditMode || (_isEditMode && value != _getOriginalEmail())) {
      final existingUser = _users.firstWhere(
        (u) => u['email']?.toString().toLowerCase() == value.toLowerCase() && u['id'] != _editingUserId,
        orElse: () => {},
      );
      if (existingUser.isNotEmpty) {
        return "Email sudah digunakan";
      }
    }

    return null;
  }

  String? _getOriginalEmail() {
    if (_editingUserId == null) return null;
    final user = _users.firstWhere((u) => u['id'] == _editingUserId, orElse: () => {});
    return user['email'];
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Nomor HP wajib diisi";

    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanValue.length < 10 || cleanValue.length > 13) {
      return "Nomor HP harus 10-13 digit";
    }

    if (!cleanValue.startsWith('8')) {
      return "Nomor harus diawali dengan 8";
    }

    // CEK DUPLIKAT NOMOR HP (hanya untuk create mode, atau jika nomor berubah di edit mode)
    if (!_isEditMode || (_isEditMode && cleanValue != _getOriginalPhone())) {
      final existingUser = _users.firstWhere(
        (u) => u['phone']?.replaceAll(RegExp(r'[^\d]'), '') == cleanValue && u['id'] != _editingUserId,
        orElse: () => {},
      );
      if (existingUser.isNotEmpty) {
        return "Nomor HP sudah digunakan";
      }
    }

    return null;
  }

  String? _getOriginalPhone() {
    if (_editingUserId == null) return null;
    final user = _users.firstWhere((u) => u['id'] == _editingUserId, orElse: () => {});
    return user['phone']?.replaceAll(RegExp(r'[^\d]'), '');
  }

  String? _validatePassword(String? value) {
    // Di edit mode, password opsional
    if (_isEditMode && (value == null || value.isEmpty)) return null;

    if (value == null || value.isEmpty) return "Password wajib diisi";
    if (value.length < 8) return "Minimal 8 karakter";
    if (!value.contains(RegExp(r'[A-Z]'))) return "Harus ada huruf besar";
    if (!value.contains(RegExp(r'[a-z]'))) return "Harus ada huruf kecil";
    if (!value.contains(RegExp(r'[0-9]'))) return "Harus ada angka";

    return null;
  }

  // ================= ENKRIPSI DATA =================
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ================= SEND EMAIL NOTIFICATION =================
  Future<void> _sendWelcomeEmail(String email, String password, String nama, String role) async {
    try {
      await _firestore.collection('mail').add({
        'to': email,
        'template': {
          'name': 'welcome_user',
          'data': {
            'nama': nama,
            'email': email,
            'password': password,
            'role': role,
            'login_url': 'https://yourapp.page.link/login',
          }
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      logger.i('Welcome email notification saved for: $email');
    } catch (e) {
      logger.e('Error saving email notification: $e');
    }
  }

  // ================= CREATE USER - FIXED VERSION =================
Future<void> _createUser(String nama, String email, String phone, DateTime now) async {
  try {
    // ✅ LANGKAH 1: VALIDASI DUPLIKAT DI FIRESTORE TERLEBIH DAHULU
    logger.i('Memeriksa duplikat data di Firestore...');
    
    // Cek apakah email sudah ada di Firestore
    final emailQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    
    if (emailQuery.docs.isNotEmpty) {
      throw Exception('Email sudah digunakan');
    }
    
    // Cek apakah nomor HP sudah ada di Firestore
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final phoneQuery = await _firestore
        .collection('users')
        .where('phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();
    
    if (phoneQuery.docs.isNotEmpty) {
      throw Exception('Nomor HP sudah digunakan');
    }
    
    logger.i('Validasi duplikat berhasil, melanjutkan ke Firebase Auth...');
    
    // ✅ LANGKAH 2: BUAT USER DI FIREBASE AUTH
    // Firebase Auth akan otomatis memvalidasi email unik
    logger.i('Membuat user di Firebase Auth...');
    UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );
    } catch (authError) {
      logger.e('Firebase Auth error: $authError');
      
      if (authError.toString().contains('email-already-in-use')) {
        throw Exception('Email sudah digunakan');
      } else if (authError.toString().contains('weak-password')) {
        throw Exception('Password terlalu lemah');
      } else if (authError.toString().contains('invalid-email')) {
        throw Exception('Format email tidak valid');
      } else if (authError.toString().contains('network-request-failed')) {
        throw Exception('Gagal terhubung ke server. Periksa koneksi internet');
      } else {
        throw Exception('Gagal membuat akun: ${authError.toString()}');
      }
    }

    final User? user = userCredential.user;
    if (user == null) {
      throw Exception("Gagal membuat akun: user credential null");
    }

    logger.i('Firebase Auth berhasil, UID: ${user.uid}');

    // ✅ LANGKAH 3: VALIDASI DATA SEBELUM SIMPAN KE FIRESTORE
    String fungsiLabel = _getFungsiLabel(_selectedFungsi);
    
    // Data yang akan disimpan - SESUAI DENGAN RULES FIRESTORE
    Map<String, dynamic> userData = {
      // IDENTITAS DASAR (String)
      "id": user.uid,
      "nama_lengkap": nama,
      "email": email,
      "email_hash": _hashData(email),
      "phone": cleanPhone,
      "phone_hash": _hashData(cleanPhone),
      "role": _selectedRole,
      "fungsi": _selectedFungsi,
      "fungsi_label": fungsiLabel,
      
      // STATUS AKUN (String, boolean, number)
      "status_akun": "active",
      "is_verified": true,
      "account_locked": false,
      "login_attempts": 0,
      
      // KEAMANAN (Map)
      "security": {
        "session_id": _sessionId,
        "registered_at": FieldValue.serverTimestamp(),
        "security_level": "medium",
      },
      
      // TERMS (boolean, Timestamp, String)
      "terms_accepted": true,
      "terms_accepted_at": FieldValue.serverTimestamp(),
      "terms_version": "1.0",
      
      // METADATA (Timestamp, boolean)
      "created_at": FieldValue.serverTimestamp(),
      "last_login": FieldValue.serverTimestamp(),
      "profile_complete": true,
      
      // AUDIT TRAIL - HARUS LIST DENGAN MINIMAL 1 ITEM
      "audit_trail": [
        {
          "action": "user_created_by_admin",
          "timestamp": DateTime.now(),
          "session_id": _sessionId,
        }
      ],
    };

    // ✅ LANGKAH 4: SIMPAN KE FIRESTORE DENGAN VALIDASI
    logger.i('Menyimpan data ke Firestore...');
    
    try {
      await _firestore.collection("users").doc(user.uid).set(userData);
      logger.i('Data berhasil disimpan ke Firestore');
    } catch (firestoreError) {
      logger.e('Firestore error: $firestoreError');
      
      // Jika gagal menyimpan ke Firestore, rollback dengan menghapus user dari Firebase Auth
      logger.i('Rollback: Menghapus user dari Firebase Auth...');
      try {
        await user.delete();
        logger.i('Rollback berhasil: user dihapus dari Firebase Auth');
        
        // Catat ke system logs untuk audit
        await _firestore.collection('system_logs').add({
          'type': 'rollback_success',
          'user': _auth.currentUser?.email ?? 'system',
          'target_user': email,
          'target_user_id': user.uid,
          'error': firestoreError.toString(),
          'session_id': _sessionId,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Rollback berhasil: user dihapus dari Auth karena gagal di Firestore',
        });
      } catch (deleteError) {
        logger.e('Rollback gagal: ${deleteError.toString()}');
        // Catat ke system logs untuk audit manual
        await _firestore.collection('system_logs').add({
          'type': 'rollback_failed',
          'user': _auth.currentUser?.email ?? 'system',
          'target_user': email,
          'target_user_id': user.uid,
          'error': firestoreError.toString(),
          'delete_error': deleteError.toString(),
          'session_id': _sessionId,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'KRITIS: Gagal menyimpan ke Firestore DAN gagal rollback! User ada di Auth tapi tidak di Firestore.',
        });
      }
      
      throw Exception('Gagal menyimpan data user ke database. Data tidak tersimpan.');
    }

    // ✅ LANGKAH 5: SYSTEM LOGS
    await _firestore.collection('system_logs').add({
      'type': 'user_created',
      'user': _auth.currentUser?.email ?? 'system',
      'target_user': email,
      'target_user_id': user.uid,
      'target_role': _selectedRole,
      'session_id': _sessionId,
      'timestamp': FieldValue.serverTimestamp(),
      'description': 'User baru ditambahkan: $nama ($email) dengan role $_selectedRole',
    });

    // Kirim email notifikasi jika diperlukan
    if (_sendEmailNotification) {
      await _sendWelcomeEmail(email, _passwordController.text, nama, _selectedRole);
    }

    // ✅ LANGKAH 6: TAMPILKAN POP UP SUKSES
    if (mounted) {
      // Tutup dialog loading terlebih dahulu
      Navigator.pop(context); // Tutup form dialog
      
      // Tampilkan dialog sukses
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Berhasil!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'User berhasil ditambahkan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nama,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getRoleLabel(_selectedRole),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _getRoleColor(_selectedRole),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_sendEmailNotification) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.notifications_active, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notifikasi email akan dikirim',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                ),
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
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog sukses
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog sukses
                  // Opsional: langsung buka detail user
                  // _showUserDetails({'id': user.uid, 'nama_lengkap': nama, 'email': email});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGradientStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Lihat Detail',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          );
        },
      );
    }

    logger.i('User berhasil dibuat di Firebase Auth dan Firestore dengan ID: ${user.uid}');
    
  } catch (e) {
    logger.e('Error creating user: $e');
    
    // Tampilkan pop up error jika terjadi kegagalan
    if (mounted) {
      // Tutup dialog loading jika masih ada
      if (_isDialogLoading) {
        Navigator.pop(context); // Tutup form dialog
      }
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: softRed.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    color: softRed,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gagal!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: softRed,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tidak ada data yang tersimpan. Silakan coba lagi.',
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
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Buka form lagi
                  _showAddEditUserDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGradientStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          );
        },
      );
    }
    
    // Lempar error untuk ditangani oleh pemanggil
    throw Exception(e.toString());
  }
}

  // ================= UPDATE USER =================
Future<void> _updateUser(String nama, String email, String phone, DateTime now) async {
  if (_editingUserId == null || _editingUserId!.isEmpty) {
    throw Exception("ID user tidak valid");
  }

  try {
    String fungsiLabel = _getFungsiLabel(_selectedFungsi);
    
    // Data yang akan diupdate
    Map<String, dynamic> updateData = {
      "nama_lengkap": nama,
      "phone": phone,
      "phone_hash": _hashData(phone),
      "role": _selectedRole,
      "fungsi": _selectedFungsi,
      "fungsi_label": fungsiLabel,
    };

    // Jika email berubah, update juga email dan email_hash
    final originalEmail = _getOriginalEmail();
    if (email != originalEmail) {
      // Validasi duplikat email sebelum update
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (emailQuery.docs.isNotEmpty && emailQuery.docs.first.id != _editingUserId) {
        throw Exception('Email sudah digunakan oleh user lain');
      }
      
      updateData["email"] = email;
      updateData["email_hash"] = _hashData(email);
    }

    // Validasi duplikat nomor HP
    final phoneQuery = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    
    if (phoneQuery.docs.isNotEmpty && phoneQuery.docs.first.id != _editingUserId) {
      throw Exception('Nomor HP sudah digunakan oleh user lain');
    }

    // Update di Firestore
    await _firestore.collection("users").doc(_editingUserId).update(updateData);

    // ✅ PERBAIKI: Tambahkan audit trail untuk update user - PAKAI FieldValue.serverTimestamp()
    await _firestore.collection("users").doc(_editingUserId).update({
      "audit_trail": FieldValue.arrayUnion([
        {
          "action": "user_updated_by_admin",
          "timestamp": now, 
          "session_id": _sessionId,
        }
      ])
    });

    // Catat ke system logs
    await _firestore.collection('system_logs').add({
      'type': 'user_updated',
      'user': _auth.currentUser?.email ?? 'system',
      'target_user': email,
      'target_user_id': _editingUserId,
      'target_role': _selectedRole,
      'session_id': _sessionId,
      'timestamp': FieldValue.serverTimestamp(),
      'description': 'User diperbarui: $nama ($email)',
    });

    // Jika ada password baru, kirim email reset
    if (_passwordController.text.isNotEmpty) {
      await _sendPasswordResetEmail(email, nama);
    }

    logger.i('User berhasil diupdate: $_editingUserId');
    
  } catch (e) {
    logger.e('Error updating user: $e');
    rethrow;
  }
}

  // ================= SAVE USER (CREATE OR UPDATE) =================
  Future<void> _saveUser() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Validasi password strength hanya untuk create mode
    if (!_isEditMode && _passwordStrength < 0.5) {
      _showErrorSnackbar('Password terlalu lemah. Gunakan password yang lebih kuat.');
      return;
    }

    setState(() {
      _isDialogLoading = true;
    });

    try {
      final cleanEmail = _emailController.text.trim().toLowerCase();
      final cleanPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      final cleanNama = _namaController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final now = DateTime.now();

      if (_isEditMode) {
        await _updateUser(cleanNama, cleanEmail, cleanPhone, now);
        
        if (mounted) {
          Navigator.pop(context); // Tutup form dialog
          _showSuccessSnackbar('User berhasil diperbarui');
        }
      } else {
        await _createUser(cleanNama, cleanEmail, cleanPhone, now);
        // _createUser sudah menangani pop up sukses dan tutup dialog
      }

      await _loadUsers();
      _resetForm();
      
    } catch (e) {
      logger.e('Error saving user: $e');
      if (mounted) {
        setState(() {
          _isDialogLoading = false;
        });
        
        String errorMessage = 'Gagal menyimpan user';
        if (e.toString().contains('Email sudah digunakan')) {
          errorMessage = 'Email sudah digunakan';
        } else if (e.toString().contains('Nomor HP sudah digunakan')) {
          errorMessage = 'Nomor HP sudah digunakan';
        } else if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Anda tidak memiliki izin untuk menambah/mengubah user';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Gagal terhubung ke server';
        } else {
          errorMessage = 'Gagal menyimpan user: ${e.toString().replaceAll('Exception: ', '')}';
        }
        
        // Tampilkan snackbar error sebagai fallback jika dialog error sudah ditampilkan
        _showErrorSnackbar(errorMessage);
      }
    }
  }

  // ================= DELETE USER (HARD DELETE) =================
  Future<void> _deleteUser(String userId, String userEmail, String userName) async {
    if (userId.isEmpty) {
      if (mounted) {
        setState(() => _isDeleting = false);
        _showErrorSnackbar('Gagal menghapus user: ID user tidak valid');
      }
      return;
    }

    if (userId == _auth.currentUser?.uid) {
      if (mounted) {
        setState(() => _isDeleting = false);
        Navigator.pop(context);
        _showErrorSnackbar('Tidak dapat menghapus akun sendiri');
      }
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final now = DateTime.now();
      
      logger.i('Attempting to delete user with ID: $userId');
      
      final docSnapshot = await _firestore.collection("users").doc(userId).get();
      
      if (!docSnapshot.exists) {
        throw Exception("User tidak ditemukan di database");
      }
      
      final userData = docSnapshot.data();
      
      // CATAT KE SYSTEM LOGS
      await _firestore.collection('system_logs').add({
        'type': 'user_deleted',
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': userEmail,
        'target_user_id': userId,
        'target_user_data': userData,
        'session_id': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User dihapus: $userName ($userEmail)',
      });

      // Hapus dari Firestore
      await _firestore.collection("users").doc(userId).delete();

      await _loadUsers();

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('User berhasil dihapus dari database');
      }
    } catch (e) {
      logger.e('Error deleting user: $e');
      if (mounted) {
        setState(() => _isDeleting = false);
        _showErrorSnackbar('Gagal menghapus user: ${e.toString()}');
      }
    }
  }

  // ================= SOFT DELETE (SET STATUS = "deleted") =================
  Future<void> _softDeleteUser(String userId, String userEmail, String userName) async {
    if (userId.isEmpty || userId == _auth.currentUser?.uid) return;

    try {
      final now = DateTime.now();

      await _firestore.collection("users").doc(userId).update({
        "status_akun": "deleted",
        "audit_trail": FieldValue.arrayUnion([
          {
            "action": "user_soft_deleted_by_admin",
            "timestamp": now,
            "session_id": _sessionId,
          }
        ])
      });

      await _firestore.collection('system_logs').add({
        'type': 'user_soft_deleted',
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': userEmail,
        'target_user_id': userId,
        'session_id': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User dinonaktifkan: $userName',
      });

      await _loadUsers();

      if (mounted) {
        _showSuccessSnackbar('User berhasil dinonaktifkan');
      }
    } catch (e) {
      logger.e('Error soft deleting user: $e');
      _showErrorSnackbar('Gagal menonaktifkan user');
    }
  }

  // ================= TOGGLE USER STATUS =================
  Future<void> _toggleUserStatus(String userId, String currentStatus, String userEmail, String userName) async {
    if (userId.isEmpty) {
      _showErrorSnackbar('Gagal mengubah status: ID user tidak valid');
      return;
    }

    if (userId == _auth.currentUser?.uid) {
      _showErrorSnackbar('Tidak dapat mengubah status akun sendiri');
      return;
    }

    try {
      final now = DateTime.now();
      String newStatus;
      String statusText;

      if (currentStatus == 'active') {
        newStatus = 'inactive';
        statusText = 'dinonaktifkan';
      } else if (currentStatus == 'inactive') {
        newStatus = 'active';
        statusText = 'diaktifkan';
      } else if (currentStatus == 'blocked') {
        newStatus = 'active';
        statusText = 'diaktifkan';
      } else {
        newStatus = 'active';
        statusText = 'diaktifkan';
      }

      await _firestore.collection("users").doc(userId).update({
        "status_akun": newStatus,
        "audit_trail": FieldValue.arrayUnion([
          {
            "action": "status_changed_by_admin",
            "timestamp": now,
            "session_id": _sessionId,
          }
        ])
      });

      await _firestore.collection('system_logs').add({
        'type': 'user_status_changed',
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': userEmail,
        'target_user_id': userId,
        'old_status': currentStatus,
        'new_status': newStatus,
        'session_id': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Status user $userName diubah dari $currentStatus menjadi $newStatus',
      });

      await _loadUsers();

      if (mounted) {
        _showSuccessSnackbar('Status user berhasil $statusText');
      }
    } catch (e) {
      logger.e('Error toggling user status: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal mengubah status user: $e');
      }
    }
  }

  // ================= RESET PASSWORD =================
  Future<void> _sendPasswordResetEmail(String userEmail, String userName) async {
    try {
      await _auth.sendPasswordResetEmail(email: userEmail);
      
      final now = DateTime.now();
      
      await _firestore.collection('system_logs').add({
        'type': 'password_reset_requested',
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': userEmail,
        'session_id': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Admin meminta reset password untuk user $userName',
      });

      // Catat di audit trail user
      final userDoc = _users.firstWhere((u) => u['email'] == userEmail, orElse: () => {});
      if (userDoc.isNotEmpty) {
        await _firestore.collection("users").doc(userDoc['id']).update({
          "audit_trail": FieldValue.arrayUnion([
            {
              "action": "password_reset_requested_by_admin",
              "timestamp": now,
              "session_id": _sessionId,
            }
          ])
        });
      }
      
      if (mounted) {
        _showSuccessSnackbar('Email reset password telah dikirim ke $userEmail');
      }
    } catch (e) {
      logger.e('Error sending password reset email: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal mengirim email reset password');
      }
    }
  }

  // ================= BULK ACTIONS =================
  void _toggleSelectAll() {
    setState(() {
      if (_selectedUsers.length == _filteredUsers.length) {
        _selectedUsers.clear();
      } else {
        _selectedUsers = _filteredUsers.map((u) => u['id'] as String).toSet();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
    });
  }

  Future<void> _bulkStatusChange(String newStatus) async {
    if (_selectedUsers.isEmpty) {
      _showErrorSnackbar('Pilih user terlebih dahulu');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah Status ${_selectedUsers.length} User?'),
        content: Text('Anda akan mengubah status ${_selectedUsers.length} user menjadi $newStatus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryGradientStart),
            child: Text('Ya, Ubah'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBulkAction = true);

    try {
      final now = DateTime.now();
      final batch = _firestore.batch();
      
      for (var userId in _selectedUsers) {
        final userRef = _firestore.collection("users").doc(userId);
        batch.update(userRef, {
          "status_akun": newStatus,
          "audit_trail": FieldValue.arrayUnion([
            {
              "action": "bulk_status_change_by_admin",
              "timestamp": now,
              "session_id": _sessionId,
            }
          ])
        });
      }

      await batch.commit();

      await _firestore.collection('system_logs').add({
        'type': 'bulk_status_change',
        'user': _auth.currentUser?.email ?? 'unknown',
        'affected_users': _selectedUsers.length,
        'new_status': newStatus,
        'session_id': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Bulk status change to $newStatus for ${_selectedUsers.length} users',
      });

      await _loadUsers();
      
      setState(() {
        _selectedUsers.clear();
        _isBulkAction = false;
      });

      _showSuccessSnackbar('Status ${_selectedUsers.length} user berhasil diubah');
    } catch (e) {
      logger.e('Error in bulk status change: $e');
      setState(() => _isBulkAction = false);
      _showErrorSnackbar('Gagal mengubah status user');
    }
  }

  // ================= HELPER METHODS =================
  String _getRoleLabel(String role) {
    switch (role) {
      case 'superadmin':
        return 'Super Admin';
      case 'manager':
        return 'Manager';
      case 'pengawas':
        return 'Pengawas';
      case 'mitra':
        return 'Mitra';
      default:
        return role;
    }
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi) {
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
        return fungsi;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return const Color(0xFFE74C3C);
      case 'manager':
        return const Color(0xFF3498DB);
      case 'pengawas':
        return const Color(0xFF2ECC71);
      case 'mitra':
        return const Color(0xFFF39C12);
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'superadmin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'pengawas':
        return Icons.visibility;
      case 'mitra':
        return Icons.handshake;
      default:
        return Icons.person;
    }
  }

  String _getStatusBadge(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Nonaktif';
      case 'blocked':
        return 'Diblokir';
      case 'deleted':
        return 'Dihapus';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      case 'deleted':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  void _resetForm() {
    _namaController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _selectedRole = 'mitra';
    _selectedFungsi = 'operation';
    _sendEmailNotification = true;
    _hidePassword = true;
    _isEditMode = false;
    _editingUserId = null;
    _showPasswordStrength = false;
  }

  void _showSuccessSnackbar(String message) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ================= DIALOGS =================
  void _showAddEditUserDialog({Map<String, dynamic>? user}) {
    if (!canAddUser && user == null) {
      _showErrorSnackbar('Anda tidak memiliki izin untuk menambah user');
      return;
    }

    if (user != null && !canEditUser) {
      _showErrorSnackbar('Anda tidak memiliki izin untuk mengubah user');
      return;
    }

    if (user != null) {
      _isEditMode = true;
      _editingUserId = user['id'];
      _namaController.text = user['nama_lengkap'] ?? '';
      _emailController.text = user['email'] ?? '';
      _phoneController.text = user['phone'] ?? '';
      _selectedRole = user['role'] ?? 'mitra';
      _selectedFungsi = user['fungsi'] ?? 'operation';
      _passwordController.clear();
      _sendEmailNotification = false;
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
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
                        const SizedBox(height: 16),

                        Text(
                          _isEditMode ? 'Edit User' : 'Tambah User Baru',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditMode
                              ? 'Perbarui data user'
                              : 'Buat akun untuk user baru',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              controller: scrollController,
                              children: [
                                _buildDialogField(
                                  controller: _namaController,
                                  label: 'Nama Lengkap',
                                  icon: Icons.person_outline,
                                  validator: _validateNama,
                                ),
                                const SizedBox(height: 16),

                                _buildDialogField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  type: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                  enabled: true,
                                ),
                                const SizedBox(height: 16),

                                _buildDialogField(
                                  controller: _phoneController,
                                  label: 'Nomor HP',
                                  icon: Icons.phone_iphone,
                                  type: TextInputType.phone,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(13),
                                  ],
                                  validator: _validatePhone,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                _buildDialogPasswordField(setDialogState),
                                if (_showPasswordStrength) ...[
                                  const SizedBox(height: 8),
                                  _buildPasswordStrengthIndicator(),
                                ],
                                const SizedBox(height: 16),

                                // Role
                                _buildDialogRoleField(setDialogState),
                                const SizedBox(height: 16),

                                // Fungsi
                                _buildDialogFungsiField(setDialogState),
                                const SizedBox(height: 16),

                                // Options (hanya untuk create mode)
                                if (!_isEditMode) _buildDialogOptions(setDialogState),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isDialogLoading ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isDialogLoading ? null : _saveUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGradientStart,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isDialogLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isEditMode ? 'Perbarui' : 'Tambah User',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: type,
          inputFormatters: formatters,
          validator: validator,
          enabled: enabled,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4158D0), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            fillColor: enabled ? Colors.white : Colors.grey[100],
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogPasswordField(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isEditMode ? 'Password (Opsional)' : 'Password',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            if (!_isEditMode)
              const Text(
                " *",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: _hidePassword,
          validator: _validatePassword,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: Colors.grey[600]),
            suffixIcon: IconButton(
              icon: Icon(
                _hidePassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setDialogState(() {
                  _hidePassword = !_hidePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4158D0), width: 2),
            ),
            hintText: _isEditMode ? 'Kosongkan jika tidak diubah' : 'Minimal 8 karakter',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _passwordStrengthText,
                style: GoogleFonts.poppins(
                  color: _passwordStrengthColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Password harus mengandung huruf besar, huruf kecil, dan angka',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRoleField(StateSetter setDialogState) {
    // Filter role berdasarkan permission
    List<Map<String, dynamic>> availableRoles = List.from(_roleList);
    if (!canChangeRole) {
      availableRoles = availableRoles.where((r) => 
        r['value'] != 'superadmin' && r['value'] != 'manager'
      ).toList();
      
      if (!availableRoles.any((r) => r['value'] == _selectedRole)) {
        _selectedRole = 'mitra';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Role',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              isExpanded: true,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              borderRadius: BorderRadius.circular(12),
              items: availableRoles.map((role) {
                return DropdownMenuItem<String>(
                  value: role['value'] as String,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (role['color'] as Color).withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            role['icon'] as IconData,
                            color: role['color'] as Color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['label'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                role['description'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setDialogState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogFungsiField(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fungsi Kerja',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFungsi,
              isExpanded: true,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              borderRadius: BorderRadius.circular(12),
              items: _fungsiList.map((fungsi) {
                return DropdownMenuItem<String>(
                  value: fungsi['value'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(fungsi['icon']!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fungsi['label']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                fungsi['description']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setDialogState(() {
                    _selectedFungsi = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogOptions(StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _sendEmailNotification,
                onChanged: (value) {
                  setDialogState(() {
                    _sendEmailNotification = value ?? true;
                  });
                },
                activeColor: primaryGradientStart,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kirim notifikasi email',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'User akan menerima email berisi informasi akun',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[600],
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

  void _showDeleteConfirmation(String userId, String userName, String userEmail) {
    if (userId.isEmpty) {
      _showErrorSnackbar('Error: ID user tidak valid');
      return;
    }

    if (!canDeleteUser) {
      _showErrorSnackbar('Hanya Super Admin yang dapat menghapus user');
      return;
    }

    if (userId == _auth.currentUser?.uid) {
      _showErrorSnackbar('Tidak dapat menghapus akun sendiri');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Hapus User',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus user "$userName"?\n\n'
            'Tindakan ini akan menghapus data user dari database. '
            'User tidak akan bisa login lagi.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: _isDeleting ? null : () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(),
              ),
            ),
            ElevatedButton(
              onPressed: _isDeleting
                  ? null
                  : () => _deleteUser(userId, userEmail, userName),
              style: ElevatedButton.styleFrom(
                backgroundColor: softRed,
                foregroundColor: Colors.white,
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Hapus',
                      style: GoogleFonts.poppins(),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showSoftDeleteConfirmation(String userId, String userName, String userEmail) {
    if (userId.isEmpty || userId == _auth.currentUser?.uid) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Nonaktifkan User',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Nonaktifkan user "$userName"?\n\n'
            'User tidak akan bisa login, tapi data tetap tersimpan.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _softDeleteUser(userId, userEmail, userName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('Nonaktifkan'),
            ),
          ],
        );
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user['role'] ?? '').withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRoleIcon(user['role'] ?? ''),
                      color: _getRoleColor(user['role'] ?? ''),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['nama_lengkap'] ?? '-',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user['email'] ?? '-',
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
              const SizedBox(height: 20),
              _buildDetailItem('Role', _getRoleLabel(user['role'] ?? ''), _getRoleColor(user['role'] ?? '')),
              _buildDetailItem('Fungsi', user['fungsi_label'] ?? user['fungsi'] ?? '-', null),
              _buildDetailItem('Nomor HP', user['phone'] ?? '-', null),
              _buildDetailItem('Status', _getStatusBadge(user['status_akun'] ?? 'active'), _getStatusColor(user['status_akun'] ?? 'active')),
              _buildDetailItem('Terdaftar', _formatDate(user['created_at']), null),
              _buildDetailItem('Terakhir Login', _formatDate(user['last_login']), null),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (canEditUser)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddEditUserDialog(user: user);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGradientStart,
                          side: const BorderSide(color: Color(0xFF4158D0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                  if (canEditUser) const SizedBox(width: 8),
                  if (canResetPassword)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendPasswordResetEmail(user['email'] ?? '', user['nama_lengkap'] ?? '');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reset Password'),
                      ),
                    ),
                  if (canResetPassword) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGradientStart,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          if (color != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  // ================= BUILD MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Manajemen User',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGradientStart, primaryGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'DAFTAR USER'),
            Tab(text: 'STATISTIK'),
          ],
        ),
        actions: [
          if (canBulkAction && _selectedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () {
                setState(() {
                  _selectedUsers.clear();
                });
              },
              tooltip: 'Clear selection',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserListTab(),
          _buildStatisticsTab(),
        ],
      ),
      floatingActionButton: canAddUser
          ? FloatingActionButton(
              onPressed: () => _showAddEditUserDialog(),
              backgroundColor: primaryGradientStart,
              child: const Icon(Icons.person_add, color: Colors.white),
              tooltip: 'Tambah User Baru',
            )
          : null,
    );
  }

  Widget _buildUserListTab() {
    return Column(
      children: [
        _buildSearchFilterBar(),
        if (canBulkAction && _selectedUsers.isNotEmpty)
          _buildBulkActionBar(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4158D0)),
                  ),
                )
              : _filteredUsers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      color: primaryGradientStart,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: primaryGradientStart.withAlpha(25),
      child: Row(
        children: [
          Checkbox(
            value: _selectedUsers.length == _filteredUsers.length,
            onChanged: (_) => _toggleSelectAll(),
            activeColor: primaryGradientStart,
          ),
          Text(
            '${_selectedUsers.length} terpilih',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (_isBulkAction)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _bulkStatusChange('active'),
                  tooltip: 'Aktifkan semua',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.pause_circle, color: Colors.orange),
                  onPressed: () => _bulkStatusChange('inactive'),
                  tooltip: 'Nonaktifkan semua',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.red),
                  onPressed: () => _bulkStatusChange('blocked'),
                  tooltip: 'Blokir semua',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    final fungsiSet = <String>{};
    for (var user in _users) {
      final fungsi = user['fungsi'];
      if (fungsi != null && fungsi.toString().isNotEmpty) {
        fungsiSet.add(fungsi);
      }
    }
    final fungsiList = ['Semua', ...fungsiSet.map((f) => f.toString())];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau nomor HP...',
              hintStyle: GoogleFonts.poppins(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : IconButton(
                      icon: Icon(
                        _showFilters ? Icons.filter_list : Icons.filter_list_off,
                        size: 18,
                        color: _showFilters ? primaryGradientStart : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4158D0)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (_showFilters) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Role',
                    value: _selectedRoleFilter,
                    items: const ['Semua', 'Super Admin', 'Manager', 'Pengawas', 'Mitra'],
                    onChanged: (value) => setState(() {
                      _selectedRoleFilter = value;
                      _filterUsers();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Status',
                    value: _selectedStatusFilter,
                    items: const ['Semua', 'Aktif', 'Nonaktif', 'Diblokir'],
                    onChanged: (value) => setState(() {
                      _selectedStatusFilter = value;
                      _filterUsers();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Fungsi',
                    value: _selectedFungsiFilter,
                    items: fungsiList,
                    onChanged: (value) => setState(() {
                      _selectedFungsiFilter = value;
                      _filterUsers();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedRoleFilter = 'Semua';
                        _selectedStatusFilter = 'Semua';
                        _selectedFungsiFilter = 'Semua';
                        _filterUsers();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Reset Filter',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: primaryGradientStart,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_filteredUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredUsers.length} user ditemukan',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryGradientStart.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Total: ${_users.length} user',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: primaryGradientStart,
                        fontWeight: FontWeight.w500,
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

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          style: GoogleFonts.poppins(fontSize: 12),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'mitra';
    final roleColor = _getRoleColor(role);
    final status = user['status_akun'] ?? 'active';
    final statusColor = _getStatusColor(status);
    
    final String userId = user['id']?.toString() ?? '';
    final String userEmail = user['email']?.toString() ?? '';
    final String userName = user['nama_lengkap']?.toString() ?? '';

    final bool isSelected = _selectedUsers.contains(userId);
    final bool showCheckbox = canBulkAction;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? primaryGradientStart : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  if (showCheckbox) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleUserSelection(userId),
                      activeColor: primaryGradientStart,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: roleColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRoleIcon(role),
                      color: roleColor,
                      size: 22,
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
                                userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusBadge(status),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildUserInfoChip(
                      icon: Icons.badge,
                      label: _getRoleLabel(role),
                      color: roleColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUserInfoChip(
                      icon: Icons.work,
                      label: user['fungsi_label'] ?? user['fungsi'] ?? '-',
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUserInfoChip(
                      icon: Icons.phone,
                      label: user['phone'] ?? '-',
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terdaftar: ${_formatDate(user['created_at'])}',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                  ),
                  Row(
                    children: [
                      if (canResetPassword && userId != _auth.currentUser?.uid)
                        IconButton(
                          icon: Icon(Icons.lock_reset, size: 18, color: Colors.orange[400]),
                          onPressed: () => _sendPasswordResetEmail(userEmail, userName),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'Reset Password',
                        ),
                      if (canEditUser && userId != _auth.currentUser?.uid)
                        IconButton(
                          icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                          onPressed: () => _showAddEditUserDialog(user: user),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'Edit User',
                        ),
                      if (canChangeStatus && userId != _auth.currentUser?.uid)
                        IconButton(
                          icon: Icon(
                            status == 'active' ? Icons.block : Icons.check_circle,
                            size: 18,
                            color: status == 'active' ? Colors.orange : Colors.green,
                          ),
                          onPressed: () => _toggleUserStatus(
                            userId,
                            status,
                            userEmail,
                            userName,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: status == 'active' ? 'Nonaktifkan' : 'Aktifkan',
                        ),
                      if (canDeleteUser && userId != _auth.currentUser?.uid)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _showDeleteConfirmation(userId, userName, userEmail);
                            } else if (value == 'soft_delete') {
                              _showSoftDeleteConfirmation(userId, userName, userEmail);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever, color: Colors.red, size: 16),
                                  SizedBox(width: 8),
                                  Text('Hapus Permanen'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'soft_delete',
                              child: Row(
                                children: [
                                  Icon(Icons.pause_circle, color: Colors.orange, size: 16),
                                  SizedBox(width: 8),
                                  Text('Nonaktifkan'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada user',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan user baru dengan tombol +',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedRoleFilter != 'Semua' || _selectedStatusFilter != 'Semua')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedRoleFilter = 'Semua';
                      _selectedStatusFilter = 'Semua';
                      _selectedFungsiFilter = 'Semua';
                      _filterUsers();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGradientStart,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Reset Filter'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u['status_akun'] == 'active').length;
    final inactiveUsers = _users.where((u) => u['status_akun'] == 'inactive').length;
    final blockedUsers = _users.where((u) => u['status_akun'] == 'blocked').length;

    final superadminCount = _users.where((u) => u['role'] == 'superadmin').length;
    final managerCount = _users.where((u) => u['role'] == 'manager').length;
    final pengawasCount = _users.where((u) => u['role'] == 'pengawas').length;
    final mitraCount = _users.where((u) => u['role'] == 'mitra').length;

    final fungsiStats = <String, int>{};
    for (var user in _users) {
      final fungsi = user['fungsi_label'] ?? user['fungsi'] ?? 'Tidak diketahui';
      fungsiStats[fungsi] = (fungsiStats[fungsi] ?? 0) + 1;
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final newUsersToday = _users.where((u) {
      final created = (u['created_at'] as Timestamp?)?.toDate();
      return created != null && created.isAfter(todayStart);
    }).length;

    final thisWeek = today.subtract(const Duration(days: 7));
    final newUsersThisWeek = _users.where((u) {
      final created = (u['created_at'] as Timestamp?)?.toDate();
      return created != null && created.isAfter(thisWeek);
    }).length;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadUsers,
            color: primaryGradientStart,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildStatCard(
                        'Total User',
                        '$totalUsers',
                        Icons.people,
                        primaryGradientStart,
                        '+$newUsersToday hari ini',
                      ),
                      _buildStatCard(
                        'Aktif',
                        '$activeUsers',
                        Icons.check_circle,
                        Colors.green,
                        '${totalUsers > 0 ? (activeUsers * 100 / totalUsers).toStringAsFixed(1) : 0}%',
                      ),
                      _buildStatCard(
                        'Nonaktif',
                        '$inactiveUsers',
                        Icons.pause_circle,
                        Colors.orange,
                        '${totalUsers > 0 ? (inactiveUsers * 100 / totalUsers).toStringAsFixed(1) : 0}%',
                      ),
                      _buildStatCard(
                        'Diblokir',
                        '$blockedUsers',
                        Icons.block,
                        softRed,
                        '${totalUsers > 0 ? (blockedUsers * 100 / totalUsers).toStringAsFixed(1) : 0}%',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 18, color: primaryGradientStart),
                            const SizedBox(width: 8),
                            Text(
                              'Pertumbuhan User',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildGrowthItem('Hari Ini', newUsersToday, primaryGradientStart),
                            _buildGrowthItem('Minggu Ini', newUsersThisWeek, Colors.green),
                            _buildGrowthItem('Bulan Ini', _getNewUsersThisMonth(), Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart, size: 18, color: primaryGradientStart),
                            const SizedBox(width: 8),
                            Text(
                              'Distribusi Role',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDistributionItem(
                          'Super Admin',
                          superadminCount,
                          totalUsers,
                          const Color(0xFFE74C3C),
                        ),
                        _buildDistributionItem(
                          'Manager',
                          managerCount,
                          totalUsers,
                          const Color(0xFF3498DB),
                        ),
                        _buildDistributionItem(
                          'Pengawas',
                          pengawasCount,
                          totalUsers,
                          const Color(0xFF2ECC71),
                        ),
                        _buildDistributionItem(
                          'Mitra',
                          mitraCount,
                          totalUsers,
                          const Color(0xFFF39C12),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (fungsiStats.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.work, size: 18, color: primaryGradientStart),
                              const SizedBox(width: 8),
                              Text(
                                'Distribusi Fungsi',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...fungsiStats.entries.map((entry) {
                            return _buildDistributionItem(
                              entry.key,
                              entry.value,
                              totalUsers,
                              Colors.blueGrey,
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.new_releases, size: 18, color: primaryGradientStart),
                                const SizedBox(width: 8),
                                Text(
                                  'User Terbaru',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total: ${_users.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._users.take(5).map((user) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => _showUserDetails(user),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(user['role'] ?? '').withAlpha(25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getRoleIcon(user['role'] ?? ''),
                                        color: _getRoleColor(user['role'] ?? ''),
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['nama_lengkap'] ?? '-',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            user['email'] ?? '-',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(user['role'] ?? '').withAlpha(25),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getRoleLabel(user['role'] ?? ''),
                                            style: GoogleFonts.poppins(
                                              fontSize: 8,
                                              color: _getRoleColor(user['role'] ?? ''),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(user['created_at']),
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  int _getNewUsersThisMonth() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    return _users.where((u) {
      final created = (u['created_at'] as Timestamp?)?.toDate();
      return created != null && created.isAfter(firstDayOfMonth);
    }).length;
  }

  Widget _buildGrowthItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$count (${(percentage * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}