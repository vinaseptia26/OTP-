import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
import '../core/services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _emailSent = false;
  String _errorMessage = "";
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
    _generateSessionId();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'session_$timestamp${random.nextInt(10000)}';
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = "";
    });

    try {
      final result = await _authService.sendResetPasswordEmail(
        email: _emailController.text.trim(),
        sessionId: _sessionId,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() => _emailSent = true);
        _showSnackBar("Link reset password telah dikirim!", isSuccess: true);
      } else {
        setState(() => _errorMessage = result.errorMessage);
      }
    } catch (e) {
      setState(() => _errorMessage = "Terjadi kesalahan. Silakan coba lagi.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmResetDone() async {
    await _authService.confirmResetPassword(
      email: _emailController.text.trim(),
      sessionId: _sessionId,
    );

    if (!mounted) return;
    _showSuccessDialog();
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.primaryBlue : AppColors.softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Konfirmasi Reset Password',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda sudah menyelesaikan langkah berikut?',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(height: 16),
              _stepItem(Icons.email_rounded, 'Membuka email reset password', true),
              const SizedBox(height: 12),
              _stepItem(Icons.link_rounded, 'Mengklik link reset di email', true),
              const SizedBox(height: 12),
              _stepItem(Icons.password_rounded, 'Membuat password baru', true),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jika sudah, klik "Sudah, Lanjut Login" untuk masuk dengan password baru.',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: Text('Belum Selesai', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmResetDone();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              child: Text('Sudah, Lanjut Login',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Widget _stepItem(IconData icon, String text, bool done) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: done ? AppColors.primaryBlue.withAlpha(25) : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: done ? AppColors.primaryBlue : Colors.grey[400]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: done ? Colors.black87 : Colors.grey[500],
              fontWeight: done ? FontWeight.w500 : FontWeight.normal,
            )),
        ),
        if (done) const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 18),
      ],
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 50),
              ),
              const SizedBox(height: 20),
              Text('Password Berhasil Diubah!',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              const SizedBox(height: 8),
              Text('Silakan login dengan password baru Anda',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                  child: Text('Ke Halaman Login',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text("Reset Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Icon & Judul
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _emailSent ? "Cek Email Anda! 📧" : "Lupa Password?",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _emailSent
                    ? "Kami telah mengirimkan link reset password. Setelah mengubah password, klik tombol di bawah untuk konfirmasi."
                    : "Masukkan email yang terdaftar. Kami akan mengirimkan link untuk mereset password Anda.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              // Form / Konfirmasi
              if (!_emailSent) ...[
                _buildForm(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ] else ...[
                _buildConfirmationUI(),
              ],
              const SizedBox(height: 32),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: "contoh@email.com",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryBlue, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.softRed)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.softRed, width: 2)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: Validators.validateEmail,
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.softRed.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.softRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage,
                        style: GoogleFonts.poppins(color: AppColors.softRed, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            child: _loading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text("Kirim Link Reset",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 54,
          child: OutlinedButton(
            onPressed: _goBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Kembali ke Login",
                style: GoogleFonts.poppins(color: AppColors.primaryBlue, fontWeight: FontWeight.w500, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Email terkirim ke:",
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primaryBlue))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                ),
                child: Text(_emailController.text,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ),
              const SizedBox(height: 16),
              Text("Setelah Anda selesai membuat password baru melalui email,",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primaryBlue.withAlpha(180))),
              const SizedBox(height: 8),
              Text("klik tombol di bawah untuk konfirmasi",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, size: 20),
                const SizedBox(width: 8),
                Text("Saya Sudah Reset Password",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _sendResetLink,
          child: Text("Kirim ulang email",
              style: GoogleFonts.poppins(color: AppColors.primaryBlue, decoration: TextDecoration.underline, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _goBack,
          child: Text("Kembali ke Login",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text("Langkah Reset Password",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _infoStep(1, "Masukkan email dan klik 'Kirim Link Reset'"),
          const SizedBox(height: 8),
          _infoStep(2, "Buka email Anda (cek juga folder spam)"),
          const SizedBox(height: 8),
          _infoStep(3, "Klik link reset password di email"),
          const SizedBox(height: 8),
          _infoStep(4, "Buat password baru di halaman browser"),
          const SizedBox(height: 8),
          _infoStep(5, "Kembali ke aplikasi dan klik 'Saya Sudah Reset Password'"),
          const SizedBox(height: 8),
          _infoStep(6, "Konfirmasi dan login dengan password baru"),
        ],
      ),
    );
  }

  Widget _infoStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
          child: Center(
            child: Text(number.toString(),
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(color: AppColors.primaryBlue.withAlpha(200), fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}