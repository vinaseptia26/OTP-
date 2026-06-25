// lib/core/services/pendapatan_service.dart
// ============================================================================
// PENDAPATAN SERVICE - Menghitung estimasi pendapatan mitra
// ============================================================================
//
// Service ini menghitung ESTIMASI pendapatan mitra berdasarkan:
// - Lembur yang SUDAH selesai (status: selesai / disetujui)
// - Absensi yang SUDAH dilakukan (check-in & check-out)
// - Tarif lembur per jam (mengacu ke OvertimeRateService)
//
// NOTE: Ini hanya ESTIMASI, bukan gaji final!
// ============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  MODEL: PendapatanItem                                                ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class PendapatanItem {
  final String id;
  final String? lemburId;
  final String? groupId;
  final DateTime tanggal;
  final String? jamMulai;
  final String? jamSelesai;
  final double totalJam;
  final String? jenisLembur;
  final String? statusAbsensi;
  final String? statusLembur; // pending, disetujui, selesai, ditolak, kadaluarsa, dibatalkan
  final DateTime? absensiWaktu; // check-in time
  final DateTime? completedAt; // check-out time
  final double tarifPerJam;
  final double estimasiPendapatan;
  final String? fotoUrl;
  final String? lokasi;
  final String? namaPengawas;
  final DateTime? createdAt;

  const PendapatanItem({
    required this.id,
    this.lemburId,
    this.groupId,
    required this.tanggal,
    this.jamMulai,
    this.jamSelesai,
    required this.totalJam,
    this.jenisLembur,
    this.statusAbsensi,
    this.statusLembur,
    this.absensiWaktu,
    this.completedAt,
    required this.tarifPerJam,
    required this.estimasiPendapatan,
    this.fotoUrl,
    this.lokasi,
    this.namaPengawas,
    this.createdAt,
  });

  /// Format pendapatan ke Rupiah
  String get formattedPendapatan {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(estimasiPendapatan);
  }

  /// Format durasi (check-in → check-out)
  String get formattedDurasiAbsensi {
    if (absensiWaktu == null || completedAt == null) {
      return '${jamMulai ?? "-"} → ${jamSelesai ?? "-"}';
    }
    final checkIn = DateFormat('HH:mm').format(absensiWaktu!);
    final checkOut = DateFormat('HH:mm').format(completedAt!);
    return '$checkIn → $checkOut';
  }

  /// Status absensi label
  String get absensiStatusLabel {
    switch (statusAbsensi) {
      case 'selesai':
        return '✅ Selesai';
      case 'selesai_terlambat':
        return '⚠️ Terlambat';
      case 'sudah_absen':
        return '📸 Sudah Check-in';
      case 'belum_absen':
        return '⏳ Belum Absen';
      case 'expired':
        return '❌ Kadaluarsa';
      default:
        return statusAbsensi ?? '-';
    }
  }

  /// Warna status
  Color get absensiStatusColor {
    switch (statusAbsensi) {
      case 'selesai':
        return Colors.green;
      case 'selesai_terlambat':
        return Colors.orange;
      case 'sudah_absen':
        return Colors.blue;
      case 'belum_absen':
        return Colors.grey;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Status lembur label
  String get statusLemburLabel {
    switch (statusLembur) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      case 'selesai':
        return 'Selesai';
      case 'kadaluarsa':
        return 'Kadaluarsa';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return statusLembur ?? '-';
    }
  }

  /// Warna status lembur
  Color get statusLemburColor {
    switch (statusLembur) {
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'selesai':
        return Colors.blue;
      case 'kadaluarsa':
        return Colors.grey;
      case 'dibatalkan':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  SERVICE: PendapatanService                                           ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class PendapatanService {
  static final PendapatanService _instance = PendapatanService._internal();
  factory PendapatanService() => _instance;
  PendapatanService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cLembur = 'lembur_mitra';

 
  // TARIF DASAR PER JAM (fallback kalau settings ga ada)
 
  static const double tarifDasarPerJam = 25000; // Rp 25.000/jam
  static const double multiplierHariLibur = 2.0;
  static const double multiplierMalam = 1.5;

  // Cache rates
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastRatesFetch;
  static const Duration _ratesCacheDuration = Duration(minutes: 5);

 
  // HELPER: Parse jam dari string "HH:mm"
 
  DateTime _parseJam(DateTime tanggal, String jamStr) {
    final parts = jamStr.split(':');
    final jam = int.tryParse(parts[0]) ?? 0;
    final menit = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(tanggal.year, tanggal.month, tanggal.day, jam, menit);
  }

 
  // LOAD RATES DARI FIRESTORE SETTINGS
 
  Future<Map<String, dynamic>> _loadRates() async {
    // Return cache if valid
    if (_cachedRates != null &&
        _lastRatesFetch != null &&
        DateTime.now().difference(_lastRatesFetch!) < _ratesCacheDuration) {
      return _cachedRates!;
    }

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedRates = doc.data();
        _lastRatesFetch = DateTime.now();
        return _cachedRates!;
      }
    } catch (e) {
      debugPrint('⚠️ PendapatanService: Gagal load rates - $e');
    }

    // Fallback default
    _cachedRates = _getDefaultRates();
    _lastRatesFetch = DateTime.now();
    return _cachedRates!;
  }

  Map<String, dynamic> _getDefaultRates() {
    return {
      'rate_per_hour': tarifDasarPerJam,
      'base_salary': 3000000.0,
      'jam_kerja_per_bulan': 173,
    };
  }

 
  // HITUNG TARIF PER JAM
 
  Future<double> _hitungTarifPerJam({
    required String? jenisLembur,
    required DateTime tanggal,
    required String? jamMulai,
    required String? jamSelesai,
  }) async {
    final rates = await _loadRates();
    double tarif = (rates['rate_per_hour'] as num?)?.toDouble() ?? tarifDasarPerJam;

    // Multiplier hari libur
    if (jenisLembur != null && jenisLembur.toLowerCase() == 'hari_libur') {
      tarif *= multiplierHariLibur;
    }

    // Multiplier malam (jika jam selesai > 22:00)
    if (jamMulai != null && jamSelesai != null) {
      final selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.hour >= 22) {
        final mulaiTime = _parseJam(tanggal, jamMulai);
        if (mulaiTime.hour >= 22) {
          tarif *= multiplierMalam;
        }
      }
    }

    return tarif;
  }

 
  // GET PENDAPATAN MITRA (STREAM - REAL TIME)
 
  Stream<List<PendapatanItem>> getPendapatanStream({
    required String mitraId,
    String? bulan,
  }) {
    // 🔧 QUERY KOMPATIBEL DENGAN STRUKTUR DATA OvertimeService
    // Filter: user_id = mitraId, absensi_status = 'selesai'
    // NOTE: pakai user_id (bukan mitra_id) karena ini field yang dipakai
    // oleh OvertimeService untuk role 'mitra'
    var query = _firestore
        .collection(_cLembur)
        .where('user_id', isEqualTo: mitraId)
        .where('absensi_status', isEqualTo: 'selesai')
        .orderBy('tanggal', descending: true);

    // Filter bulan (pakai field 'tahun_bulan' yang sudah ada)
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final List<PendapatanItem> items = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Parse data dari Firestore (sesuai struktur OvertimeHistory)
          final tanggal = (data['tanggal'] as Timestamp?)?.toDate() ??
              (data['tanggal_lembur'] as Timestamp?)?.toDate() ??
              DateTime.now();

          final jamMulai = data['jam_mulai'] as String? ?? '';
          final jamSelesai = data['jam_selesai'] as String? ?? '';
          final totalJam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
          final jenisLembur = data['jenis_lembur'] as String? ?? 'hari_kerja';
          final statusAbsensi = data['absensi_status'] as String? ?? '';
          final statusLembur = data['status'] as String? ?? '';
          final namaPengawas =
              data['nama_pengawas'] ?? data['diajukan_oleh_nama'] ?? '-';

          // Parse lokasi
          String? lokasi;
          if (data['lokasi'] is Map) {
            lokasi =
                (data['lokasi'] as Map)['alamat']?.toString() ??
                (data['lokasi'] as Map)['nama_lokasi']?.toString() ??
                'Kantor';
          } else {
            lokasi = 'Kantor';
          }

          // Parse waktu absensi
          DateTime? absensiWaktu;
          DateTime? completedAt;

          if (data['absensi_waktu'] is Timestamp) {
            absensiWaktu = (data['absensi_waktu'] as Timestamp).toDate();
          }
          if (data['completed_at'] is Timestamp) {
            completedAt = (data['completed_at'] as Timestamp).toDate();
          }

          // Hitung tarif per jam
          final tarifPerJam = await _hitungTarifPerJam(
            jenisLembur: jenisLembur,
            tanggal: tanggal,
            jamMulai: jamMulai,
            jamSelesai: jamSelesai,
          );

          // Hitung estimasi pendapatan
          final estimasiPendapatan = totalJam * tarifPerJam;

          items.add(PendapatanItem(
            id: doc.id,
            lemburId: data['lembur_id'] as String? ?? doc.id,
            groupId: data['group_id'] as String? ?? '',
            tanggal: tanggal,
            jamMulai: jamMulai,
            jamSelesai: jamSelesai,
            totalJam: totalJam,
            jenisLembur: jenisLembur,
            statusAbsensi: statusAbsensi,
            statusLembur: statusLembur,
            absensiWaktu: absensiWaktu,
            completedAt: completedAt,
            tarifPerJam: tarifPerJam,
            estimasiPendapatan: estimasiPendapatan,
            fotoUrl: data['absensi_foto_url'] as String?,
            lokasi: lokasi,
            namaPengawas: namaPengawas,
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? tanggal,
          ));
        } catch (e) {
          debugPrint('❌ PendapatanService: Error parsing doc ${doc.id} - $e');
          // Skip item yang error parsing
        }
      }

      // Sort by tanggal descending (untuk jaga-jaga)
      items.sort((a, b) => b.tanggal.compareTo(a.tanggal));

      return items;
    }).handleError((error) {
      debugPrint('❌ PendapatanService: Stream error - $error');
      // Return list kosong instead of error
      return <PendapatanItem>[];
    });
  }

 
  // GET RINGKASAN PENDAPATAN BULANAN (FUTURE)
 
  Future<Map<String, dynamic>> getRingkasanPendapatan({
    required String mitraId,
    String? bulan,
  }) async {
    try {
      var query = _firestore
          .collection(_cLembur)
          .where('user_id', isEqualTo: mitraId)
          .where('absensi_status', isEqualTo: 'selesai');

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();

      int totalLembur = 0;
      double totalJam = 0;
      double totalPendapatan = 0;
      int tepatWaktu = 0;
      int terlambat = 0;
      double rataRataPerHari = 0;

      final Set<String> hariUnik = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final tanggal =
            (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
        final totalJamItem =
            (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        final jenisLembur = data['jenis_lembur'] as String? ?? 'hari_kerja';
        final jamMulai = data['jam_mulai'] as String? ?? '';
        final jamSelesai = data['jam_selesai'] as String? ?? '';
        final absensiStatus = data['absensi_status'] as String? ?? '';

        final tarif = await _hitungTarifPerJam(
          jenisLembur: jenisLembur,
          tanggal: tanggal,
          jamMulai: jamMulai,
          jamSelesai: jamSelesai,
        );

        totalLembur++;
        totalJam += totalJamItem;
        totalPendapatan += totalJamItem * tarif;

        if (absensiStatus == 'selesai') {
          tepatWaktu++;
        } else if (absensiStatus == 'selesai_terlambat') {
          terlambat++;
        }

        hariUnik.add(DateFormat('yyyy-MM-dd').format(tanggal));
      }

      // Rata-rata pendapatan per hari lembur
      if (hariUnik.isNotEmpty) {
        rataRataPerHari = totalPendapatan / hariUnik.length;
      }

      return {
        'totalLembur': totalLembur,
        'totalJam': totalJam,
        'totalPendapatan': totalPendapatan,
        'tepatWaktu': tepatWaktu,
        'terlambat': terlambat,
        'rataRataPerHari': rataRataPerHari,
        'totalHariLembur': hariUnik.length,
        'tarifDasar': tarifDasarPerJam,
      };
    } catch (e) {
      debugPrint('❌ PendapatanService: getRingkasanPendapatan error - $e');
      return {
        'totalLembur': 0,
        'totalJam': 0,
        'totalPendapatan': 0,
        'tepatWaktu': 0,
        'terlambat': 0,
        'rataRataPerHari': 0,
        'totalHariLembur': 0,
        'tarifDasar': tarifDasarPerJam,
      };
    }
  }

  /// Clear cache rates
  void clearCache() {
    _cachedRates = null;
    _lastRatesFetch = null;
    debugPrint('🧹 PendapatanService: Cache cleared');
  }
}