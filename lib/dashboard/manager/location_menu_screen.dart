// FILE: lib/dashboard/manager/location_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class LocationMenuScreen extends StatefulWidget {
  final List<Map<String, dynamic>> teamMembers;
  final List<Map<String, dynamic>> locations;

  const LocationMenuScreen({
    super.key,
    required this.teamMembers,
    required this.locations,
  });

  @override
  State<LocationMenuScreen> createState() => _LocationMenuScreenState();
}

class _LocationMenuScreenState extends State<LocationMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? selectedLocation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'baru saja';

    DateTime time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return 'baru saja';
    }

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} bln';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hr';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} mnt';
    } else {
      return 'br saja';
    }
  }

  Future<void> _launchMaps(double lat, double lng) async {
    try {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka maps')),
      );
    }
  }

  void _showLocationDetail(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (location['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: location['color'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              location['address'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (location['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          location['status'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: location['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildDetailRow('Koordinat',
                            '${location['lat'].toStringAsFixed(4)}, ${location['lng'].toStringAsFixed(4)}'),
                        _buildDetailRow('Last Update', _getTimeAgo(location['lastUpdate'])),
                        const Divider(height: 24),
                        _buildDetailRow('Jumlah Pekerja', '${location['workers']} orang'),
                        _buildDetailRow('CCTV Terpasang', '${location['cctv']} unit'),
                        _buildDetailRow('Battery', '${location['battery']}%'),
                        _buildDetailRow('Sinyal', location['signal']),
                        if (location['anomaly'] != null) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['anomaly'],
                                    style: GoogleFonts.poppins(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (location['warning'] != null) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['warning'],
                                    style: GoogleFonts.poppins(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchMaps(location['lat'], location['lng']),
                          icon: const Icon(Icons.map),
                          label: Text('Buka Maps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: location['color'],
                            side: BorderSide(color: location['color']),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: location['color'],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Monitoring Lokasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Peta', icon: Icon(Icons.map)),
            Tab(text: 'Daftar', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Map View
          Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(-6.2088, 106.8456),
                  initialZoom: 11,
                  maxZoom: 18,
                  minZoom: 3,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: widget.locations.map((location) {
                      return Marker(
                        point: LatLng(location['lat'], location['lng']),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showLocationDetail(location),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (location['status'] == 'Anomali')
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.5, end: 1.5),
                                  duration: const Duration(seconds: 1),
                                  curve: Curves.easeInOut,
                                  builder: (context, double scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: location['color'],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (location['color'] as Color).withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  location['status'] == 'Anomali'
                                      ? Icons.warning
                                      : Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Summary Card
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMapStat(
                          'Total Site',
                          widget.locations.length.toString(),
                          Icons.location_on,
                          Colors.purple,
                        ),
                        Container(height: 30, width: 1, color: Colors.grey[300]),
                        _buildMapStat(
                          'Normal',
                          widget.locations.where((l) => l['status'] == 'Normal').length.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        Container(height: 30, width: 1, color: Colors.grey[300]),
                        _buildMapStat(
                          'Anomali',
                          widget.locations.where((l) => l['status'] != 'Normal').length.toString(),
                          Icons.warning,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // List View
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.locations.length,
            itemBuilder: (context, index) {
              final location = widget.locations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _showLocationDetail(location),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (location['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      location['status'] == 'Anomali' ? Icons.warning : Icons.location_on,
                      color: location['color'],
                    ),
                  ),
                  title: Text(
                    location['name'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    location['address'],
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (location['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          location['status'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: location['color'],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${location['workers']} pekerja',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}