// lib/core/services/my_team_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamMember {
  final String id;
  final String namaLengkap;
  final String email;
  final String phone;
  final String role;
  final String fungsi;
  final String fungsiLabel;
  final String statusAkun;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final bool isActive;
  final String? fotoUrl;

  TeamMember({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.phone,
    required this.role,
    required this.fungsi,
    required this.fungsiLabel,
    required this.statusAkun,
    this.lastLogin,
    required this.createdAt,
    required this.isActive,
    this.fotoUrl,
  });

  factory TeamMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    DateTime? lastLogin;
    if (data['last_login'] != null) {
      if (data['last_login'] is Timestamp) {
        lastLogin = (data['last_login'] as Timestamp).toDate();
      }
    }

    DateTime createdAt;
    if (data['created_at'] != null) {
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    return TeamMember(
      id: doc.id,
      namaLengkap: data['nama_lengkap'] ?? 'Tanpa Nama',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'mitra',
      fungsi: data['fungsi'] ?? '',
      fungsiLabel: data['fungsi_label'] ?? '',
      statusAkun: data['status_akun'] ?? 'inactive',
      lastLogin: lastLogin,
      createdAt: createdAt,
      isActive: data['status_akun'] == 'active',
      fotoUrl: data['foto_url'],
    );
  }

  String get inisial {
    if (namaLengkap.isEmpty) return '?';
    final parts = namaLengkap.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return namaLengkap[0].toUpperCase();
  }

  String get lastLoginFormatted {
    if (lastLogin == null) return 'Belum pernah login';
    final now = DateTime.now();
    final diff = now.difference(lastLogin!);
    
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${lastLogin!.day}/${lastLogin!.month}/${lastLogin!.year}';
  }
}

class MyTeamService {
  static final MyTeamService _instance = MyTeamService._internal();
  factory MyTeamService() => _instance;
  MyTeamService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan semua anggota tim berdasarkan fungsi pengawas
  Stream<List<TeamMember>> getTeamMembersStream({
    required String fungsi,
  }) {
    return _firestore
        .collection('users')
        .where('fungsi', isEqualTo: fungsi.toLowerCase())
        .where('role', isEqualTo: 'mitra')
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((doc) => TeamMember.fromFirestore(doc))
              .toList();

          // Sort: active first, then by name
          members.sort((a, b) {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            return a.namaLengkap.compareTo(b.namaLengkap);
          });

          return members;
        });
  }

  /// Mendapatkan jumlah total anggota tim
  Future<int> getTotalTeamMembers({required String fungsi}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('fungsi', isEqualTo: fungsi.toLowerCase())
          .where('role', isEqualTo: 'mitra')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting total team members: $e');
      return 0;
    }
  }

  /// Mendapatkan statistik tim
  Future<Map<String, dynamic>> getTeamStats({
    required String fungsi,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('fungsi', isEqualTo: fungsi.toLowerCase())
          .where('role', isEqualTo: 'mitra')
          .get();

      final members = snapshot.docs;

      int total = members.length;
      int active = members.where((d) => d.data()['status_akun'] == 'active').length;
      int inactive = members.where((d) => d.data()['status_akun'] != 'active').length;
      
      // Hitung yang login dalam 7 hari terakhir
      int recentlyActive = 0;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      for (var doc in members) {
        final data = doc.data();
        if (data['last_login'] != null) {
          final lastLogin = (data['last_login'] as Timestamp).toDate();
          if (lastLogin.isAfter(sevenDaysAgo)) {
            recentlyActive++;
          }
        }
      }

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'recentlyActive': recentlyActive,
        'fungsi': fungsi,
      };
    } catch (e) {
      debugPrint('Error getting team stats: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'recentlyActive': 0,
        'fungsi': fungsi,
      };
    }
  }

  /// Cari anggota tim spesifik
  Future<TeamMember?> getTeamMemberById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return TeamMember.fromFirestore(
        doc
      );
    } catch (e) {
      debugPrint('Error getting team member: $e');
      return null;
    }
  }
}