// screens/reset_password_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

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
  static const Color primaryBlue = Color(0xFF1E3C72);
  static const Color softRed = Color(0xFFE74C3C);
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
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

  // ================= SESSION ID =================
  void _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'session_$timestamp${random.nextInt(10000)}';
  }

  // ================= TAMBAH KE AUDIT TRAIL =================
  Future<void> _addToAuditTrail({
    required String action,
    required String email,
    String? uid,
  }) async {
    try {
      final now = DateTime.now();
      
      // Cari user berdasarkan email
      if (uid == null) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          uid = userQuery.docs.first.id;
        } else {
          debugPrint('User not found for email: $email');
          return;
        }
      }
      
      // Update audit trail
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'audit_trail': FieldValue.arrayUnion([
          {
            "action": action, // "reset_password_request" atau "reset_password_complete"
            "timestamp": FieldValue.serverTimestamp(),
            "session_id": _sessionId,
            "email": email,
          }
        ]),
      });
      
      debugPrint('Audit trail updated: $action for $email');
    } catch (e) {
      debugPrint('Error adding to audit trail: $e');
      // Jangan gagalkan proses utama jika audit trail gagal
    }
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _errorMessage = "";
    });

    try {
      final email = _emailController.text.trim();
      
      // Kirim email reset password via Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );
      
      // Catat ke audit trail - PERMINTAAN RESET
      await _addToAuditTrail(
        action: 'reset_password_request',
        email: email,
      );
      
      setState(() {
        _emailSent = true;
      });
      
      // Tampilkan notifikasi sukses
      _showSuccessSnackBar("Link reset password telah dikirim ke $email");
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan. Silakan coba lagi.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ================= FITUR KONFIRMASI MANUAL =================
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi Reset Password',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda sudah menyelesaikan langkah berikut?',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildConfirmationStep(
                icon: Icons.email_rounded,
                text: 'Membuka email reset password',
                isCompleted: true,
              ),
              const SizedBox(height: 12),
              _buildConfirmationStep(
                icon: Icons.link_rounded,
                text: 'Mengklik link reset di email',
                isCompleted: true,
              ),
              const SizedBox(height: 12),
              _buildConfirmationStep(
                icon: Icons.password_rounded,
                text: 'Membuat password baru',
                isCompleted: true,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jika sudah melakukan langkah di atas, klik "Sudah, Lanjut Login" untuk masuk dengan password baru.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blue[800],
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
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: Text(
                'Belum Selesai',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog
                
                // Catat ke audit trail - RESET SELESAI
                await _addToAuditTrail(
                  action: 'reset_password_complete',
                  email: _emailController.text.trim(),
                );
                
                _showSuccessAndRedirect(); // Tampilkan sukses dan redirect
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Sudah, Lanjut Login',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationStep({
    required IconData icon,
    required String text,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green.withAlpha(25) : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isCompleted ? Colors.green : Colors.grey[400],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isCompleted ? Colors.black87 : Colors.grey[500],
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        if (isCompleted)
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
      ],
    );
  }

  void _showSuccessAndRedirect() {
    // Tampilkan dialog sukses
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Password Berhasil Diubah!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan login dengan password baru Anda',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Tutup dialog
                    Navigator.pop(context); // Kembali ke login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Ke Halaman Login',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-not-found':
        return 'Email tidak terdaftar dalam sistem';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan. Tunggu beberapa saat';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet';
      default:
        return 'Gagal mengirim link reset. Silakan coba lagi';
    }
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _returnToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Reset Password",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _returnToLogin,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Icon dan Judul
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryBlue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                    size: 60,
                    color: _emailSent ? Colors.green : primaryBlue,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                _emailSent ? "Cek Email Anda! 📧" : "Lupa Password?",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _emailSent ? Colors.green : primaryBlue,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                _emailSent 
                    ? "Kami telah mengirimkan link reset password. Setelah mengubah password, klik tombol di bawah untuk konfirmasi."
                    : "Masukkan email yang terdaftar. Kami akan mengirimkan link untuk mereset password Anda.",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form atau Tombol Konfirmasi
              if (!_emailSent) ...[
                _buildForm(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ] else ...[
                _buildConfirmationUI(),
              ],
              
              const SizedBox(height: 32),
              
              // Informasi Tambahan
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
            Text(
              "Email",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: "contoh@email.com",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.email_outlined, color: primaryBlue, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryBlue, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: softRed, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: softRed, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(value)) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
        // Tombol Kirim Link
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Kirim Link Reset",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tombol Kembali
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _returnToLogin,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Kembali ke Login",
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
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
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Email terkirim ke:",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _emailController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Setelah Anda selesai membuat password baru melalui email,",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "klik tombol di bawah untuk konfirmasi",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tombol Konfirmasi Reset Selesai
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Saya Sudah Reset Password",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Tombol Kirim Ulang
        TextButton(
          onPressed: _sendResetLink,
          child: Text(
            "Kirim ulang email",
            style: GoogleFonts.poppins(
              color: Colors.green[700],
              decoration: TextDecoration.underline,
              fontSize: 12,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Tombol Kembali
        TextButton(
          onPressed: _returnToLogin,
          child: Text(
            "Kembali ke Login",
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                "Langkah Reset Password",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(1, "Masukkan email dan klik 'Kirim Link Reset'"),
          const SizedBox(height: 8),
          _buildStep(2, "Buka email Anda (cek juga folder spam)"),
          const SizedBox(height: 8),
          _buildStep(3, "Klik link reset password di email"),
          const SizedBox(height: 8),
          _buildStep(4, "Buat password baru di halaman browser"),
          const SizedBox(height: 8),
          _buildStep(5, "Kembali ke aplikasi dan klik 'Saya Sudah Reset Password'"),
          const SizedBox(height: 8),
          _buildStep(6, "Konfirmasi dan login dengan password baru"),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.blue[800],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}