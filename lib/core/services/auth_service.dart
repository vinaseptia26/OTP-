// lib/core/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DASHBOARD
import '../../dashboard/manager/manager_dashboard.dart';
import '../../dashboard/mitra/mitra_dashboard.dart';
import '../../dashboard/pengawas/pengawas_dashboard.dart';
import '../../dashboard/superadmin/superadmin_dashboard.dart';

// SCREEN
import '../../screens/login_screen.dart';
import '../../screens/welcome_screen.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // AUTH CHECK
  // =========================================================

  Future<Widget> checkAuthAndGetDestination() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return const WelcomeScreen();
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await signOut();
        return const LoginScreen();
      }

      final data = doc.data() ?? {};

      final role = (data['role'] ?? '').toString().toLowerCase();
      final status = (data['status_akun'] ?? '').toString().toLowerCase();

      if (status != 'active') {
        await signOut();
        return const LoginScreen();
      }

      return getDashboardForRole(role);
    } catch (e) {
      debugPrint('checkAuthAndGetDestination error: $e');
      await signOut();
      return const LoginScreen();
    }
  }

  // =========================================================
  // LOGIN
  // =========================================================

  LoginResult? _lastResult;

  LoginResult get lastResult => _lastResult ?? LoginResult(success: false);

  Future<LoginResult> login({
    required String identity,
    required String password,
    required String sessionId,
    required bool rememberMe,
  }) async {
    try {
      String email = identity.trim();

      // LOGIN VIA NOMOR HP
      if (!identity.contains('@')) {
        final cleanPhone = identity.replaceAll(RegExp(r'[^\d]'), '');

        final phoneQuery = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();

        if (phoneQuery.docs.isEmpty) {
          return _result(
            false,
            error: 'Email / nomor HP tidak ditemukan',
            code: 'user-not-found',
          );
        }

        email = phoneQuery.docs.first.data()['email'];
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout');
        },
      );

      final user = credential.user;

      if (user == null) {
        return _result(false, error: 'User tidak ditemukan', code: 'user-null');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await signOut();
        return _result(false, error: 'Data user tidak ditemukan', code: 'data-not-found');
      }

      final userData = userDoc.data() ?? {};

      // VALIDASI STATUS
      if (userData['account_locked'] == true) {
        await signOut();
        return _result(false, error: 'Akun diblokir', code: 'account-locked');
      }

      if (userData['status_akun'] != 'active') {
        await signOut();
        return _result(false, error: 'Akun tidak aktif', code: 'account-inactive');
      }

      await _firestore.collection('users').doc(user.uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'login_attempts': 0,
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'login',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
          }
        ]),
      });

      // REMEMBER ME
      if (rememberMe) {
        await _saveRememberMe(identity);
      } else {
        await _clearRememberMe();
      }

      return _result(
        true,
        role: userData['role'] ?? '',
        nama: userData['nama_lengkap'] ?? '',
        userData: userData,
      );
    } on FirebaseAuthException catch (e) {
      return _result(false, error: _getFirebaseErrorMessage(e.code), code: e.code);
    } on TimeoutException {
      return _result(false, error: 'Koneksi timeout', code: 'timeout');
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return _result(false, error: 'Terjadi kesalahan sistem', code: 'unknown');
    }
  }

  // =========================================================
  // AUTO LOGIN
  // =========================================================

  Future<LoginResult?> tryAutoLogin() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        return null;
      }

      final doc = await _firestore.collection('users').doc(currentUser.uid).get();

      if (!doc.exists) {
        await signOut();
        return null;
      }

      final data = doc.data() ?? {};

      if (data['status_akun'] != 'active') {
        await signOut();
        return null;
      }

      final sessionId = _generateSessionId();

      await _firestore.collection('users').doc(currentUser.uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'login_attempts': 0,
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'auto_login',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
          }
        ]),
      });

      return _result(
        true,
        role: data['role'] ?? '',
        nama: data['nama_lengkap'] ?? '',
        userData: data,
      );
    } catch (e) {
      debugPrint('AUTO LOGIN ERROR: $e');
      await signOut();
      return null;
    }
  }

  // =========================================================
  // 🔥 CREATE USER (FIXED - ADMIN TETAP LOGIN!)
  // =========================================================

  Future<CreateUserResult> createUser({
    required String nama,
    required String email,
    required String phone,
    required String password,
    required String role,
    required String fungsi,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;

      if (currentAdmin == null) {
        return CreateUserResult(
          success: false,
          message: 'Admin belum login',
        );
      }

      // CEK DUPLIKAT EMAIL
      final emailCheck = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        return CreateUserResult(
          success: false,
          message: 'Email sudah digunakan',
        );
      }

      // CEK DUPLIKAT NOMOR HP
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final phoneCheck = await _firestore
          .collection('users')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (phoneCheck.docs.isNotEmpty) {
        return CreateUserResult(
          success: false,
          message: 'Nomor HP sudah digunakan',
        );
      }

      // 🔥 Buat user via secondary FirebaseApp
      // Admin TETAP LOGIN karena pakai secondary instance
      String newUserUid;

      try {
        final FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );

        final FirebaseAuth secondaryAuth =
            FirebaseAuth.instanceFor(app: secondaryApp);

        final UserCredential credential =
            await secondaryAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password.trim(),
        );

        newUserUid = credential.user!.uid;

        // Bersihkan secondary auth
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      } catch (e) {
        debugPrint('Secondary auth error: $e');
        return CreateUserResult(
          success: false,
          message: 'Gagal membuat akun. Silakan coba lagi.',
        );
      }

      final sessionId = _generateSessionId();
      final now = Timestamp.now();

      // Simpan data user ke Firestore
      await _firestore.collection('users').doc(newUserUid).set({
        'id': newUserUid,
        'nama_lengkap': nama.trim(),
        'email': email.trim().toLowerCase(),
        'email_hash': _hashData(email.trim().toLowerCase()),
        'phone': cleanPhone,
        'phone_hash': _hashData(cleanPhone),
        'role': role.toLowerCase(),
        'fungsi': fungsi,
        'fungsi_label': _getFungsiLabel(fungsi),
        'status_akun': 'active',
        'is_verified': true,
        'account_locked': false,
        'login_attempts': 0,
        'security': {
          'session_id': sessionId,
          'registered_at': now,
          'security_level': 'standard',
          'created_by': currentAdmin.uid,
          'created_by_email': currentAdmin.email,
        },
        'terms_accepted': true,
        'terms_accepted_at': now,
        'terms_version': '2.0.0',
        'created_at': now,
        'updated_at': now,
        'last_login': null,
        'audit_trail': [
          {
            'action': 'admin_created',
            'timestamp': now,
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
            'admin_email': currentAdmin.email,
          }
        ],
      });

      // System log
      await _firestore.collection('system_logs').add({
        'type': 'user_created',
        'admin_id': currentAdmin.uid,
        'admin_email': currentAdmin.email,
        'target_user_id': newUserUid,
        'target_user_email': email.trim().toLowerCase(),
        'target_user_role': role.toLowerCase(),
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Admin membuat user baru: $nama (${role.toUpperCase()})',
      });

      return CreateUserResult(
        success: true,
        message: 'User $nama berhasil dibuat sebagai ${role.toUpperCase()}',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('CREATE USER AUTH ERROR: ${e.code}');
      return CreateUserResult(
        success: false,
        message: _getCreateUserErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('CREATE USER ERROR: $e');
      return CreateUserResult(
        success: false,
        message: 'Terjadi kesalahan sistem',
      );
    }
  }

  // =========================================================
  // GET ALL USERS
  // =========================================================
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('GET ALL USERS ERROR: $e');
      throw _handleFirestoreError(e);
    }
  }

  // =========================================================
  // GET USER BY ID
  // =========================================================
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('GET USER BY ID ERROR: $e');
      throw _handleFirestoreError(e);
    }
  }

  // =========================================================
  // UPDATE USER
  // =========================================================
  Future<UpdateUserResult> updateUser({
    required String userId,
    required String nama,
    required String email,
    required String phone,
    String? password,
    required String role,
    required String fungsi,
    required String sessionId,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return UpdateUserResult(
          success: false,
          message: 'Admin belum login',
        );
      }

      final userRef = _firestore.collection('users').doc(userId);
      final existingDoc = await userRef.get();

      if (!existingDoc.exists) {
        return UpdateUserResult(
          success: false,
          message: 'User tidak ditemukan',
        );
      }

      final currentData = existingDoc.data()!;

      final updateData = <String, dynamic>{};

      if (nama.isNotEmpty && nama != currentData['nama_lengkap']) {
        updateData['nama_lengkap'] = nama.trim();
      }

      if (email.isNotEmpty && email.toLowerCase() != currentData['email']) {
        final emailCheck = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();

        if (emailCheck.docs.isNotEmpty && emailCheck.docs.first.id != userId) {
          return UpdateUserResult(
            success: false,
            message: 'Email sudah digunakan oleh user lain',
          );
        }
        updateData['email'] = email.toLowerCase();
        updateData['email_hash'] = _hashData(email.toLowerCase());
      }

      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone != _cleanPhone(currentData['phone'] ?? '')) {
        final phoneCheck = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();

        if (phoneCheck.docs.isNotEmpty && phoneCheck.docs.first.id != userId) {
          return UpdateUserResult(
            success: false,
            message: 'Nomor HP sudah digunakan oleh user lain',
          );
        }
        updateData['phone'] = cleanPhone;
        updateData['phone_hash'] = _hashData(cleanPhone);
      }

      if (role.isNotEmpty && role.toLowerCase() != currentData['role']) {
        updateData['role'] = role.toLowerCase();
      }

      if (fungsi.isNotEmpty && fungsi != currentData['fungsi']) {
        updateData['fungsi'] = fungsi;
        updateData['fungsi_label'] = _getFungsiLabel(fungsi);
      }

      if (password != null && password.isNotEmpty) {
        try {
          await _auth.sendPasswordResetEmail(email: currentData['email']);
        } catch (e) {
          debugPrint('PASSWORD RESET EMAIL ERROR: $e');
        }
      }

      updateData['updated_at'] = FieldValue.serverTimestamp();
      updateData['audit_trail'] = FieldValue.arrayUnion([
        {
          'action': 'user_updated_by_admin',
          'timestamp': Timestamp.now(),
          'session_id': sessionId,
          'admin_id': currentAdmin.uid,
        }
      ]);

      await userRef.update(updateData);

      await _firestore.collection('system_logs').add({
        'type': 'user_updated',
        'admin_id': currentAdmin.uid,
        'target_user_id': userId,
        'target_user_email': currentData['email'],
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User diperbarui: $nama',
      });

      return UpdateUserResult(
        success: true,
        message: 'User berhasil diperbarui',
      );
    } catch (e) {
      debugPrint('UPDATE USER ERROR: $e');
      return UpdateUserResult(
        success: false,
        message: 'Gagal memperbarui user: ${e.toString()}',
      );
    }
  }

  // =========================================================
  // DELETE USER (HARD DELETE)
  // =========================================================
  Future<DeleteUserResult> deleteUser({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return DeleteUserResult(
          success: false,
          message: 'Admin belum login',
        );
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return DeleteUserResult(
          success: false,
          message: 'User tidak ditemukan',
        );
      }

      final userData = userDoc.data()!;

      if (userId == currentAdmin.uid) {
        return DeleteUserResult(
          success: false,
          message: 'Tidak dapat menghapus akun sendiri',
        );
      }

      await _firestore.collection('system_logs').add({
        'type': 'user_deleted',
        'admin_id': currentAdmin.uid,
        'target_user_id': userId,
        'target_user_email': userData['email'],
        'target_user_data': userData,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User dihapus: ${userData['nama_lengkap']}',
      });

      await _firestore.collection('users').doc(userId).delete();

      return DeleteUserResult(
        success: true,
        message: 'User berhasil dihapus',
      );
    } catch (e) {
      debugPrint('DELETE USER ERROR: $e');
      return DeleteUserResult(
        success: false,
        message: 'Gagal menghapus user: ${e.toString()}',
      );
    }
  }

  // =========================================================
  // TOGGLE USER STATUS
  // =========================================================
  Future<ToggleStatusResult> toggleUserStatus({
    required String userId,
    required String newStatus,
    required String sessionId,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return ToggleStatusResult(
          success: false,
          message: 'Admin belum login',
        );
      }

      const validStatus = ['active', 'inactive', 'blocked'];
      if (!validStatus.contains(newStatus)) {
        return ToggleStatusResult(
          success: false,
          message: 'Status tidak valid',
        );
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return ToggleStatusResult(
          success: false,
          message: 'User tidak ditemukan',
        );
      }

      if (userId == currentAdmin.uid) {
        return ToggleStatusResult(
          success: false,
          message: 'Tidak dapat mengubah status akun sendiri',
        );
      }

      final currentStatus = userDoc.data()!['status_akun'] ?? 'active';

      await _firestore.collection('users').doc(userId).update({
        'status_akun': newStatus,
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'status_changed_by_admin',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
            'old_status': currentStatus,
            'new_status': newStatus,
          }
        ]),
      });

      await _firestore.collection('system_logs').add({
        'type': 'user_status_changed',
        'admin_id': currentAdmin.uid,
        'target_user_id': userId,
        'old_status': currentStatus,
        'new_status': newStatus,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Status user diubah dari $currentStatus menjadi $newStatus',
      });

      String message;
      switch (newStatus) {
        case 'active':
          message = 'User berhasil diaktifkan';
          break;
        case 'inactive':
          message = 'User berhasil dinonaktifkan';
          break;
        case 'blocked':
          message = 'User berhasil diblokir';
          break;
        default:
          message = 'Status user berhasil diubah';
      }

      return ToggleStatusResult(success: true, message: message);
    } catch (e) {
      debugPrint('TOGGLE STATUS ERROR: $e');
      return ToggleStatusResult(
        success: false,
        message: 'Gagal mengubah status user',
      );
    }
  }

  // =========================================================
  // BULK STATUS CHANGE
  // =========================================================
  Future<BulkStatusResult> bulkStatusChange({
    required List<String> userIds,
    required String newStatus,
    required String sessionId,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return BulkStatusResult(
          success: false,
          message: 'Admin belum login',
        );
      }

      if (userIds.isEmpty) {
        return BulkStatusResult(
          success: false,
          message: 'Tidak ada user yang dipilih',
        );
      }

      const validStatus = ['active', 'inactive', 'blocked'];
      if (!validStatus.contains(newStatus)) {
        return BulkStatusResult(
          success: false,
          message: 'Status tidak valid',
        );
      }

      final batch = _firestore.batch();
      final timestamp = Timestamp.now();

      for (var userId in userIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'status_akun': newStatus,
          'audit_trail': FieldValue.arrayUnion([
            {
              'action': 'bulk_status_change_by_admin',
              'timestamp': timestamp,
              'session_id': sessionId,
              'admin_id': currentAdmin.uid,
              'new_status': newStatus,
            }
          ]),
        });
      }

      await batch.commit();

      await _firestore.collection('system_logs').add({
        'type': 'bulk_status_change',
        'admin_id': currentAdmin.uid,
        'affected_count': userIds.length,
        'new_status': newStatus,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Bulk status change to $newStatus for ${userIds.length} users',
      });

      return BulkStatusResult(
        success: true,
        message: 'Status ${userIds.length} user berhasil diubah',
        affectedCount: userIds.length,
      );
    } catch (e) {
      debugPrint('BULK STATUS ERROR: $e');
      return BulkStatusResult(
        success: false,
        message: 'Gagal mengubah status user secara massal',
      );
    }
  }

  // =========================================================
  // SEND PASSWORD RESET EMAIL (ADMIN TRIGGERED)
  // =========================================================
  Future<ResetPasswordResult> adminResetPassword({
    required String email,
    required String sessionId,
  }) async {
    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return ResetPasswordResult(
          success: false,
          errorMessage: 'Admin belum login',
        );
      }

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return ResetPasswordResult(
          success: false,
          errorMessage: 'Email tidak ditemukan',
        );
      }

      final uid = query.docs.first.id;
      final userData = query.docs.first.data();

      await _auth.sendPasswordResetEmail(email: email.trim());

      await _firestore.collection('users').doc(uid).update({
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'password_reset_by_admin',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
          }
        ]),
      });

      await _firestore.collection('system_logs').add({
        'type': 'password_reset_by_admin',
        'admin_id': currentAdmin.uid,
        'target_user_id': uid,
        'target_user_email': email,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Admin mereset password user: ${userData['nama_lengkap']}',
      });

      return ResetPasswordResult(success: true, errorMessage: '');
    } on FirebaseAuthException catch (e) {
      return ResetPasswordResult(
        success: false,
        errorMessage: _getResetPasswordErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('ADMIN RESET PASSWORD ERROR: $e');
      return ResetPasswordResult(
        success: false,
        errorMessage: 'Gagal mengirim email reset password',
      );
    }
  }

  // =========================================================
  // RESET PASSWORD (USER SELF SERVICE)
  // =========================================================
  Future<ResetPasswordResult> sendResetPasswordEmail({
    required String email,
    required String sessionId,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());

      await _addResetAuditTrail(
        action: 'reset_password_request',
        email: email,
        sessionId: sessionId,
      );

      return ResetPasswordResult(success: true);
    } on FirebaseAuthException catch (e) {
      return ResetPasswordResult(
        success: false,
        errorMessage: _getResetPasswordErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('RESET PASSWORD ERROR: $e');
      return ResetPasswordResult(
        success: false,
        errorMessage: 'Terjadi kesalahan',
      );
    }
  }

  Future<void> confirmResetPassword({
    required String email,
    required String sessionId,
  }) async {
    await _addResetAuditTrail(
      action: 'reset_password_complete',
      email: email,
      sessionId: sessionId,
    );
  }

  // =========================================================
  // REMEMBER ME
  // =========================================================
  Future<RememberMeData> loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return RememberMeData(
        remembered: prefs.getBool('remember_me') ?? false,
        identity: prefs.getString('saved_identity') ?? '',
      );
    } catch (e) {
      return RememberMeData(remembered: false, identity: '');
    }
  }

  Future<void> _saveRememberMe(String identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_identity', identity);
    } catch (e) {
      debugPrint('SAVE REMEMBER ME ERROR: $e');
    }
  }

  Future<void> _clearRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_identity');
      await prefs.setBool('remember_me', false);
    } catch (e) {
      debugPrint('CLEAR REMEMBER ME ERROR: $e');
    }
  }

  // =========================================================
  // DASHBOARD
  // =========================================================
  Widget getDashboardForRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const SuperAdminDashboard();
      case 'manager':
        return const ManagerDashboard();
      case 'pengawas':
        return const PengawasDashboard();
      case 'mitra':
        return const MitraDashboard();
      default:
        return const WelcomeScreen();
    }
  }

  // =========================================================
  // SIGN OUT
  // =========================================================
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // =========================================================
  // HELPER
  // =========================================================
  String _generateSessionId() {
    final random = Random();
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999999)}';
  }

  String _hashData(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
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
        return fungsi.toUpperCase();
    }
  }

  Exception _handleFirestoreError(dynamic e) {
    if (e.toString().contains('permission-denied')) {
      return Exception('Anda tidak memiliki izin untuk mengakses data');
    }
    if (e.toString().contains('network')) {
      return Exception('Gagal terhubung ke server');
    }
    return Exception(e.toString());
  }

  LoginResult _result(
    bool success, {
    String error = '',
    String code = '',
    Map<String, dynamic>? userData,
    String role = '',
    String nama = '',
  }) {
    _lastResult = LoginResult(
      success: success,
      errorMessage: error,
      errorCode: code,
      userData: userData,
      role: role,
      nama: nama,
    );
    return _lastResult!;
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-not-found':
        return 'User tidak ditemukan';
      case 'wrong-password':
        return 'Password salah';
      case 'invalid-credential':
        return 'Email / password salah';
      case 'user-disabled':
        return 'Akun dinonaktifkan';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet';
      default:
        return 'Login gagal';
    }
  }

  String _getResetPasswordErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-not-found':
        return 'Email tidak ditemukan';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan';
      default:
        return 'Gagal reset password';
    }
  }

  String _getCreateUserErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah digunakan';
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'weak-password':
        return 'Password terlalu lemah';
      case 'operation-not-allowed':
        return 'Email/password belum aktif';
      default:
        return 'Gagal membuat user';
    }
  }

  Future<void> _addResetAuditTrail({
    required String action,
    required String email,
    required String sessionId,
  }) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final uid = query.docs.first.id;

      await _firestore.collection('users').doc(uid).update({
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': action,
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
            'email': email,
          }
        ]),
      });
    } catch (e) {
      debugPrint('RESET AUDIT ERROR: $e');
    }
  }
}

// =========================================================
// DATA CLASSES
// =========================================================

class LoginResult {
  final bool success;
  final String errorMessage;
  final String errorCode;
  final Map<String, dynamic>? userData;
  final String role;
  final String nama;

  LoginResult({
    required this.success,
    this.errorMessage = '',
    this.errorCode = '',
    this.userData,
    this.role = '',
    this.nama = '',
  });
}

class RememberMeData {
  final bool remembered;
  final String identity;

  RememberMeData({
    required this.remembered,
    required this.identity,
  });
}

class ResetPasswordResult {
  final bool success;
  final String errorMessage;

  ResetPasswordResult({
    required this.success,
    this.errorMessage = '',
  });
}

class CreateUserResult {
  final bool success;
  final String message;

  CreateUserResult({
    required this.success,
    required this.message,
  });
}

class UpdateUserResult {
  final bool success;
  final String message;

  UpdateUserResult({
    required this.success,
    required this.message,
  });
}

class DeleteUserResult {
  final bool success;
  final String message;

  DeleteUserResult({
    required this.success,
    required this.message,
  });
}

class ToggleStatusResult {
  final bool success;
  final String message;

  ToggleStatusResult({
    required this.success,
    required this.message,
  });
}

class BulkStatusResult {
  final bool success;
  final String message;
  final int? affectedCount;

  BulkStatusResult({
    required this.success,
    required this.message,
    this.affectedCount,
  });
}