import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OvertimeValidationChip extends StatelessWidget {
  final Map<String, dynamic>? lemburLokasi;
  final Map<String, dynamic>? absensiLokasi;
  final bool sudahAbsen;

  const OvertimeValidationChip({
    super.key,
    this.lemburLokasi,
    this.absensiLokasi,
    this.sudahAbsen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!sudahAbsen) {
      return _buildPending();
    }

    final validation = _validate();

    if (validation['is_valid'] == true) {
      return _buildValid(validation['distance'] as double);
    } else {
      return _buildInvalid(validation['distance'] as double, validation['message'] as String);
    }
  }

  Widget _buildPending() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'Belum divalidasi',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildValid(double distance) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lokasi sesuai (${distance.toStringAsFixed(0)}m)',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalid(double distance, String message) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 14, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tidak sesuai: ${distance.toStringAsFixed(0)}m',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _validate() {
    final lemburLat = lemburLokasi?['latitude'] as double?;
    final lemburLng = lemburLokasi?['longitude'] as double?;
    final absensiLat = absensiLokasi?['latitude'] as double?;
    final absensiLng = absensiLokasi?['longitude'] as double?;

    if (lemburLat == null || lemburLng == null || absensiLat == null || absensiLng == null) {
      return {
        'is_valid': false,
        'distance': 0.0,
        'message': 'Data koordinat tidak lengkap',
      };
    }

    final distance = _calculateDistance(lemburLat, lemburLng, absensiLat, absensiLng);
    const tolerance = 100.0;

    return {
      'is_valid': distance <= tolerance,
      'distance': distance,
      'tolerance': tolerance,
      'message': distance <= tolerance
          ? 'Lokasi sesuai dengan pengajuan'
          : 'Jarak ${distance.toStringAsFixed(0)}m melebihi toleransi ${tolerance.toStringAsFixed(0)}m',
    };
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}