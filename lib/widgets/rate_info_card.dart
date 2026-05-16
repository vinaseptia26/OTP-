import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_rate_service.dart';

class RateInfoCard extends StatelessWidget {
  final Map<String, dynamic>? rates;
  final OvertimeRateService _overtimeRateService = OvertimeRateService();

  RateInfoCard({
    super.key,
    required this.rates,
  });

  // ==================== SAFE PARSER ====================

  double _toDouble(
    dynamic value, {
    double defaultValue = 0.0,
  }) {
    if (value == null) return defaultValue;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
      final normalized = cleaned.replaceAll(',', '.');
      return double.tryParse(normalized) ?? defaultValue;
    }

    return defaultValue;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _formatMultiplier(double value) {
    return '${value.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    if (rates == null || rates!.isEmpty) {
      return const SizedBox.shrink();
    }

    final ratePerJam = _toDouble(
      rates!['rate_per_hour'],
      defaultValue: 0.0,
    );

    final weekdayRates = _toMap(rates!['weekday_rate']);
    final holidayRates = _toMap(rates!['holiday_rate']);

    final firstHourMultiplier = _toDouble(
      weekdayRates['first_hour_multiplier'],
      defaultValue: 1.5,
    );

    final nextHoursMultiplier = _toDouble(
      weekdayRates['next_hours_multiplier'],
      defaultValue: 2.0,
    );

    final first8HoursMultiplier = _toDouble(
      holidayRates['first_8_hours_multiplier'],
      defaultValue: 2.0,
    );

    final ninthHourMultiplier = _toDouble(
      holidayRates['ninth_hour_multiplier'],
      defaultValue: 3.0,
    );

    final tenthPlusMultiplier = _toDouble(
      holidayRates['tenth_plus_multiplier'],
      defaultValue: 4.0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(ratePerJam),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRateColumn(
                  '🏢 Hari Kerja',
                  [
                    _buildRateRow(
                      'Jam 1',
                      _formatMultiplier(firstHourMultiplier),
                      _overtimeRateService.formatRupiahCompact(
                        ratePerJam * firstHourMultiplier,
                      ),
                    ),
                    _buildRateRow(
                      'Jam 2+',
                      _formatMultiplier(nextHoursMultiplier),
                      _overtimeRateService.formatRupiahCompact(
                        ratePerJam * nextHoursMultiplier,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateColumn(
                  '🎉 Hari Libur',
                  [
                    _buildRateRow(
                      '8 jam pertama',
                      _formatMultiplier(first8HoursMultiplier),
                      _overtimeRateService.formatRupiahCompact(
                        ratePerJam * first8HoursMultiplier,
                      ),
                    ),
                    _buildRateRow(
                      'Jam ke-9',
                      _formatMultiplier(ninthHourMultiplier),
                      _overtimeRateService.formatRupiahCompact(
                        ratePerJam * ninthHourMultiplier,
                      ),
                    ),
                    _buildRateRow(
                      'Jam ke-10+',
                      _formatMultiplier(tenthPlusMultiplier),
                      _overtimeRateService.formatRupiahCompact(
                        ratePerJam * tenthPlusMultiplier,
                      ),
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

  Widget _buildHeader(double ratePerJam) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.attach_money,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarif Lembur Aktif',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                _overtimeRateService.formatRupiahCompact(ratePerJam),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '/ jam',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateColumn(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _buildRateRow(String label, String multiplier, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  multiplier,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                amount,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}