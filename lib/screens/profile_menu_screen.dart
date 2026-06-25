// screens/profile/profile_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_nav/app_bottom_nav.dart'; // ✅ Import AppBottomNav

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? userData;
  String? userId;
  String? userEmail;
  String? userName;
  String? userPhotoUrl;
  String? _userRole; // ✅ Tambah userRole
  File? _selectedImage;

  bool isEditing = false;
  bool isLoading = true;
  bool isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedFungsi = "operation";

  Map<String, dynamic> stats = {
    'totalKehadiran': 0,
    'totalLembur': 0,
    'totalJamLembur': 0,
    'memberSince': '',
  };

  static const Color primaryBlue = Color(0xFF1E3C72);
  static const Color accentOrange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      userEmail = user.email;
      userPhotoUrl = user.photoURL;
      await _loadUserData();
      await _loadUserStats();
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _loadUserData() async {
    if (userId == null) return;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          userData = data;
          userName = data['nama_lengkap'] ?? userEmail?.split('@')[0] ?? 'User';
          _userRole = data['role']?.toString() ?? 'mitra'; // ✅ Load role
          _namaController.text = userName ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _selectedFungsi = data['fungsi'] ?? 'operation';
          userPhotoUrl = data['photo_url'] ?? userPhotoUrl;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserStats() async {
    if (userId == null) return;
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      int totalKehadiran = 0;
      try {
        final absensiSnap = await _firestore
            .collection('absensi')
            .where('user_id', isEqualTo: userId)
            .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('waktu', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get();
        totalKehadiran = absensiSnap.docs.length;
      } catch (e) {
        debugPrint('Absensi load error: $e');
      }

      int totalLembur = 0;
      int totalJamLembur = 0;
      try {
        final lemburSnap = await _firestore
            .collection('lembur_mitra')
            .where('user_id', isEqualTo: userId)
            .where('status', isEqualTo: 'approved')
            .get();
        totalLembur = lemburSnap.docs.length;
        for (var doc in lemburSnap.docs) {
          final data = doc.data();
          totalJamLembur += (data['total_jam_desimal'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        debugPrint('Lembur load error: $e');
      }

      String memberSince = '';
      if (userData != null && userData!['created_at'] != null) {
        try {
          final createdAt = userData!['created_at'];
          DateTime date;
          if (createdAt is Timestamp) {
            date = createdAt.toDate();
          } else if (createdAt is String) {
            date = DateTime.parse(createdAt);
          } else {
            date = DateTime.now();
          }
          memberSince = DateFormat('MMMM yyyy', 'id_ID').format(date);
        } catch (e) {
          memberSince = 'Baru';
        }
      }

      if (mounted) {
        setState(() {
          stats = {
            'totalKehadiran': totalKehadiran,
            'totalLembur': totalLembur,
            'totalJamLembur': totalJamLembur,
            'memberSince': memberSince,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // ✅ Method untuk dapat index bottom nav berdasarkan role
  int _getCurrentNavIndex() {
    switch (_userRole) {
      case 'superadmin':
        return 2; // Profile di index 2
      case 'manager':
        return 2; // Profile di index 2
      case 'pengawas':
        return 3; // Profile di index 3
      case 'mitra':
        return 3; // Profile di index 3
      default:
        return 0;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      await _firestore.collection('users').doc(userId).update({
        'nama_lengkap': _namaController.text.trim(),
        'phone': _phoneController.text.trim(),
        'fungsi': _selectedFungsi,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          userName = _namaController.text.trim();
          isEditing = false;
        });
        _showSnackBar('✅ Profil berhasil diperbarui', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui profil', Colors.red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _selectedImage = File(file.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isLoading)
            isEditing
                ? TextButton(
                    onPressed: () {
                      setState(() {
                        isEditing = false;
                        _namaController.text = userName ?? '';
                        _phoneController.text = userData?['phone']?.toString() ?? '';
                        _selectedFungsi = userData?['fungsi'] ?? 'operation';
                        _selectedImage = null;
                      });
                    },
                    child: const Text('Batal', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  )
                : IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => setState(() => isEditing = true),
                  ),
        ],
      ),
      // ✅ TAMBAHKAN BOTTOM NAV
      bottomNavigationBar: _userRole != null
          ? AppBottomNav(
              userRole: _userRole!,
              currentIndex: _getCurrentNavIndex(),
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadUserStats();
              },
              color: primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 80), // ✅ Extra padding untuk bottom nav
                child: Column(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                            ? Image.network(userPhotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildAvatar())
                            : _buildAvatar(),
                  ),
                ),
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: accentOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            userName ?? 'User',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(
              userEmail ?? '-',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Text(
          (userName?.isNotEmpty == true ? userName![0].toUpperCase() : 'U'),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
        ),
      ),
    );
  }

  // ==================== STATS ====================
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Kehadiran', '${stats['totalKehadiran']}', Icons.calendar_today, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Lembur', '${stats['totalLembur']}', Icons.work_history, accentOrange)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Jam', '${stats['totalJamLembur']}j', Icons.timer, Colors.green)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ==================== FORM ====================
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Pribadi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryBlue)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _namaController,
              label: 'Nama Lengkap',
              icon: Icons.person_outline,
              enabled: isEditing,
              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : (v.length < 3 ? 'Terlalu pendek' : null),
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _phoneController,
              label: 'Nomor HP',
              icon: Icons.phone_android,
              enabled: isEditing,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
              prefix: '+62',
            ),
            const SizedBox(height: 14),
            _buildReadOnlyField(Icons.email_outlined, 'Email', userEmail ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? prefix,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(fontSize: 14, color: enabled ? primaryBlue : Colors.grey[700]),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(prefix, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryBlue)),
              )
            : Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentOrange)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildReadOnlyField(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1E3C72))),
            ],
          ),
          const Spacer(),
          const Icon(Icons.lock, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================
  Widget _buildActionButtons() {
    return Column(
      children: [
        if (isEditing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Keluar dari Aplikasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}