// lib/core/services/overtime_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODEL OvertimeHistory ====================
class OvertimeHistory {
  final String id;
  final String groupId;
  final String? pengawasId;
  final String? namaPengawas;
  final String? pengawasFungsi;
  final String? mitraId;
  final String? namaMitra;
  final String? fungsiMitra;
  final String? noHpMitra;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final String jenisLembur;
  final Map<String, dynamic> lokasi;
  final String urgensi;
  final String alasan;
  final String catatanTambahan;
  final double estimasiBiayaPerMitra;
  final double estimasiBiayaTotal;
  final int totalMitra;
  final bool isMultiple;
  final bool isOverride;
  final String status;
  final String absensiStatus;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Rate snapshot untuk audit
  final Map<String, dynamic>? rateSnapshot;

  // 🔥 Pembatalan fields
  final String? alasanPembatalan;
  final String? dibatalkanOleh;
  final String? dibatalkanOlehNama;
  final DateTime? dibatalkanPada;

  OvertimeHistory({
    required this.id,
    required this.groupId,
    this.pengawasId,
    this.namaPengawas,
    this.pengawasFungsi,
    this.mitraId,
    this.namaMitra,
    this.fungsiMitra,
    this.noHpMitra,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.jenisLembur,
    required this.lokasi,
    required this.urgensi,
    required this.alasan,
    required this.catatanTambahan,
    required this.estimasiBiayaPerMitra,
    required this.estimasiBiayaTotal,
    required this.totalMitra,
    required this.isMultiple,
    required this.isOverride,
    required this.status,
    required this.absensiStatus,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rateSnapshot,
    this.alasanPembatalan,
    this.dibatalkanOleh,
    this.dibatalkanOlehNama,
    this.dibatalkanPada,
  });

  factory OvertimeHistory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return OvertimeHistory(
      id: doc.id,
      groupId: data['group_id'] ?? data['pengajuan_id'] ?? '',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      tanggal: (data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : (data['tanggal_lembur'] as Timestamp).toDate()),
      jamMulai: data['jam_mulai'] ?? '',
      jamSelesai: data['jam_selesai'] ?? '',
      totalJam: (data['total_jam_desimal'] ?? 0).toDouble(),
      jenisLembur: data['jenis_lembur'] ?? 'hari_kerja',
      lokasi: data['lokasi'] ?? {},
      urgensi: data['urgensi'] ?? 'normal',
      alasan: data['alasan'] ?? '',
      catatanTambahan: data['catatan_tambahan'] ?? '',
      estimasiBiayaPerMitra: (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0).toDouble(),
      estimasiBiayaTotal: (data['estimasi_biaya_total'] ?? 0).toDouble(),
      totalMitra: data['total_mitra'] ?? 1,
      isMultiple: data['is_multiple'] ?? false,
      isOverride: data['is_override'] ?? false,
      status: data['status'] ?? 'pending',
      absensiStatus: data['absensi_status'] ?? 'belum_absen',
      approvedBy: data['approved_by'],
      approvedByName: data['approved_by_name'],
      approvedAt: data['approved_at'] != null 
          ? (data['approved_at'] as Timestamp).toDate() 
          : null,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      rateSnapshot: data['rate_snapshot'] as Map<String, dynamic>?,
      // 🔥 Pembatalan fields
      alasanPembatalan: data['alasan_pembatalan'],
      dibatalkanOleh: data['dibatalkan_oleh'],
      dibatalkanOlehNama: data['dibatalkan_oleh_nama'],
      dibatalkanPada: data['dibatalkan_pada'] != null 
          ? (data['dibatalkan_pada'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'pengawas_id': pengawasId,
      'nama_pengawas': namaPengawas,
      'pengawas_fungsi': pengawasFungsi,
      'mitra_id': mitraId,
      'nama_mitra': namaMitra,
      'fungsi_mitra': fungsiMitra,
      'no_hp_mitra': noHpMitra,
      'tanggal': Timestamp.fromDate(tanggal),
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'total_jam_desimal': totalJam,
      'jenis_lembur': jenisLembur,
      'lokasi': lokasi,
      'urgensi': urgensi,
      'alasan': alasan,
      'catatan_tambahan': catatanTambahan,
      'estimasi_biaya_per_mitra': estimasiBiayaPerMitra,
      'estimasi_biaya_total': estimasiBiayaTotal,
      'total_mitra': totalMitra,
      'is_multiple': isMultiple,
      'is_override': isOverride,
      'status': status,
      'absensi_status': absensiStatus,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      if (rateSnapshot != null) 'rate_snapshot': rateSnapshot,
      if (alasanPembatalan != null) 'alasan_pembatalan': alasanPembatalan,
      if (dibatalkanOleh != null) 'dibatalkan_oleh': dibatalkanOleh,
      if (dibatalkanOlehNama != null) 'dibatalkan_oleh_nama': dibatalkanOlehNama,
      if (dibatalkanPada != null) 'dibatalkan_pada': Timestamp.fromDate(dibatalkanPada!),
    };
  }

  /// Cek apakah pengajuan bisa dibatalkan
  bool get canBeCancelled => status == 'pending';
  
  /// Cek apakah ini pengajuan yang dibatalkan
  bool get isCancelled => status == 'dibatalkan';
}

// ==================== OVERTIME SERVICE ====================
class OvertimeService {
  static final OvertimeService _instance = OvertimeService._internal();
  factory OvertimeService() => _instance;
  OvertimeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ==================== KONSTANTA KOLEKSI ====================
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionSettings = 'settings';

  // ==================== TARIF LEMBUR ====================
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const double jamKerjaPerBulan = 173;

  /// Load overtime rates dari Firestore settings
  Future<Map<String, dynamic>> loadOvertimeRates({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedRates != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      debugPrint('📦 Using cached overtime rates');
      return _cachedRates!;
    }

    try {
      debugPrint('🔄 Fetching overtime rates from Firestore...');
      final doc = await _firestore
          .collection(collectionSettings)
          .doc('overtime_rates')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        if (data['base_salary'] == null || data['rate_per_hour'] == null) {
          debugPrint('⚠️ Rates data incomplete, using defaults');
          _cachedRates = _getDefaultRates();
        } else {
          _cachedRates = data;
        }
        
        _lastFetch = DateTime.now();
        debugPrint('✅ Overtime rates loaded successfully');
        return _cachedRates!;
      }
      
      debugPrint('⚠️ No rates document found, creating default...');
      await _createDefaultRatesDocument();
      _cachedRates = _getDefaultRates();
      _lastFetch = DateTime.now();
      return _cachedRates!;
      
    } catch (e) {
      debugPrint('❌ Error loading overtime rates: $e');
      _cachedRates = _getDefaultRates();
      return _cachedRates!;
    }
  }

  Future<void> _createDefaultRatesDocument() async {
    try {
      final defaultRates = _getDefaultRates();
      await _firestore
          .collection(collectionSettings)
          .doc('overtime_rates')
          .set({
        ...defaultRates,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': 'system',
      });
      debugPrint('✅ Default rates document created');
    } catch (e) {
      debugPrint('❌ Failed to create default rates: $e');
    }
  }

  Map<String, dynamic> _getDefaultRates() {
    const defaultGaji = 3000000.0;
    final upahPerJam = defaultGaji / jamKerjaPerBulan;
    
    return {
      'base_salary': defaultGaji,
      'rate_per_hour': upahPerJam,
      'jam_kerja_per_bulan': jamKerjaPerBulan,
      'max_jam_lembur_per_bulan': 60,
      'last_updated': null,
      'updated_by': 'system',
      'version': '1.0',
      'weekday_rate': {
        'first_hour_multiplier': 1.5,
        'next_hours_multiplier': 2.0,
        'description': '1.5x untuk jam pertama, 2.0x untuk jam berikutnya',
        'is_active': true,
      },
      'holiday_rate': {
        'first_8_hours_multiplier': 2.0,
        'ninth_hour_multiplier': 3.0,
        'tenth_plus_multiplier': 4.0,
        'description': '2x (8 jam pertama), 3x (jam ke-9), 4x (jam ke-10+)',
        'is_active': true,
      },
    };
  }

  Future<void> updateOvertimeRates(Map<String, dynamic> newRates) async {
    try {
      final user = _auth.currentUser;
      await _firestore
          .collection(collectionSettings)
          .doc('overtime_rates')
          .set({
        ...newRates,
        'last_updated': DateTime.now().toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': user?.uid ?? 'system',
        'updated_by_email': user?.email ?? 'system',
      }, SetOptions(merge: true));
      
      clearCache();
      debugPrint('✅ Overtime rates updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating overtime rates: $e');
      rethrow;
    }
  }

  double calculateOvertimeCost({
    required double totalHours,
    required bool isHoliday,
    required Map<String, dynamic> rates,
  }) {
    final ratePerHour = (rates['rate_per_hour'] as num?)?.toDouble() ?? 0;
    if (ratePerHour <= 0 || totalHours <= 0) return 0;

    if (isHoliday) {
      return _calculateHolidayOvertime(totalHours, ratePerHour, rates);
    } else {
      return _calculateWeekdayOvertime(totalHours, ratePerHour, rates);
    }
  }

  Map<String, dynamic> calculateOvertimeCostDetailed({
    required double totalHours,
    required bool isHoliday,
    required Map<String, dynamic> rates,
  }) {
    final ratePerHour = (rates['rate_per_hour'] as num?)?.toDouble() ?? 0;
    
    if (ratePerHour <= 0 || totalHours <= 0) {
      return {
        'total_cost': 0,
        'rate_per_hour': ratePerHour,
        'total_hours': totalHours,
        'is_holiday': isHoliday,
        'breakdown': {},
      };
    }

    if (isHoliday) {
      return _calculateHolidayOvertimeDetailed(totalHours, ratePerHour, rates);
    } else {
      return _calculateWeekdayOvertimeDetailed(totalHours, ratePerHour, rates);
    }
  }

  double _calculateWeekdayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>? ?? {};
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;

    if (roundedHours <= 1) {
      totalCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      totalCost += ratePerHour * firstHourMultiplier;
      totalCost += (roundedHours - 1) * ratePerHour * nextHoursMultiplier;
    }

    return totalCost;
  }

  Map<String, dynamic> _calculateWeekdayOvertimeDetailed(
    double totalHours, double ratePerHour, Map<String, dynamic> rates,
  ) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>? ?? {};
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double firstHourCost = 0, remainingHoursCost = 0;
    double firstHourActual = 0, remainingHoursActual = 0;

    if (roundedHours <= 1) {
      firstHourActual = roundedHours;
      firstHourCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      firstHourActual = 1;
      firstHourCost = ratePerHour * firstHourMultiplier;
      remainingHoursActual = roundedHours - 1;
      remainingHoursCost = remainingHoursActual * ratePerHour * nextHoursMultiplier;
    }

    return {
      'total_cost': firstHourCost + remainingHoursCost,
      'rate_per_hour': ratePerHour,
      'total_hours': totalHours,
      'rounded_hours': roundedHours,
      'is_holiday': false,
      'breakdown': {
        'type': 'weekday',
        'first_hour': {'hours': firstHourActual, 'multiplier': firstHourMultiplier, 'cost': firstHourCost},
        'remaining_hours': {'hours': remainingHoursActual, 'multiplier': nextHoursMultiplier, 'cost': remainingHoursCost},
      },
    };
  }

  double _calculateHolidayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>? ?? {};
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;
    
    final first8Hours = roundedHours < 8 ? roundedHours : 8;
    totalCost += first8Hours * ratePerHour * first8Multiplier;
    
    if (roundedHours > 8) {
      final ninthHour = roundedHours < 9 ? roundedHours - 8 : 1;
      totalCost += ninthHour * ratePerHour * ninthMultiplier;
    }
    
    if (roundedHours > 9) {
      totalCost += (roundedHours - 9) * ratePerHour * tenthMultiplier;
    }
    
    return totalCost;
  }

  Map<String, dynamic> _calculateHolidayOvertimeDetailed(
    double totalHours, double ratePerHour, Map<String, dynamic> rates,
  ) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>? ?? {};
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    double first8Cost = 0, ninthHourCost = 0, tenthPlusCost = 0;
    double first8Actual = 0, ninthActual = 0, tenthActual = 0;
    
    first8Actual = roundedHours < 8 ? roundedHours : 8;
    first8Cost = first8Actual * ratePerHour * first8Multiplier;
    
    if (roundedHours > 8) {
      ninthActual = roundedHours < 9 ? roundedHours - 8 : 1;
      ninthHourCost = ninthActual * ratePerHour * ninthMultiplier;
    }
    
    if (roundedHours > 9) {
      tenthActual = roundedHours - 9;
      tenthPlusCost = tenthActual * ratePerHour * tenthMultiplier;
    }

    return {
      'total_cost': first8Cost + ninthHourCost + tenthPlusCost,
      'rate_per_hour': ratePerHour,
      'total_hours': totalHours,
      'rounded_hours': roundedHours,
      'is_holiday': true,
      'breakdown': {
        'type': 'holiday',
        'first_8_hours': {'hours': first8Actual, 'multiplier': first8Multiplier, 'cost': first8Cost},
        'ninth_hour': {'hours': ninthActual, 'multiplier': ninthMultiplier, 'cost': ninthHourCost},
        'tenth_plus_hours': {'hours': tenthActual, 'multiplier': tenthMultiplier, 'cost': tenthPlusCost},
      },
    };
  }

  double calculateTotalLemburCost({
    required double totalHours,
    required bool isHoliday,
    required Map<String, dynamic> rates,
    required int jumlahMitra,
  }) {
    final biayaLemburPerMitra = calculateOvertimeCost(
      totalHours: totalHours, isHoliday: isHoliday, rates: rates,
    );
    return biayaLemburPerMitra * jumlahMitra;
  }

  double getRatePerHour(Map<String, dynamic> rates) =>
      (rates['rate_per_hour'] as num?)?.toDouble() ?? 0;

  double getBaseSalary(Map<String, dynamic> rates) =>
      (rates['base_salary'] as num?)?.toDouble() ?? 0;

  double getMaxJamLemburPerBulan(Map<String, dynamic> rates) =>
      (rates['max_jam_lembur_per_bulan'] as num?)?.toDouble() ?? 60;

  void clearCache() {
    _cachedRates = null;
    _lastFetch = null;
    debugPrint('🧹 Overtime rates cache cleared');
  }

  // ==================== FORMATTING ====================
  
  String formatRupiah(dynamic value) {
    final amount = value is double ? value : (value as num).toDouble();
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount.round())}';
  }

  String formatRupiahCompact(dynamic value) {
    final amount = value is double ? value : (value as num).toDouble();
    if (amount >= 1000000) {
      final juta = amount / 1000000;
      final decimal = amount % 1000000 == 0 ? 0 : 1;
      return 'Rp ${juta.toStringAsFixed(decimal)} Jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} Rb';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  // ==================== RIWAYAT LEMBUR (STREAM) ====================
  
  Stream<List<OvertimeHistory>> getOvertimeHistoryStream({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);

    if (userRole == 'manager') {
      if (userFungsi != null && userFungsi.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
      }
    } else if (userRole == 'pengawas') {
      query = query.where('pengawas_id', isEqualTo: userId);
    } else if (userRole == 'mitra') {
      query = query.where('user_id', isEqualTo: userId);
    }

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    if (statusFilter != null && statusFilter != 'semua' && statusFilter != 'need_absensi') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs
              .map((doc) => OvertimeHistory.fromFirestore(doc))
              .toList();

          if (statusFilter == 'need_absensi') {
            docs = docs.where((item) =>
                item.status == 'disetujui' && item.absensiStatus != 'selesai').toList();
          }

          // 🔥 Hide cancelled for non-superadmin (unless explicitly filtered)
          if (userRole != 'superadmin' && statusFilter != 'dibatalkan') {
            docs = docs.where((item) => item.status != 'dibatalkan').toList();
          }

          return docs;
        });
  }

  // ==================== STATISTIK ====================

  Future<Map<String, dynamic>> getOvertimeStats({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);

      if (userRole == 'manager') {
        if (userFungsi != null && userFungsi.isNotEmpty) {
          query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        }
      } else if (userRole == 'pengawas') {
        query = query.where('pengawas_id', isEqualTo: userId);
      } else if (userRole == 'mitra') {
        query = query.where('user_id', isEqualTo: userId);
      }

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      int total = docs.length;
      int pending = 0, approved = 0, completed = 0, rejected = 0, expired = 0, cancelled = 0, needAbsensi = 0;
      double totalJam = 0, totalBiaya = 0;

      for (var doc in docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        
        switch (status) {
          case 'pending': pending++; break;
          case 'disetujui':
            approved++;
            if (data['absensi_status'] != 'selesai') needAbsensi++;
            break;
          case 'selesai':
            completed++;
            totalJam += (data['total_jam_desimal'] ?? 0).toDouble();
            totalBiaya += (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0).toDouble();
            break;
          case 'ditolak': rejected++; break;
          case 'kadaluarsa': expired++; break;
          case 'dibatalkan': cancelled++; break;
        }
      }

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'rejected': rejected,
        'expired': expired,
        'cancelled': cancelled,
        'needAbsensi': needAbsensi,
        'totalJam': totalJam,
        'totalBiaya': totalBiaya,
        'totalMitra': total,
      };
    } catch (e) {
      debugPrint('❌ Error getting stats: $e');
      return {
        'total': 0, 'pending': 0, 'approved': 0, 'completed': 0,
        'rejected': 0, 'expired': 0, 'cancelled': 0, 'needAbsensi': 0,
        'totalJam': 0, 'totalBiaya': 0, 'totalMitra': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getMitraOvertimeStats({
    required String mitraId,
    required String yearMonth,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isEqualTo: yearMonth)
          .where('status', whereIn: ['disetujui', 'pending'])
          .get();

      double totalJam = 0, totalBiaya = 0;
      int totalLembur = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalJam += (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        totalBiaya += (data['estimasi_biaya_per_mitra'] as num?)?.toDouble() ?? 0;
      }

      const maxJamPerBulan = 60.0;

      return {
        'total_jam': totalJam,
        'total_biaya': totalBiaya,
        'total_lembur': totalLembur,
        'tahun_bulan': yearMonth,
        'max_jam_per_bulan': maxJamPerBulan,
        'sisa_jam': (maxJamPerBulan - totalJam).clamp(0, maxJamPerBulan),
        'is_exceeded': totalJam >= maxJamPerBulan,
        'persentase': (totalJam / maxJamPerBulan * 100).clamp(0.0, 100.0),
      };
    } catch (e) {
      debugPrint('❌ Error getting mitra overtime stats: $e');
      return {
        'total_jam': 0, 'total_biaya': 0, 'total_lembur': 0,
        'sisa_jam': 60, 'is_exceeded': false, 'persentase': 0,
      };
    }
  }

  // ==================== SINGLE DOCUMENT ====================

  Future<OvertimeHistory?> getOvertimeById(String id) async {
    try {
      final doc = await _firestore.collection(collectionLemburMitra).doc(id).get();
      if (!doc.exists) return null;
      return OvertimeHistory.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting overtime by id: $e');
      return null;
    }
  }

  Future<OvertimeHistory?> getPengajuanById(String groupId) async {
    try {
      final doc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      if (!doc.exists) return null;
      return OvertimeHistory.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting pengajuan: $e');
      return null;
    }
  }

  Future<List<OvertimeHistory>> getLemburMitraByGroup(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      return snapshot.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting lembur mitra by group: $e');
      return [];
    }
  }

  // ==================== APPROVAL / STATUS UPDATE ====================

  Future<void> updateOvertimeStatus({
    required String docId,
    required String status,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
    
    await _firestore.collection(collectionLemburMitra).doc(docId).update({
      'status': status,
      if (note != null) 'approval_note': note,
      'approved_by': user.uid,
      'approved_by_name': userName,
      'approved_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    final lembur = await getOvertimeById(docId);
    if (lembur != null && lembur.pengawasId != null) {
      await _firestore.collection('notifications').add({
        'userId': lembur.pengawasId,
        'title': status == 'disetujui' ? '✅ Lembur Disetujui' : '❌ Lembur Ditolak',
        'body': 'Pengajuan lembur tanggal ${formatTanggalShort(lembur.tanggal)} ${status == 'disetujui' ? 'disetujui' : 'ditolak'}${note != null ? '\nAlasan: $note' : ''}',
        'type': 'overtime_${status == 'disetujui' ? 'approved' : 'rejected'}',
        'data': {'lembur_id': docId, 'group_id': lembur.groupId, if (note != null) 'reason': note},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> batchUpdateStatusByGroup({
    required String groupId,
    required String status,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
    
    final snapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('group_id', isEqualTo: groupId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': status,
        if (note != null) 'approval_note': note,
        'approved_by': user.uid,
        'approved_by_name': userName,
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    
    if (snapshot.docs.isNotEmpty) {
      final first = OvertimeHistory.fromFirestore(snapshot.docs.first);
      if (first.pengawasId != null) {
        await _firestore.collection('notifications').add({
          'userId': first.pengawasId,
          'title': status == 'disetujui' ? '✅ Lembur Disetujui' : '❌ Lembur Ditolak',
          'body': 'Pengajuan lembur group $groupId ${status == 'disetujui' ? 'disetujui' : 'ditolak'}${note != null ? '\nAlasan: $note' : ''}',
          'type': 'overtime_batch_${status == 'disetujui' ? 'approved' : 'rejected'}',
          'data': {'group_id': groupId, if (note != null) 'reason': note},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ==================== PEMBATALAN PENGAJUAN ====================

  /// Batalkan pengajuan lembur individual (soft delete)
  Future<void> cancelOvertime({
    required String docId,
    String? alasanPembatalan,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');
      
      final doc = await _firestore.collection(collectionLemburMitra).doc(docId).get();
      if (!doc.exists) throw Exception('Dokumen tidak ditemukan');
      
      final currentStatus = doc.data()?['status'] ?? '';
      if (currentStatus != 'pending') {
        throw Exception('Hanya pengajuan dengan status pending yang dapat dibatalkan');
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
      final now = FieldValue.serverTimestamp();
      
      await _firestore.collection(collectionLemburMitra).doc(docId).update({
        'status': 'dibatalkan',
        'alasan_pembatalan': alasanPembatalan ?? 'Dibatalkan oleh pengguna',
        'dibatalkan_oleh': user.uid,
        'dibatalkan_oleh_nama': userName,
        'dibatalkan_pada': now,
        'updated_at': now,
      });
      
      debugPrint('✅ Overtime $docId cancelled by $userName');
    } catch (e) {
      debugPrint('❌ Error cancelling overtime: $e');
      rethrow;
    }
  }

  /// Batalkan semua pengajuan dalam satu group (batch)
  Future<void> cancelOvertimeGroup({
    required String groupId,
    String? alasanPembatalan,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
      final now = FieldValue.serverTimestamp();
      
      final batch = _firestore.batch();
      
      // Update pengajuan_lembur
      batch.update(_firestore.collection(collectionPengajuan).doc(groupId), {
        'status': 'dibatalkan',
        'alasan_pembatalan': alasanPembatalan ?? 'Dibatalkan oleh pengguna',
        'dibatalkan_oleh': user.uid,
        'dibatalkan_oleh_nama': userName,
        'dibatalkan_pada': now,
        'updated_at': now,
      });
      
      // Update semua lembur_mitra
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'dibatalkan',
          'alasan_pembatalan': alasanPembatalan ?? 'Dibatalkan oleh pengguna',
          'dibatalkan_oleh': user.uid,
          'dibatalkan_oleh_nama': userName,
          'dibatalkan_pada': now,
          'updated_at': now,
        });
      }
      
      await batch.commit();
      debugPrint('✅ Group $groupId cancelled (${snapshot.docs.length} mitra) by $userName');
    } catch (e) {
      debugPrint('❌ Error cancelling overtime group: $e');
      rethrow;
    }
  }

  /// Restore pengajuan yang dibatalkan (Superadmin only)
  Future<void> restoreCancelledOvertime({
    required String docId,
    String? catatanRestore,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'] ?? '';
      
      if (userRole != 'superadmin') {
        throw Exception('Hanya superadmin yang dapat merestore pengajuan');
      }
      
      final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
      final now = FieldValue.serverTimestamp();
      
      await _firestore.collection(collectionLemburMitra).doc(docId).update({
        'status': 'pending',
        'restored_at': now,
        'restored_by': user.uid,
        'restored_by_nama': userName,
        'restore_catatan': catatanRestore ?? 'Direstore oleh superadmin',
        'updated_at': now,
      });
      
      debugPrint('✅ Overtime $docId restored by $userName');
    } catch (e) {
      debugPrint('❌ Error restoring overtime: $e');
      rethrow;
    }
  }

  /// Restore seluruh group (Superadmin only)
  Future<void> restoreCancelledOvertimeGroup({
    required String groupId,
    String? catatanRestore,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'] ?? '';
      
      if (userRole != 'superadmin') {
        throw Exception('Hanya superadmin yang dapat merestore pengajuan');
      }
      
      final userName = userDoc.data()?['nama_lengkap'] ?? user.email ?? 'Unknown';
      final now = FieldValue.serverTimestamp();
      
      final batch = _firestore.batch();
      
      batch.update(_firestore.collection(collectionPengajuan).doc(groupId), {
        'status': 'pending',
        'restored_at': now,
        'restored_by': user.uid,
        'restored_by_nama': userName,
        'restore_catatan': catatanRestore ?? 'Direstore oleh superadmin',
        'updated_at': now,
      });
      
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'pending',
          'restored_at': now,
          'restored_by': user.uid,
          'restored_by_nama': userName,
          'restore_catatan': catatanRestore ?? 'Direstore oleh superadmin',
          'updated_at': now,
        });
      }
      
      await batch.commit();
      debugPrint('✅ Group $groupId restored (${snapshot.docs.length} mitra) by $userName');
    } catch (e) {
      debugPrint('❌ Error restoring overtime group: $e');
      rethrow;
    }
  }

  // ==================== ABSENSI ====================

  Future<void> submitAbsensi({
    required String docId,
    required String fotoUrl,
    required String userId,
    required String userName,
  }) async {
    final batch = _firestore.batch();
    
    batch.update(_firestore.collection(collectionLemburMitra).doc(docId), {
      'absensi_status': 'selesai',
      'absensi_foto_url': fotoUrl,
      'absensi_waktu': FieldValue.serverTimestamp(),
      'absensi_oleh': userId,
      'absensi_nama': userName,
      'updated_at': FieldValue.serverTimestamp(),
    });

    batch.set(_firestore.collection('absensi').doc(), {
      'lembur_id': docId,
      'user_id': userId,
      'user_name': userName,
      'foto_url': fotoUrl,
      'waktu': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    
    final lembur = await getOvertimeById(docId);
    if (lembur != null && lembur.status == 'disetujui') {
      await _firestore.collection(collectionLemburMitra).doc(docId).update({
        'status': 'selesai',
        'completed_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== REMINDER ====================

  Future<void> sendAbsensiReminder(String docId, String groupId, String pengawasName) async {
    final lembur = await getOvertimeById(docId);
    if (lembur == null || lembur.mitraId == null) return;
    
    await _firestore.collection('notifications').add({
      'userId': lembur.mitraId,
      'title': '📸 Pengingat Absensi Lembur',
      'body': 'Pengawas $pengawasName mengingatkan untuk segera melakukan absensi lembur tanggal ${formatTanggalShort(lembur.tanggal)}.',
      'type': 'absensi_reminder',
      'data': {'lembur_id': docId, 'group_id': groupId, 'pengawas_name': pengawasName},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAbsensiReminderToGroup(String groupId, String pengawasName) async {
    final mitraList = await getLemburMitraByGroup(groupId);
    for (final mitra in mitraList) {
      if (mitra.mitraId != null && mitra.absensiStatus != 'selesai') {
        await sendAbsensiReminder(mitra.id, groupId, pengawasName);
      }
    }
  }

  // ==================== EXPIRED CHECKER ====================

  Future<void> checkAndUpdateExpiredOvertime(String userId, String userRole) async {
    try {
      final now = DateTime.now();
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
      
      if (userRole == 'mitra') {
        query = query.where('user_id', isEqualTo: userId);
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
        final tanggalLembur = (data['tanggal'] as Timestamp).toDate();
        final jamSelesai = data['jam_selesai'] ?? '00:00';
        
        final parts = jamSelesai.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        
        final waktuSelesai = DateTime(
          tanggalLembur.year, tanggalLembur.month, tanggalLembur.day, hour, minute,
        );
        
        if (now.isAfter(waktuSelesai.add(const Duration(days: 1)))) {
          batch.update(doc.reference, {
            'status': 'kadaluarsa',
            'absensi_status': 'expired',
            'expired_at': FieldValue.serverTimestamp(),
            'expired_reason': 'Tidak melakukan absensi hingga batas waktu',
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('✅ Updated ${snapshot.docs.length} expired overtime');
      }
    } catch (e) {
      debugPrint('❌ Error checking expired overtime: $e');
    }
  }

  // ==================== HELPER METHODS ====================
  
  String formatTanggal(DateTime date) =>
      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  
  String formatTanggalShort(DateTime date) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(date);
  
  String formatWaktu(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  
  String getStatusText(String status) {
    switch (status) {
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'pending': return 'Pending';
      case 'selesai': return 'Selesai';
      case 'kadaluarsa': return 'Kadaluarsa';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }
  
  Color getStatusColor(String status) {
    switch (status) {
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'pending': return Colors.orange;
      case 'selesai': return Colors.blue;
      case 'kadaluarsa': return Colors.grey;
      case 'dibatalkan': return Colors.grey;
      default: return Colors.grey;
    }
  }
  
  String getJenisLemburLabel(String jenis) {
    switch (jenis) {
      case 'hari_kerja': return 'Hari Kerja';
      case 'hari_libur': return 'Hari Libur';
      default: return jenis;
    }
  }
  
  String getUrgensiLabel(String? urgensi) {
    switch (urgensi) {
      case 'rendah': return 'Rendah';
      case 'normal': return 'Normal';
      case 'tinggi': return 'Tinggi';
      case 'kritis': return 'Kritis';
      default: return urgensi ?? 'Normal';
    }
  }
  
  Color getUrgensiColor(String? urgensi) {
    switch (urgensi) {
      case 'rendah': return Colors.green;
      case 'normal': return Colors.blue;
      case 'tinggi': return Colors.orange;
      case 'kritis': return Colors.red;
      default: return Colors.blue;
    }
  }
  
  String getFungsiLabel(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi ?? 'Unknown';
    }
  }
  
  Color getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF1E3C72);
    }
  }
  
  String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
  
  String getAlamatLengkap(Map<String, dynamic>? lokasi) {
    if (lokasi == null) return '-';
    String alamat = lokasi['alamat'] ?? '-';
    final rt = lokasi['rt'];
    final rw = lokasi['rw'];
    if (rt != null && rt.toString().isNotEmpty) alamat += ' RT $rt';
    if (rw != null && rw.toString().isNotEmpty) alamat += ' RW $rw';
    return alamat;
  }
}