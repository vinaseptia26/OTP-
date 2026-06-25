// lib/features/superadmin/widgets/location_monitoring.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/services/superadmin_service.dart';

class LocationMonitoring extends StatefulWidget {
  final DashboardService service;

  const LocationMonitoring({
    super.key,
    required this.service,
  });

  @override
  State<LocationMonitoring> createState() => _LocationMonitoringState();
}

class _LocationMonitoringState extends State<LocationMonitoring>
    with WidgetsBindingObserver {
  late final MapController _mapController;

  bool _disposed = false;

  List<LocationData> _lastLocations = [];

  DateTime _lastRefresh = DateTime.now();

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

    super.dispose();
  }

  // =========================
  // AUTO FIT MARKERS
  // =========================

  void _scheduleAutoFit(List<LocationData> locations) {
    if (locations.isEmpty) return;

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
      if (!_disposed && mounted) {
        _fitAllMarkers(locations);
      }
    });
  }

  void _fitAllMarkers(List<LocationData> locations) {
    if (locations.isEmpty) return;

    try {
      double minLat = locations.first.lat;
      double maxLat = locations.first.lat;
      double minLng = locations.first.lng;
      double maxLng = locations.first.lng;

      for (final loc in locations) {
        if (loc.lat < minLat) minLat = loc.lat;
        if (loc.lat > maxLat) maxLat = loc.lat;
        if (loc.lng < minLng) minLng = loc.lng;
        if (loc.lng > maxLng) maxLng = loc.lng;
      }

      final bounds = LatLngBounds(
        LatLng(minLat - 0.02, minLng - 0.02),
        LatLng(maxLat + 0.02, maxLng + 0.02),
      );

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      debugPrint('Fit marker error: $e');
    }
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final stream = widget.service.streamActiveOvertimeLocations();

    final screenWidth = MediaQuery.of(context).size.width;

    final mapHeight = screenWidth < 400 ? 220.0 : 270.0;

    final cardHeight = screenWidth < 360 ? 100.0 : 115.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<List<LocationData>>(
        stream: stream,
        builder: (context, snapshot) {
          // =========================
          // ERROR
          // =========================

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // =========================
          // LOADING
          // =========================

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildLoadingState(mapHeight);
          }

          final locations = snapshot.data ?? [];

          final anomalyCount =
              locations.where((e) => e.status != 'Normal').length;

          _lastRefresh = DateTime.now();

          if (locations.isNotEmpty) {
            _scheduleAutoFit(locations);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================
              // HEADER
              // =========================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Monitoring Lokasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // LIVE STATUS
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: anomalyCount > 0
                          ? Colors.red.withAlpha(20)
                          : Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: anomalyCount > 0
                                ? Colors.red
                                : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${locations.length} Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: anomalyCount > 0
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                'Update terakhir ${widget.service.getTimeAgo(_lastRefresh)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),

              const SizedBox(height: 16),

              // =========================
              // EMPTY
              // =========================

              if (locations.isEmpty)
                _buildEmptyState(mapHeight)
              else ...[
                // =========================
                // MAP
                // =========================

                _buildMap(
                  locations,
                  mapHeight,
                ),

                const SizedBox(height: 14),

                // =========================
                // LOCATION CARDS
                // =========================

                _buildLocationCards(
                  locations,
                  cardHeight,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // =========================
  // MAP
  // =========================

  Widget _buildMap(
    List<LocationData> locations,
    double height,
  ) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  locations.first.lat,
                  locations.first.lng,
                ),
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.otp_apk.app',
                  tileProvider: CancellableNetworkTileProvider(),
                  panBuffer: 2,
                  keepBuffer: 5,
                ),

                MarkerLayer(
                  markers: locations.map((location) {
                    final isAnomaly =
                        location.status == 'Anomali';

                    final point = LatLng(
                      location.lat,
                      location.lng,
                    );

                    return Marker(
                      point: point,
                      width: 85,
                      height: 85,
                      child: GestureDetector(
                        onTap: () {
                          _showDetail(location);

                          _mapController.move(point, 15);
                        },
                        child: _buildMarker(
                          location,
                          isAnomaly,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // =========================
          // FLOATING ZOOM BUTTONS
          // =========================

          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _mapButton(
                  Icons.add,
                  () {
                    final current =
                        _mapController.camera.zoom;

                    _mapController.move(
                      _mapController.camera.center,
                      current + 1,
                    );
                  },
                ),

                const SizedBox(height: 8),

                _mapButton(
                  Icons.remove,
                  () {
                    final current =
                        _mapController.camera.zoom;

                    _mapController.move(
                      _mapController.camera.center,
                      current - 1,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  // =========================
  // MARKER
  // =========================

  Widget _buildMarker(
    LocationData location,
    bool isAnomaly,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAnomaly)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(40),
              shape: BoxShape.circle,
            ),
          ),

        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: location.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: location.color.withAlpha(80),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            isAnomaly
                ? Icons.warning_rounded
                : Icons.location_on_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),

        const SizedBox(height: 4),

        Container(
          constraints: const BoxConstraints(
            maxWidth: 80,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: location.color,
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // LOCATION CARDS
  // =========================

  Widget _buildLocationCards(
    List<LocationData> locations,
    double height,
  ) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        cacheExtent: 300,
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];

          return GestureDetector(
            onTap: () {
              _showDetail(location);

              _mapController.move(
                LatLng(location.lat, location.lng),
                16,
              );
            },
            child: Container(
              width: 185,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: location.color.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: location.color.withAlpha(40),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: location.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _infoChip(
                        Icons.people,
                        '${location.workers}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _infoChip(
                        Icons.videocam,
                        '${location.cctv}',
                        Colors.grey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        location.battery > 50
                            ? Icons.battery_full
                            : Icons.battery_alert,
                        size: 12,
                        color: location.battery > 50
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${location.battery}%',
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 10,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.service.getTimeAgo(
                          location.lastUpdate,
                        ),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
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

  Widget _infoChip(
    IconData icon,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // =========================
  // STATES
  // =========================

  Widget _buildLoadingState(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada lokasi aktif',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // DETAIL SHEET
  // =========================

  void _showDetail(LocationData location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      location.address,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _detailTile(
                      Icons.people,
                      'Pekerja',
                      '${location.workers} Orang',
                    ),

                    _detailTile(
                      Icons.battery_full,
                      'Battery',
                      '${location.battery}%',
                    ),

                    _detailTile(
                      Icons.network_cell,
                      'Signal',
                      location.signal,
                    ),

                    _detailTile(
                      Icons.videocam,
                      'CCTV',
                      '${location.cctv} Unit',
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () =>
                          _launchMaps(location.lat, location.lng),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize:
                            const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text(
                        'Buka Google Maps',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _detailTile(
    IconData icon,
    String title,
    String value,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: AppColors.primaryBlue,
      ),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  // =========================
  // MAPS
  // =========================

  Future<void> _launchMaps(
    double lat,
    double lng,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      _showSnackBar(
        'Tidak dapat membuka Google Maps',
      );
    }
  }

  // =========================
  // SNACKBAR
  // =========================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}