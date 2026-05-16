// lib/screens/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
import '../core/services/auth_service.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ================= SERVICE =================
  final AuthService _authService = AuthService();
  
  // ================= FORM & CONTROLLERS =================
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  // ================= STATE =================
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _errorMessage = "";
  
  // ================= RATE LIMITING =================
  int _loginAttempts = 0;
  DateTime? _lastLoginAttempt;
  Timer? _coolDownTimer;
  static const int _maxAttempts = 5;
  static const int _coolDownSeconds = 30;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _coolDownTimer?.cancel();
    super.dispose();
  }

  // ================= REMEMBER ME =================
  Future<void> _loadRememberMe() async {
    final data = await _authService.loadRememberMe();
    setState(() {
      _rememberMe = data.remembered;
      if (data.remembered && data.identity.isNotEmpty) {
        _identityController.text = data.identity;
      }
    });
  }

  // ================= AUTO LOGIN =================
  Future<void> _checkAutoLogin() async {
    final result = await _authService.tryAutoLogin();
    if (result != null && result.success && mounted) {
      _showSuccess("Selamat datang kembali, ${result.nama}!");
      _navigateToDashboard(result.role);
    }
  }

  // ================= RATE LIMITING =================
  int get _cooldownRemaining {
    if (_lastLoginAttempt == null) return 0;
    final diff = DateTime.now().difference(_lastLoginAttempt!);
    final remaining = _coolDownSeconds - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldownTimer() {
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining <= 0) {
        timer.cancel();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  bool get _isBlocked => _loginAttempts >= _maxAttempts && _cooldownRemaining > 0;

  // ================= PROSES LOGIN =================
  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_cooldownRemaining > 0) {
      _showError("Terlalu banyak percobaan. Tunggu ${_cooldownRemaining} detik.");
      return;
    }
    
    if (_isBlocked) {
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
      // PANGGIL AUTH SERVICE
      final result = await _authService.login(
        identity: _identityController.text.trim(),
        password: _passwordController.text,
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      if (result.success) {
        _loginAttempts = 0;
        _showSuccess("Selamat datang, ${result.nama}!");
        _navigateToDashboard(result.role);
      } else {
        setState(() => _errorMessage = result.errorMessage);
        
        if (_loginAttempts >= _maxAttempts) {
          _startCooldownTimer();
          _showError("Terlalu banyak percobaan. Tunggu $_coolDownSeconds detik.");
        } else {
          _showError(result.errorMessage);
        }
      }

    } catch (e) {
      debugPrint("Login error: $e");
      setState(() => _errorMessage = "Terjadi kesalahan sistem. Silakan coba lagi.");
      _showError("Terjadi kesalahan sistem. Silakan coba lagi.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= NAVIGASI =================
  void _navigateToDashboard(String role) {
    final dashboard = _authService.getDashboardForRole(role);
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => dashboard,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ================= SNACKBAR =================
  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: AppColors.softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
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
                      _buildLoginForm(),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security_rounded, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text("Login Aman & Terenkripsi",
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
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
          Icon(Icons.login_rounded, size: 80, color: AppColors.primaryBlue.withAlpha(76)),
          Positioned(
            right: 0, top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text("Selamat Datang Kembali! 👋", textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
        const SizedBox(height: 4),
        Text("Masuk untuk mengakses sistem pengajuan lembur\nSemua data dienkripsi dengan SHA-256",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withAlpha(89), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormHeader(),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),
            _buildIdentityField(),
            const SizedBox(height: 12),
            _buildPasswordField(),
            const SizedBox(height: 8),
            _buildRememberAndForgot(),
            const SizedBox(height: 16),
            _buildLoginButton(),
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
        Text("LOGIN AMAN", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text("Masukkan kredensial Anda", textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.softRed.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.softRed.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.softRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage,
            style: GoogleFonts.poppins(color: AppColors.softRed, fontSize: 11, fontWeight: FontWeight.w500))),
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
          validator: Validators.validateIdentity, // PAKE VALIDATORS
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
          validator: Validators.validatePassword, // PAKE VALIDATORS
          suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 20),
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
                checkColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (value) => setState(() => _rememberMe = value ?? false),
              ),
            ),
            Text("Ingat saya", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(initialEmail: _identityController.text.trim()),
            ));
          },
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text("Lupa Password?", style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final remaining = _cooldownRemaining;
    final isDisabled = _loading || remaining > 0;
    
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isDisabled ? 0 : 2,
        ),
        child: _loading
            ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)))
            : remaining > 0
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text("Coba lagi dalam $remaining detik", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ]),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Belum punya akun? ", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text("Daftar Sekarang", style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(25), shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, color: AppColors.primaryBlue, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text("Login Aman Terenkripsi 🔒",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              Text("SHA-256 + Rate Limiting", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[600])),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelWithAsterisk(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        children: const [TextSpan(text: " *", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white, size: 18),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 4), child: suffix) : null,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white54)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.softRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.softRed)),
        errorStyle: GoogleFonts.poppins(color: AppColors.softRed, fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        isDense: true,
      ),
    );
  }
}