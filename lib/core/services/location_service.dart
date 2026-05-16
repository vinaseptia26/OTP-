// lib/core/services/location_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const double kantorLat = -7.134711;
  static const double kantorLng = 107.799540;
  static const double radiusKantor = 300;
  static const String alamatKantor = "PT Pertamina Geothermal Energy Area Kamojang";

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan posisi GPS saat ini
  static Future<Position> getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      rethrow;
    }
  }

  /// Mendapatkan rekomendasi lokasi berdasarkan riwayat yang sering dipakai
  static Future<List<Map<String, dynamic>>> getRecommendedLocations() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('lembur_mitra')
          .where('pengawas_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      final Map<String, Map<String, dynamic>> locationFrequency = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map<String, dynamic>?;
        
        if (lokasi != null && lokasi['latitude'] != null && lokasi['longitude'] != null) {
          final lat = (lokasi['latitude'] as num).toDouble();
          final lng = (lokasi['longitude'] as num).toDouble();
          final alamat = lokasi['alamat'] ?? 'Lokasi Lembur';
          
          final key = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
          
          if (locationFrequency.containsKey(key)) {
            locationFrequency[key]!['count'] = (locationFrequency[key]!['count'] as int) + 1;
            locationFrequency[key]!['last_used'] = (data['created_at'] as Timestamp).toDate();
          } else {
            locationFrequency[key] = {
              'name': _getLocationName(alamat, lokasi),
              'address': alamat,
              'lat': lat,
              'lng': lng,
              'count': 1,
              'last_used': (data['created_at'] as Timestamp).toDate(),
            };
          }
        }
      }

      List<Map<String, dynamic>> recommendations = locationFrequency.values.toList();
      
      recommendations.sort((a, b) {
        final countCompare = (b['count'] as int).compareTo(a['count'] as int);
        if (countCompare != 0) return countCompare;
        return (b['last_used'] as DateTime).compareTo(a['last_used'] as DateTime);
      });

      recommendations = recommendations.take(10).toList();

      debugPrint('📍 Mendapatkan ${recommendations.length} rekomendasi lokasi');
      return recommendations;
      
    } catch (e) {
      debugPrint('Error getting recommended locations: $e');
      return [];
    }
  }

  /// Mendapatkan riwayat lokasi terbaru
  static Future<List<Map<String, dynamic>>> getRecentLocations({int limit = 20}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('lembur_mitra')
          .where('pengawas_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> locations = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map<String, dynamic>?;
        
        if (lokasi != null && lokasi['latitude'] != null && lokasi['longitude'] != null) {
          locations.add({
            'name': _getLocationName(lokasi['alamat'] ?? 'Lokasi Lembur', lokasi),
            'address': lokasi['alamat'] ?? 'Lokasi Lembur',
            'lat': (lokasi['latitude'] as num).toDouble(),
            'lng': (lokasi['longitude'] as num).toDouble(),
            'timestamp': (data['created_at'] as Timestamp).toDate(),
            'tanggal': _formatTanggal((data['tanggal'] as Timestamp).toDate()),
          });
        }
      }

      return locations;
      
    } catch (e) {
      debugPrint('Error getting recent locations: $e');
      return [];
    }
  }

  /// Search lokasi (dari rekomendasi + OpenStreetMap)
  static Future<List<Map<String, dynamic>>?> searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // 1. Cari dari rekomendasi yang match
      final recommendations = await getRecommendedLocations();
      final matchedRecommendations = recommendations.where((loc) {
        return loc['name'].toLowerCase().contains(query.toLowerCase()) ||
               loc['address'].toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      if (matchedRecommendations.isNotEmpty) {
        return matchedRecommendations;
      }

      // 2. Cari dari OpenStreetMap API
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1'
      );

      final response = await http.get(
        url, 
        headers: {'User-Agent': 'OvertimeApp-PGE/1.0'}
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) => {
            'lat': double.parse(item['lat']),
            'lng': double.parse(item['lon']),
            'address': item['display_name'],
            'name': _getDisplayName(item['display_name']),
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }
    return null;
  }

  /// Simpan lokasi ke riwayat (dipanggil setelah lembur disetujui)
  static Future<void> saveLocationToHistory({
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final historyRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('location_history')
          .doc();

      await historyRef.set({
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'used_at': FieldValue.serverTimestamp(),
        'count': 1,
      });
      
      debugPrint('✅ Lokasi disimpan ke riwayat: $address');
      
    } catch (e) {
      debugPrint('Error saving location history: $e');
    }
  }

  /// Mendapatkan lokasi kantor
  static Map<String, dynamic> getKantorLocation() {
    return {
      'name': 'Kantor PGE Kamojang',
      'address': alamatKantor,
      'lat': kantorLat,
      'lng': kantorLng,
      'is_kantor': true,
    };
  }

  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1'
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
      debugPrint('Error reverse geocoding: $e');
    }
    return null;
  }

  static Future<bool> detectFakeGPS() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          timeLimit: Duration(seconds: 15)
        ),
      );
      return position.isMocked || position.accuracy > 100;
    } catch (e) {
      debugPrint('Error detecting fake GPS: $e');
      return false;
    }
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static bool isOutsideRadius(double lat, double lng) {
    return calculateDistance(kantorLat, kantorLng, lat, lng) > radiusKantor;
  }

  // --- Helper private ---
  static String _getDisplayName(String fullAddress) {
    final parts = fullAddress.split(',');
    return parts.length > 3 ? parts.sublist(0, 3).join(',') : fullAddress;
  }

  static String _getLocationName(String address, [Map<String, dynamic>? lokasi]) {
    String base = '';
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      base = parts[0].trim();
    } else {
      base = address.length > 30 ? '${address.substring(0, 30)}...' : address;
    }

    if (lokasi != null) {
      final rt = lokasi['rt'];
      final rw = lokasi['rw'];
      if (rt != null && rt.toString().isNotEmpty) base += ' RT $rt';
      if (rw != null && rw.toString().isNotEmpty) base += '/$rw';
    }
    return base;
  }

  static String _formatTanggal(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}