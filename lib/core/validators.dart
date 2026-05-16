// lib/core/validators.dart
class Validators {
  // ==================== NAMA LENGKAP ====================
  static String? validateNama(String? value) {
    if (value == null || value.isEmpty) return "Nama lengkap wajib diisi";
    if (value.length < 3) return "Nama terlalu pendek (min. 3 karakter)";
    if (value.length > 100) return "Nama terlalu panjang (maks. 100 karakter)";
    if (!RegExp(r"^[a-zA-Z\s\.']+$").hasMatch(value)) {
      return "Nama hanya boleh mengandung huruf, spasi, titik, dan apostrof";
    }
    return null;
  }

  // ==================== EMAIL ====================
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email wajib diisi";

    // PERBAIKAN: Pake raw string (r) + petik dua biar aman
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$"
    );

    if (!emailRegex.hasMatch(value)) {
      return "Format email tidak valid";
    }

    return null;
  }

  // ==================== NOMOR HP ====================
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Nomor HP wajib diisi";

    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanValue.length < 10 || cleanValue.length > 13) {
      return "Nomor HP harus 10-13 digit";
    }

    if (!cleanValue.startsWith('8')) {
      return "Nomor harus diawali dengan 8 (contoh: 81234567890)";
    }

    return null;
  }

  // ==================== PASSWORD ====================
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password wajib diisi";
    if (value.length < 8) return "Minimal 8 karakter";
    if (!value.contains(RegExp(r'[A-Z]'))) return "Harus ada minimal 1 huruf besar (A-Z)";
    if (!value.contains(RegExp(r'[a-z]'))) return "Harus ada minimal 1 huruf kecil (a-z)";
    if (!value.contains(RegExp(r'[0-9]'))) return "Harus ada minimal 1 angka (0-9)";

    return null;
  }

  // ==================== IDENTITY (EMAIL / NOMOR HP) ====================
  static String? validateIdentity(String? value) {
    if (value == null || value.isEmpty) {
      return "Email atau nomor HP wajib diisi";
    }

    final isEmail = value.contains('@');
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    final isPhone = cleanPhone.length >= 10 && cleanPhone.length <= 13 && cleanPhone.startsWith('8');

    // Kalau bukan email & bukan nomor HP valid
    if (!isEmail && !isPhone) {
      return "Masukkan email valid atau nomor HP (diawali 8, 10-13 digit)";
    }

    // Kalau email, validasi format email
    if (isEmail) {
      // PERBAIKAN: Pake raw string (r) + petik dua
      final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$"
      );
      if (!emailRegex.hasMatch(value)) {
        return "Format email tidak valid";
      }
    }

    // Kalau nomor HP, validasi format nomor HP
    if (isPhone && !isEmail) {
      if (cleanPhone.length < 10 || cleanPhone.length > 13) {
        return "Nomor HP harus 10-13 digit";
      }
      if (!cleanPhone.startsWith('8')) {
        return "Nomor HP harus diawali dengan 8 (contoh: 81234567890)";
      }
    }

    return null;
  }

  // ==================== KONFIRMASI PASSWORD ====================
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return "Konfirmasi password wajib diisi";
    if (value != password) return "Password tidak cocok";
    return null;
  }

  // ==================== CAPTCHA ====================
  static String? validateCaptcha(String? value) {
    if (value == null || value.isEmpty) return "Jawaban captcha wajib diisi";
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return "Jawaban harus berupa angka";
    return null;
  }
}