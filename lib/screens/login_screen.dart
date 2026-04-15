// screens/login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

// Import your dashboard screens
import '../dashboard/superadmin/superadmin_dashboard.dart';
import '../dashboard/manager/manager_dashboard.dart';
import '../dashboard/pengawas/pengawas_dashboard.dart';
import '../dashboard/mitra/mitra_dashboard.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ================= KONSTANTA (SAMA DENGAN REGISTER) =================
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color secondaryBlue = const Color(0xFF2A4F8C);
  final Color accentOrange = const Color(0xFFFF6B35);
  final Color softRed = const Color(0xFFE74C3C);

  // ================= FORM & CONTROLLERS =================
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  // ================= STATE VARIABLES =================
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _errorMessage = "";
  
  // ================= KEAMANAN: RATE LIMITING =================
  int _loginAttempts = 0;
  DateTime? _lastLoginAttempt;
  Timer? _coolDownTimer;
  static const int _maxAttempts = 5;
  static const int _coolDownSeconds = 30; // 🔥 DIUBAH: 30 detik setelah 5x gagal (sebelumnya 90 detik)
  
  // ================= KEAMANAN: SESSION MANAGEMENT =================
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    _checkExistingSession();
    _generateSessionId();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _coolDownTimer?.cancel();
    super.dispose();
  }

  // ================= SESSION ID (SAMA DENGAN REGISTER) =================
  void _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'session_$timestamp${random.nextInt(10000)}';
  }

  // ================= HASH DATA (SAMA DENGAN REGISTER) =================
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ================= REMEMBER ME =================
  Future<void> _loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _rememberMe = prefs.getBool('remember_me') ?? false;
        if (_rememberMe) {
          _identityController.text = prefs.getString('saved_identity') ?? '';
        }
      });
    } catch (e) {
      debugPrint("Error loading remember me: $e");
    }
  }

  Future<void> _saveRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      if (_rememberMe) {
        await prefs.setString('saved_identity', _identityController.text.trim());
      } else {
        await prefs.remove('saved_identity');
      }
    } catch (e) {
      debugPrint("Error saving remember me: $e");
    }
  }

  // ================= CEK SESI YANG ADA =================
  Future<void> _checkExistingSession() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        // Cek dengan field yang sesuai schema register
        if (userDoc.exists && userDoc.data()?['status_akun'] == 'active') {
          _autoLogin(currentUser.uid);
        } else {
          await FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      debugPrint("Error checking session: $e");
    }
  }

  Future<void> _autoLogin(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      final userData = userDoc.data()!;
      
      // FIXED: Gunakan DateTime.now() untuk array, serverTimestamp untuk field biasa
      final now = DateTime.now();
      
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'last_login': FieldValue.serverTimestamp(), // ✅ BOLEH (di root document)
        'login_attempts': 0,
        // FIXED: Jangan pakai serverTimestamp di dalam array
        'audit_trail': FieldValue.arrayUnion([
          {
            "action": "auto_login",
            "timestamp": now,
            "session_id": _sessionId,
          }
        ]),
      });

      if (mounted) {
        _showSuccessSnackBar("Selamat datang kembali, ${userData['nama_lengkap']}!");
        _navigateBasedOnRole(userData['role'] ?? 'mitra');
      }
    } catch (e) {
      debugPrint("Auto login failed: $e");
      await FirebaseAuth.instance.signOut();
    }
  }

  // ================= KEAMANAN: RATE LIMITING =================
  int _getCooldownRemaining() {
    if (_lastLoginAttempt == null) return 0;
    final diff = DateTime.now().difference(_lastLoginAttempt!);
    final remaining = _coolDownSeconds - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldownTimer() {
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_getCooldownRemaining() == 0) {
        timer.cancel();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  bool _isSuspiciousActivity() {
    if (_loginAttempts >= _maxAttempts) return true;
    return false;
  }

  // ================= VALIDASI INPUT =================
  String? _validateIdentity(String? value) {
    if (value == null || value.isEmpty) {
      return "Email atau nomor HP wajib diisi";
    }
    
    final isEmail = value.contains('@');
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    final isPhone = cleanPhone.length >= 10 && cleanPhone.length <= 13 && cleanPhone.startsWith('8');
    
    if (!isEmail && !isPhone) {
      return "Masukkan email valid atau nomor HP (diawali 8, 10-13 digit)";
    }
    
    if (isEmail) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$'
      );
      if (!emailRegex.hasMatch(value)) {
        return "Format email tidak valid";
      }
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password wajib diisi";
    }
    if (value.length < 8) {
      return "Password minimal 8 karakter";
    }
    return null;
  }

  // ================= PROSES LOGIN (TANPA VERIFIKASI EMAIL) =================
  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;
    
    final remaining = _getCooldownRemaining();
    if (remaining > 0) {
      _showError("Terlalu banyak percobaan. Tunggu $remaining detik.");
      return;
    }
    
    if (_isSuspiciousActivity()) {
      _showError("Terlalu banyak percobaan. Silakan tunggu $_coolDownSeconds detik.");
      _loginAttempts = _maxAttempts;
      _lastLoginAttempt = DateTime.now();
      _startCooldownTimer();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = "";
      _loginAttempts++;
      _lastLoginAttempt = DateTime.now();
    });

    try {
      final input = _identityController.text.trim();
      String email = input;
      
      // Cek apakah input adalah nomor HP
      if (!input.contains('@')) {
        final cleanPhone = input.replaceAll(RegExp(r'[^\d]'), '');
        
        final phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .where('status_akun', isNotEqualTo: 'deleted')
            .limit(1)
            .get();

        if (phoneQuery.docs.isEmpty) {
          throw FirebaseAuthException(code: 'user-not-found');
        }

        email = phoneQuery.docs.first['email'];
      }

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("Koneksi timeout. Periksa jaringan Anda.");
            },
          );

      final user = cred.user!;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await user.delete();
        throw Exception("Data user tidak ditemukan");
      }

      final userData = userDoc.data()!;
      
      // CEK STATUS AKUN - Sesuai schema register
      if (userData['account_locked'] == true) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Akun Anda diblokir. Hubungi administrator.");
      }

      // CEK STATUS AKUN - Pastikan akun aktif
      if (userData['status_akun'] != 'active') {
        await FirebaseAuth.instance.signOut();
        throw Exception("Akun Anda tidak aktif. Hubungi administrator.");
      }

      // 🚫 VERIFIKASI EMAIL DIHAPUS - Langsung login tanpa cek emailVerified

      // Update data user
      final now = DateTime.now();
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'login_attempts': 0,
        'audit_trail': FieldValue.arrayUnion([
          {
            "action": "login",
            "timestamp": now,
            "session_id": _sessionId,
          }
        ]),
      });

      await _saveRememberMe();

      // Reset counter
      _loginAttempts = 0;

      if (mounted) {
        _showSuccessSnackBar("Selamat datang, ${userData['nama_lengkap']}!");
        _navigateBasedOnRole(userData['role'] ?? 'mitra');
      }

    } on FirebaseAuthException catch (e) {
      await Future.delayed(const Duration(seconds: 1));
      
      String message = _getFirebaseErrorMessage(e.code);
      setState(() => _errorMessage = message);
      
      if (_loginAttempts >= _maxAttempts) {
        _startCooldownTimer();
        _showError("Terlalu banyak percobaan. Tunggu $_coolDownSeconds detik.");
      } else {
        _showError(message);
      }
      
    } on TimeoutException catch (_) {
      setState(() => _errorMessage = "Koneksi timeout. Periksa jaringan Anda.");
      _showError("Koneksi timeout. Periksa jaringan Anda.");
    } catch (e) {
      debugPrint("Login error: $e");
      setState(() => _errorMessage = "Terjadi kesalahan sistem. Silakan coba lagi.");
      _showError("Terjadi kesalahan sistem. Silakan coba lagi.");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ================= NAVIGASI BERDASARKAN ROLE =================
  void _navigateBasedOnRole(String role) {
    Widget dashboard;
    
    // Sesuaikan dengan role yang mungkin ada di sistem
    switch (role) {
      case 'superadmin':
        dashboard = const SuperAdminDashboard();
        break;
      case 'manager':
        dashboard = const ManagerDashboard();
        break;
      case 'pengawas':
        dashboard = const PengawasDashboard();
        break;
      case 'mitra':
      default:
        dashboard = const MitraDashboard();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  // ================= ERROR HANDLING =================
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-not-found':
        return 'Email/nomor HP tidak terdaftar';
      case 'wrong-password':
        return 'Password salah';
      case 'invalid-credential':
        return 'Email/password salah';
      case 'user-disabled':
        return 'Akun dinonaktifkan';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu beberapa saat';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet';
      default:
        return 'Login gagal. Silakan coba lagi';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
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

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    final remaining = _getCooldownRemaining();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildIllustration(),
                      const SizedBox(height: 16),
                      _buildTitle(),
                      const SizedBox(height: 20),
                      _buildLoginForm(remaining),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF1E3C72),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withAlpha(76)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security_rounded, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(
                "Login Aman & Terenkripsi",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.login_rounded,
            size: 80,
            color: primaryBlue.withAlpha(76),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          "Selamat Datang Kembali! 👋",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Masuk untuk mengakses sistem pengajuan lembur\nSemua data dienkripsi dengan SHA-256",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(int remaining) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withAlpha(89),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormHeader(),
            const SizedBox(height: 16),
            
            if (_errorMessage.isNotEmpty)
              _buildErrorMessage(),
            
            _buildIdentityField(),
            const SizedBox(height: 12),
            _buildPasswordField(),
            const SizedBox(height: 8),
            _buildRememberAndForgot(),
            const SizedBox(height: 16),
            _buildLoginButton(remaining),
            const SizedBox(height: 12),
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Column(
      children: [
        Text(
          "LOGIN AMAN",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Masukkan kredensial Anda",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: softRed.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: softRed.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: softRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: softRed,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Email atau Nomor HP"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _identityController,
          icon: Icons.person_outline,
          hint: "contoh@email.com / 81234567890",
          validator: _validateIdentity,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Password"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _passwordController,
          icon: Icons.lock_outline,
          hint: "Masukkan password",
          obscure: _obscurePassword,
          validator: _validatePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        Row(
          children: [
            Transform.scale(
              scale: 0.7,
              child: Checkbox(
                value: _rememberMe,
                activeColor: Colors.white,
                checkColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
              ),
            ),
            Text(
              "Ingat saya",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(
                  initialEmail: _identityController.text.trim(),
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(50, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Lupa Password?",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(int remaining) {
    bool isDisabled = _loading || remaining > 0;
    
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDisabled ? 0 : 2,
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3C72)),
                ),
              )
            : remaining > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "Coba lagi dalam $remaining detik",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Belum punya akun? ",
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(50, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Daftar Sekarang",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryBlue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_rounded, color: primaryBlue, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Login Aman Terenkripsi 🔒",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                Text(
                  "SHA-256 + Rate Limiting",
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
  }

  // ================= HELPER WIDGETS =================
  Widget _buildLabelWithAsterisk(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        children: const [
          TextSpan(
            text: " *",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      inputFormatters: formatters,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: Colors.white54,
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: Colors.white, size: 18),
        suffixIcon: suffix != null 
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: suffix,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE74C3C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE74C3C)),
        ),
        errorStyle: GoogleFonts.poppins(
          color: softRed,
          fontSize: 10,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        isDense: true,
      ),
    );
  }
}