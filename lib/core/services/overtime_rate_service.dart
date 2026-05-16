import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OvertimeRateService {
  static final OvertimeRateService _instance = OvertimeRateService._internal();
  factory OvertimeRateService() => _instance;
  OvertimeRateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== CACHE ====================
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const double jamKerjaPerBulan = 173;

  // ==================== LOAD RATES ====================
  
  Future<Map<String, dynamic>> loadOvertimeRates({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedRates != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedRates!;
    }

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .get();

      if (doc.exists) {
        _cachedRates = doc.data();
        _lastFetch = DateTime.now();
        return _cachedRates!;
      }
    } catch (e) {
      debugPrint('Error loading overtime rates: $e');
    }

    return _getDefaultRates();
  }

  Map<String, dynamic> _getDefaultRates() {
    const defaultGaji = 3000000.0;
    final upahPerJam = defaultGaji / jamKerjaPerBulan;
    
    return {
      'base_salary': defaultGaji,
      'rate_per_hour': upahPerJam,
      'last_updated': null,
      'updated_by': 'system',
      'weekday_rate': {
        'first_hour_multiplier': 1.5,
        'next_hours_multiplier': 2.0,
        'is_active': true,
      },
      'holiday_rate': {
        'first_8_hours_multiplier': 2.0,
        'ninth_hour_multiplier': 3.0,
        'tenth_plus_multiplier': 4.0,
        'is_active': true,
      },
    };
  }

  void clearCache() {
    _cachedRates = null;
    _lastFetch = null;
  }

  // ==================== CALCULATE COST ====================
  
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

  double _calculateWeekdayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>;
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;

    if (roundedHours <= 1) {
      totalCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      totalCost += ratePerHour * firstHourMultiplier;
      final remainingHours = roundedHours - 1;
      totalCost += remainingHours * ratePerHour * nextHoursMultiplier;
    }

    return totalCost;
  }

  double _calculateHolidayOvertime(double totalHours, double ratePerHour, Map<String, dynamic> rates) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>;
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
      final remainingHours = roundedHours - 9;
      totalCost += remainingHours * ratePerHour * tenthMultiplier;
    }
    
    return totalCost;
  }

  // ==================== FORMAT RUPIAH ====================
  
  String formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  String formatRupiahCompact(double value) {
    if (value >= 1000000) {
      final juta = value / 1000000;
      return 'Rp ${juta.toStringAsFixed(1)} Jt';
    } else if (value >= 1000) {
      final ribu = value / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    } else {
      return 'Rp ${value.toStringAsFixed(0)}';
    }
  }
}