// lib/features/superadmin/widgets/location_monitoring.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/services/superadmin_service.dart';

class LocationMonitoring extends StatefulWidget {
  final DashboardService service;

  const LocationMonitoring({super.key, required this.service});

  @override
  State<LocationMonitoring> createState() => _LocationMonitoringState();
}

class _LocationMonitoringState extends State<LocationMonitoring>
    with WidgetsBindingObserver {
  MapController? _mapController;
  bool _disposed = false;
  List<LocationData> _lastLocations = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  // Auto-fit ketika data berubah (jumlah marker atau koordinat berubah)
  void _scheduleAutoFit(List<LocationData> locations) {
    if (locations.isEmpty || _mapController == null) return;

    bool changed = _lastLocations.length != locations.length;
    if (!changed) {
      for (int i = 0; i < locations.length; i++) {
        final a = _lastLocations[i];
        final b = locations[i];
        if (a.id != b.id || a.lat != b.lat || a.lng != b.lng) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;

    _lastLocations = locations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted) _fitAllMarkers(locations);
    });
  }

  void _fitAllMarkers(List<LocationData> locations) {
    if (locations.isEmpty || _mapController == null) return;
    try {
      double minLat = locations.first.lat;
      double maxLat = locations.first.lat;
      double minLng = locations.first.lng;
      double maxLng = locations.first.lng;

      for (var loc in locations) {
        if (loc.lat < minLat) minLat = loc.lat;
        if (loc.lat > maxLat) maxLat = loc.lat;
        if (loc.lng < minLng) minLng = loc.lng;
        if (loc.lng > maxLng) maxLng = loc.lng;
      }

      final bounds = LatLngBounds(
        LatLng(minLat - 0.02, minLng - 0.02),
        LatLng(maxLat + 0.02, maxLng + 0.02),
      );

      _mapController!.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (e) {
      debugPrint('Fit markers error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan stream aktif (filter hanya yang sedang check-in lembur)
    final stream = widget.service.streamActiveOvertimeLocations();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<List<LocationData>>(
        stream: stream,
        builder: (context, snapshot) {
          // Error state
          if (snapshot.hasError) {
            return _buildErrorMap(snapshot.error.toString());
          }

          // Loading state (belum ada data pertama)
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingMap();
          }

          final locations = snapshot.data ?? [];
          final anomalyCount = locations.where((l) => l.status != 'Normal').length;

          // Auto-fit jika data berubah
          if (locations.isNotEmpty) {
            _scheduleAutoFit(locations);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text('Monitoring Lokasi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: anomalyCount > 0
                          ? Colors.red.withAlpha(26)
                          : Colors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: anomalyCount > 0 ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${locations.length} Site · $anomalyCount Anomali',
                          style: TextStyle(
                            fontSize: 10,
                            color: anomalyCount > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Map area
              if (locations.isEmpty)
                _buildEmptyMap()
              else ...[
                _buildRealMap(locations),
                const SizedBox(height: 12),
                _buildLocationCards(locations),
              ],
            ],
          );
        },
      ),
    );
  }

  // ==================== MAP COMPONENTS (menerima data) ====================
  Widget _buildLoadingMap() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 12),
            Text('Memuat peta & data lokasi...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMap(String error) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {}), // trigger rebuild untuk reconnect stream
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMap() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Belum ada data lokasi', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('Lokasi akan muncul setelah ada\naktivitas absensi atau lembur',
                style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRealMap(List<LocationData> locations) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8), // ⬅️ warna latar peta (pengganti backgroundColor)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: locations.isNotEmpty
              ? LatLng(locations.first.lat, locations.first.lng)
              : const LatLng(-2.5, 118.0),
          initialZoom: locations.isNotEmpty ? 13.0 : 5.0,
          minZoom: 3.0,
          maxZoom: 18.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (_, point) => _showSnackBar(
            'Koordinat: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.otp_apk.app',
            tileProvider: CancellableNetworkTileProvider(),
            // ❌ backgroundColor sudah dihapus
          ),
          MarkerLayer(
            markers: locations.map((loc) {
              final isAnomaly = loc.status == 'Anomali';
              final latLng = LatLng(loc.lat, loc.lng);
              return Marker(
                point: latLng,
                width: isAnomaly ? 90 : 80,
                height: isAnomaly ? 90 : 80,
                child: GestureDetector(
                  onTap: () {
                    _showDetail(loc);
                    _mapController?.move(latLng, 15.0);
                  },
                  child: _buildMarkerWidget(loc, isAnomaly),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerWidget(LocationData location, bool isAnomaly) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAnomaly)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.5, end: 1.5),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            onEnd: () {
              if (!_disposed && mounted) setState(() {});
            },
          ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: location.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: location.color.withAlpha(128), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Icon(
            isAnomaly ? Icons.warning_rounded : Icons.location_on_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 2)],
          ),
          child: Text(
            location.name.length > 15 ? '${location.name.substring(0, 12)}...' : location.name,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: location.color),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCards(List<LocationData> locations) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          return GestureDetector(
            onTap: () {
              _showDetail(location);
              _mapController?.move(LatLng(location.lat, location.lng), 15.0);
            },
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: location.color.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: location.color.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: location.color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(location.name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.people, '${location.workers}', Colors.blue),
                      const SizedBox(width: 6),
                      _buildInfoChip(Icons.videocam, '${location.cctv}', Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        location.battery > 50 ? Icons.battery_charging_full : Icons.battery_alert,
                        size: 10, color: location.battery > 50 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 2),
                      Text('${location.battery}%', style: const TextStyle(fontSize: 9)),
                      const SizedBox(width: 8),
                      Icon(Icons.network_cell, size: 10, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(location.signal, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 8, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(widget.service.getTimeAgo(location.lastUpdate),
                          style: TextStyle(fontSize: 8, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }

  void _showDetail(LocationData location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: location.color.withAlpha(26), shape: BoxShape.circle),
                        child: Icon(Icons.location_on, color: location.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(location.address, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: location.color.withAlpha(26), borderRadius: BorderRadius.circular(16)),
                        child: Text(location.status, style: TextStyle(fontSize: 12, color: location.color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildDetailRow('Koordinat', '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}'),
                        _buildDetailRow('Last Update', widget.service.getTimeAgo(location.lastUpdate)),
                        const Divider(height: 24),
                        _buildDetailRow('Jumlah Pekerja', '${location.workers} orang'),
                        _buildDetailRow('Battery', '${location.battery}%'),
                        _buildDetailRow('Sinyal', location.signal),
                        _buildDetailRow('CCTV', '${location.cctv} unit'),
                        const Divider(height: 24),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.directions, color: Colors.blue, size: 20),
                          ),
                          title: const Text('Navigasi ke Lokasi'),
                          subtitle: const Text('Buka Google Maps'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _launchMaps(location.lat, location.lng),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.streetview, color: Colors.green, size: 20),
                          ),
                          title: const Text('Lihat di Peta'),
                          subtitle: const Text('Zoom ke lokasi'),
                          trailing: const Icon(Icons.zoom_in, size: 14),
                          onTap: () {
                            Navigator.pop(context);
                            if (!_disposed) _mapController?.move(LatLng(location.lat, location.lng), 17.0);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: location.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tutup'),
                    ),
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackBar('Tidak dapat membuka Google Maps');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}