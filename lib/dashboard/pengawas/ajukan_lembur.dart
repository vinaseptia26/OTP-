// FILE: lib/dashboard/pengawas/lembur/ajukan_lembur_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// OVERTIME SERVICE - SINGLE SOURCE OF TRUTH UNTUK TARIF LEMBUR
// ============================================================================
class OvertimeService {
  static final OvertimeService _instance = OvertimeService._internal();
  factory OvertimeService() => _instance;
  OvertimeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache dengan timeout 5 menit
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const double jamKerjaPerBulan = 173;

  /// Load tarif dari Firestore dengan cache mechanism
  Future<Map<String, dynamic>> loadOvertimeRates({bool forceRefresh = false}) async {
    // Return cache jika masih fresh dan tidak dipaksa refresh
    if (!forceRefresh && 
        _cachedRates != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      debugPrint('📦 Menggunakan cached overtime rates');
      return _cachedRates!;
    }

    debugPrint('🔄 Mengambil overtime rates dari Firestore');
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .get(const GetOptions(source: Source.server));

      if (doc.exists) {
        _cachedRates = doc.data();
        _lastFetch = DateTime.now();
        debugPrint('✅ Overtime rates berhasil dimuat');
        return _cachedRates!;
      }
    } catch (e) {
      debugPrint('❌ Error loading overtime rates: $e');
    }

    // Default values jika tidak ada data di Firestore
    debugPrint('⚠️ Menggunakan default overtime rates');
    return _getDefaultRates();
  }

  /// Default rates berdasarkan UU Ketenagakerjaan
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

  /// Hitung biaya lembur berdasarkan jam dan jenis hari
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

  double _calculateWeekdayOvertime(
    double totalHours, 
    double ratePerHour, 
    Map<String, dynamic> rates
  ) {
    final weekdayRates = rates['weekday_rate'] as Map<String, dynamic>;
    final firstHourMultiplier = (weekdayRates['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
    final nextHoursMultiplier = (weekdayRates['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;

    // Pembulatan ke atas untuk perhitungan yang adil
    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;

    if (roundedHours <= 1) {
      totalCost = roundedHours * ratePerHour * firstHourMultiplier;
    } else {
      // Jam pertama
      totalCost += ratePerHour * firstHourMultiplier;
      
      // Jam berikutnya (jam 2,3,4 dst)
      final remainingHours = roundedHours - 1;
      totalCost += remainingHours * ratePerHour * nextHoursMultiplier;
    }

    return totalCost;
  }

  double _calculateHolidayOvertime(
    double totalHours, 
    double ratePerHour, 
    Map<String, dynamic> rates
  ) {
    final holidayRates = rates['holiday_rate'] as Map<String, dynamic>;
    final first8Multiplier = (holidayRates['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
    final ninthMultiplier = (holidayRates['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
    final tenthMultiplier = (holidayRates['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;

    final roundedHours = totalHours.ceilToDouble();
    double totalCost = 0;
    
    // 8 jam pertama
    final first8Hours = math.min(roundedHours, 8);
    totalCost += first8Hours * ratePerHour * first8Multiplier;
    
    // Jam ke-9
    if (roundedHours > 8) {
      final ninthHour = math.min(roundedHours - 8, 1);
      totalCost += ninthHour * ratePerHour * ninthMultiplier;
    }
    
    // Jam ke-10 dan seterusnya
    if (roundedHours > 9) {
      final remainingHours = roundedHours - 9;
      totalCost += remainingHours * ratePerHour * tenthMultiplier;
    }
    
    return totalCost;
  }

  /// Format rupiah dengan pemisah ribuan
  String formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';
  }

  /// Format rupiah compact (misal: Rp 1,5 Jt)
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

  /// Dapatkan detail tarif untuk ditampilkan
  Map<String, dynamic> getRateDetails(Map<String, dynamic> rates) {
    final weekday = rates['weekday_rate'] as Map<String, dynamic>;
    final holiday = rates['holiday_rate'] as Map<String, dynamic>;
    final ratePerHour = rates['rate_per_hour'] as double;

    return {
      'weekday': {
        'first_hour': ratePerHour * (weekday['first_hour_multiplier'] as double),
        'first_hour_multiplier': weekday['first_hour_multiplier'],
        'next_hours': ratePerHour * (weekday['next_hours_multiplier'] as double),
        'next_hours_multiplier': weekday['next_hours_multiplier'],
      },
      'holiday': {
        'first_8_hours': ratePerHour * (holiday['first_8_hours_multiplier'] as double),
        'first_8_hours_multiplier': holiday['first_8_hours_multiplier'],
        'ninth_hour': ratePerHour * (holiday['ninth_hour_multiplier'] as double),
        'ninth_hour_multiplier': holiday['ninth_hour_multiplier'],
        'tenth_plus': ratePerHour * (holiday['tenth_plus_multiplier'] as double),
        'tenth_plus_multiplier': holiday['tenth_plus_multiplier'],
      },
      'rate_per_hour': ratePerHour,
    };
  }

  /// Clear cache (panggil setelah update tarif)
  void clearCache() {
    _cachedRates = null;
    _lastFetch = null;
    debugPrint('🧹 Overtime rates cache cleared');
  }
}

// ============================================================================
// NOTIFICATION SERVICE
// ============================================================================
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String emailJsServiceId = 'Overtime_PGE_Kamojang';
  static const String emailJsTemplateId = 'overtime_pge_approval';
  static const String emailJsUserId = 'C3mihi6PZC5uH4gyx';
  static const String emailJsApiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  static const String fonnteApiKey = 'Eo4VfZvp2mv9Fg6A3DRE6Uq7ydVrbRs';
  static const String fonnteApiUrl = 'https://api.fonnte.com/send';

  Future<void> sendManagerNotification({
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required DateTime tanggal,
    required double totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required List<String> lemburIds,
    required Map<String, dynamic> overtimeRates,
  }) async {
    try {
      final managers = await _getManagersByFungsi(fungsi);
      
      if (managers.isEmpty) {
        debugPrint('⚠️ Tidak ada manager untuk fungsi $fungsi');
        return;
      }

      final tanggalFormat = DateFormat('dd/MM/yyyy').format(tanggal);
      final biayaFormat = OvertimeService().formatRupiah(totalBiaya);
      final ratePerHour = OvertimeService().formatRupiahCompact(
        (overtimeRates['rate_per_hour'] as num?)?.toDouble() ?? 0
      );

      final groupId = lemburIds.isNotEmpty ? lemburIds.first : '';
      final priority = urgensi == 'kritis' ? 1 : 
                      urgensi == 'tinggi' ? 2 : 
                      urgensi == 'normal' ? 3 : 4;

      for (final manager in managers) {
        final managerId = manager['id'];
        final email = manager['email'] ?? '';
        final noHp = manager['no_hp'] ?? '';

        await _createFirestoreNotification(
          managerId: managerId,
          pengawasNama: pengawasNama,
          fungsi: fungsi,
          jumlahMitra: jumlahMitra,
          tanggal: tanggalFormat,
          totalBiaya: biayaFormat,
          urgensi: urgensi,
          isOutsideRadius: isOutsideRadius,
          groupId: groupId,
          priority: priority,
          ratePerHour: ratePerHour,
        );

        if (email.isNotEmpty) {
          _sendEmail(
            to: email,
            toName: manager['nama_lengkap'] ?? 'Manager',
            pengawasNama: pengawasNama,
            fungsi: fungsi,
            jumlahMitra: jumlahMitra,
            tanggal: tanggalFormat,
            totalBiaya: biayaFormat,
            urgensi: urgensi,
            isOutsideRadius: isOutsideRadius,
            groupId: groupId,
            ratePerHour: ratePerHour,
          );
        }

        if (noHp.isNotEmpty) {
          _sendWhatsApp(
            phoneNumber: noHp,
            managerName: manager['nama_lengkap'] ?? 'Manager',
            pengawasNama: pengawasNama,
            fungsi: fungsi,
            jumlahMitra: jumlahMitra,
            tanggal: tanggalFormat,
            totalBiaya: biayaFormat,
            urgensi: urgensi,
            isOutsideRadius: isOutsideRadius,
            groupId: groupId,
            ratePerHour: ratePerHour,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sendManagerNotification: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getManagersByFungsi(String fungsi) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .where('fungsi', isEqualTo: fungsi)
          .where('status_akun', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'nama_lengkap': data['nama_lengkap'] ?? 'Manager',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error get managers: $e');
      return [];
    }
  }

  Future<void> _createFirestoreNotification({
    required String managerId,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required String groupId,
    required int priority,
    required String ratePerHour,
  }) async {
    try {
      final notificationRef = _firestore
          .collection('notifications')
          .doc(managerId)
          .collection('items')
          .doc();

      await notificationRef.set({
        'type': 'lembur_submitted',
        'title': '📋 Pengajuan Lembur Baru',
        'message': '''
👤 Pengawas: $pengawasNama ($fungsi)
👥 Mitra: $jumlahMitra orang
📅 Tanggal: $tanggal
💰 Biaya: $totalBiaya
💵 Rate/Jam: $ratePerHour
⚡ Urgensi: ${urgensi.toUpperCase()}
${isOutsideRadius ? '⚠️ LOKASI LUAR RADIUS' : ''}
''',
        'data': {
          'group_id': groupId,
          'pengawas_id': FirebaseAuth.instance.currentUser?.uid ?? '',
          'pengawas_nama': pengawasNama,
          'fungsi': fungsi,
          'jumlah_mitra': jumlahMitra,
          'tanggal': tanggal,
          'total_biaya': totalBiaya,
          'urgensi': urgensi,
          'is_outside_radius': isOutsideRadius,
          'rate_per_hour': ratePerHour,
        },
        'read': false,
        'created_at': FieldValue.serverTimestamp(),
        'priority': priority,
      });
    } catch (e) {
      debugPrint('❌ Error create notification: $e');
    }
  }

  void _sendEmail({
    required String to,
    required String toName,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required String groupId,
    required String ratePerHour,
  }) {
    // Implementasi email (async tapi tidak perlu await)
    http.post(
      Uri.parse(emailJsApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': emailJsServiceId,
        'template_id': emailJsTemplateId,
        'user_id': emailJsUserId,
        'template_params': {
          'to_email': to,
          'to_name': toName,
          'from_name': 'Sistem Lembur PGE',
          'pengawas_nama': pengawasNama,
          'fungsi': fungsi.toUpperCase(),
          'jumlah_mitra': jumlahMitra.toString(),
          'tanggal': tanggal,
          'total_biaya': totalBiaya,
          'urgensi': urgensi.toUpperCase(),
          'lokasi_status': isOutsideRadius ? 'LUAR RADIUS' : 'DALAM RADIUS',
          'rate_per_hour': ratePerHour,
          'group_id': groupId.substring(0, 8),
          'link_approval': 'https://yourapp.firebaseapp.com/approval/$groupId',
        },
      }),
    ).timeout(const Duration(seconds: 10)).catchError((e) {
      debugPrint('❌ Error send email: $e');
      return http.Response('Error', 500); // Return response
    });
  }

  void _sendWhatsApp({
    required String phoneNumber,
    required String managerName,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required String groupId,
    required String ratePerHour,
  }) {
    try {
      String formattedNumber = phoneNumber;
      if (formattedNumber.startsWith('0')) {
        formattedNumber = '62${formattedNumber.substring(1)}';
      }
      if (!formattedNumber.startsWith('62')) {
        formattedNumber = '62$formattedNumber';
      }

      final message = '''
🔔 *PENGAJUAN LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Yth. Bapak/Ibu *$managerName*

Ada pengajuan lembur baru yang membutuhkan persetujuan:

👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi.toUpperCase()}
👥 *Mitra:* $jumlahMitra orang
📅 *Tanggal:* $tanggal
💰 *Estimasi Biaya:* $totalBiaya
💵 *Rate/Jam:* $ratePerHour
⚡ *Urgensi:* ${urgensi.toUpperCase()}
📍 *Status:* ${isOutsideRadius ? '⚠️ LUAR RADIUS' : '✅ DALAM RADIUS'}

━━━━━━━━━━━━━━━━━━━
*ID Pengajuan:* ${groupId.substring(0, 8)}...
*Status:* Menunggu Persetujuan
━━━━━━━━━━━━━━━━━━━

🔗 *Link Approve:*
https://yourapp.firebaseapp.com/approval/$groupId

Silakan login ke aplikasi untuk melakukan persetujuan.

Terima kasih.
''';

      http.post(
        Uri.parse(fonnteApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': fonnteApiKey,
        },
        body: json.encode({
          'target': formattedNumber,
          'message': message,
          'countryCode': '62',
        }),
      ).timeout(const Duration(seconds: 10)).catchError((e) {
        debugPrint('❌ Error send WhatsApp: $e');
        return http.Response('Error', 500); // Return response
      });
    } catch (e) {
      debugPrint('❌ Error prepare WhatsApp: $e');
    }
  }
}

// ============================================================================
// LOCATION SERVICE
// ============================================================================
class LocationService {
  static const double kantorLat = -7.134711;
  static const double kantorLng = 107.799540;
  static const double radiusKantor = 300; // meter
  static const String alamatKantor = "PT Pertamina Geothermal Energy Area Kamojang";

  // Daftar lokasi proyek PGE
  static final List<Map<String, dynamic>> proyekLocations = [
    {
      'name': 'Proyek Sumur KMJ-42',
      'lat': -7.135678,
      'lng': 107.800123,
      'address': 'Area Sumur KMJ-42, Lapangan Kamojang',
    },
    {
      'name': 'Proyek Sumur KMJ-57',
      'lat': -7.136789,
      'lng': 107.801234,
      'address': 'Area Sumur KMJ-57, Lapangan Kamojang',
    },
    {
      'name': 'Proyek Pembangkit Unit 1',
      'lat': -7.133456,
      'lng': 107.798765,
      'address': 'Area Pembangkit Unit 1, Kamojang',
    },
    {
      'name': 'Proyek Pembangkit Unit 2',
      'lat': -7.134567,
      'lng': 107.797654,
      'address': 'Area Pembangkit Unit 2, Kamojang',
    },
    {
      'name': 'Proyek Pembangkit Unit 3',
      'lat': -7.135678,
      'lng': 107.796543,
      'address': 'Area Pembangkit Unit 3, Kamojang',
    },
    {
      'name': 'Proyek Wellpad A',
      'lat': -7.137890,
      'lng': 107.802345,
      'address': 'Wellpad A, Lapangan Kamojang',
    },
    {
      'name': 'Proyek Wellpad B',
      'lat': -7.138901,
      'lng': 107.803456,
      'address': 'Wellpad B, Lapangan Kamojang',
    },
    {
      'name': 'Proyek Wellpad C',
      'lat': -7.139012,
      'lng': 107.804567,
      'address': 'Wellpad C, Lapangan Kamojang',
    },
    {
      'name': 'Proyek Pipeline Utama',
      'lat': -7.140123,
      'lng': 107.805678,
      'address': 'Koridor Pipeline, Kamojang',
    },
    {
      'name': 'Proyek Gardu Induk',
      'lat': -7.141234,
      'lng': 107.806789,
      'address': 'Area Gardu Induk, Kamojang',
    },
  ];

  static Future<List<Map<String, dynamic>>?> searchLocation(String query) async {
    try {
      // Cari di lokasi proyek dulu
      final proyekResults = proyekLocations.where((loc) {
        return loc['name'].toLowerCase().contains(query.toLowerCase()) ||
               loc['address'].toLowerCase().contains(query.toLowerCase());
      }).toList();

      if (proyekResults.isNotEmpty) {
        return proyekResults;
      }

      // Jika tidak ada di proyek, cari di OpenStreetMap
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=5'
        '&addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'OvertimeApp-PGE/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) {
            return {
              'lat': double.parse(item['lat']),
              'lng': double.parse(item['lon']),
              'address': item['display_name'],
              'name': _getDisplayName(item['display_name']),
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Search location error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    try {
      // Cek apakah lokasi ini termasuk proyek
      for (final proyek in proyekLocations) {
        final distance = calculateDistance(lat, lng, proyek['lat'], proyek['lng']);
        if (distance < 100) { // Dalam radius 100 meter dari proyek
          return {
            'address': proyek['address'],
            'lat': lat,
            'lng': lng,
            'name': proyek['name'],
            'is_proyek': true,
          };
        }
      }

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng'
        '&format=json'
        '&addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'OvertimeApp-PGE/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'address': data['display_name'],
          'lat': lat,
          'lng': lng,
          'is_proyek': false,
        };
      }
    } catch (e) {
      debugPrint('⚠️ Reverse geocode error: $e');
    }
    return null;
  }

  static Future<bool> detectFakeGPS() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && 
          permission != LocationPermission.whileInUse) {
        return false;
      }

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (position.isMocked) return true;
      if (position.accuracy > 100) return true;

      return false;
    } catch (e) {
      debugPrint('❌ Error detect fake GPS: $e');
      return false;
    }
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static bool isOutsideRadius(double lat, double lng) {
    final distance = calculateDistance(kantorLat, kantorLng, lat, lng);
    return distance > radiusKantor;
  }

  static String _getDisplayName(String fullAddress) {
    final parts = fullAddress.split(',');
    if (parts.length > 3) {
      return parts.sublist(0, 3).join(',');
    }
    return fullAddress;
  }
}

// ============================================================================
// MITRA LIMIT SERVICE
// ============================================================================
class MitraLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const double maxJamBulanan = 60; // Batasan 60 jam per bulan

  Future<Map<String, dynamic>> checkMitraLimit({
    required String mitraId,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    try {
      final tahunBulan = DateFormat('yyyy-MM').format(tanggal);
      
      final snapshot = await _firestore
          .collection('lembur')
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
      debugPrint('❌ Error check mitra limit: $e');
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
    if (jam % 1 == 0) {
      return '${jam.toInt()} jam';
    } else {
      return '${jam.toStringAsFixed(1)} jam';
    }
  }
}

// ============================================================================
// MODEL: OvertimeRateDisplay
// ============================================================================
class OvertimeRateDisplay {
  final double ratePerJam;
  final double weekdayFirstHour;
  final double weekdayNextHours;
  final double holidayFirst8Hours;
  final double holidayNinthHour;
  final double holidayTenthPlus;
  final double weekdayFirstMultiplier;
  final double weekdayNextMultiplier;
  final double holidayFirst8Multiplier;
  final double holidayNinthMultiplier;
  final double holidayTenthMultiplier;

  OvertimeRateDisplay.fromRates(Map<String, dynamic> rates) : 
    ratePerJam = (rates['rate_per_hour'] as num?)?.toDouble() ?? 0,
    weekdayFirstMultiplier = ((rates['weekday_rate'] as Map<String, dynamic>)['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5,
    weekdayNextMultiplier = ((rates['weekday_rate'] as Map<String, dynamic>)['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0,
    holidayFirst8Multiplier = ((rates['holiday_rate'] as Map<String, dynamic>)['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0,
    holidayNinthMultiplier = ((rates['holiday_rate'] as Map<String, dynamic>)['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0,
    holidayTenthMultiplier = ((rates['holiday_rate'] as Map<String, dynamic>)['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0,
    weekdayFirstHour = ((rates['rate_per_hour'] as num?)?.toDouble() ?? 0) * (((rates['weekday_rate'] as Map<String, dynamic>)['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5),
    weekdayNextHours = ((rates['rate_per_hour'] as num?)?.toDouble() ?? 0) * (((rates['weekday_rate'] as Map<String, dynamic>)['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0),
    holidayFirst8Hours = ((rates['rate_per_hour'] as num?)?.toDouble() ?? 0) * (((rates['holiday_rate'] as Map<String, dynamic>)['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0),
    holidayNinthHour = ((rates['rate_per_hour'] as num?)?.toDouble() ?? 0) * (((rates['holiday_rate'] as Map<String, dynamic>)['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0),
    holidayTenthPlus = ((rates['rate_per_hour'] as num?)?.toDouble() ?? 0) * (((rates['holiday_rate'] as Map<String, dynamic>)['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0);
}

// ============================================================================
// AJUKAN LEMBUR PAGE - MAIN SCREEN
// ============================================================================
class AjukanLemburPage extends StatefulWidget {
  const AjukanLemburPage({super.key});

  @override
  State<AjukanLemburPage> createState() => _AjukanLemburPageState();
}

class _AjukanLemburPageState extends State<AjukanLemburPage> with SingleTickerProviderStateMixin {
  // ============== SERVICES ==============
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OvertimeService _overtimeService = OvertimeService();
  final MitraLimitService _mitraLimitService = MitraLimitService();
  final ScrollController _scrollController = ScrollController();
  
  // ============== ANIMATION ==============
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ============== DATA PENGGUNA ==============
  String? pengawasId;
  String? fungsiPengawas;
  String? namaPengawas;
  String? jabatanPengawas;
  bool isLoadingUser = true;

  // ============== TARIF LEMBUR ==============
  Map<String, dynamic>? _overtimeRates;
  OvertimeRateDisplay? _rateDisplay;
  bool isLoadingRates = true;
  String? rateErrorMessage;

  // ============== MITRA ==============
  List<Map<String, dynamic>> selectedMiras = [];
  List<String> selectedMitraIds = [];

  // ============== WAKTU ==============
  DateTime? tanggalLembur;
  TimeOfDay? jamMulai;
  TimeOfDay? jamSelesai;
  double totalJam = 0.0;
  double totalBiaya = 0.0;

  // ============== OPSI ==============
  String jenisLembur = "hari_kerja";
  String urgensi = "normal";
  
  // ============== PILIHAN LOKASI ==============
  String lokasiPilihan = "kantor"; // "kantor" atau "proyek"
  String? proyekTerpilih;

  // ============== CONTROLLER ==============
  final alasanController = TextEditingController();
  final catatanTambahanController = TextEditingController();

  // ============== LOKASI ==============
  LatLng? lokasiLatLng;
  String? alamatLokasi;
  bool loadingLokasi = false;
  bool isSubmitting = false;
  MapController? mapController;
  String? sourceProvider;
  
  // ============== SEARCH ==============
  final searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  Timer? _searchDebounce;

  // ============== KONSTANTA ==============
  static const double kantorLat = -7.134711;
  static const double kantorLng = 107.799540;
  static const double radiusKantor = 300;

  // ============== OVERRIDE & LIMIT ==============
  bool isOverride = false;
  Map<String, dynamic>? limitInfo;

  // ============== VALID FUNGSI ==============
  final List<String> validFungsi = ['operation', 'lab', 'maintenance', 'hsse', 'gpr', 'bs'];

  // ============== INIT & DISPOSE ==============
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    alasanController.dispose();
    catatanTambahanController.dispose();
    _scrollController.dispose();
    mapController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ============== INITIALIZATION ==============
  Future<void> _initializeApp() async {
    mapController = MapController();
    
    // Load data secara parallel
    await Future.wait([
      _loadUserData(),
      _loadOvertimeRates(),
    ]);
    
    // Set default location ke kantor
    if (mounted) {
      setState(() {
        lokasiLatLng = LatLng(kantorLat, kantorLng);
        alamatLokasi = LocationService.alamatKantor;
        sourceProvider = 'kantor';
        lokasiPilihan = 'kantor';
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => isLoadingUser = true);

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!userDoc.exists) {
        _showErrorSnackbar("❌ Data user tidak ditemukan");
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final data = userDoc.data();
      
      final userRole = data?['role']?.toString().toLowerCase() ?? '';
      if (userRole != 'pengawas') {
        _showErrorSnackbar("❌ Hanya pengawas yang dapat mengajukan lembur");
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final userFungsi = data?['fungsi']?.toString().toLowerCase() ?? '';
      if (userFungsi.isEmpty) {
        _showErrorSnackbar("❌ Fungsi pengawas tidak ditemukan");
        return;
      }

      if (!validFungsi.contains(userFungsi)) {
        _showErrorSnackbar("❌ Fungsi Anda ($userFungsi) tidak valid");
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (mounted) {
        setState(() {
          pengawasId = _auth.currentUser?.uid;
          namaPengawas = data?['nama_lengkap'] ?? data?['displayName'] ?? 'Unknown';
          jabatanPengawas = data?['jabatan'] ?? 'Pengawas';
          fungsiPengawas = userFungsi;
          isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      _showErrorSnackbar('❌ Gagal memuat data pengguna');
      if (mounted) setState(() => isLoadingUser = false);
    }
  }

  Future<void> _loadOvertimeRates() async {
    setState(() {
      isLoadingRates = true;
      rateErrorMessage = null;
    });

    try {
      final rates = await _overtimeService.loadOvertimeRates();
      
      if (mounted) {
        setState(() {
          _overtimeRates = rates;
          _rateDisplay = OvertimeRateDisplay.fromRates(rates);
          isLoadingRates = false;
        });
        debugPrint('✅ Tarif lembur berhasil dimuat');
      }
    } catch (e) {
      debugPrint('❌ Error loading overtime rates: $e');
      if (mounted) {
        setState(() {
          isLoadingRates = false;
          rateErrorMessage = 'Gagal memuat tarif: $e';
        });
        _showErrorSnackbar('❌ Gagal memuat tarif lembur');
      }
    }
  }

  // ============== PERHITUNGAN BIAYA ==============
  void _recalculateBiaya() {
    if (jamMulai == null || jamSelesai == null || tanggalLembur == null || _overtimeRates == null) return;
    
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || 
                      tanggalLembur!.weekday == DateTime.sunday;
    
    final startMinutes = jamMulai!.hour * 60 + jamMulai!.minute;
    final endMinutes = jamSelesai!.hour * 60 + jamSelesai!.minute;
    final diff = endMinutes - startMinutes;
    
    if (diff > 0) {
      totalJam = diff / 60.0;
      
      final biayaPerMitra = _overtimeService.calculateOvertimeCost(
        totalHours: totalJam,
        isHoliday: isWeekend,
        rates: _overtimeRates!,
      );
      
      final jumlahMitra = selectedMiras.length;
      
      setState(() {
        totalBiaya = biayaPerMitra * jumlahMitra;
      });
    }
  }

  // ============== CEK LIMIT MITRA ==============
  Future<void> _checkMitraLimits() async {
    if (tanggalLembur == null || totalJam <= 0 || selectedMiras.isEmpty) return;

    final results = <String, dynamic>{};
    bool adaYangMelebihi = false;

    for (final mitra in selectedMiras) {
      final result = await _mitraLimitService.checkMitraLimit(
        mitraId: mitra['id'],
        tanggal: tanggalLembur!,
        tambahanJam: totalJam,
      );
      
      results[mitra['id']] = result;
      if (result['is_exceeded']) {
        adaYangMelebihi = true;
      }
    }

    if (mounted) {
      setState(() {
        limitInfo = results;
        isOverride = adaYangMelebihi;
        
        // Auto set urgensi ke kritis jika override
        if (adaYangMelebihi) {
          urgensi = 'kritis';
        }
      });
    }
  }

  // ============== LOKASI ==============
  Future<void> _pilihLokasiKantor() async {
    setState(() {
      lokasiPilihan = 'kantor';
      lokasiLatLng = LatLng(kantorLat, kantorLng);
      alamatLokasi = LocationService.alamatKantor;
      sourceProvider = 'kantor';
      proyekTerpilih = null;
    });
    _moveMapToLocation();
  }

  Future<void> _pilihLokasiProyek() async {
    final proyekList = LocationService.proyekLocations;
    
    final selectedProyek = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Pilih Lokasi Proyek",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: proyekList.length,
                  itemBuilder: (context, index) {
                    final proyek = proyekList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                          child: const Icon(Icons.location_on, color: Color(0xFF1976D2)),
                        ),
                        title: Text(
                          proyek['name'],
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(proyek['address']),
                        onTap: () => Navigator.pop(context, proyek),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedProyek != null && mounted) {
      setState(() {
        lokasiPilihan = 'proyek';
        proyekTerpilih = selectedProyek['name'];
        lokasiLatLng = LatLng(selectedProyek['lat'], selectedProyek['lng']);
        alamatLokasi = selectedProyek['address'];
        sourceProvider = 'proyek';
      });
      _moveMapToLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => loadingLokasi = true);

    try {
      // Cek fake GPS
      final isFake = await LocationService.detectFakeGPS();
      if (isFake) {
        final confirm = await _showConfirmDialog(
          title: "⚠️ Fake GPS Terdeteksi",
          message: "Sistem mendeteksi penggunaan Fake GPS.\n\n"
                  "Ini melanggar aturan perusahaan.\n\n"
                  "Apakah Anda tetap ingin melanjutkan?",
          confirmText: "YA, LANJUTKAN",
          cancelText: "BATALKAN",
        );
        
        if (!confirm) {
          setState(() => loadingLokasi = false);
          return;
        }
      }

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      final result = await LocationService.reverseGeocode(
        position.latitude, 
        position.longitude
      );

      if (result != null && mounted) {
        setState(() {
          lokasiLatLng = LatLng(position.latitude, position.longitude);
          alamatLokasi = result['address'];
          sourceProvider = 'gps';
          lokasiPilihan = 'custom';
          loadingLokasi = false;
        });

        _checkRadius();
        _moveMapToLocation();
        _showSuccessSnackbar("✅ Lokasi GPS berhasil didapatkan");
      } else if (mounted) {
        setState(() => loadingLokasi = false);
        _showInfoDialog(
          title: "❌ Gagal Mendapatkan Lokasi GPS",
          message: "Tidak dapat mengakses GPS.\n\n"
                  "Silakan cari lokasi manual menggunakan fitur pencarian.",
        );
      }
    } catch (e) {
      debugPrint('❌ Error get location: $e');
      
      if (mounted) {
        _showInfoDialog(
          title: "❌ Gagal Mendapatkan Lokasi GPS",
          message: "Tidak dapat mengakses GPS.\n\n"
                  "Silakan cari lokasi manual menggunakan fitur pencarian.",
        );
      }
      setState(() => loadingLokasi = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final results = await LocationService.searchLocation(query);
      
      if (results != null && mounted) {
        setState(() {
          searchResults = results;
          isSearching = false;
        });
      } else if (mounted) {
        setState(() => isSearching = false);
      }
    } catch (e) {
      debugPrint('❌ Search error: $e');
      if (mounted) setState(() => isSearching = false);
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    setState(() {
      lokasiLatLng = LatLng(location['lat'], location['lng']);
      alamatLokasi = location['address'];
      sourceProvider = 'search';
      lokasiPilihan = 'custom';
      searchResults = [];
      searchController.clear();
      isSearching = false;
    });

    _checkRadius();
    _moveMapToLocation();
    _showSuccessSnackbar("✅ Lokasi dipilih: ${location['name']}");
  }

  void _checkRadius() {
    if (lokasiLatLng == null) return;
    
    final distance = LocationService.calculateDistance(
      kantorLat, kantorLng,
      lokasiLatLng!.latitude, lokasiLatLng!.longitude
    );

    final outside = distance > radiusKantor;
    
    if (outside) {
      _showToast("📍 ${(distance/1000).toStringAsFixed(1)} km dari kantor");
    } else {
      _showToast("✅ Dalam radius ${radiusKantor}m kantor");
    }
  }

  void _moveMapToLocation() {
    if (lokasiLatLng != null && mapController != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && mapController != null) {
          mapController?.move(lokasiLatLng!, 16);
        }
      });
    }
  }

  // ============== MITRA ==============
  Future<List<Map<String, dynamic>>> _fetchMitraList() async {
    try {
      if (fungsiPengawas == null || fungsiPengawas!.isEmpty) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mitra')
          .where('fungsi', isEqualTo: fungsiPengawas)
          .where('status_akun', isEqualTo: 'active')
          .orderBy('nama_lengkap')
          .limit(50)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nama_lengkap': data['nama_lengkap'] ?? 'Tanpa Nama',
          'jabatan': data['jabatan'] ?? '',
          'email': data['email'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'fungsi': data['fungsi']?.toString().toLowerCase() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching mitra list: $e');
      return [];
    }
  }

  Future<void> _showMitraSelectionDialog() async {
    if (fungsiPengawas == null || fungsiPengawas!.isEmpty) {
      _showErrorSnackbar("❌ Fungsi belum dimuat");
      return;
    }

    final mitraList = await _fetchMitraList();
    
    if (mitraList.isEmpty) {
      _showErrorSnackbar("❌ Tidak ada mitra aktif di fungsi Anda");
      return;
    }

    final availableMitras = mitraList.where((mitra) 
      => !selectedMitraIds.contains(mitra['id'])).toList();

    List<Map<String, dynamic>> filteredMitras = List.from(availableMitras);
    String searchQuery = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Pilih Mitra",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    
                    // Search
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Cari mitra...",
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF718096)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFF),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                            filteredMitras = availableMitras.where((mitra) {
                              final nama = mitra['nama_lengkap']?.toLowerCase() ?? '';
                              return nama.contains(searchQuery);
                            }).toList();
                          });
                        },
                      ),
                    ),

                    // Selected count
                    if (selectedMitraIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "${selectedMitraIds.length} mitra dipilih",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // List
                    Expanded(
                      child: filteredMitras.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Tidak ada mitra ditemukan",
                                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredMitras.length,
                              itemBuilder: (context, index) {
                                final mitra = filteredMitras[index];
                                final isSelected = selectedMitraIds.contains(mitra['id']);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          selectedMitraIds.remove(mitra['id']);
                                          this.selectedMiras.removeWhere((m) => m['id'] == mitra['id']);
                                        } else {
                                          selectedMitraIds.add(mitra['id']);
                                          this.selectedMiras.add(mitra);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: _getFungsiColor(mitra['fungsi'] ?? ''),
                                            child: Text(
                                              (mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  mitra['nama_lengkap'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  mitra['jabatan'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getFungsiColor(mitra['fungsi'] ?? '').withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    _getFungsiLabel(mitra['fungsi'] ?? '').toUpperCase(),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getFungsiColor(mitra['fungsi'] ?? ''),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade400,
                                                width: 2,
                                              ),
                                              color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  selectedMitraIds.clear();
                                  selectedMiras.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Hapus Semua"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _recalculateBiaya();
                                _checkMitraLimits();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Simpan"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _removeMitra(String mitraId) {
    setState(() {
      selectedMitraIds.remove(mitraId);
      selectedMiras.removeWhere((mitra) => mitra['id'] == mitraId);
    });
    _recalculateBiaya();
    _checkMitraLimits();
  }

  // ============== WAKTU ==============
  Future<void> _pilihTanggal() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('id', 'ID'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF2D3748),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        tanggalLembur = selectedDate;
        jamMulai = null;
        jamSelesai = null;
        totalJam = 0;
        totalBiaya = 0.0;
        
        // Set jenis lembur berdasarkan hari
        final isWeekend = selectedDate.weekday == DateTime.saturday || 
                         selectedDate.weekday == DateTime.sunday;
        if (isWeekend) {
          jenisLembur = "hari_libur";
        } else {
          jenisLembur = "hari_kerja";
        }
      });
    }
  }

  Future<void> _pilihWaktu(bool isJamMulai) async {
    if (tanggalLembur == null) {
      _showErrorSnackbar("Pilih tanggal terlebih dahulu");
      return;
    }

    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || 
                     tanggalLembur!.weekday == DateTime.sunday;

    // Untuk semua hari (kerja dan libur), tidak ada batasan jam
    TimeOfDay? initialTime;
    if (isJamMulai) {
      // Default jam 07:00 untuk semua hari (bisa diubah)
      initialTime = jamMulai ?? const TimeOfDay(hour: 7, minute: 0);
    } else {
      initialTime = jamSelesai ?? (jamMulai ?? const TimeOfDay(hour: 17, minute: 0));
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D3748),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    if (selectedTime != null && mounted) {
      if (isJamMulai) {
        _setJamMulai(selectedTime, isWeekend);
      } else {
        _setJamSelesai(selectedTime, isWeekend);
      }
    }
  }

  void _setJamMulai(TimeOfDay time, bool isWeekend) {
    if (time.minute % 30 != 0) {
      _showErrorSnackbar("Jam harus dalam kelipatan 30 menit");
      return;
    }

    // TIDAK ADA BATASAN JAM MULAI UNTUK HARI KERJA
    // Semua jam diperbolehkan, hanya dibatasi oleh limit bulanan mitra

    setState(() {
      jamMulai = time;
      jamSelesai = null;
      totalJam = 0;
      totalBiaya = 0.0;
    });
  }

  void _setJamSelesai(TimeOfDay time, bool isWeekend) {
    if (jamMulai == null) {
      _showErrorSnackbar("Pilih jam mulai terlebih dahulu");
      return;
    }

    if (time.minute % 30 != 0) {
      _showErrorSnackbar("Jam harus dalam kelipatan 30 menit");
      return;
    }

    final startMinutes = jamMulai!.hour * 60 + jamMulai!.minute;
    final endMinutes = time.hour * 60 + time.minute;
    final diff = endMinutes - startMinutes;

    if (diff <= 0) {
      _showErrorSnackbar("Jam selesai harus setelah jam mulai");
      return;
    }

    if (diff < 30) {
      _showErrorSnackbar("Durasi lembur minimal 30 menit");
      return;
    }

    // TIDAK ADA BATASAN JAM SELESAI UNTUK HARI KERJA
    // Semua jam diperbolehkan, hanya dibatasi oleh limit bulanan mitra

    setState(() {
      jamSelesai = time;
    });

    _recalculateBiaya();
    _checkMitraLimits();
  }

  // ============== SUBMIT ==============
  bool _allDataComplete() {
    return selectedMiras.isNotEmpty &&
        tanggalLembur != null &&
        jamMulai != null &&
        jamSelesai != null &&
        lokasiLatLng != null &&
        alasanController.text.isNotEmpty &&
        alasanController.text.length >= 20 &&
        _overtimeRates != null;
  }

  Future<void> _submit() async {
    try {
      FocusScope.of(context).unfocus();
      
      if (!_formKey.currentState!.validate()) {
        _showErrorSnackbar("Harap lengkapi semua data dengan benar");
        return;
      }

      if (_overtimeRates == null) {
        _showErrorSnackbar("Tarif lembur belum dimuat. Refresh halaman.");
        return;
      }

      if (selectedMiras.isEmpty) {
        _showErrorSnackbar("Pilih minimal 1 mitra");
        return;
      }

      if (tanggalLembur == null) {
        _showErrorSnackbar("Pilih tanggal lembur");
        return;
      }

      if (jamMulai == null || jamSelesai == null) {
        _showErrorSnackbar("Pilih jam mulai dan selesai");
        return;
      }

      if (totalJam <= 0) {
        _showErrorSnackbar("Durasi lembur minimal 30 menit");
        return;
      }

      if (lokasiLatLng == null) {
        _showErrorSnackbar("Pilih lokasi lembur");
        return;
      }

      if (alasanController.text.length < 20) {
        _showErrorSnackbar("Alasan lembur minimal 20 karakter");
        return;
      }

      // Cek limit
      if (isOverride) {
        final confirm = await _showConfirmDialog(
          title: "⚠️ Melebihi Batas Lembur",
          message: _buildLimitWarningMessage(),
          confirmText: "YA, TETAP AJUKAN",
          cancelText: "PERIKSA KEMBALI",
        );
        
        if (!confirm) return;
      }

      final confirmed = await _showConfirmDialog(
        title: "KONFIRMASI PENGAJUAN",
        message: _buildConfirmationMessage(),
        confirmText: "YA, AJUKAN",
        cancelText: "PERIKSA KEMBALI",
      );

      if (!confirmed) return;

      setState(() => isSubmitting = true);
      await _processSubmission();

    } catch (e) {
      debugPrint('❌ Error: $e');
      _showErrorDialog("Gagal Mengajukan Lembur", e.toString());
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _buildLimitWarningMessage() {
    if (limitInfo == null) return "";
    
    final mitraOver = <String>[];
    limitInfo!.forEach((mitraId, info) {
      if (info['is_exceeded']) {
        final mitra = selectedMiras.firstWhere((m) => m['id'] == mitraId);
        final totalSetelah = (info['total_jam_bulan_ini'] + info['tambahan_jam']).toStringAsFixed(1);
        mitraOver.add("• ${mitra['nama_lengkap']}: ${info['total_jam_bulan_ini'].toStringAsFixed(1)} jam + ${info['tambahan_jam'].toStringAsFixed(1)} jam = $totalSetelah jam (${info['persentase'].toStringAsFixed(0)}%)");
      }
    });

    return """
Beberapa mitra akan melebihi batas maksimal 60 jam/bulan:

${mitraOver.join('\n')}

⚠️ Pengajuan ini akan ditandai sebagai KRITIS dan memerlukan persetujuan khusus dari manager.

Apakah Anda tetap ingin mengajukan?
""";
  }

  String _buildConfirmationMessage() {
    final tanggalFormatted = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggalLembur!);
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || 
                     tanggalLembur!.weekday == DateTime.sunday;
    final isOutside = LocationService.isOutsideRadius(
      lokasiLatLng!.latitude, 
      lokasiLatLng!.longitude
    );
    final ratePerJam = _overtimeService.formatRupiahCompact(
      (_overtimeRates!['rate_per_hour'] as num?)?.toDouble() ?? 0
    );
    
    String lokasiInfo;
    if (lokasiPilihan == 'kantor') {
      lokasiInfo = "🏢 Kantor PGE";
    } else if (lokasiPilihan == 'proyek') {
      lokasiInfo = "🏗️ Proyek: $proyekTerpilih";
    } else {
      lokasiInfo = isOutside ? '📍 LUAR RADIUS' : '📍 Dalam Radius';
    }

    return """
📋 DETAIL PENGAJUAN
━━━━━━━━━━━━━━━━━

👤 Pengawas: $namaPengawas
🏢 Fungsi: ${_getFungsiLabel(fungsiPengawas ?? '').toUpperCase()}
👥 Mitra: ${selectedMiras.length} orang

📅 Tanggal: $tanggalFormatted
📆 Jenis: ${isWeekend ? 'LIBUR' : 'HARI KERJA'}
⏰ Waktu: ${_formatTime(jamMulai!)} - ${_formatTime(jamSelesai!)}
⏱️ Durasi: ${totalJam.toStringAsFixed(1)} jam
💵 Rate/Jam: $ratePerJam

$lokasiInfo
⚡ Urgensi: ${urgensi.toUpperCase()}
${isOverride ? '⚠️ MELEBIHI BATAS 60 JAM/BULAN' : ''}

💰 Estimasi Biaya:
   • Per Mitra: ${_overtimeService.formatRupiah(_biayaPerMitra)}
   • Total: ${_overtimeService.formatRupiah(totalBiaya)}
""";
  }

  Future<void> _processSubmission() async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.now();
      final List<String> lemburIds = [];
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();

      final isWeekend = tanggalLembur!.weekday == DateTime.saturday || 
                       tanggalLembur!.weekday == DateTime.sunday;
      final finalJenisLembur = isWeekend ? "hari_libur" : jenisLembur;
      final isOutside = LocationService.isOutsideRadius(
        lokasiLatLng!.latitude, 
        lokasiLatLng!.longitude
      );

      // Simpan snapshot tarif saat pengajuan untuk audit trail
      final rateSnapshot = {
        'base_salary': _overtimeRates!['base_salary'],
        'rate_per_hour': _overtimeRates!['rate_per_hour'],
        'weekday_rate': _overtimeRates!['weekday_rate'],
        'holiday_rate': _overtimeRates!['holiday_rate'],
      };

      final baseData = {
        'group_id': groupId,
        'pengawas_id': _auth.currentUser?.uid,
        'nama_pengawas': namaPengawas ?? 'Unknown',
        'pengawas_fungsi': fungsiPengawas ?? '',
        'tanggal': Timestamp.fromDate(tanggalLembur!),
        'tahun_bulan': DateFormat('yyyy-MM').format(tanggalLembur!),
        'created_at': now,
        'status': 'pending',
        'jam_mulai': _formatTime(jamMulai!),
        'jam_selesai': _formatTime(jamSelesai!),
        'total_jam': (totalJam * 2).round(), // dalam setengah jam
        'total_jam_desimal': totalJam,
        'jenis_lembur': finalJenisLembur,
        'lokasi': {
          'pilihan': lokasiPilihan,
          'proyek': proyekTerpilih,
          'alamat': alamatLokasi,
          'latitude': lokasiLatLng!.latitude,
          'longitude': lokasiLatLng!.longitude,
          'source': sourceProvider,
          'is_outside_radius': isOutside,
          'distance_from_kantor': LocationService.calculateDistance(
            kantorLat, kantorLng,
            lokasiLatLng!.latitude, lokasiLatLng!.longitude
          ),
        },
        'urgensi': urgensi,
        'alasan': alasanController.text.trim(),
        'catatan_tambahan': catatanTambahanController.text.trim(),
        'estimasi_biaya_per_mitra': _biayaPerMitra,
        'estimasi_biaya_total': totalBiaya,
        'is_multiple': selectedMiras.length > 1,
        'total_mitra': selectedMiras.length,
        'absensi_status': 'belum_absen',
        'is_override': isOverride,
        'rate_snapshot': rateSnapshot, // Simpan tarif saat pengajuan
        'updated_at': now,
      };

      // Leader document
      final leaderRef = _firestore.collection('lembur').doc(groupId);
      batch.set(leaderRef, {
        ...baseData,
        'is_group_leader': true,
        'mitra_ids': selectedMitraIds,
      });
      lemburIds.add(groupId);

      // Mitra documents
      for (final mitra in selectedMiras) {
        final docRef = _firestore.collection('lembur').doc('$groupId-${mitra['id']}');
        batch.set(docRef, {
          ...baseData,
          'is_group_leader': false,
          'mitra_id': mitra['id'],
          'nama_mitra': mitra['nama_lengkap'],
          'fungsi_mitra': mitra['fungsi'],
          'no_hp_mitra': mitra['no_hp'] ?? '',
          'email_mitra': mitra['email'] ?? '',
        });
        lemburIds.add(docRef.id);
      }

      await batch.commit();
      debugPrint('✅ Data lembur berhasil disimpan, Group ID: $groupId');

      // Kirim notifikasi
      try {
        await NotificationService().sendManagerNotification(
          pengawasNama: namaPengawas ?? 'Unknown',
          fungsi: fungsiPengawas ?? '',
          jumlahMitra: selectedMiras.length,
          tanggal: tanggalLembur!,
          totalBiaya: totalBiaya,
          urgensi: urgensi,
          isOutsideRadius: isOutside,
          lemburIds: lemburIds,
          overtimeRates: _overtimeRates!,
        );
      } catch (e) {
        debugPrint('❌ Gagal kirim notifikasi: $e');
      }

      if (mounted) {
        await _showSuccessDialog(groupId);
      }

    } catch (e) {
      debugPrint('❌ Error processing submission: $e');
      rethrow;
    }
  }

  double get _biayaPerMitra => selectedMiras.isNotEmpty ? totalBiaya / selectedMiras.length : 0.0;

  // ============== UI COMPONENTS ==============
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    // Loading state
    if (isLoadingUser || isLoadingRates) {
      return _buildLoadingScreen();
    }

    // Error state
    if (rateErrorMessage != null) {
      return _buildErrorScreen();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: _buildAppBar(isSmallScreen),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 16),
                            _buildProgressStepper(),
                            const SizedBox(height: 16),
                            _buildRateInfoCard(),
                            const SizedBox(height: 16),
                            _buildMitraSection(),
                            const SizedBox(height: 16),
                            _buildWaktuSection(),
                            const SizedBox(height: 16),
                            _buildLocationSection(),
                            const SizedBox(height: 16),
                            _buildUrgensiSection(),
                            const SizedBox(height: 16),
                            _buildAlasanSection(),
                            const SizedBox(height: 16),
                            if (_allDataComplete()) _buildSummaryCard(),
                            SizedBox(height: size.height * 0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1976D2)),
            const SizedBox(height: 16),
            Text(
              isLoadingUser ? "Memuat data pengguna..." : "Memuat tarif lembur...",
              style: GoogleFonts.poppins(color: const Color(0xFF2D3748)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              "Gagal Memuat Data",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                rateErrorMessage ?? "Terjadi kesalahan",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoadingRates = true;
                  rateErrorMessage = null;
                });
                _loadOvertimeRates();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isSmallScreen) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2D3748),
      elevation: 0,
      title: Text(
        "Pengajuan Lembur",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: isSmallScreen ? 18 : 20,
          color: const Color(0xFF1A237E),
        ),
      ),
      centerTitle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF1976D2)),
          onPressed: () async {
            _overtimeService.clearCache();
            await _loadOvertimeRates();
            _showSuccessSnackbar("Tarif lembur diperbarui");
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history, color: Color(0xFF1976D2)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RiwayatLemburPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Informasi Penting",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Batas maksimal lembur 60 jam/bulan per mitra. Lembur hari kerja maupun libur bisa dimulai kapan saja.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stepItem(1, "Mitra", Icons.people, selectedMiras.isNotEmpty),
          _stepItem(2, "Waktu", Icons.access_time, jamMulai != null && jamSelesai != null),
          _stepItem(3, "Lokasi", Icons.location_on, lokasiLatLng != null),
          _stepItem(4, "Review", Icons.checklist, _allDataComplete()),
        ],
      ),
    );
  }

  Widget _stepItem(int step, String label, IconData icon, bool isComplete) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isComplete
                ? const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  )
                : LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                  ),
            shape: BoxShape.circle,
            boxShadow: isComplete
                ? [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Icon(icon, size: 20, color: isComplete ? Colors.white : Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isComplete ? const Color(0xFF1A237E) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRateInfoCard() {
    if (_rateDisplay == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_money, color: Color(0xFF1976D2), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                "Tarif Lembur Aktif",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Rate/Jam: ${_overtimeService.formatRupiahCompact(_rateDisplay!.ratePerJam)}",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🏢 Hari Kerja",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    _buildRateRow(
                      "Jam 1", 
                      "${_rateDisplay!.weekdayFirstMultiplier.toStringAsFixed(1)}x",
                      _overtimeService.formatRupiahCompact(_rateDisplay!.weekdayFirstHour),
                    ),
                    const SizedBox(height: 2),
                    _buildRateRow(
                      "Jam 2+", 
                      "${_rateDisplay!.weekdayNextMultiplier.toStringAsFixed(1)}x",
                      _overtimeService.formatRupiahCompact(_rateDisplay!.weekdayNextHours),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade300),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎉 Hari Libur",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    _buildRateRow(
                      "8 jam pertama", 
                      "${_rateDisplay!.holidayFirst8Multiplier.toStringAsFixed(1)}x",
                      _overtimeService.formatRupiahCompact(_rateDisplay!.holidayFirst8Hours),
                    ),
                    const SizedBox(height: 2),
                    _buildRateRow(
                      "Jam ke-9", 
                      "${_rateDisplay!.holidayNinthMultiplier.toStringAsFixed(1)}x",
                      _overtimeService.formatRupiahCompact(_rateDisplay!.holidayNinthHour),
                    ),
                    const SizedBox(height: 2),
                    _buildRateRow(
                      "Jam ke-10+", 
                      "${_rateDisplay!.holidayTenthMultiplier.toStringAsFixed(1)}x",
                      _overtimeService.formatRupiahCompact(_rateDisplay!.holidayTenthPlus),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String label, String multiplier, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                multiplier,
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              amount,
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMitraSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.people, "Pilih Mitra", const Color(0xFF1976D2)),
          const SizedBox(height: 12),
          
          // Selected mitra
          if (selectedMiras.isNotEmpty) ...[
            ...selectedMiras.map((mitra) => _buildMitraItem(mitra)).toList(),
            const SizedBox(height: 12),
          ],
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(
                selectedMiras.isEmpty ? "Tambah Mitra" : "Tambah Mitra Lain",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showMitraSelectionDialog,
            ),
          ),
          
          if (isOverride) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFF57C00)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "⚠️ Melebihi Batas Lembur",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF57C00),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Beberapa mitra akan melebihi 60 jam/bulan. Pengajuan akan ditandai KRITIS.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF4A5568),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMitraItem(Map<String, dynamic> mitra) {
    // Cek limit mitra ini
    final mitraLimit = limitInfo != null ? limitInfo![mitra['id']] : null;
    final persentase = mitraLimit != null ? (mitraLimit['persentase'] as double).clamp(0, 100) : 0;
    final isNearLimit = persentase > 80 && persentase <= 100;
    final isOverLimit = persentase > 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverLimit ? const Color(0xFFFFEBEE).withValues(alpha: 0.8) : (isNearLimit ? const Color(0xFFFFF3E0).withValues(alpha: 0.8) : const Color(0xFFF0F9FF).withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverLimit ? const Color(0xFFEF5350) : (isNearLimit ? const Color(0xFFFFB74D) : const Color(0xFFBBDEFB)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getFungsiColor(mitra['fungsi'] ?? ''),
                radius: 20,
                child: Text(
                  (mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mitra['nama_lengkap'] ?? '',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mitra['jabatan'] ?? '',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF546E7A)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getFungsiColor(mitra['fungsi'] ?? '').withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getFungsiLabel(mitra['fungsi'] ?? '').toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _getFungsiColor(mitra['fungsi'] ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEEBEE).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFFD32F2F)),
                ),
                onPressed: () => _removeMitra(mitra['id']),
              ),
            ],
          ),
          if (mitraLimit != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: persentase / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverLimit ? Colors.red : (isNearLimit ? Colors.orange : Colors.green),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${persentase.toStringAsFixed(0)}%",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isOverLimit ? Colors.red : (isNearLimit ? Colors.orange : Colors.green),
                  ),
                ),
              ],
            ),
            Text(
              "Jam bulan ini: ${_mitraLimitService.formatJam(mitraLimit['total_jam_bulan_ini'])} + ${_mitraLimitService.formatJam(mitraLimit['tambahan_jam'])}",
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaktuSection() {
    if (_rateDisplay == null) return const SizedBox();

    final isWeekend = tanggalLembur?.weekday == DateTime.saturday || 
                     tanggalLembur?.weekday == DateTime.sunday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.access_time, "Waktu Lembur", const Color(0xFF388E3C)),
          const SizedBox(height: 12),
          
          // Tanggal
          InkWell(
            onTap: _pilihTanggal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: tanggalLembur == null ? const Color(0xFFE2E8F0) : const Color(0xFF1976D2),
                ),
                borderRadius: BorderRadius.circular(12),
                color: tanggalLembur == null ? const Color(0xFFF8FAFF) : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: tanggalLembur == null ? const Color(0xFFA0AEC0) : const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tanggalLembur == null ? "Pilih tanggal lembur" : _formatTanggal(tanggalLembur!),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tanggalLembur == null ? const Color(0xFFA0AEC0) : const Color(0xFF2D3748),
                          ),
                        ),
                        if (tanggalLembur != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            isWeekend 
                                ? "✅ Hari Libur - Bisa mulai kapan saja" 
                                : "🏢 Hari Kerja - Bisa mulai kapan saja (sesuai kebutuhan)",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isWeekend ? const Color(0xFFF57C00) : const Color(0xFF388E3C),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (tanggalLembur != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFFD32F2F)),
                      onPressed: () {
                        setState(() {
                          tanggalLembur = null;
                          jamMulai = null;
                          jamSelesai = null;
                          totalJam = 0;
                          totalBiaya = 0.0;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          
          if (tanggalLembur != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker("Jam Mulai", jamMulai, true, isWeekend),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePicker("Jam Selesai", jamSelesai, false, isWeekend),
                ),
              ],
            ),
          ],
          
          if (totalJam > 0) _buildTimeSummary(),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, bool isJamMulai, bool isWeekend) {
    String hintText = "--:--";

    return InkWell(
      onTap: () => _pilihWaktu(isJamMulai),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: time == null ? const Color(0xFFE2E8F0) : const Color(0xFF1976D2),
          ),
          borderRadius: BorderRadius.circular(12),
          color: time == null ? const Color(0xFFF8FAFF) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: time == null ? const Color(0xFFA0AEC0) : const Color(0xFF1976D2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    time == null ? hintText : _formatTime(time),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: time == null ? const Color(0xFFA0AEC0) : const Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Durasi Lembur:",
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2E7D32)),
              ),
              Text(
                "${totalJam.toStringAsFixed(1)} jam",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          if (selectedMiras.isNotEmpty && _rateDisplay != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Biaya per Mitra:",
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2E7D32)),
                ),
                Text(
                  _overtimeService.formatRupiah(_biayaPerMitra),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            if (selectedMiras.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Biaya:",
                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2E7D32)),
                  ),
                  Text(
                    _overtimeService.formatRupiah(totalBiaya),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final isOutside = lokasiLatLng != null && LocationService.isOutsideRadius(
      lokasiLatLng!.latitude, lokasiLatLng!.longitude
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.location_on, "Lokasi Lembur", const Color(0xFF1976D2)),
          const SizedBox(height: 12),
          
          // Pilihan lokasi: Kantor atau Proyek
          Row(
            children: [
              Expanded(
                child: _buildLocationOption(
                  icon: Icons.business,
                  label: "Kantor",
                  isSelected: lokasiPilihan == 'kantor',
                  onTap: _pilihLokasiKantor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationOption(
                  icon: Icons.location_city,
                  label: "Proyek",
                  isSelected: lokasiPilihan == 'proyek',
                  onTap: _pilihLokasiProyek,
                ),
              ),
            ],
          ),
          
          if (lokasiPilihan == 'proyek' && proyekTerpilih != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1976D2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Proyek: $proyekTerpilih",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Search bar (untuk custom lokasi)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Cari lokasi lain...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF718096)),
                suffixIcon: isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) {
                if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  _searchLocation(value);
                });
              },
            ),
          ),
          
          // Search results
          if (searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Color(0xFF1976D2)),
                    title: Text(
                      result['name'],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      result['address'].length > 50
                          ? '${result['address'].substring(0, 50)}...'
                          : result['address'],
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    onTap: () => _selectLocation(result),
                  );
                },
              ),
            ),
          
          const SizedBox(height: 12),
          
          // GPS button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: loadingLokasi
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                loadingLokasi ? "Mendapatkan lokasi..." : "Gunakan Lokasi GPS Saat Ini",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: loadingLokasi ? null : _getCurrentLocation,
            ),
          ),
          
          if (lokasiLatLng != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: lokasiLatLng!,
                        initialZoom: 16,
                        onTap: (tapPosition, point) {
                          // Update lokasi saat tap di map (realtime)
                          setState(() {
                            lokasiLatLng = point;
                            sourceProvider = 'map_tap';
                            lokasiPilihan = 'custom';
                          });
                          _checkRadius();
                          _getAddressFromLatLng(point.latitude, point.longitude);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.lembur.pge',
                        ),
                        if (lokasiLatLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: lokasiLatLng!,
                                width: 50,
                                height: 50,
                                child: Column(
                                  children: [
                                    Icon(
                                      isOutside ? Icons.warning : Icons.location_pin,
                                      color: isOutside ? Colors.orange : Colors.red,
                                      size: 30,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 2),
                                        ],
                                      ),
                                      child: Text(
                                        isOutside ? "Luar Radius" : "Lokasi",
                                        style: GoogleFonts.poppins(fontSize: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (lokasiLatLng != null && !isOutside)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(kantorLat, kantorLng),
                                radius: radiusKantor,
                                color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                                borderColor: const Color(0xFF1976D2),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () {
                              final zoom = (mapController?.camera.zoom ?? 16) + 1;
                              mapController?.move(lokasiLatLng!, zoom);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () {
                              final zoom = (mapController?.camera.zoom ?? 16) - 1;
                              mapController?.move(lokasiLatLng!, zoom);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutside ? const Color(0xFFFFF3E0).withValues(alpha: 0.8) : const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOutside ? const Color(0xFFFFB74D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOutside ? Icons.warning_amber : Icons.location_on,
                    color: isOutside ? const Color(0xFFF57C00) : const Color(0xFF1976D2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alamatLokasi ?? 'Memuat alamat...',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF2D3748),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isOutside) ...[
                          const SizedBox(height: 4),
                          Text(
                            "⚠️ Lokasi di luar radius kantor",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF57C00),
                            ),
                          ),
                        ],
                        if (sourceProvider != null && sourceProvider != 'kantor')
                          Text(
                            "Sumber: ${sourceProvider!.toUpperCase()}",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF1976D2),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final result = await LocationService.reverseGeocode(lat, lng);
      if (result != null && mounted) {
        setState(() {
          alamatLokasi = result['address'];
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Widget _buildUrgensiSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.priority_high, "Tingkat Urgensi", const Color(0xFF1976D2)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _urgencyChip("Rendah", "rendah", Icons.low_priority, const Color(0xFF4CAF50)),
              _urgencyChip("Normal", "normal", Icons.timeline, const Color(0xFF2196F3)),
              _urgencyChip("Tinggi", "tinggi", Icons.priority_high, const Color(0xFFFF9800)),
              _urgencyChip("Kritis", "kritis", Icons.warning, const Color(0xFFF44336)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getUrgensiColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_getUrgensiIcon(), color: _getUrgensiColor()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getUrgensiLabel(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _getUrgensiColor(),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getUrgensiDescription(),
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF4A5568)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgencyChip(String label, String value, IconData icon, Color color) {
    final isSelected = urgensi == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => urgensi = value),
      backgroundColor: Colors.white,
      selectedColor: color,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: isSelected ? Colors.white : color,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: isSelected ? 0 : 1),
      ),
    );
  }

  Widget _buildAlasanSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.description, "Alasan Lembur", const Color(0xFF1976D2)),
          const SizedBox(height: 12),
          TextFormField(
            controller: alasanController,
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: "Jelaskan alasan lembur secara detail...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Alasan wajib diisi";
              if (value.length < 20) return "Minimal 20 karakter";
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Minimal 20 karakter",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFFA0AEC0),
                ),
              ),
              Text(
                "${alasanController.text.length}/500",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: alasanController.text.length >= 20
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFA0AEC0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: catatanTambahanController,
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: "Catatan tambahan (opsional)",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (!_allDataComplete() || _rateDisplay == null) return const SizedBox();

    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || 
                     tanggalLembur!.weekday == DateTime.sunday;
    final isOutside = LocationService.isOutsideRadius(
      lokasiLatLng!.latitude, lokasiLatLng!.longitude
    );

    String lokasiInfo;
    if (lokasiPilihan == 'kantor') {
      lokasiInfo = "🏢 Kantor PGE";
    } else if (lokasiPilihan == 'proyek') {
      lokasiInfo = "🏗️ Proyek: $proyekTerpilih";
    } else {
      lokasiInfo = isOutside ? '⚠️ Luar Radius' : '📍 Dalam Radius';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.summarize, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                "Ringkasan Pengajuan",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow("👤 Pengawas", namaPengawas ?? "-"),
          _summaryRow("🏢 Fungsi", _getFungsiLabel(fungsiPengawas ?? '').toUpperCase()),
          _summaryRow("👥 Mitra", "${selectedMiras.length} orang"),
          ...selectedMiras.take(2).map((m) => 
            _summaryRow("  • ${m['nama_lengkap']}", m['jabatan'] ?? '')
          ),
          if (selectedMiras.length > 2)
            _summaryRow("  • dan ${selectedMiras.length - 2} lainnya", ""),
          _summaryRow(
            "📅 Tanggal",
            tanggalLembur != null
                ? DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggalLembur!)
                : "-",
          ),
          _summaryRow(
            "⏰ Waktu",
            "${_formatTime(jamMulai!)} - ${_formatTime(jamSelesai!)}",
          ),
          _summaryRow("⏱️ Durasi", "${totalJam.toStringAsFixed(1)} jam"),
          _summaryRow("📍 Lokasi", lokasiInfo),
          _summaryRow("⚡ Urgensi", _getUrgensiLabel()),
          if (isOverride) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "⚠️ Melebihi batas 60 jam/bulan",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Biaya per Mitra:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _overtimeService.formatRupiah(_biayaPerMitra),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFFC6F6D5),
                      ),
                    ),
                  ],
                ),
                if (selectedMiras.length > 1) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Biaya:",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _overtimeService.formatRupiah(totalBiaya),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: const Color(0xFFC6F6D5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isComplete = _allDataComplete();

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSubmitting ? null : () => _showCancelDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A5568),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("BATALKAN"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSubmitting || !isComplete ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isComplete ? const Color(0xFF1976D2) : const Color(0xFFCBD5E0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text("AJUKAN"),
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER METHODS ==============
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1A237E).withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: const Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi;
    }
  }

  Color _getUrgensiColor() {
    switch (urgensi) {
      case 'rendah': return const Color(0xFF4CAF50);
      case 'normal': return const Color(0xFF2196F3);
      case 'tinggi': return const Color(0xFFFF9800);
      case 'kritis': return const Color(0xFFF44336);
      default: return const Color(0xFF2196F3);
    }
  }

  IconData _getUrgensiIcon() {
    switch (urgensi) {
      case 'rendah': return Icons.low_priority;
      case 'normal': return Icons.timeline;
      case 'tinggi': return Icons.priority_high;
      case 'kritis': return Icons.warning;
      default: return Icons.timeline;
    }
  }

  String _getUrgensiLabel() {
    switch (urgensi) {
      case 'rendah': return "Urgensi Rendah";
      case 'normal': return "Urgensi Normal";
      case 'tinggi': return "Urgensi Tinggi";
      case 'kritis': return "Urgensi Kritis";
      default: return "Urgensi Normal";
    }
  }

  String _getUrgensiDescription() {
    switch (urgensi) {
      case 'rendah': return "Lembur biasa tanpa target waktu ketat";
      case 'normal': return "Lembur standar dengan prioritas normal";
      case 'tinggi': return "Lembur mendesak dengan deadline dekat";
      case 'kritis': return "Lembur sangat mendesak untuk situasi darurat";
      default: return "Prioritas standar lembur";
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTanggal(DateTime date) {
    final weekday = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final month = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${weekday[date.weekday % 7]}, ${date.day} ${month[date.month - 1]} ${date.year}';
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Color(0xFFD32F2F))),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
            ),
            child: const Text("COBA LAGI"),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Batalkan Pengajuan"),
        content: const Text("Apakah Anda yakin ingin membatalkan? Semua data akan hilang."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Lanjutkan"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text("Ya, Batalkan"),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(String groupId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                "BERHASIL!",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Pengajuan lembur telah dikirim",
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                "ID: ${groupId.substring(0, 8)}...",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Notifikasi telah dikirim ke manager",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("SELESAI"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// RIWAYAT LEMBUR PAGE
// ============================================================================
class RiwayatLemburPage extends StatefulWidget {
  const RiwayatLemburPage({super.key});

  @override
  State<RiwayatLemburPage> createState() => _RiwayatLemburPageState();
}

class _RiwayatLemburPageState extends State<RiwayatLemburPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser!;
  final OvertimeService _overtimeService = OvertimeService();
  String? fungsiPengawas;
  String filterStatus = 'semua';
  List<String> statusOptions = ['semua', 'pending', 'disetujui', 'ditolak', 'selesai'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          fungsiPengawas = data?['fungsi']?.toString().toLowerCase() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Riwayat Lembur",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A237E),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildLemburList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (fungsiPengawas != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getFungsiColor(fungsiPengawas!),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getFungsiLabel(fungsiPengawas!).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ...statusOptions.map((status) {
              final isSelected = filterStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(status.toUpperCase()),
                  selected: isSelected,
                  onSelected: (_) => setState(() => filterStatus = status),
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: _getStatusColor(status).withValues(alpha: 0.2),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isSelected ? _getStatusColor(status) : Colors.grey.shade700,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLemburList() {
    if (fungsiPengawas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getLemburStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  "Belum ada riwayat lembur",
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final lembur = doc.data() as Map<String, dynamic>;
            return _buildLemburCard(lembur);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getLemburStream() {
    Query query = _firestore
        .collection('lembur')
        .where('pengawas_id', isEqualTo: currentUser.uid)
        .orderBy('created_at', descending: true)
        .limit(50);

    if (filterStatus != 'semua') {
      query = query.where('status', isEqualTo: filterStatus);
    }

    return query.snapshots();
  }

  Widget _buildLemburCard(Map<String, dynamic> lembur) {
    final status = lembur['status'] ?? 'pending';
    final tanggal = (lembur['tanggal'] as Timestamp).toDate();
    final biayaPerMitra = (lembur['estimasi_biaya_per_mitra'] ?? 0).toDouble();
    final biayaTotal = (lembur['estimasi_biaya_total'] ?? 0).toDouble();
    final namaMitra = lembur['nama_mitra'] ?? 'Tidak diketahui';
    final totalJam = (lembur['total_jam_desimal'] ?? 0).toDouble();
    final isMultiple = lembur['is_multiple'] ?? false;
    final lokasi = lembur['lokasi'] ?? {};
    final isOutside = lokasi['is_outside_radius'] ?? false;
    final lokasiPilihan = lokasi['pilihan'] ?? 'kantor';
    final proyekTerpilih = lokasi['proyek'];
    final isOverride = lembur['is_override'] ?? false;

    String lokasiInfo;
    if (lokasiPilihan == 'kantor') {
      lokasiInfo = "Kantor";
    } else if (lokasiPilihan == 'proyek' && proyekTerpilih != null) {
      lokasiInfo = "Proyek";
    } else {
      lokasiInfo = isOutside ? "Luar Radius" : "Dalam Radius";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy').format(tanggal),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  if (isOverride)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "OVERRIDE",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF57C00)),
                      ),
                    ),
                  if (isOutside)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "LUAR RADIUS",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF57C00)),
                      ),
                    ),
                  if (isMultiple)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "GRUP",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1976D2)),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isMultiple ? "Grup (${lembur['total_mitra']} mitra)" : "Mitra: $namaMitra",
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "Waktu: ${lembur['jam_mulai']} - ${lembur['jam_selesai']}",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            "Durasi: ${totalJam.toStringAsFixed(1)} jam",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            "Lokasi: $lokasiInfo",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMultiple ? "Estimasi Biaya Total:" : "Estimasi Biaya:",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                _overtimeService.formatRupiah(isMultiple ? biayaTotal : biayaPerMitra),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'disetujui': return const Color(0xFF4CAF50);
      case 'ditolak': return const Color(0xFFF44336);
      case 'pending': return const Color(0xFFFF9800);
      case 'selesai': return const Color(0xFF2196F3);
      default: return Colors.grey;
    }
  }
}