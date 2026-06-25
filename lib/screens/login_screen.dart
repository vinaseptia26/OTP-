// lib/screens/login_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ================= SERVICE =================
  final AuthService _authService = AuthService();

  // ================= FORM =================
  final _formKey = GlobalKey<FormState>();

  // ================= CONTROLLER =================
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  // ================= STATE =================
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String _errorMessage = "";

  // ================= RATE LIMIT =================
  int _loginAttempts = 0;
  Timer? _coolDownTimer;
  int _cooldownRemaining = 0;

  static const int _maxAttempts = 3;
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

  // =========================================================
  // REMEMBER ME
  // =========================================================

  Future<void> _loadRememberMe() async {
    final data = await _authService.loadRememberMe();

    if (!mounted) return;

    setState(() {
      _rememberMe = data.remembered;

      if (data.remembered && data.identity.isNotEmpty) {
        _identityController.text = data.identity;
      }
    });
  }

  // =========================================================
  // AUTO LOGIN
  // =========================================================

  Future<void> _checkAutoLogin() async {
    final result = await _authService.tryAutoLogin();

    if (!mounted) return;

    if (result != null && result.success) {
      _showSuccess("Selamat datang kembali, ${result.nama}!");
      _navigateToDashboard(result.role);
    }
  }

  // =========================================================
  // RATE LIMIT
  // =========================================================

  bool get _isBlocked => _cooldownRemaining > 0;

  void _startCooldown() {
    _cooldownRemaining = _coolDownSeconds;

    _coolDownTimer?.cancel();

    _coolDownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _cooldownRemaining--;
        });

        if (_cooldownRemaining <= 0) {
          timer.cancel();

          setState(() {
            _cooldownRemaining = 0;
            _loginAttempts = 0;
          });
        }
      },
    );
  }

  void _resetCooldown() {
    _coolDownTimer?.cancel();

    setState(() {
      _cooldownRemaining = 0;
      _loginAttempts = 0;
    });
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final formError = _authService.validateLoginForm(
      _identityController.text,
      _passwordController.text,
    );

    if (formError != null) {
      _showError(formError);
      return;
    }

    if (_isBlocked) {
      _showError(
        "Terlalu banyak percobaan. Tunggu $_cooldownRemaining detik.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _loginAttempts++;
    });

    try {
      final result = await _authService.login(
        identity: _identityController.text.trim(),
        password: _passwordController.text,
        sessionId: _authService.generateSessionId(),
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        _resetCooldown();

        _showSuccess(
          "Selamat datang, ${result.nama}!",
        );

        _navigateToDashboard(result.role);
      } else {
        if (result.errorCode == 'network-request-failed' ||
            result.errorCode == 'timeout' ||
            result.errorCode == 'unknown') {
          _loginAttempts--;
        }

        setState(() {
          _errorMessage = result.errorMessage;
        });

        if (_loginAttempts >= _maxAttempts) {
          _startCooldown();

          _showError(
            "Terlalu banyak percobaan. Akun dikunci selama $_coolDownSeconds detik.",
          );
        } else {
          final remaining = _maxAttempts - _loginAttempts;

          _showError(
            "${result.errorMessage}\nSisa percobaan: $remaining kali.",
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loginAttempts--;
        _errorMessage = "Terjadi kesalahan sistem.";
      });

      debugPrint("Login Error: $e");

      _showError(
        "Terjadi kesalahan sistem. Silakan coba lagi.",
      );
    }
  }

  // =========================================================
  // NAVIGASI
  // =========================================================

  void _navigateToDashboard(String role) {
    final path = _authService.getDashboardPath(role);
    context.go(path);
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.softRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final isSmallHeight =
        MediaQuery.of(context).size.height < 750;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),

                    SizedBox(
                      height: isSmallHeight ? 10 : 16,
                    ),

                    _buildIllustration(isSmallHeight),

                    SizedBox(
                      height: isSmallHeight ? 10 : 16,
                    ),

                    _buildTitle(),

                    SizedBox(
                      height: isSmallHeight ? 14 : 20,
                    ),

                    _buildLoginForm(),

                    const SizedBox(height: 16),

                    _buildFooter(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.primaryBlue,
            ),
          ),
        ),

        const Spacer(),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.withAlpha(70),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.security_rounded,
                color: Colors.green,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                "Login Aman",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ILLUSTRATION
  // =========================================================

  Widget _buildIllustration(bool isSmallHeight) {
    return SizedBox(
      height: isSmallHeight ? 70 : 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.login_rounded,
            size: isSmallHeight ? 60 : 80,
            color: AppColors.primaryBlue.withAlpha(70),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
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

  // =========================================================
  // TITLE
  // =========================================================

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          "Selamat Datang Kembali 👋",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          "Masuk untuk mengakses sistem pengajuan lembur",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LOGIN FORM
  // =========================================================

  Widget _buildLoginForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(70),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildFormHeader(),

            const SizedBox(height: 18),

            if (_isBlocked)
              _buildCooldownBanner(),

            if (_errorMessage.isNotEmpty && !_isBlocked)
              _buildErrorMessage(),

            _buildIdentityField(),

            const SizedBox(height: 14),

            _buildPasswordField(),

            const SizedBox(height: 8),

            _buildRememberAndForgot(),

            const SizedBox(height: 18),

            _buildLoginButton(),

            const SizedBox(height: 14),

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
          "LOGIN",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          "Masukkan kredensial Anda",
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildCooldownBanner() {
    final progress = _cooldownRemaining > 0
        ? 1.0 - (_cooldownRemaining / _coolDownSeconds)
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentOrange.withAlpha(70),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: AppColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Terlalu banyak percobaan gagal",
                  style: GoogleFonts.poppins(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  AppColors.accentOrange.withAlpha(40),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                AppColors.accentOrange,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Silakan tunggu $_cooldownRemaining detik lagi...",
            style: GoogleFonts.poppins(
              color: AppColors.accentOrange,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.softRed.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.softRed.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.softRed,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: AppColors.softRed,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FIELD
  // =========================================================

  Widget _buildIdentityField() {
    return _fieldColumn(
      "Email atau Nomor HP",
      _identityController,
      Icons.person_outline_rounded,
      "contoh@email.com",
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Wajib diisi';
        }

        if (v.contains('@')) {
          return _authService.validateEmail(v);
        }

        return _authService.validatePhone(v);
      },
    );
  }

  Widget _buildPasswordField() {
    return _fieldColumn(
      "Password",
      _passwordController,
      Icons.lock_outline_rounded,
      "Masukkan password",
      obscure: _obscurePassword,
      validator: (v) => _authService.validatePassword(v),
      suffix: IconButton(
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off
              : Icons.visibility,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        Row(
          children: [
            Transform.scale(
              scale: 0.75,
              child: Checkbox(
                value: _rememberMe,
                activeColor: Colors.white,
                checkColor: AppColors.primaryBlue,
                onChanged: (v) {
                  setState(() {
                    _rememberMe = v ?? false;
                  });
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
            context.push(
              '/reset-password',
              extra: _identityController.text.trim(),
            );
          },
          child: Text(
            "Lupa Password?",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LOGIN BUTTON
  // =========================================================

  Widget _buildLoginButton() {
    final isDisabled = _isLoading || _isBlocked;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDisabled ? Colors.grey.shade400 : Colors.white,
          foregroundColor: AppColors.primaryBlue,
          elevation: isDisabled ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryBlue,
                ),
              )
            : _isBlocked
                ? Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Terkunci $_cooldownRemaining detik",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        "LOGIN",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                    ],
                  ),
      ),
    );
  }

  // =========================================================
  // REGISTER
  // =========================================================

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Belum punya akun?",
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),

        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            "Daftar Sekarang",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 16,
              color: AppColors.primaryBlue,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Login Aman Terenkripsi 🔒",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),

                Text(
                  "3x gagal → terkunci 30 detik",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HELPER
  // =========================================================

  Widget _fieldColumn(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithAsterisk(label),

        const SizedBox(height: 4),

        _buildInputField(
          controller: controller,
          icon: icon,
          hint: hint,
          obscure: obscure,
          validator: validator,
          suffix: suffix,
        ),
      ],
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
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: Colors.white54,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withAlpha(20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.white54,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.white,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.softRed,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.softRed,
          ),
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 10,
          color: AppColors.softRed,
        ),
      ),
    );
  }
}