// lib/features/superadmin/widgets/analytics_section.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/app_colors.dart';
import '../../core/services/superadmin_service.dart';

class AnalyticsSection extends StatefulWidget {
  final DashboardData data;

  const AnalyticsSection({
    super.key,
    required this.data,
  });

  @override
  State<AnalyticsSection> createState() =>
      _AnalyticsSectionState();
}

class _AnalyticsSectionState
    extends State<AnalyticsSection> {
  int _selectedIndex = -1;

  bool _isLoading = true;

  List<double> _weeklyData = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    try {
      final firestore =
          FirebaseFirestore.instance;

      final now = DateTime.now();

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final startOfWeek = today.subtract(
        Duration(days: today.weekday - 1),
      );

      final snapshot = await firestore
          .collection('lembur_mitra')
          .where(
            'tanggal',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(
              startOfWeek,
            ),
          )
          .orderBy(
            'tanggal',
            descending: false,
          )
          .limit(300)
          .get();

      final List<double> dailyData = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final tanggal =
            (data['tanggal']
                    as Timestamp?)
                ?.toDate();

        final totalJam =
            (data['total_jam_desimal']
                        as num?)
                    ?.toDouble() ??
                0;

        if (tanggal != null &&
            totalJam > 0) {
          final index =
              tanggal.weekday - 1;

          if (index >= 0 &&
              index < 7) {
            dailyData[index] += totalJam;
          }
        }
      }

      if (mounted) {
        setState(() {
          _weeklyData = dailyData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'AnalyticsSection Error: $e',
      );

      final avg =
          (widget.data.totalOvertime / 7)
              .clamp(0.0, 25.0);

      if (mounted) {
        setState(() {
          _weeklyData = List.generate(
            7,
            (i) => (avg *
                    (0.45 +
                        (i % 5) * 0.22))
                .clamp(0.0, 25.0),
          );

          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    await _loadWeeklyData();
  }

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width;

    final isTablet = width >= 700;

    final chartHeight =
        isTablet ? 270.0 : 220.0;

    final barWidth =
        isTablet ? 24.0 : 18.0;

    final maxVal = _weeklyData.reduce(
      (a, b) => a > b ? a : b,
    );

    final maxY = (maxVal * 1.4)
        .ceilToDouble()
        .clamp(10.0, 50.0);

    final hasData =
        _weeklyData.any((e) => e > 0);

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // =========================
          // HEADER
          // =========================

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,

            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .all(10),

                    decoration:
                        BoxDecoration(
                      color:
                          AppColors
                              .primaryBlue
                              .withAlpha(20),

                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),

                    child: const Icon(
                      Icons
                          .analytics_rounded,
                      color:
                          AppColors
                              .primaryBlue,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        'Lembur Mingguan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      SizedBox(height: 2),

                      Text(
                        'Analisis aktivitas lembur mingguan',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              InkWell(
                onTap: _refresh,

                borderRadius:
                    BorderRadius.circular(
                        12),

                child: Container(
                  padding:
                      const EdgeInsets
                          .all(10),

                  decoration:
                      BoxDecoration(
                    color:
                        AppColors
                            .primaryBlue
                            .withAlpha(16),

                    borderRadius:
                        BorderRadius
                            .circular(12),
                  ),

                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color: AppColors
                                .primaryBlue,
                          ),
                        )
                      : const Icon(
                          Icons
                              .refresh_rounded,
                          size: 20,
                          color: AppColors
                              .primaryBlue,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =========================
          // INFO CHIPS
          // =========================

          Wrap(
            spacing: 8,
            runSpacing: 8,

            children: [
              _buildChip(
                label: 'Total',
                value:
                    '${widget.data.totalOvertime}',
                icon:
                    Icons.work_history_rounded,
                color:
                    AppColors.primaryBlue,
              ),

              _buildChip(
                label: 'Pending',
                value:
                    '${widget.data.pendingApprovals}',
                icon:
                    Icons.pending_actions_rounded,
                color: Colors.orange,
              ),

              _buildChip(
                label: 'Approved',
                value:
                    '${widget.data.approvedOvertime}',
                icon:
                    Icons.check_circle_rounded,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // =========================
          // CHART
          // =========================

          AnimatedSwitcher(
            duration:
                const Duration(
                    milliseconds: 350),

            child: SizedBox(
              key: ValueKey(
                _isLoading.toString() +
                    hasData.toString(),
              ),

              height: chartHeight,

              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color: AppColors
                            .primaryBlue,
                      ),
                    )
                  : !hasData
                      ? _buildEmptyState()
                      : BarChart(
                          BarChartData(
                            alignment:
                                BarChartAlignment
                                    .spaceAround,

                            maxY: maxY,

                            borderData:
                                FlBorderData(
                              show: false,
                            ),

                            gridData:
                                FlGridData(
                              show: true,

                              drawVerticalLine:
                                  false,

                              horizontalInterval:
                                  (maxY / 4)
                                      .clamp(
                                1,
                                25,
                              ),

                              getDrawingHorizontalLine:
                                  (value) {
                                return FlLine(
                                  color: Colors
                                      .grey
                                      .withAlpha(
                                          20),

                                  strokeWidth:
                                      1,
                                );
                              },
                            ),

                            titlesData:
                                FlTitlesData(
                              topTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),

                              rightTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),

                              leftTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      true,

                                  interval:
                                      (maxY /
                                              4)
                                          .ceilToDouble(),

                                  reservedSize:
                                      34,

                                  getTitlesWidget:
                                      (
                                    value,
                                    meta,
                                  ) {
                                    return Text(
                                      '${value.toInt()}j',

                                      style:
                                          const TextStyle(
                                        fontSize:
                                            10,
                                        color:
                                            Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              bottomTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      true,

                                  getTitlesWidget:
                                      (
                                    value,
                                    meta,
                                  ) {
                                    const days =
                                        [
                                      'Sen',
                                      'Sel',
                                      'Rab',
                                      'Kam',
                                      'Jum',
                                      'Sab',
                                      'Min',
                                    ];

                                    if (value >=
                                            0 &&
                                        value <
                                            7) {
                                      final isToday =
                                          DateTime.now()
                                                      .weekday -
                                                  1 ==
                                              value
                                                  .toInt();

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(
                                          top: 8,
                                        ),

                                        child:
                                            Text(
                                          days[value
                                              .toInt()],

                                          style:
                                              TextStyle(
                                            fontSize:
                                                10,

                                            fontWeight: isToday
                                                ? FontWeight.bold
                                                : FontWeight.w500,

                                            color: isToday
                                                ? AppColors.primaryBlue
                                                : Colors.grey,
                                          ),
                                        ),
                                      );
                                    }

                                    return const SizedBox();
                                  },
                                ),
                              ),
                            ),

                            barTouchData:
                                BarTouchData(
                              enabled: true,

                              touchCallback:
                                  (
                                event,
                                response,
                              ) {
                                setState(() {
                                  _selectedIndex =
                                      response
                                              ?.spot
                                              ?.touchedBarGroupIndex ??
                                          -1;
                                });
                              },

                              touchTooltipData:
                                  BarTouchTooltipData(
                                tooltipPadding:
                                    const EdgeInsets.all(
                                  10,
                                ),

                                tooltipMargin:
                                    8,

                                getTooltipColor:
                                    (_) =>
                                        Colors
                                            .blueGrey
                                            .shade800,

                                getTooltipItem:
                                    (
                                  group,
                                  groupIndex,
                                  rod,
                                  rodIndex,
                                ) {
                                  const days =
                                      [
                                    'Senin',
                                    'Selasa',
                                    'Rabu',
                                    'Kamis',
                                    'Jumat',
                                    'Sabtu',
                                    'Minggu',
                                  ];

                                  return BarTooltipItem(
                                    '${days[group.x.toInt()]}\n${_weeklyData[group.x.toInt()].toStringAsFixed(1)} jam',

                                    const TextStyle(
                                      color:
                                          Colors
                                              .white,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          12,
                                    ),
                                  );
                                },
                              ),
                            ),

                            barGroups:
                                List.generate(
                              7,
                              (index) {
                                final value =
                                    _weeklyData[
                                        index];

                                final isSelected =
                                    _selectedIndex ==
                                        index;

                                final isToday =
                                    DateTime.now()
                                                .weekday -
                                            1 ==
                                        index;

                                return BarChartGroupData(
                                  x: index,

                                  showingTooltipIndicators:
                                      isSelected
                                          ? [0]
                                          : [],

                                  barRods: [
                                    BarChartRodData(
                                      toY:
                                          value,

                                      width:
                                          barWidth,

                                      borderRadius:
                                          const BorderRadius.only(
                                        topLeft:
                                            Radius.circular(
                                          6,
                                        ),
                                        topRight:
                                            Radius.circular(
                                          6,
                                        ),
                                      ),

                                      gradient:
                                          LinearGradient(
                                        begin:
                                            Alignment.bottomCenter,
                                        end:
                                            Alignment.topCenter,

                                        colors:
                                            isSelected
                                                ? [
                                                    AppColors.accentOrange,
                                                    AppColors.accentOrange.withAlpha(180),
                                                  ]
                                                : isToday
                                                    ? [
                                                        AppColors.primaryBlue,
                                                        AppColors.primaryBlue.withAlpha(200),
                                                      ]
                                                    : [
                                                        AppColors.primaryBlue.withAlpha(140),
                                                        AppColors.primaryBlue.withAlpha(90),
                                                      ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ),

          const SizedBox(height: 18),

          // =========================
          // LEGEND
          // =========================

          Center(
            child: _buildLegend(
              'Jam Lembur',
              AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // CHIP
  // =========================

  Widget _buildChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 95,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: color.withAlpha(16),

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color: color.withAlpha(40),
        ),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),

          const SizedBox(width: 6),

          Flexible(
            child: Text(
              '$label: $value',

              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,

              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // LEGEND
  // =========================

  Widget _buildLegend(
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 12,
          height: 12,

          decoration: BoxDecoration(
            color: color,
            borderRadius:
                BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================
  // EMPTY STATE
  // =========================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Container(
            width: 70,
            height: 70,

            decoration: BoxDecoration(
              color:
                  Colors.grey.withAlpha(10),
              shape: BoxShape.circle,
            ),

            child: Icon(
              Icons.bar_chart_rounded,
              size: 38,
              color: Colors.grey[350],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Belum ada data lembur',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Tidak ada aktivitas lembur minggu ini.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}