// lib/screens/register_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/services/auth_service.dart';
import '../../core/services/superadmin_service.dart'; // 🔥 NEW: Import DashboardService

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ================= CONTROLLER =================
  final _formKey = GlobalKey<FormState>();
  final _idPekerjaController = TextEditingController(); // 🔥 NEW: ID Pekerja
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _captchaController = TextEditingController();

  // ================= STATE =================
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;
  bool _agreeTerms = false;

  String _selectedFungsi = "operation";
  bool _showPasswordStrength = false;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "";
  Color _passwordStrengthColor = Colors.grey;

  // 🔥 NEW: Validasi ID Pekerja
  bool _isValidatingWorker = false;
  bool _workerValidated = false;
  Map<String, dynamic>? _validatedWorker;
  String _workerValidationMessage = '';

  // ================= RATE LIMITING =================
  int _registerAttempts = 0;
  DateTime? _lastRegisterAttempt;
  Timer? _coolDownTimer;
  static const int _maxAttempts = 3;
  static const int _coolDownSeconds = 30;

  // ================= CAPTCHA =================
  String _captchaQuestion = "";
  int _captchaAnswer = 0;
  int _captchaDifficulty = 1;

  // ================= SERVICE =================
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService(); // 🔥 NEW
  late String _sessionId;

  // ================= FUNGSI LIST =================
  final List<Map<String, String>> _fungsiList = [
    {"value": "operation",   "label": "Operation",      "icon": "⚙️", "description": "Operasional Lapangan"},
    {"value": "lab",         "label": "Laboratorium",    "icon": "🔬", "description": "Laboratorium & Pengujian"},
    {"value": "maintenance", "label": "Maintenance",     "icon": "🔧", "description": "Perawatan & Perbaikan"},
    {"value": "hsse",        "label": "HSSE",            "icon": "🛡️", "description": "Keselamatan & K3"},
    {"value": "gpr",         "label": "GPR",             "icon": "📊", "description": "General Processing"},
    {"value": "bs",          "label": "Business Support","icon": "📋", "description": "Business Support"},
  ];

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_calculatePasswordStrength);
    _generateCaptcha();
    _sessionId = _authService.generateSessionId();
    // 🔥 Reset validasi saat ID berubah
    _idPekerjaController.addListener(() {
      if (_workerValidated) {
        setState(() {
          _workerValidated = false;
          _validatedWorker = null;
          _workerValidationMessage = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_calculatePasswordStrength);
    _idPekerjaController.dispose(); // 🔥 NEW
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _captchaController.dispose();
    _coolDownTimer?.cancel();
    super.dispose();
  }

  // ================= PASSWORD STRENGTH =================
  void _calculatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (_showPasswordStrength) {
        setState(() { _showPasswordStrength = false; _passwordStrength = 0.0; });
      }
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
        _passwordStrengthColor = AppColors.softRed;
      } else if (_passwordStrength < 0.8) {
        _passwordStrengthText = "Sedang";
        _passwordStrengthColor = AppColors.accentOrange;
      } else {
        _passwordStrengthText = "Kuat";
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // 🔥 ================= VALIDASI ID PEKERJA =================
  Future<void> _validateWorkerId() async {
    final idPekerja = _idPekerjaController.text.trim();

    if (idPekerja.isEmpty) {
      _showError("ID Pekerja tidak boleh kosong");
      return;
    }

    setState(() {
      _isValidatingWorker = true;
      _workerValidated = false;
      _validatedWorker = null;
      _workerValidationMessage = '';
    });

    try {
      final result = await _dashboardService.validateWorkerId(idPekerja);

      if (!mounted) return;

      if (result != null) {
        // ID VALID
        setState(() {
          _isValidatingWorker = false;
          _workerValidated = true;
          _validatedWorker = result;
          _workerValidationMessage = '✅ ID Valid - ${result['nama']}';
        });

        // 🔥 Auto-fill Nama dari Master Data
        _namaController.text = result['nama'] ?? '';
        
        // 🔥 Auto-fill Fungsi dari Master Data
        if (result['fungsi'] != null && result['fungsi'].toString().isNotEmpty) {
          setState(() {
            _selectedFungsi = result['fungsi'].toString();
          });
        }

        _showSuccessSnackbar('ID Pekerja valid: ${result['nama']}');
      } else {
        // ID TIDAK VALID
        setState(() {
          _isValidatingWorker = false;
          _workerValidated = false;
          _validatedWorker = null;
          _workerValidationMessage = '❌ ID Pekerja tidak ditemukan';
        });
        _showError("ID Pekerja tidak ditemukan di database. Hubungi admin.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingWorker = false;
        _workerValidated = false;
        _workerValidationMessage = '❌ Gagal validasi';
      });
      _showError("Gagal validasi ID Pekerja. Periksa koneksi Anda.");
    }
  }

  void _showSuccessSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= CAPTCHA =================
  void _generateCaptcha() {
    final random = Random();
    int num1, num2, result;
    String op;

    switch (_captchaDifficulty) {
      case 1:
        num1 = random.nextInt(10) + 1;
        num2 = random.nextInt(10) + 1;
        op = '+';
        result = num1 + num2;
        break;
      case 2:
        if (random.nextBool()) {
          num1 = random.nextInt(15) + 5;
          num2 = random.nextInt(10) + 1;
          op = '+';
          result = num1 + num2;
        } else {
          num1 = random.nextInt(20) + 10;
          num2 = random.nextInt(10) + 1;
          op = '-';
          result = num1 - num2;
        }
        break;
      case 3:
        if (random.nextBool()) {
          num1 = random.nextInt(30) + 10;
          num2 = random.nextInt(20) + 1;
          op = '+';
          result = num1 + num2;
        } else {
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
    return userAnswer != null && userAnswer == _captchaAnswer;
  }

  // ================= RATE LIMITING =================
  int _getCooldownRemaining() {
    if (_lastRegisterAttempt == null) return 0;
    final remaining = _coolDownSeconds - DateTime.now().difference(_lastRegisterAttempt!).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldownTimer() {
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_getCooldownRemaining() <= 0) {
        _coolDownTimer?.cancel();
        if (mounted) {
          setState(() {
            _registerAttempts = 0;
          });
        }
      }
      if (mounted) setState(() {});
    });
  }

  // ================= PROSES REGISTER =================
  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    // Validasi Terms
    if (!_agreeTerms) {
      _showError("Anda harus menyetujui Syarat & Ketentuan");
      return;
    }

    // Rate Limiting
    final remaining = _getCooldownRemaining();
    if (remaining > 0) {
      _showError("Terlalu banyak percobaan. Tunggu $remaining detik.");
      return;
    }
    if (_registerAttempts >= _maxAttempts) {
      _showError("Terlalu banyak percobaan. Silakan tunggu $_coolDownSeconds detik.");
      _registerAttempts = _maxAttempts;
      _lastRegisterAttempt = DateTime.now();
      _startCooldownTimer();
      return;
    }

    // 🔥 Validasi ID Pekerja
    if (!_workerValidated) {
      _showError("ID Pekerja harus divalidasi terlebih dahulu. Klik tombol Validasi.");
      return;
    }

    // 🔥 Pastikan ID yang divalidasi sama dengan yang diinput
    if (_validatedWorker?['id_pekerja'] != _idPekerjaController.text.trim()) {
      _showError("ID Pekerja berubah. Silakan validasi ulang.");
      return;
    }

    // Validasi Form
    final formError = _authService.validateRegisterForm(
      nama: _namaController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (formError != null) {
      _showError(formError);
      return;
    }

    // Konfirmasi Password
    if (_passwordController.text != _confirmController.text) {
      _showError("Password dan konfirmasi tidak sama");
      return;
    }

    // Password Strength
    if (_passwordStrength < 0.5) {
      _showError("Password terlalu lemah. Kombinasikan huruf besar, kecil, dan angka.");
      return;
    }

    // Captcha
    if (!_validateCaptcha()) {
      _showError("Jawaban captcha salah");
      if (_captchaDifficulty < 3) {
        _captchaDifficulty++;
      }
      _generateCaptcha();
      return;
    }

    // Track attempt
    setState(() {
      _registerAttempts++;
      _loading = true;
    });
    _lastRegisterAttempt = DateTime.now();

    try {
      final result = await _authService.register(
        idPekerja: _idPekerjaController.text.trim(), // 🔥 NEW: Kirim ID Pekerja
        nama: _namaController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        fungsi: _selectedFungsi,
        sessionId: _sessionId,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (result.success) {
        setState(() {
          _registerAttempts = 0;
          _captchaDifficulty = 1;
        });
        await _showSuccessDialog();
      } else {
        setState(() {
          _registerAttempts--;
          if (_captchaDifficulty < 3) _captchaDifficulty++;
        });
        _showError(result.message);
        _generateCaptcha();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
        if (_captchaDifficulty < 3) _captchaDifficulty++;
      });
      _showError(_getFirebaseErrorMessage(e.code));
      _generateCaptcha();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
      });
      _showError("Koneksi timeout. Periksa jaringan Anda.");
      _generateCaptcha();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
      });
      debugPrint("Registrasi error: $e");
      _showError("Terjadi kesalahan sistem. Silakan coba lagi.");
      _generateCaptcha();
    }
  }

  // ================= POPUP SUKSES =================
  Future<void> _showSuccessDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70, height: 70,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              Text("Registrasi Berhasil! 🎉",
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Akun Anda telah berhasil dibuat.\nSilakan login dengan akun yang telah dibuat.",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text("OK, Masuk Sekarang",
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      context.go('/login');
    }
  }

  // ================= ERROR =================
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: AppColors.softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email sudah terdaftar.\nSilakan login atau gunakan email lain.';
      case 'invalid-email':        return 'Format email tidak valid.\nContoh: nama@email.com';
      case 'weak-password':        return 'Password terlalu lemah.\nGunakan minimal 6 karakter.';
      case 'operation-not-allowed': return 'Pendaftaran belum diaktifkan.\nHubungi admin.';
      default:                     return 'Pendaftaran gagal. Silakan coba lagi.';
    }
  }

  // =========================================================
  // 🔥 UI BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final remaining = _getCooldownRemaining();
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
    GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryBlue),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.security_rounded, color: Colors.green, size: 14),
        const SizedBox(width: 4),
        Text("Keamanan Terenkripsi",
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
      ]),
    ),
  ]);

  Widget _buildIllustration() => SizedBox(height: 100, child: Stack(alignment: Alignment.center, children: [
    Icon(Icons.app_registration_rounded, size: 80, color: AppColors.primaryBlue.withAlpha(76)),
    Positioned(
      right: 0, top: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
      ),
    ),
  ]));

  Widget _buildTitle() => Column(children: [
    Text("Daftar Akun Baru 👤", textAlign: TextAlign.center,
      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
    const SizedBox(height: 4),
    Text("Verifikasi ID Pekerja TAD untuk bergabung",
      textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
  ]);

  Widget _buildRegisterForm(int remaining) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primaryBlue,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(89), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildFormHeader(), const SizedBox(height: 16),
        // 🔥 ID PEKERJA - PALING ATAS!
        _buildIdPekerjaField(),
        // 🔥 Info validasi
        if (_workerValidationMessage.isNotEmpty) _buildValidationInfo(),
        const SizedBox(height: 12),
        _buildNamaField(), const SizedBox(height: 12),
        _buildEmailField(), const SizedBox(height: 12),
        _buildPhoneField(), const SizedBox(height: 12),
        _buildPasswordField(),
        if (_showPasswordStrength) _buildPasswordStrength(),
        const SizedBox(height: 12),
        _buildConfirmPasswordField(), const SizedBox(height: 16),
        _buildFungsiField(), const SizedBox(height: 16),
        _buildCaptchaField(), const SizedBox(height: 16),
        _buildTermsCheckbox(), const SizedBox(height: 16),
        _buildRegisterButton(remaining), const SizedBox(height: 12),
        _buildLoginLink(),
      ]),
    ),
  );

  Widget _buildFormHeader() => Column(children: [
    Text("REGISTRASI", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
    const SizedBox(height: 4),
    Text("Verifikasi ID Pekerja terlebih dahulu", textAlign: TextAlign.center,
      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
  ]);

  // 🔥 FIELD ID PEKERJA
  Widget _buildIdPekerjaField() => _fieldColumn(
    "ID Pekerja", _idPekerjaController, Icons.badge_rounded, "Masukkan ID Pekerja (contoh: P12345)",
    validator: (v) {
      if (v == null || v.isEmpty) return "ID Pekerja wajib diisi";
      if (!_workerValidated) return "ID Pekerja harus divalidasi";
      return null;
    },
    suffix: _buildValidateButton(),
  );

  // 🔥 TOMBOL VALIDASI
  Widget _buildValidateButton() {
    if (_isValidatingWorker) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (_workerValidated) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
      );
    }

    return TextButton(
      onPressed: _validateWorkerId,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Colors.white.withAlpha(40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text("Validasi", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // 🔥 INFO VALIDASI
  Widget _buildValidationInfo() => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _workerValidated ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _workerValidated ? Colors.greenAccent.withAlpha(100) : Colors.redAccent.withAlpha(100)),
    ),
    child: Row(children: [
      Icon(_workerValidated ? Icons.verified : Icons.warning_rounded,
        color: _workerValidated ? Colors.greenAccent : Colors.redAccent, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(_workerValidationMessage,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      ),
    ]),
  );

  Widget _buildNamaField() => _fieldColumn(
    "Nama Lengkap", _namaController, Icons.person_outline, "Masukkan nama lengkap",
    validator: (v) => _authService.validateNama(v),
  );

  Widget _buildEmailField() => _fieldColumn(
    "Email", _emailController, Icons.email_outlined, "contoh@email.com",
    type: TextInputType.emailAddress,
    validator: (v) => _authService.validateEmail(v),
  );

  Widget _buildPhoneField() => _fieldColumn(
    "Nomor HP", _phoneController, Icons.phone_iphone_rounded, "081234567890 atau 6281234567890",
    type: TextInputType.phone,
    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
    validator: (v) => _authService.validatePhone(v),
  );

  Widget _buildPasswordField() => _fieldColumn(
    "Password", _passwordController, Icons.lock_outline, "Buat password",
    obscure: _hidePass,
    suffix: IconButton(
      icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 20),
      onPressed: () => setState(() => _hidePass = !_hidePass),
    ),
    validator: (v) => _authService.validatePassword(v),
  );

  Widget _buildPasswordStrength() => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
            minHeight: 4,
          ),
        )),
        const SizedBox(width: 8),
        Text(_passwordStrengthText,
          style: GoogleFonts.poppins(color: _passwordStrengthColor, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 2),
      Text("Minimal 8 karakter: Huruf besar, kecil, angka",
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8)),
    ]),
  );

  Widget _buildConfirmPasswordField() => _fieldColumn(
    "Konfirmasi Password", _confirmController, Icons.lock_reset_rounded, "Ulangi password Anda",
    obscure: _hideConfirm,
    suffix: IconButton(
      icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 20),
      onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
    ),
    validator: (v) {
      if (v == null || v.isEmpty) return "Wajib diisi";
      if (v != _passwordController.text) return "Password tidak cocok";
      return null;
    },
  );

  Widget _buildFungsiField() => _fieldColumn(
    "Fungsi Kerja", null, Icons.work_outline, "",
    customField: Container(
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
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.expand_more_rounded, color: Colors.white),
          ),
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          dropdownColor: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(12),
          items: _fungsiList.map((item) => DropdownMenuItem<String>(
            value: item['value'],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item['label']!,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(item['description']!,
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
            ),
          )).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedFungsi = v);
          },
        ),
      ),
    ),
  );

  Widget _buildCaptchaField() => _fieldColumn(
    "Verifikasi Keamanan", null, Icons.security, "",
    customField: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Text(_captchaQuestion,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: Text("Level $_captchaDifficulty",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
          ),
        ]),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softRed),
            ),
            errorStyle: const TextStyle(color: AppColors.softRed, fontSize: 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
            onPressed: _generateCaptcha,
            child: Text("Refresh Captcha",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, decoration: TextDecoration.underline)),
          ),
        ]),
      ]),
    ),
  );

  Widget _buildTermsCheckbox() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Transform.scale(
      scale: 0.8,
      child: Checkbox(
        value: _agreeTerms,
        activeColor: Colors.white,
        checkColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: (v) => setState(() => _agreeTerms = v ?? false),
      ),
    ),
    Expanded(child: GestureDetector(
      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
      child: RichText(
        text: TextSpan(
          text: "Saya setuju dengan ",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
          children: [
            TextSpan(
              text: "Syarat & Ketentuan",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, fontSize: 11),
            ),
            const TextSpan(text: " dan "),
            TextSpan(
              text: "Kebijakan Privasi",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, fontSize: 11),
            ),
          ],
        ),
      ),
    )),
  ]);

  Widget _buildRegisterButton(int remaining) {
    final isDisabled = _loading || remaining > 0 || !_workerValidated; // 🔥 Harus validasi dulu
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isDisabled ? 0 : 2,
        ),
        child: _loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
              )
            : remaining > 0
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text("Tunggu $remaining detik",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("DAFTAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ]),
      ),
    );
  }

  Widget _buildLoginLink() => Center(
    child: TextButton(
      onPressed: () => context.pop(),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(50, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text("Sudah punya akun? Masuk sekarang",
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12)),
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(25), shape: BoxShape.circle),
        child: const Icon(Icons.shield_rounded, color: AppColors.primaryBlue, size: 16),
      ),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text("Keamanan Terenkripsi 🔒",
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
        Text("SHA-256 + Rate Limiting 30 detik",
          style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[600])),
      ])),
    ]),
  );

  // ================= WIDGET HELPER =================
  Widget _fieldColumn(
    String label,
    TextEditingController? controller,
    IconData icon,
    String hint, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    Widget? suffix,
    Widget? prefixWidget,
    Widget? customField,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _buildLabelWithAsterisk(label),
      const SizedBox(height: 4),
      customField ?? _buildInputField(
        controller: controller!,
        icon: icon,
        hint: hint,
        obscure: obscure,
        type: type,
        formatters: formatters,
        validator: validator,
        suffix: suffix,
        prefixWidget: prefixWidget,
      ),
    ]);
  }

  Widget _buildLabelWithAsterisk(String label) => RichText(
    text: TextSpan(
      text: label,
      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
      children: const [TextSpan(text: " *",
        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))],
    ),
  );

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
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: prefixWidget != null ? null : Icon(icon, color: Colors.white, size: 18),
        prefix: prefixWidget,
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 4), child: suffix) : null,
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
          borderSide: const BorderSide(color: AppColors.softRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.softRed),
        ),
        errorStyle: const TextStyle(color: AppColors.softRed, fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        isDense: true,
      ),
    );
  }
}