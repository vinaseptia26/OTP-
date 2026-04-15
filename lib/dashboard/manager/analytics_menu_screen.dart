// FILE: lib/dashboard/manager/analytics_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsMenuScreen extends StatefulWidget {
  final List<Map<String, dynamic>> projectStats;
  final List<Map<String, dynamic>> teamMembers;
  final double totalHours;
  final int overtimeThreshold;

  const AnalyticsMenuScreen({
    super.key,
    required this.projectStats,
    required this.teamMembers,
    required this.totalHours,
    required this.overtimeThreshold,
  });

  @override
  State<AnalyticsMenuScreen> createState() => _AnalyticsMenuScreenState();
}

class _AnalyticsMenuScreenState extends State<AnalyticsMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analisis & Statistik',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Proyek', icon: Icon(Icons.assignment)),
            Tab(text: 'Tim', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Metrics Cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _buildMetricCard(
                      'Total Lembur',
                      '${widget.totalHours.toStringAsFixed(1)} jam',
                      Icons.access_time,
                      Colors.blue,
                      'Bulan ini',
                    ),
                    _buildMetricCard(
                      'Batas Lembur',
                      '${widget.overtimeThreshold} jam',
                      Icons.timer,
                      Colors.orange,
                      'Per bulan',
                    ),
                    _buildMetricCard(
                      'Sisa Kuota',
                      '${(widget.overtimeThreshold - widget.totalHours).toStringAsFixed(1)} jam',
                      Icons.hourglass_empty,
                      (widget.overtimeThreshold - widget.totalHours) > 0
                          ? Colors.green
                          : Colors.red,
                      'Tersisa',
                    ),
                    _buildMetricCard(
                      'Utilisasi',
                      '${widget.totalHours > 0 ? ((widget.totalHours / widget.overtimeThreshold) * 100).toStringAsFixed(1) : '0'}%',
                      Icons.percent,
                      Colors.purple,
                      'Dari batas',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress Lembur Bulan Ini',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: widget.totalHours / widget.overtimeThreshold,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.totalHours / widget.overtimeThreshold > 0.8
                              ? Colors.red
                              : Colors.green,
                        ),
                        minHeight: 12,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.totalHours.toStringAsFixed(1)} jam',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${widget.overtimeThreshold} jam',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Distribution Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribusi Lembur per Proyek',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildPieChart(),
                      ),
                      const SizedBox(height: 16),
                      ..._buildPieChartLegends(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Proyek Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistik Per Proyek',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.projectStats.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.assignment, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada data proyek',
                          style: GoogleFonts.poppins(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                else
                  ...widget.projectStats.map((project) => _buildProjectCard(project)).toList(),
              ],
            ),
          ),

          // Tim Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kinerja Tim',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.teamMembers.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.people, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada data tim',
                          style: GoogleFonts.poppins(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                else
                  ...widget.teamMembers.map((member) => _buildTeamCard(member)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (widget.projectStats.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions) {
                touchedIndex = -1;
                return;
              }
              touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(widget.projectStats.length, (index) {
          final project = widget.projectStats[index];
          final totalJam = _toDouble(project['totalJam']);
          final isTouched = index == touchedIndex;
          final fontSize = isTouched ? 16.0 : 12.0;
          final radius = isTouched ? 120.0 : 110.0;

          return PieChartSectionData(
            color: _getProjectColor(index),
            value: totalJam,
            title: '${totalJam.toStringAsFixed(1)} jam',
            radius: radius,
            titleStyle: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildPieChartLegends() {
    if (widget.projectStats.isEmpty) return [];

    return widget.projectStats.asMap().entries.map((entry) {
      final index = entry.key;
      final project = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getProjectColor(index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                project['nama'],
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
            Text(
              '${_toDouble(project['totalJam']).toStringAsFixed(1)} jam',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getProjectColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final totalJam = _toDouble(project['totalJam']);
    final persentase = widget.totalHours > 0 ? (totalJam / widget.totalHours * 100) : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['nama'],
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${project['totalPengajuan']} pengajuan',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${totalJam.toStringAsFixed(1)} jam',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: persentase / 100,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kontribusi',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${persentase.toStringAsFixed(1)}% dari total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> member) {
    final totalLembur = _toDouble(member['totalLembur']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member['isOnline'] == true ? Colors.green : Colors.grey,
          child: Text(
            member['nama'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member['nama'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${member['role']} · ${member['fungsi']}',
          style: GoogleFonts.poppins(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${totalLembur.toStringAsFixed(1)} jam',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: member['isOnline'] == true ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}