// lib/core/services/overtime_rate_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Service untuk mengelola tarif lembur
/// Handle loading, caching, kalkulasi, dan formatting
class OvertimeRateService {
  // Singleton pattern
  static final OvertimeRateService _instance = OvertimeRateService._internal();
  factory OvertimeRateService() => _instance;
  OvertimeRateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== KONSTANTA ====================
  static const String collectionSettings = 'settings';
  static const String docOvertimeRates = 'overtime_rates';
  static const double jamKerjaPerBulan = 173; // Standar ketenagakerjaan
  static const double maxJamLemburPerBulan = 60; // Batas maksimal lembur
  
  // ==================== CACHE ====================
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // ==================== LOAD RATES ====================
  
  /// Load overtime rates dari Firestore dengan caching
  /// [forceRefresh] - Jika true, akan memaksa fetch ulang dari Firestore
  Future<Map<String, dynamic>> loadOvertimeRates({bool forceRefresh = false}) async {
    // Return cache jika masih valid
    if (!forceRefresh && 
        _cachedRates != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      debugPrint('📦 OvertimeRateService: Using cached rates');
      return _cachedRates!;
    }

    try {
      debugPrint('🔄 OvertimeRateService: Fetching rates from Firestore...');
      
      final doc = await _firestore
          .collection(collectionSettings)
          .doc(docOvertimeRates)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Validasi kelengkapan data
        if (_validateRatesData(data)) {
          _cachedRates = data;
          _lastFetch = DateTime.now();
          debugPrint('✅ OvertimeRateService: Rates loaded successfully');
          return _cachedRates!;
        } else {
          debugPrint('⚠️ OvertimeRateService: Incomplete rates data, creating default...');
          await _createDefaultRatesDocument();
          _cachedRates = _getDefaultRates();
          _lastFetch = DateTime.now();
          return _cachedRates!;
        }
      }
      
      // Jika dokumen tidak ada, buat default
      debugPrint('⚠️ OvertimeRateService: No rates document found, creating default...');
      await _createDefaultRatesDocument();
      _cachedRates = _getDefaultRates();
      _lastFetch = DateTime.now();
      return _cachedRates!;
      
    } catch (e) {
      debugPrint('❌ OvertimeRateService: Error loading rates - $e');
      // Fallback ke default
      _cachedRates = _getDefaultRates();
      return _cachedRates!;
    }
  }

  /// Validasi kelengkapan data rates
  bool _validateRatesData(Map<String, dynamic> data) {
    final requiredFields = ['base_salary', 'rate_per_hour', 'weekday_rate', 'holiday_rate'];
    for (final field in requiredFields) {
      if (data[field] == null) {
        debugPrint('⚠️ Missing required field: $field');
        return false;
      }
    }
    
    // Validasi nested fields untuk weekday_rate
    final weekdayRate = data['weekday_rate'] as Map<String, dynamic>?;
    if (weekdayRate == null || 
        weekdayRate['first_hour_multiplier'] == null || 
        weekdayRate['next_hours_multiplier'] == null) {
      debugPrint('⚠️ Incomplete weekday_rate data');
      return false;
    }
    
    // Validasi nested fields untuk holiday_rate
    final holidayRate = data['holiday_rate'] as Map<String, dynamic>?;
    if (holidayRate == null || 
        holidayRate['first_8_hours_multiplier'] == null) {
      debugPrint('⚠️ Incomplete holiday_rate data');
      return false;
    }
    
    return true;
  }

  /// Buat dokumen default rates di Firestore
  Future<void> _createDefaultRatesDocument() async {
    try {
      final defaultRates = _getDefaultRates();
      await _firestore
          .collection(collectionSettings)
          .doc(docOvertimeRates)
          .set({
        ...defaultRates,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': 'system',
        'version': '1.0',
      });
      debugPrint('✅ OvertimeRateService: Default rates document created');
    } catch (e) {
      debugPrint('❌ OvertimeRateService: Failed to create default rates - $e');
    }
  }

  /// Default rates sesuai ketenagakerjaan
  Map<String, dynamic> _getDefaultRates() {
    const defaultGaji = 3000000.0; // Rp 3.000.000
    final upahPerJam = defaultGaji / jamKerjaPerBulan;
    
    return {
      'base_salary': defaultGaji,
      'rate_per_hour': upahPerJam.roundToDouble(),
      'jam_kerja_per_bulan': jamKerjaPerBulan,
      'max_jam_lembur_per_bulan': maxJamLemburPerBulan,
      'last_updated': null,
      'updated_by': 'system',
      'version': '1.0',
      
      // Tarif hari kerja
      'weekday_rate': {
        'first_hour_multiplier': 1.5,
        'next_hours_multiplier': 2.0,
        'description': '1.5x untuk jam pertama, 2.0x untuk jam berikutnya',
        'is_active': true,
      },
      
      // Tarif hari libur
      'holiday_rate': {
        'first_8_hours_multiplier': 2.0,
        'ninth_hour_multiplier': 3.0,
        'tenth_plus_multiplier': 4.0,
        'description': '2x (8 jam pertama), 3x (jam ke-9), 4x (jam ke-10+)',
        'is_active': true,
      },
    };
  }

  /// Clear cache (force reload next time)
  void clearCache() {
    _cachedRates = null;
    _lastFetch = null;
    debugPrint('🧹 OvertimeRateService: Cache cleared');
  }

  /// Update overtime rates (Admin only)
  Future<void> updateOvertimeRates({
    required Map<String, dynamic> newRates,
    required String updatedBy,
  }) async {
    try {
      // Validasi data baru
      if (!_validateRatesData(newRates)) {
        throw Exception('Data rates tidak lengkap');
      }
      
      await _firestore
          .collection(collectionSettings)
          .doc(docOvertimeRates)
          .set({
        ...newRates,
        'last_updated': DateTime.now().toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': updatedBy,
        'version': '1.0',
      }, SetOptions(merge: true));
      
      // Clear cache setelah update
      clearCache();
      debugPrint('✅ OvertimeRateService: Rates updated by $updatedBy');
    } catch (e) {
      debugPrint('❌ OvertimeRateService: Error updating rates - $e');
      rethrow;
    }
  }

  /// Get rates stream (real-time updates)
  Stream<Map<String, dynamic>> getRatesStream() {
    return _firestore
        .collection(collectionSettings)
        .doc(docOvertimeRates)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null && _validateRatesData(doc.data()!)) {
            _cachedRates = doc.data();
            _lastFetch = DateTime.now();
            return doc.data()!;
          }
          return _getDefaultRates();
        });
  }

  // ==================== CALCULATE COST ====================
  
  /// Kalkulasi biaya lembur (simple)
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

  /// Kalkulasi biaya lembur dengan breakdown detail
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
        'error': 'Invalid rate or hours',
      };
    }

    if (isHoliday) {
      return _calculateHolidayOvertimeDetailed(totalHours, ratePerHour, rates);
    } else {
      return _calculateWeekdayOvertimeDetailed(totalHours, ratePerHour, rates);
    }
  }

  double _calculateWeekdayOvertime(
    double totalHours, 
    double ratePerHour, 
    Map<String, dynamic> rates,
  ) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>? ?? {};
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;

    if (roundedHours <= 1) {
      totalCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      // Jam pertama
      totalCost += ratePerHour * firstHourMultiplier;
      // Jam berikutnya
      final remainingHours = roundedHours - 1;
      totalCost += remainingHours * ratePerHour * nextHoursMultiplier;
    }

    return totalCost;
  }

  Map<String, dynamic> _calculateWeekdayOvertimeDetailed(
    double totalHours,
    double ratePerHour,
    Map<String, dynamic> rates,
  ) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>? ?? {};
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double firstHourCost = 0;
    double remainingHoursCost = 0;
    double firstHourActual = 0;
    double remainingHoursActual = 0;

    if (roundedHours <= 1) {
      firstHourActual = roundedHours;
      firstHourCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      firstHourActual = 1;
      firstHourCost = ratePerHour * firstHourMultiplier;
      remainingHoursActual = roundedHours - 1;
      remainingHoursCost = remainingHoursActual * ratePerHour * nextHoursMultiplier;
    }

    final totalCost = firstHourCost + remainingHoursCost;

    return {
      'total_cost': totalCost,
      'rate_per_hour': ratePerHour,
      'total_hours': totalHours,
      'rounded_hours': roundedHours,
      'is_holiday': false,
      'breakdown': {
        'type': 'weekday',
        'first_hour': {
          'hours': firstHourActual,
          'multiplier': firstHourMultiplier,
          'cost': firstHourCost,
        },
        'remaining_hours': {
          'hours': remainingHoursActual,
          'multiplier': nextHoursMultiplier,
          'cost': remainingHoursCost,
        },
      },
    };
  }

  double _calculateHolidayOvertime(
    double totalHours,
    double ratePerHour,
    Map<String, dynamic> rates,
  ) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>? ?? {};
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;
    
    // 8 jam pertama
    final first8Hours = roundedHours < 8 ? roundedHours : 8;
    totalCost += first8Hours * ratePerHour * first8Multiplier;
    
    // Jam ke-9
    if (roundedHours > 8) {
      final ninthHour = roundedHours < 9 ? roundedHours - 8 : 1;
      totalCost += ninthHour * ratePerHour * ninthMultiplier;
    }
    
    // Jam ke-10 dan seterusnya
    if (roundedHours > 9) {
      final remainingHours = roundedHours - 9;
      totalCost += remainingHours * ratePerHour * tenthMultiplier;
    }
    
    return totalCost;
  }

  Map<String, dynamic> _calculateHolidayOvertimeDetailed(
    double totalHours,
    double ratePerHour,
    Map<String, dynamic> rates,
  ) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>? ?? {};
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    
    double first8Cost = 0, ninthHourCost = 0, tenthPlusCost = 0;
    double first8Actual = 0, ninthActual = 0, tenthActual = 0;
    
    // 8 jam pertama
    first8Actual = roundedHours < 8 ? roundedHours : 8;
    first8Cost = first8Actual * ratePerHour * first8Multiplier;
    
    // Jam ke-9
    if (roundedHours > 8) {
      ninthActual = roundedHours < 9 ? roundedHours - 8 : 1;
      ninthHourCost = ninthActual * ratePerHour * ninthMultiplier;
    }
    
    // Jam ke-10+
    if (roundedHours > 9) {
      tenthActual = roundedHours - 9;
      tenthPlusCost = tenthActual * ratePerHour * tenthMultiplier;
    }
    
    final totalCost = first8Cost + ninthHourCost + tenthPlusCost;

    return {
      'total_cost': totalCost,
      'rate_per_hour': ratePerHour,
      'total_hours': totalHours,
      'rounded_hours': roundedHours,
      'is_holiday': true,
      'breakdown': {
        'type': 'holiday',
        'first_8_hours': {
          'hours': first8Actual,
          'multiplier': first8Multiplier,
          'cost': first8Cost,
        },
        'ninth_hour': {
          'hours': ninthActual,
          'multiplier': ninthMultiplier,
          'cost': ninthHourCost,
        },
        'tenth_plus_hours': {
          'hours': tenthActual,
          'multiplier': tenthMultiplier,
          'cost': tenthPlusCost,
        },
      },
    };
  }

  /// Hitung total biaya lembur saja (tanpa tunjangan)
  double calculateTotalLemburCost({
    required double totalHours,
    required bool isHoliday,
    required Map<String, dynamic> rates,
    required int jumlahMitra,
  }) {
    final biayaLemburPerMitra = calculateOvertimeCost(
      totalHours: totalHours,
      isHoliday: isHoliday,
      rates: rates,
    );
    
    return biayaLemburPerMitra * jumlahMitra;
  }

  /// Dapatkan rate per hour
  double getRatePerHour(Map<String, dynamic> rates) {
    return (rates['rate_per_hour'] as num?)?.toDouble() ?? 0;
  }

  /// Dapatkan base salary
  double getBaseSalary(Map<String, dynamic> rates) {
    return (rates['base_salary'] as num?)?.toDouble() ?? 0;
  }

  /// Cek apakah weekday rate aktif
  bool isWeekdayRateActive(Map<String, dynamic> rates) {
    final weekdayRate = rates['weekday_rate'] as Map<String, dynamic>?;
    return weekdayRate?['is_active'] == true;
  }

  /// Cek apakah holiday rate aktif
  bool isHolidayRateActive(Map<String, dynamic> rates) {
    final holidayRate = rates['holiday_rate'] as Map<String, dynamic>?;
    return holidayRate?['is_active'] == true;
  }

  /// Dapatkan max jam lembur per bulan
  double getMaxJamLemburPerBulan(Map<String, dynamic> rates) {
    return (rates['max_jam_lembur_per_bulan'] as num?)?.toDouble() ?? maxJamLemburPerBulan;
  }

  /// Dapatkan jam kerja per bulan
  double getJamKerjaPerBulan(Map<String, dynamic> rates) {
    return (rates['jam_kerja_per_bulan'] as num?)?.toDouble() ?? jamKerjaPerBulan;
  }

  // ==================== FORMATTING ====================
  
  /// Format ke Rupiah lengkap (Rp 1.000.000)
  String formatRupiah(dynamic value) {
    final amount = value is double ? value : (value as num).toDouble();
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount.round())}';
  }

  /// Format ke Rupiah compact (Rp 1 Jt / Rp 500 Rb)
  String formatRupiahCompact(dynamic value) {
    final amount = value is double ? value : (value as num).toDouble();
    
    if (amount >= 1000000) {
      final juta = amount / 1000000;
      final decimal = amount % 1000000 == 0 ? 0 : 1;
      return 'Rp ${juta.toStringAsFixed(decimal)} Jt';
    } else if (amount >= 1000) {
      final ribu = amount / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    } else {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  /// Format jam (1.5 -> "1 jam 30 menit")
  String formatJam(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    
    if (h == 0 && m == 0) return '0 menit';
    if (h == 0) return '$m menit';
    if (m == 0) return '$h jam';
    return '$h jam $m menit';
  }

  /// Format multiplier untuk display
  String formatMultiplier(double multiplier) {
    return '${multiplier}x';
  }

  /// Debug print rates (untuk development)
  void debugPrintRates(Map<String, dynamic> rates) {
    debugPrint('========== OVERTIME RATES ==========');
    debugPrint('Base Salary: ${formatRupiah(rates['base_salary'])}');
    debugPrint('Rate/Hour: ${formatRupiah(rates['rate_per_hour'])}');
    debugPrint('Jam Kerja/Bulan: ${rates['jam_kerja_per_bulan']} jam');
    debugPrint('Max Lembur/Bulan: ${rates['max_jam_lembur_per_bulan']} jam');
    debugPrint('');
    debugPrint('--- Weekday Rates ---');
    final weekday = rates['weekday_rate'] as Map<String, dynamic>?;
    debugPrint('  First Hour: ${weekday?['first_hour_multiplier']}x');
    debugPrint('  Next Hours: ${weekday?['next_hours_multiplier']}x');
    debugPrint('  Active: ${weekday?['is_active']}');
    debugPrint('  Desc: ${weekday?['description']}');
    debugPrint('');
    debugPrint('--- Holiday Rates ---');
    final holiday = rates['holiday_rate'] as Map<String, dynamic>?;
    debugPrint('  First 8 Hours: ${holiday?['first_8_hours_multiplier']}x');
    debugPrint('  9th Hour: ${holiday?['ninth_hour_multiplier']}x');
    debugPrint('  10th+ Hours: ${holiday?['tenth_plus_multiplier']}x');
    debugPrint('  Active: ${holiday?['is_active']}');
    debugPrint('  Desc: ${holiday?['description']}');
    debugPrint('=====================================');
  }
}