// lib/core/services/overtime_absensi_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OvertimeAbsensiService {
  static final OvertimeAbsensiService _instance = OvertimeAbsensiService._internal();
  factory OvertimeAbsensiService() => _instance;
  OvertimeAbsensiService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit absensi lembur
  Future<void> submitAbsensi({
    required String docId,
    required String fotoUrl,
    required String userId,
    required String userName,
  }) async {
    final batch = _firestore.batch();

    // Update dokumen lembur
    final lemburRef = _firestore.collection('lembur').doc(docId);
    batch.update(lemburRef, {
      'absensi_status': 'selesai',
      'absensi_foto_url': fotoUrl,
      'absensi_waktu': FieldValue.serverTimestamp(),
      'absensi_oleh': userId,
      'absensi_nama': userName,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Buat record absensi
    final absensiRef = _firestore.collection('absensi').doc();
    batch.set(absensiRef, {
      'lembur_id': docId,
      'user_id': userId,
      'user_name': userName,
      'foto_url': fotoUrl,
      'waktu': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Update status ke selesai jika disetujui
    final lembur = await _firestore.collection('lembur').doc(docId).get();
    if (lembur.exists && lembur.data()?['status'] == 'disetujui') {
      await lemburRef.update({
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Kirim reminder absensi
  Future<void> sendReminder({
    required String docId,
    required String groupId,
    required String pengawasName,
  }) async {
    final lemburDoc = await _firestore.collection('lembur').doc(docId).get();
    if (!lemburDoc.exists) return;

    final data = lemburDoc.data()!;
    final mitraIds = (data['lokasi']?['mitra_ids'] as List?)?.cast<String>() ?? [];

    for (var mitraId in mitraIds) {
      await _firestore.collection('notifications').add({
        'userId': mitraId,
        'title': '📸 Pengingat Absensi Lembur',
        'body': 'Pengawas $pengawasName mengingatkan untuk segera melakukan absensi.',
        'type': 'absensi_reminder',
        'data': {
          'lembur_id': docId,
          'group_id': groupId,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Check dan update lembur kadaluarsa
  Future<void> checkExpired(String userId, String userRole) async {
    try {
      final now = DateTime.now();
      Query<Map<String, dynamic>> query = _firestore.collection('lembur');

      if (userRole == 'mitra') {
        query = query.where('mitra_ids', arrayContains: userId);
      } else if (userRole == 'pengawas') {
        query = query.where('pengawas_id', isEqualTo: userId);
      }

      final snapshot = await query
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', isNotEqualTo: 'selesai')
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tanggal = (data['tanggal'] as Timestamp).toDate();
        final jamSelesai = data['jam_selesai'] ?? '00:00';

        final selesaiTime = DateTime(
          tanggal.year, tanggal.month, tanggal.day,
          int.parse(jamSelesai.split(':')[0]),
          int.parse(jamSelesai.split(':').length > 1 ? jamSelesai.split(':')[1] : '0'),
        );

        if (now.isAfter(selesaiTime.add(const Duration(days: 1)))) {
          batch.update(doc.reference, {
            'status': 'kadaluarsa',
            'absensi_status': 'expired',
            'expired_at': FieldValue.serverTimestamp(),
            'expired_reason': 'Tidak melakukan absensi hingga batas waktu',
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error checking expired: $e');
    }
  }
}