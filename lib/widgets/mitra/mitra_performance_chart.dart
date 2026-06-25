// lib/widgets/mitra/mitra_performance_chart.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class MitraPerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> performanceData;

  const MitraPerformanceChart({
    super.key,
    required this.performanceData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(10),
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
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00C853).withAlpha(30), const Color(0xFF69F0AE).withAlpha(20)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded, size: 20, color: Color(0xFF00C853)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '📈 Grafik Performa',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2B4C)),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '6m', child: Text('6 Bulan')),
                  const PopupMenuItem(value: '1y', child: Text('1 Tahun')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue() * 1.2,
                barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} jam\n${_getMonthLabel(groupIndex)}',
                      const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  },
                )),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _getMonthLabel(value.toInt()),
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue() / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.withAlpha(30), strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: performanceData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['hours'] ?? 0).toDouble(),
                        color: const Color(0xFF1565C0),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _getMaxValue() * 1.2,
                          color: const Color(0xFF1565C0).withAlpha(15),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Total Jam Lembur per Bulan',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxValue() {
    if (performanceData.isEmpty) return 50;
    double max = 0;
    for (var data in performanceData) {
      final hours = (data['hours'] ?? 0).toDouble();
      if (hours > max) max = hours;
    }
    return max < 10 ? 10 : max;
  }

  String _getMonthLabel(int index) {
    if (index < performanceData.length) {
      return performanceData[index]['month']?.toString() ?? '';
    }
    return '';
  }
}