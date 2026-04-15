// screens/register_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Warna-warna
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color secondaryBlue = const Color(0xFF2A4F8C);
  final Color accentOrange = const Color(0xFFFF6B35);
  final Color softRed = const Color(0xFFE74C3C);

  // Controller dan state
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;
  bool _agreeTerms = false;
  
  String _selectedFungsi = "operation";
  bool _showPasswordStrength = false;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "";
  Color _passwordStrengthColor = Colors.grey;

  // Rate Limiting - 30 detik
  int _registerAttempts = 0;
  DateTime? _lastRegisterAttempt;
  Timer? _coolDownTimer;
  static const int _maxAttempts = 3;
  static const int _coolDownSeconds = 30; // Timer 30 detik
  
  // Captcha - HANYA PENJUMLAHAN DAN PENGURANGAN
  String _captchaQuestion = "";
  int _captchaAnswer = 0;
  int _captchaDifficulty = 1;
  
  // Session ID sederhana
  String _sessionId = '';

  // Daftar fungsi
  final List<Map<String, String>> _fungsiList = [
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
    _passwordController.addListener(_calculatePasswordStrength);
    _generateCaptcha();
    _generateSessionId();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _captchaController.dispose();
    _coolDownTimer?.cancel();
    super.dispose();
  }

  // ================= SESSION ID =================
  void _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'session_$timestamp${random.nextInt(10000)}';
  }

  // ================= PASSWORD STRENGTH =================
  void _calculatePasswordStrength() {
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

  // ================= CAPTCHA - HANYA PENJUMLAHAN & PENGURANGAN =================
  void _generateCaptcha() {
    final random = Random();
    int num1, num2, result;
    String op;
    
    switch(_captchaDifficulty) {
      case 1: // Level 1: Penjumlahan sederhana
        num1 = random.nextInt(10) + 1;
        num2 = random.nextInt(10) + 1;
        op = '+';
        result = num1 + num2;
        break;
      case 2: // Level 2: Penjumlahan atau pengurangan
        if (random.nextBool()) {
          // Penjumlahan
          num1 = random.nextInt(15) + 5;
          num2 = random.nextInt(10) + 1;
          op = '+';
          result = num1 + num2;
        } else {
          // Pengurangan (pastikan hasil positif)
          num1 = random.nextInt(20) + 10;
          num2 = random.nextInt(10) + 1;
          op = '-';
          result = num1 - num2;
        }
        break;
      case 3: // Level 3: Angka lebih besar
        if (random.nextBool()) {
          // Penjumlahan
          num1 = random.nextInt(30) + 10;
          num2 = random.nextInt(20) + 1;
          op = '+';
          result = num1 + num2;
        } else {
          // Pengurangan
          num1 = random.nextInt(40) + 20;
          num2 = random.nextInt(15) + 1;
          op = '-';
          result = num1 - num2;
        }
        break;
      default:
        num1 = random.nextInt(10) + 1;
        num2 = random.nextInt(10) + 1;
        op = '+';
        result = num1 + num2;
    }
    
    setState(() {
      _captchaQuestion = "$num1 $op $num2 = ?";
      _captchaAnswer = result;
      _captchaController.clear();
    });
  }

  bool _validateCaptcha() {
    final userAnswer = int.tryParse(_captchaController.text.trim());
    if (userAnswer == null) return false;
    return userAnswer == _captchaAnswer;
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
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$'
    );
    
    if (!emailRegex.hasMatch(value)) {
      return "Format email tidak valid";
    }
    
    return null;
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
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password wajib diisi";
    if (value.length < 8) return "Minimal 8 karakter";
    if (!value.contains(RegExp(r'[A-Z]'))) return "Harus ada huruf besar";
    if (!value.contains(RegExp(r'[a-z]'))) return "Harus ada huruf kecil";
    if (!value.contains(RegExp(r'[0-9]'))) return "Harus ada angka";
    
    return null;
  }

  // ================= RATE LIMITING - 30 DETIK BERJALAN =================
  int _getCooldownRemaining() {
    if (_lastRegisterAttempt == null) return 0;
    final diff = DateTime.now().difference(_lastRegisterAttempt!);
    final remaining = _coolDownSeconds - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldownTimer() {
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _getCooldownRemaining();
      if (remaining <= 0) {
        timer.cancel();
        if (mounted) setState(() {}); // Update UI untuk mengembalikan tombol normal
      } else {
        if (mounted) setState(() {}); // Update UI setiap detik untuk menampilkan timer
      }
    });
  }

  // ================= CEK AKTIVITAS MENURIGAKAN =================
  bool _isSuspiciousActivity() {
    if (_registerAttempts >= _maxAttempts) {
      return true;
    }
    return false;
  }

  // ================= ENKRIPSI DATA =================
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ================= PROSES REGISTER (FIXED - LANGSUNG KE LOGIN) =================
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    
    if (!_agreeTerms) {
      _showError("Anda harus menyetujui Syarat & Ketentuan");
      return;
    }
    
    final remaining = _getCooldownRemaining();
    if (remaining > 0) {
      _showError("Terlalu banyak percobaan. Tunggu $remaining detik.");
      return;
    }
    
    if (_isSuspiciousActivity()) {
      _showError("Terlalu banyak percobaan. Silakan tunggu $_coolDownSeconds detik.");
      _registerAttempts = _maxAttempts;
      _lastRegisterAttempt = DateTime.now();
      _startCooldownTimer();
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmController.text) {
      _showError("Password dan konfirmasi tidak sama");
      return;
    }
    
    if (_passwordStrength < 0.5) {
      _showError("Password terlalu lemah. Gunakan password yang lebih kuat.");
      return;
    }
    
    if (!_validateCaptcha()) {
      _showError("Kode captcha salah");
      if (_captchaDifficulty < 3) {
        _captchaDifficulty++;
      }
      _generateCaptcha();
      return;
    }
    
    setState(() {
      _loading = true;
      _registerAttempts++;
      _lastRegisterAttempt = DateTime.now();
    });

    try {
      // Bersihkan input
      final cleanEmail = _emailController.text.trim().toLowerCase();
      final cleanPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      final cleanNama = _namaController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      
      // Dapatkan label fungsi
      String fungsiLabel = _getFungsiLabel(_selectedFungsi);

      // Buat user di Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: cleanEmail,
        password: _passwordController.text.trim(),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException("Koneksi timeout. Periksa jaringan Anda.");
        },
      );

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception("Gagal membuat akun");
      }

      // Dapatkan timestamp sekarang untuk digunakan di audit trail
      final now = DateTime.now();

      // SIMPAN KE FIRESTORE - FIXED: serverTimestamp TIDAK boleh di dalam array
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        // IDENTITAS DASAR (String)
        "id": user.uid,
        "nama_lengkap": cleanNama,
        "email": cleanEmail,
        "email_hash": _hashData(cleanEmail),
        "phone": cleanPhone,
        "phone_hash": _hashData(cleanPhone),
        "role": "mitra",
        "fungsi": _selectedFungsi,
        "fungsi_label": fungsiLabel,
        
        // STATUS AKUN (String, boolean, number)
        "status_akun": "active",
        "is_verified": true,
        "account_locked": false,
        "login_attempts": 0,
        
        // KEAMANAN (Map) - BOLEH pakai serverTimestamp di dalam Map
        "security": {
          "session_id": _sessionId,
          "registered_at": FieldValue.serverTimestamp(),
          "security_level": "standard",
        },
        
        // TERMS (boolean, Timestamp, String)
        "terms_accepted": true,
        "terms_accepted_at": FieldValue.serverTimestamp(),
        "terms_version": "1.0",
        
        // METADATA (Timestamp, boolean)
        "created_at": FieldValue.serverTimestamp(),
        "last_login": FieldValue.serverTimestamp(),
        "profile_complete": true,
        
        // AUDIT TRAIL - FIXED: GUNAKAN DateTime.now(), BUKAN serverTimestamp()
        "audit_trail": [
          {
            "action": "register",
            "timestamp": DateTime.now(),
            "session_id": _sessionId,
          }
        ],
      });

      // Reset counter
      _registerAttempts = 0;
      _captchaDifficulty = 1;

      if (mounted) {
        // Tampilkan snackbar sukses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Registrasi berhasil! Silakan login dengan akun Anda.",
                    style: GoogleFonts.poppins(fontSize: 14),
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

        // Arahkan ke halaman login (BUKAN dashboard)
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getFirebaseErrorMessage(e.code);
      _showError(errorMessage);
      
      setState(() {
        if (_captchaDifficulty < 3) {
          _captchaDifficulty++;
        }
      });
      _generateCaptcha();
      
    } on TimeoutException catch (_) {
      _showError("Koneksi timeout. Periksa jaringan Anda.");
      _generateCaptcha();
    } catch (e) {
      debugPrint("Register error: $e");
      _showError("Terjadi kesalahan sistem. Silakan coba lagi.");
      _generateCaptcha();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
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

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan gunakan email lain atau login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan kombinasi yang lebih kuat.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
      case 'operation-not-allowed':
        return 'Registrasi sedang dinonaktifkan. Hubungi admin.';
      default:
        return 'Registrasi gagal. Silakan coba lagi.';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
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
                      _buildRegisterForm(remaining),
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
                "Keamanan Terenkripsi",
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
            Icons.app_registration_rounded,
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
          "Daftar Akun Baru 👤",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Bergabung untuk mengajukan kerja lembur\ndengan sistem keamanan terenkripsi",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(int remaining) {
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
            _buildNamaField(),
            const SizedBox(height: 12),
            _buildEmailField(),
            const SizedBox(height: 12),
            _buildPhoneField(),
            const SizedBox(height: 12),
            _buildPasswordField(),
            if (_showPasswordStrength) _buildPasswordStrength(),
            const SizedBox(height: 12),
            _buildConfirmPasswordField(),
            const SizedBox(height: 16),
            _buildFungsiField(),
            const SizedBox(height: 16),
            _buildCaptchaField(),
            const SizedBox(height: 16),
            _buildTermsCheckbox(),
            const SizedBox(height: 16),
            _buildRegisterButton(remaining),
            const SizedBox(height: 12),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Column(
      children: [
        Text(
          "REGISTRASI AMAN",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Semua data dienkripsi",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildNamaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Nama Lengkap"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _namaController,
          icon: Icons.person_outline,
          hint: "Masukkan nama lengkap",
          validator: _validateNama,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Email"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _emailController,
          icon: Icons.email_outlined,
          hint: "contoh@email.com",
          type: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Nomor HP"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _phoneController,
          icon: Icons.phone_iphone_rounded,
          hint: "81234567890",
          type: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
          ],
          validator: _validatePhone,
          prefixWidget: Container(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Text(
              "+62",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Password (min. 8 karakter)"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _passwordController,
          icon: Icons.lock_outline,
          hint: "Buat password",
          obscure: _hidePass,
          suffix: IconButton(
            icon: Icon(
              _hidePass ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _hidePass = !_hidePass),
          ),
          validator: _validatePassword,
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _passwordStrengthColor,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _passwordStrengthText,
                style: GoogleFonts.poppins(
                  color: _passwordStrengthColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "Minimal 8 karakter: Huruf besar, kecil, angka",
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Konfirmasi Password"),
        const SizedBox(height: 4),
        _buildInputField(
          controller: _confirmController,
          icon: Icons.lock_reset_rounded,
          hint: "Ulangi password Anda",
          obscure: _hideConfirm,
          suffix: IconButton(
            icon: Icon(
              _hideConfirm ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
          ),
          validator: (v) {
            if (v!.isEmpty) return "Wajib diisi";
            if (v != _passwordController.text) return "Password tidak cocok";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFungsiField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Fungsi Kerja"),
        const SizedBox(height: 6),
        Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withAlpha(25),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFungsi,
              isExpanded: true,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.expand_more_rounded, color: Colors.white),
              ),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
              ),
              dropdownColor: primaryBlue,
              borderRadius: BorderRadius.circular(12),
              items: _fungsiList.map((Map<String, String> item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['label']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item['description']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.white70,
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
                  setState(() => _selectedFungsi = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithAsterisk("Verifikasi Keamanan"),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white54),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _captchaQuestion,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Level $_captchaDifficulty",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _captchaController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Masukkan jawaban",
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(25),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Wajib diisi";
                  if (!_validateCaptcha()) return "Jawaban salah";
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _generateCaptcha,
                    child: Text(
                      "Refresh Captcha",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Checkbox(
            value: _agreeTerms,
            activeColor: Colors.white,
            checkColor: primaryBlue,
            onChanged: (v) => setState(() => _agreeTerms = v ?? false),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreeTerms = !_agreeTerms),
            child: RichText(
              text: TextSpan(
                text: "Saya setuju dengan ",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                ),
                children: [
                  TextSpan(
                    text: "Syarat & Ketentuan",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      fontSize: 11,
                    ),
                  ),
                  const TextSpan(text: " dan "),
                  TextSpan(
                    text: "Kebijakan Privasi",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(int remaining) {
    bool isDisabled = _loading || remaining > 0 || !_agreeTerms;
    
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _register,
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
                        "Tunggu $remaining detik",
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
                        "DAFTAR AMAN",
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

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(50, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        "Sudah punya akun? Masuk sekarang",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
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
                  "Keamanan Terenkripsi 🔒",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                Text(
                  "SHA-256 + Rate Limiting 30 detik",
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
    Widget? prefixWidget,
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
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
        prefixIcon: prefixWidget != null ? null : Icon(icon, color: Colors.white, size: 18),
        prefix: prefixWidget,
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
        errorStyle: const TextStyle(
          color: Color(0xFFE74C3C),
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