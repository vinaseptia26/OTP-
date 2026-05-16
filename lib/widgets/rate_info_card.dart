import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_rate_service.dart';

class RateInfoCard extends StatelessWidget {
  final Map<String, dynamic>? rates;
  final OvertimeRateService _overtimeRateService = OvertimeRateService();

  RateInfoCard({super.key, required this.rates});

  @override
  Widget build(BuildContext context) {
    if (rates == null) return const SizedBox.shrink();

    final ratePerJam = (rates!['rate_per_hour'] as num?)?.toDouble() ?? 0;
    final weekdayRates = rates!['weekday_rate'] as Map<String, dynamic>;
    final holidayRates = rates!['holiday_rate'] as Map<String, dynamic>;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.attach_money, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tarif Lembur Aktif",
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
                  "/ jam",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRateColumn(
                  "🏢 Hari Kerja",
                  [
                    _buildRateRow(
                      "Jam 1",
                      "${weekdayRates['first_hour_multiplier']}x",
                      _overtimeRateService.formatRupiahCompact(ratePerJam * (weekdayRates['first_hour_multiplier'] as double)),
                    ),
                    _buildRateRow(
                      "Jam 2+",
                      "${weekdayRates['next_hours_multiplier']}x",
                      _overtimeRateService.formatRupiahCompact(ratePerJam * (weekdayRates['next_hours_multiplier'] as double)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateColumn(
                  "🎉 Hari Libur",
                  [
                    _buildRateRow(
                      "8 jam pertama",
                      "${holidayRates['first_8_hours_multiplier']}x",
                      _overtimeRateService.formatRupiahCompact(ratePerJam * (holidayRates['first_8_hours_multiplier'] as double)),
                    ),
                    _buildRateRow(
                      "Jam ke-9",
                      "${holidayRates['ninth_hour_multiplier']}x",
                      _overtimeRateService.formatRupiahCompact(ratePerJam * (holidayRates['ninth_hour_multiplier'] as double)),
                    ),
                    _buildRateRow(
                      "Jam ke-10+",
                      "${holidayRates['tenth_plus_multiplier']}x",
                      _overtimeRateService.formatRupiahCompact(ratePerJam * (holidayRates['tenth_plus_multiplier'] as double)),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          Row(
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