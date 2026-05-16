// ============================================================================
// LOCATION VALIDATOR - MOBILE OPTIMIZED & SAFE VERSION
// File: /widgets/absensi/location_validator.dart
// Last Updated: 2026-05-12
// ============================================================================
// FEATURES:
// ✅ GPS service check
// ✅ Permission handling lengkap
// ✅ Location dengan retry + fallback
// ✅ Geocoding dengan timeout
// ✅ Distance calculation (Haversine)
// ✅ Custom radius support (meter & km)
// ✅ Office vs Project radius default
// ✅ Safe null handling untuk semua field
// ✅ Detailed error logging
// ✅ Manual distance backup
// ✅ Open settings helpers
// ============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '/core/services/overtime_history_service.dart';

class LocationValidator {
  // ============================================================================
  // DEFAULT CONFIG
  // ============================================================================

  /// Default radius untuk lokasi kantor (meter)
  static const double defaultRadiusOffice = 100.0;

  /// Default radius untuk lokasi project/lapangan (meter)
  static const double defaultRadiusProject = 500.0;

  /// Akurasi GPS yang digunakan
  static const LocationAccuracy accuracy = LocationAccuracy.high;

  /// Timeout untuk mendapatkan lokasi (detik)
  static const int locationTimeoutSeconds = 20;

  /// Timeout untuk geocoding (detik)
  static const int geocodingTimeoutSeconds = 10;

  /// Maksimal retry untuk mendapatkan lokasi
  static const int maxLocationRetries = 2;

  // ============================================================================
  // LOCATION SERVICE CHECK
  // ============================================================================

  /// Cek apakah GPS/Location service aktif di perangkat
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('LocationValidator: Service check error: $e');
      return false;
    }
  }

  // ============================================================================
  // LOCATION PERMISSION CHECK
  // ============================================================================

  /// Cek dan request permission lokasi
  /// Returns status permission terakhir
  Future<LocationPermission> checkAndRequestPermission() async {
    try {
      // Cek permission saat ini
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));

      debugPrint('LocationValidator: Current permission: $permission');

      // Jika denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 30));
        debugPrint('LocationValidator: After request: $permission');
      }

      return permission;
    } catch (e) {
      debugPrint('LocationValidator: Permission check error: $e');
      return LocationPermission.denied;
    }
  }

  /// Cek apakah permission sudah granted
  bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ============================================================================
  // GET CURRENT LOCATION (WITH RETRY & FALLBACK)
  // ============================================================================

  /// Mendapatkan lokasi saat ini
  /// Mencoba beberapa kali dengan fallback ke last known location
  Future<Position?> getCurrentLocation() async {
    try {
      // -----------------------------------------------------------------------
      // CHECK GPS SERVICE
      // -----------------------------------------------------------------------
      
      final serviceEnabled = await isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('LocationValidator: GPS service tidak aktif');
        return null;
      }

      // -----------------------------------------------------------------------
      // CHECK PERMISSION
      // -----------------------------------------------------------------------
      
      final permission = await checkAndRequestPermission();

      if (!isPermissionGranted(permission)) {
        debugPrint('LocationValidator: Permission tidak granted ($permission)');
        return null;
      }

      // -----------------------------------------------------------------------
      // ATTEMPT TO GET LOCATION WITH RETRY
      // -----------------------------------------------------------------------
      
      Position? position;

      for (int attempt = 1; attempt <= maxLocationRetries; attempt++) {
        try {
          debugPrint('LocationValidator: Getting location (attempt $attempt/$maxLocationRetries)');

          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: accuracy,
            timeLimit: Duration(seconds: locationTimeoutSeconds),
          );

          debugPrint(
            'LocationValidator: Location obtained - '
            'lat: ${position.latitude}, lng: ${position.longitude}, '
            'accuracy: ${position.accuracy}m',
          );
          return position;
                } on TimeoutException {
          debugPrint('LocationValidator: Timeout on attempt $attempt');
          
          if (attempt < maxLocationRetries) {
            // Tunggu sebentar sebelum retry
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        } catch (e) {
          debugPrint('LocationValidator: Error on attempt $attempt: $e');
          
          if (attempt < maxLocationRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }

      // -----------------------------------------------------------------------
      // FALLBACK: Last Known Position
      // -----------------------------------------------------------------------
      
      debugPrint('LocationValidator: Trying last known position...');
      
      try {
        position = await Geolocator.getLastKnownPosition()
            .timeout(const Duration(seconds: 10));
        
        if (position != null) {
          debugPrint(
            'LocationValidator: Last known position - '
            'lat: ${position.latitude}, lng: ${position.longitude}',
          );
        }
      } catch (e) {
        debugPrint('LocationValidator: Last known position failed: $e');
      }

      return position;

    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('LocationValidator: getCurrentLocation CRITICAL ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);
      return null;
    }
  }

  // ============================================================================
  // ADDRESS FROM COORDINATES (WITH TIMEOUT)
  // ============================================================================

  /// Mendapatkan alamat dari koordinat
  /// Returns null jika gagal atau timeout
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint('LocationValidator: Getting address for $latitude, $longitude');

      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(Duration(seconds: geocodingTimeoutSeconds));

      if (placemarks.isEmpty) {
        debugPrint('LocationValidator: No placemarks found');
        return null;
      }

      final place = placemarks.first;

      // Build address dari parts yang ada
      final parts = <String>[];

      if (place.street?.isNotEmpty == true) {
        parts.add(place.street!);
      }
      if (place.subLocality?.isNotEmpty == true) {
        parts.add(place.subLocality!);
      }
      if (place.locality?.isNotEmpty == true) {
        parts.add(place.locality!);
      }
      if (place.subAdministrativeArea?.isNotEmpty == true) {
        parts.add(place.subAdministrativeArea!);
      }
      if (place.administrativeArea?.isNotEmpty == true) {
        parts.add(place.administrativeArea!);
      }
      if (place.country?.isNotEmpty == true) {
        parts.add(place.country!);
      }

      // Jika tidak ada parts, return null
      if (parts.isEmpty) {
        debugPrint('LocationValidator: Address parts empty');
        return null;
      }

      final address = parts.join(', ');
      debugPrint('LocationValidator: Address: $address');
      
      return address;

    } on TimeoutException {
      debugPrint('LocationValidator: Geocoding timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('LocationValidator: Geocoding error: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }

  // ============================================================================
  // VALIDATE LOCATION
  // ============================================================================

  /// Validasi apakah user berada dalam radius absensi yang diizinkan
  Future<Map<String, dynamic>> validateLocation({
    required double currentLat,
    required double currentLng,
    required OvertimeHistory overtimeItem,
  }) async {
    try {
      // -----------------------------------------------------------------------
      // PARSE LOCATION DATA SAFELY
      // -----------------------------------------------------------------------
      
      final lokasi = _parseLokasi(overtimeItem.lokasi);

      debugPrint('LocationValidator: Parsed location data: $lokasi');

      // Jika data lokasi kosong/null → anggap valid (no reference)
      if (lokasi.isEmpty) {
        debugPrint('LocationValidator: No location reference, allowing');
        return _successNoReference();
      }

      // -----------------------------------------------------------------------
      // PARSE TARGET COORDINATES
      // -----------------------------------------------------------------------
      
      final targetLat = _parseDouble(lokasi['latitude']);
      final targetLng = _parseDouble(lokasi['longitude']);

      // Jika koordinat target tidak tersedia → anggap valid
      if (targetLat == null || targetLng == null) {
        debugPrint('LocationValidator: No target coordinates, allowing');
        return _successNoReference();
      }

      // -----------------------------------------------------------------------
      // GET MAXIMUM RADIUS
      // -----------------------------------------------------------------------
      
      final maxRadius = _getMaximumRadius(lokasi);
      debugPrint('LocationValidator: Max radius: ${maxRadius.toStringAsFixed(0)}m');

      // -----------------------------------------------------------------------
      // CALCULATE DISTANCE
      // -----------------------------------------------------------------------
      
      double distance;
      
      try {
        distance = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          targetLat,
          targetLng,
        );
      } catch (e) {
        // Fallback ke perhitungan manual jika Geolocator gagal
        debugPrint('LocationValidator: Geolocator distance failed, using manual: $e');
        distance = calculateDistanceManual(
          currentLat,
          currentLng,
          targetLat,
          targetLng,
        );
      }

      debugPrint(
        'LocationValidator: Distance: ${distance.toStringAsFixed(2)}m, '
        'Max: ${maxRadius.toStringAsFixed(0)}m',
      );

      // -----------------------------------------------------------------------
      // VALIDATE
      // -----------------------------------------------------------------------
      
      final isValid = distance <= maxRadius;

      return {
        'valid': isValid,
        'distance': distance,
        'max_radius': maxRadius,
        'target_latitude': targetLat,
        'target_longitude': targetLng,
        'current_latitude': currentLat,
        'current_longitude': currentLng,
        'message': isValid
            ? 'Lokasi valid (${distance.toStringAsFixed(0)}m dari target)'
            : 'Di luar radius absensi (${distance.toStringAsFixed(0)}m, maks ${maxRadius.toStringAsFixed(0)}m)',
      };

    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('LocationValidator: validateLocation ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);

      return {
        'valid': false,
        'distance': null,
        'max_radius': null,
        'message': 'Terjadi kesalahan saat validasi lokasi',
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // BATCH VALIDATION (FOR MULTIPLE LOCATIONS)
  // ============================================================================

  /// Validasi ke beberapa lokasi target sekaligus
  /// Returns true jika minimal satu target valid
  Future<bool> validateAnyLocation({
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> targetLocations,
  }) async {
    if (targetLocations.isEmpty) return true;

    for (final target in targetLocations) {
      final targetLat = _parseDouble(target['latitude']);
      final targetLng = _parseDouble(target['longitude']);

      if (targetLat == null || targetLng == null) continue;

      final maxRadius = _getMaximumRadius(target);
      final distance = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        targetLat,
        targetLng,
      );

      if (distance <= maxRadius) {
        debugPrint('LocationValidator: Found valid location at distance ${distance.toStringAsFixed(0)}m');
        return true;
      }
    }

    return false;
  }

  // ============================================================================
  // OPEN SETTINGS HELPERS
  // ============================================================================

  /// Buka pengaturan GPS/Location
  Future<bool> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      return true;
    } catch (e) {
      debugPrint('LocationValidator: Cannot open location settings: $e');
      return false;
    }
  }

  /// Buka pengaturan aplikasi
  Future<bool> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
      return true;
    } catch (e) {
      debugPrint('LocationValidator: Cannot open app settings: $e');
      return false;
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Parse lokasi dengan aman, tangani null & tipe data tidak valid
  Map<String, dynamic> _parseLokasi(dynamic lokasiData) {
    try {
      // Null check
      if (lokasiData == null) {
        return {};
      }

      // Jika sudah Map<String, dynamic>
      if (lokasiData is Map<String, dynamic>) {
        return lokasiData;
      }

      // Jika Map biasa (dari Firestore)
      if (lokasiData is Map) {
        return Map<String, dynamic>.from(lokasiData);
      }

      // Tipe data tidak dikenal
      debugPrint('LocationValidator: Unknown lokasi type: ${lokasiData.runtimeType}');
      return {};

    } catch (e) {
      debugPrint('LocationValidator: Error parsing lokasi: $e');
      return {};
    }
  }

  /// Status sukses tanpa referensi (tidak ada koordinat target)
  Map<String, dynamic> _successNoReference() {
    return {
      'valid': true,
      'distance': null,
      'max_radius': null,
      'message': 'Tidak ada koordinat referensi - lokasi diizinkan',
    };
  }

  /// Mendapatkan radius maksimal dari data lokasi
  double _getMaximumRadius(Map<String, dynamic> lokasi) {
    try {
      // Cek radius dalam meter (custom)
      final customMeter = _parseDouble(lokasi['radius_meter']);
      if (customMeter != null && customMeter > 0) {
        debugPrint('LocationValidator: Using custom radius: ${customMeter}m');
        return customMeter;
      }

      // Cek radius dalam kilometer (custom)
      final customKm = _parseDouble(lokasi['radius_km']);
      if (customKm != null && customKm > 0) {
        final radiusInMeter = customKm * 1000;
        debugPrint('LocationValidator: Using custom radius: ${radiusInMeter}m (${customKm}km)');
        return radiusInMeter;
      }

      // Cek radius langsung (backward compatibility)
      final radius = _parseDouble(lokasi['radius']);
      if (radius != null && radius > 0) {
        return radius;
      }

      // Radius berdasarkan jenis lokasi
      final jenis = (lokasi['jenis']?.toString() ?? '').toLowerCase().trim();

      switch (jenis) {
        case 'kantor':
        case 'office':
        case 'gedung':
        case 'building':
          return defaultRadiusOffice;

        case 'project':
        case 'proyek':
        case 'lapangan':
        case 'field':
        case 'site':
        case 'lokasi':
          return defaultRadiusProject;

        default:
          // Default ke radius project yang lebih besar
          return defaultRadiusProject;
      }
    } catch (e) {
      debugPrint('LocationValidator: Error getting max radius: $e');
      return defaultRadiusProject;
    }
  }

  // ============================================================================
  // PARSE DOUBLE (SAFE)
  // ============================================================================

  /// Parse berbagai tipe data ke double dengan aman
  double? _parseDouble(dynamic value) {
    try {
      if (value == null) return null;

      // Already double
      if (value is double) {
        return value.isNaN || value.isInfinite ? null : value;
      }

      // int to double
      if (value is int) {
        return value.toDouble();
      }

      // num to double
      if (value is num) {
        return value.toDouble();
      }

      // String to double
      if (value is String) {
        return double.tryParse(value.trim());
      }

      // Fallback
      return double.tryParse(value.toString().trim());
    } catch (e) {
      debugPrint('LocationValidator: Failed to parse double: $value ($e)');
      return null;
    }
  }

  // ============================================================================
  // DISTANCE CALCULATION (HAVERSINE FORMULA)
  // ============================================================================

  /// Kalkulasi jarak manual (backup jika Geolocator gagal)
  double calculateDistanceManual(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000.0; // meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Konversi derajat ke radian
  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  /// Format jarak ke string yang readable
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} meter';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Cek apakah GPS tersedia dan permission granted
  Future<Map<String, dynamic>> checkLocationAvailability() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      final permission = await checkAndRequestPermission();
      final isGranted = isPermissionGranted(permission);

      return {
        'available': serviceEnabled && isGranted,
        'service_enabled': serviceEnabled,
        'permission_granted': isGranted,
        'permission_status': permission.toString(),
      };
    } catch (e) {
      debugPrint('LocationValidator: Availability check error: $e');
      return {
        'available': false,
        'service_enabled': false,
        'permission_granted': false,
        'error': e.toString(),
      };
    }
  }
}