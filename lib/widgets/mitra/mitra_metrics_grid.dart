// lib/widgets/mitra/mitra_metrics_grid.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraMetricsGrid extends StatelessWidget {
  final int totalLembur;
  final double totalJam;
  final int pending;
  final int disetujui;
  final double totalIncome;
  final double sisaKuota;

  const MitraMetricsGrid({
    super.key,
    required this.totalLembur,
    required this.totalJam,
    required this.pending,
    required this.disetujui,
    required this.totalIncome,
    required this.sisaKuota,
  });

  @override
  Widget build(BuildContext context) {
    // Maksimum kuota (misal 40 jam)
    const double maxKuota = 40.0;
    
    // Hitung persentase dengan batas maksimal 100%
    final double kuotaPercentage = (sisaKuota / maxKuota).clamp(0.0, 1.0);
    final int kuotaPercent = (kuotaPercentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B4C).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Premium
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1565C0),
                      const Color(0xFF0D47A1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Executive Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B4C),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Real-time Performance Metrics',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF1A2B4C).withValues(alpha: 0.5),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1565C0).withValues(alpha: 0.1),
                      const Color(0xFF0D47A1).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1565C0),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Grid Premium - 3 Kolom
          Row(
            children: [
              Expanded(
                child: _buildPremiumMetricItem(
                  icon: Icons.work_history_rounded,
                  label: 'Total Lembur',
                  value: '$totalLembur',
                  suffix: 'kali',
                  color: const Color(0xFF1565C0),
                  gradientColors: const [
                    Color(0xFFE3F2FD),
                    Color(0xFFBBDEFB),
                  ],
                  iconBgColor: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPremiumMetricItem(
                  icon: Icons.timer_rounded,
                  label: 'Total Jam',
                  value: '${totalJam.toStringAsFixed(1)}',
                  suffix: 'jam',
                  color: const Color(0xFF00897B),
                  gradientColors: const [
                    Color(0xFFE0F2F1),
                    Color(0xFFB2DFDB),
                  ],
                  iconBgColor: const Color(0xFF00897B),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Grid Premium - 3 Kolom (Row 2)
          Row(
            children: [
              Expanded(
                child: _buildPremiumMetricItem(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  value: '$pending',
                  suffix: 'pengajuan',
                  color: const Color(0xFFE65100),
                  gradientColors: const [
                    Color(0xFFFFF3E0),
                    Color(0xFFFFE0B2),
                  ],
                  iconBgColor: const Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPremiumMetricItem(
                  icon: Icons.check_circle_rounded,
                  label: 'Disetujui',
                  value: '$disetujui',
                  suffix: 'pengajuan',
                  color: const Color(0xFF2E7D32),
                  gradientColors: const [
                    Color(0xFFE8F5E9),
                    Color(0xFFC8E6C9),
                  ],
                  iconBgColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Baris Khusus: Sisa Kuota - Full Width
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A237E).withValues(alpha: 0.05),
                  const Color(0xFF0D47A1).withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A237E),
                        const Color(0xFF1565C0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sisa Kuota Lembur',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF1A2B4C).withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${sisaKuota.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'jam tersisa',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF1A2B4C).withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Status label berdasarkan persentase
                          if (kuotaPercentage < 0.2)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                '⚠️ Hampir Habis',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (kuotaPercentage < 0.4)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                '⚡ Terbatas',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (kuotaPercentage > 0.8)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                '✅ Aman',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Progress Bar
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$kuotaPercent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A237E).withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: kuotaPercentage,
                          backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          color: kuotaPercentage < 0.2 
                              ? Colors.red 
                              : kuotaPercentage < 0.4 
                                  ? Colors.orange 
                                  : const Color(0xFF1565C0),
                          minHeight: 6,
                        ),
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

  Widget _buildPremiumMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required String suffix,
    required Color color,
    required List<Color> gradientColors,
    required Color iconBgColor,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dengan efek premium
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconBgColor, iconBgColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: iconBgColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const Spacer(),
              // Badge small
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Value dengan suffix
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000000) {
      return 'Rp ${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}Jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}K';
    }
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _calculateProductivity() {
    if (totalLembur == 0) return '0';
    final productivity = (disetujui / totalLembur) * 100;
    return productivity.toStringAsFixed(0);
  }
}