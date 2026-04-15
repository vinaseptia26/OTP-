// screens/profile/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

var logger = Logger();

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  // User data
  Map<String, dynamic>? userData;
  String? userId;
  String? userEmail;
  String? userName;
  String? userPhotoUrl;
  File? _selectedImage;
  
  // Edit mode
  bool isEditing = false;
  bool isLoading = true;
  bool isSaving = false;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedFungsi = "operation";
  
  // Fungsi list (sama dengan register)
  final List<Map<String, String>> _fungsiList = [
    {"value": "operation", "label": "Operation", "icon": "⚙️", "description": "Operasional Lapangan"},
    {"value": "lab", "label": "Laboratorium", "icon": "🔬", "description": "Laboratorium & Pengujian"},
    {"value": "maintenance", "label": "Maintenance", "icon": "🔧", "description": "Perawatan & Perbaikan"},
    {"value": "hsse", "label": "HSSE", "icon": "🛡️", "description": "Keselamatan & K3"},
    {"value": "gpr", "label": "GPR", "icon": "📊", "description": "General Processing"},
    {"value": "bs", "label": "BS", "icon": "📋", "description": "Business Support"},
  ];
  
  // Stats
  Map<String, dynamic> stats = {
    'totalKehadiran': 0,
    'totalLembur': 0,
    'totalJamLembur': 0,
    'memberSince': '',
  };

  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentOrange = const Color(0xFFFF6B35);
  final Color softRed = const Color(0xFFE74C3C);

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

  // Helper function untuk format member since dengan aman
  String _formatMemberSince(dynamic createdAt) {
    if (createdAt == null) return 'Baru';
    
    try {
      DateTime createdAtDate;
      if (createdAt is Timestamp) {
        createdAtDate = createdAt.toDate();
      } else if (createdAt is String) {
        createdAtDate = DateTime.parse(createdAt);
      } else {
        return 'Baru';
      }
      return DateFormat('MMMM yyyy').format(createdAtDate);
    } catch (e) {
      logger.e('Error parsing created_at: $e');
      return 'Baru';
    }
  }

  Future<void> _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
        userEmail = user.email;
        userPhotoUrl = user.photoURL;
      });
      await _loadUserData();
      await _loadUserStats();
    } else {
      // Jika user tidak login, arahkan ke halaman login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
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
          userName = data['nama_lengkap'] ?? userEmail?.split('@')[0] ?? 'Mitra';
          _namaController.text = userName ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _selectedFungsi = data['fungsi'] ?? 'operation';
          userPhotoUrl = data['photo_url'] ?? userPhotoUrl;
        });
      }
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal memuat data profil');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserStats() async {
    if (userId == null) return;
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      // Load absensi dengan error handling
      QuerySnapshot absensiSnapshot;
      try {
        absensiSnapshot = await _firestore
            .collection('absensi')
            .where('user_id', isEqualTo: userId)
            .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('waktu', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get();
      } catch (e) {
        logger.e('Error loading absensi: $e');
        absensiSnapshot = await _firestore.collection('absensi').limit(0).get();
      }
      
      // Load lembur dengan error handling
      QuerySnapshot lemburSnapshot;
      try {
        lemburSnapshot = await _firestore
            .collection('lembur')
            .where('mitra_id', isEqualTo: userId)
            .where('status', isEqualTo: 'disetujui')
            .get();
      } catch (e) {
        logger.e('Error loading lembur: $e');
        lemburSnapshot = await _firestore.collection('lembur').limit(0).get();
      }
      
      int totalJamLembur = 0;
      for (var doc in lemburSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final totalJam = (data['total_jam'] as num?)?.toInt() ?? 0;
        totalJamLembur += totalJam;
      }
      
      // Dapatkan tanggal bergabung dengan aman
      String memberSince = '';
      if (userData != null && userData!.containsKey('created_at')) {
        memberSince = _formatMemberSince(userData!['created_at']);
      }
      
      if (mounted) {
        setState(() {
          stats = {
            'totalKehadiran': absensiSnapshot.docs.length,
            'totalLembur': lemburSnapshot.docs.length,
            'totalJamLembur': totalJamLembur,
            'memberSince': memberSince,
          };
        });
      }
    } catch (e) {
      logger.e('Error loading user stats: $e');
      // Set default values agar UI tidak error
      if (mounted) {
        setState(() {
          stats = {
            'totalKehadiran': 0,
            'totalLembur': 0,
            'totalJamLembur': 0,
            'memberSince': 'Baru',
          };
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      isSaving = true;
    });
    
    try {
      final updates = <String, dynamic>{
        'nama_lengkap': _namaController.text.trim(),
        'phone': _phoneController.text.trim(),
        'fungsi': _selectedFungsi,
        'fungsi_label': _getFungsiLabel(_selectedFungsi),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Upload photo if selected
      if (_selectedImage != null) {
        // Note: You need to implement image upload to Firebase Storage
        // This is a placeholder - you'll need to add Firebase Storage
        // updates['photo_url'] = await _uploadImage();
        
        // For now, just show a message
        _showInfoSnackbar('Upload foto akan segera tersedia');
      }
      
      await _firestore.collection('users').doc(userId).update(updates);
      
      // Update local data
      if (mounted) {
        setState(() {
          userName = _namaController.text.trim();
          userData = {
            ...?userData,
            ...updates,
          };
          isEditing = false;
        });
        
        _showSuccessSnackbar('Profil berhasil diperbarui');
      }
    } catch (e) {
      logger.e('Error updating profile: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorSnackbar('Tidak memiliki izin untuk mengubah profil');
        } else {
          _showErrorSnackbar('Gagal memperbarui profil');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      logger.e('Error picking image: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal memilih foto');
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: softRed.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, color: softRed, size: 24),
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: softRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true && mounted) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!isEditing && !isLoading)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
              tooltip: 'Edit Profil',
            ),
          if (isEditing)
            TextButton(
              onPressed: isSaving ? null : () {
                setState(() {
                  isEditing = false;
                  // Reset controllers
                  _namaController.text = userName ?? '';
                  _phoneController.text = userData?['phone']?.toString() ?? '';
                  _selectedFungsi = userData?['fungsi'] ?? 'operation';
                  _selectedImage = null;
                });
              },
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  color: softRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadUserStats();
              },
              color: primaryBlue,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildStatsCard(),
                    const SizedBox(height: 24),
                    _buildProfileForm(),
                    const SizedBox(height: 24),
                    _buildSecuritySection(),
                    const SizedBox(height: 24),
                    _buildAccountActions(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, accentOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat profil...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue, primaryBlue.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: isEditing ? _pickImage : null,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          )
                        : userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                            ? Image.network(
                                userPhotoUrl!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildAvatarPlaceholder();
                                },
                              )
                            : _buildAvatarPlaceholder(),
                  ),
                ),
              ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userName ?? 'Mitra',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.work_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  userData?['fungsi_label'] ?? userData?['fungsi']?.toUpperCase() ?? 'MITRA',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  userEmail ?? '-',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: Center(
        child: Text(
          userName?.isNotEmpty == true ? userName![0].toUpperCase() : 'M',
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                  color: primaryBlue.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Statistik Akun',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.calendar_today_rounded,
                  value: stats['totalKehadiran'].toString(),
                  label: 'Kehadiran Bulan Ini',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.access_time_rounded,
                  value: stats['totalJamLembur'].toString(),
                  label: 'Total Jam Lembur',
                  color: accentOrange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.assignment_rounded,
                  value: stats['totalLembur'].toString(),
                  label: 'Lembur Disetujui',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Bergabung sejak ',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                stats['memberSince'] != '' && stats['memberSince'] != null 
                    ? stats['memberSince'] 
                    : 'Baru',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentOrange.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: accentOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Pribadi',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _namaController,
              label: 'Nama Lengkap',
              icon: Icons.person_outline,
              enabled: isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama lengkap wajib diisi';
                }
                if (value.length < 3) {
                  return 'Nama terlalu pendek';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Nomor HP',
              icon: Icons.phone_android_rounded,
              enabled: isEditing,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nomor HP wajib diisi';
                }
                final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                if (cleanValue.length < 10 || cleanValue.length > 13) {
                  return 'Nomor HP harus 10-13 digit';
                }
                return null;
              },
              prefix: '+62',
            ),
            const SizedBox(height: 16),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildFungsiField(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: enabled ? primaryBlue : Colors.grey[700],
          ),
          decoration: InputDecoration(
            prefixIcon: prefix != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      prefix,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                  )
                : Icon(icon, size: 20, color: Colors.grey[500]),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentOrange),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE74C3C)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE74C3C)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 20, color: Colors.grey[500]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userEmail ?? '-',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Email tidak dapat diubah',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildFungsiField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fungsi Kerja',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        if (!isEditing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline, size: 20, color: Colors.grey[500]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getFungsiLabel(_selectedFungsi),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFungsi,
                isExpanded: true,
                icon: Icon(Icons.expand_more_rounded, color: primaryBlue),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: primaryBlue,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: _fungsiList.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['value'],
                    child: Row(
                      children: [
                        Text(item['icon']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['label']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item['description']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: isEditing
                    ? (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedFungsi = value;
                          });
                        }
                      }
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Keamanan Akun',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, color: Colors.blue, size: 20),
            ),
            title: Text(
              'Ubah Password',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Perbarui password untuk keamanan akun',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, color: Colors.orange, size: 20),
            ),
            title: Text(
              'Aktivitas Login',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Lihat riwayat login terakhir',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              _showLoginHistory();
            },
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool hideCurrent = true;
    bool hideNew = true;
    bool hideConfirm = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ubah Password',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: hideCurrent,
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideCurrent ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          hideCurrent = !hideCurrent;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: hideNew,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          hideNew = !hideNew;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Minimal 8 karakter, huruf besar, kecil, dan angka',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: hideConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          hideConfirm = !hideConfirm;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validate
                  if (newPasswordController.text.length < 8) {
                    _showErrorSnackbar('Password minimal 8 karakter');
                    return;
                  }
                  if (newPasswordController.text != confirmPasswordController.text) {
                    _showErrorSnackbar('Konfirmasi password tidak sesuai');
                    return;
                  }
                  
                  // Show loading
                  Navigator.pop(context);
                  setState(() {
                    isSaving = true;
                  });
                  
                  try {
                    final user = _auth.currentUser;
                    if (user != null && user.email != null) {
                      // Reauthenticate
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);
                      
                      // Update password
                      await user.updatePassword(newPasswordController.text);
                      
                      if (mounted) {
                        _showSuccessSnackbar('Password berhasil diubah');
                      }
                      
                      // Update audit trail
                      await _firestore.collection('users').doc(userId).update({
                        'audit_trail': FieldValue.arrayUnion([
                          {
                            'action': 'change_password',
                            'timestamp': Timestamp.now(),
                            'session_id': _auth.currentUser?.uid,
                          }
                        ]),
                      });
                    }
                  } catch (e) {
                    logger.e('Error changing password: $e');
                    if (mounted) {
                      _showErrorSnackbar('Gagal mengubah password. Periksa password saat ini.');
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        isSaving = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Ubah Password',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLoginHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Riwayat Aktivitas',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('users').doc(userId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: softRed),
                                const SizedBox(height: 12),
                                Text(
                                  'Gagal memuat riwayat',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        final auditTrail = data?['audit_trail'] as List<dynamic>? ?? [];
                        
                        if (auditTrail.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada aktivitas',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: auditTrail.length,
                          itemBuilder: (context, index) {
                            final item = auditTrail[index] as Map<String, dynamic>;
                            final action = item['action'] ?? 'unknown';
                            final timestamp = item['timestamp'];
                            
                            String date = 'Tanggal tidak diketahui';
                            if (timestamp != null) {
                              try {
                                if (timestamp is Timestamp) {
                                  date = DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
                                } else if (timestamp is String) {
                                  date = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(timestamp));
                                }
                              } catch (e) {
                                logger.e('Error formatting date: $e');
                              }
                            }
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getActionColor(action).withAlpha(25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getActionIcon(action),
                                      color: _getActionColor(action),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getActionTitle(action),
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          date,
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

  Color _getActionColor(String action) {
    switch (action) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.red;
      case 'register':
        return Colors.blue;
      case 'change_password':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login_rounded;
      case 'logout':
        return Icons.logout_rounded;
      case 'register':
        return Icons.app_registration_rounded;
      case 'change_password':
        return Icons.lock_reset_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'login':
        return 'Login ke Akun';
      case 'logout':
        return 'Logout dari Akun';
      case 'register':
        return 'Registrasi Akun';
      case 'change_password':
        return 'Perubahan Password';
      default:
        return action;
    }
  }

  Widget _buildAccountActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                  color: softRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: softRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tindakan Akun',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isEditing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Simpan Perubahan',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          if (!isEditing)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showLogoutDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: softRed,
                  side: BorderSide(color: softRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Keluar dari Aplikasi',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}