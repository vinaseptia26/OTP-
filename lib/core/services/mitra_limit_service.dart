// lib/core/services/mitra_limit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const double maxJamBulanan = 60;

  Future<Map<String, dynamic>> checkMitraLimit({
    required String mitraId,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    try {
      final tahunBulan = DateFormat('yyyy-MM').format(tanggal);
      
      // ⚡ Ganti koleksi ke lembur_mitra
      final snapshot = await _firestore
          .collection('lembur_mitra')
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isEqualTo: tahunBulan)
          .where('status', whereIn: ['disetujui', 'pending', 'selesai'])
          .get();

      double totalJam = 0;
      for (var doc in snapshot.docs) {
        totalJam += (doc.data()['total_jam_desimal'] ?? 0).toDouble();
      }

      final sisaJam = maxJamBulanan - totalJam;
      final isExceeded = (totalJam + tambahanJam) > maxJamBulanan;

      return {
        'total_jam_bulan_ini': totalJam,
        'sisa_jam': sisaJam,
        'is_exceeded': isExceeded,
        'tambahan_jam': tambahanJam,
        'max_jam': maxJamBulanan,
        'persentase': ((totalJam + tambahanJam) / maxJamBulanan * 100).clamp(0, 100),
      };
    } catch (e) {
      debugPrint('Error checking mitra limit: $e');
      return {
        'total_jam_bulan_ini': 0,
        'sisa_jam': maxJamBulanan,
        'is_exceeded': false,
        'tambahan_jam': tambahanJam,
        'max_jam': maxJamBulanan,
        'persentase': (tambahanJam / maxJamBulanan * 100).clamp(0, 100),
      };
    }
  }

  String formatJam(double jam) {
    return jam % 1 == 0 ? '${jam.toInt()} jam' : '${jam.toStringAsFixed(1)} jam';
  }
}