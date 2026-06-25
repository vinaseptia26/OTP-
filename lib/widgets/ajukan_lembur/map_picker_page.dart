// lib/features/pengawas/lembur/widgets/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/core/services/location_service.dart';

/// MapPickerPage - Halaman pemilihan lokasi dengan peta satelit interaktif
/// 
/// Fitur:
/// - Google Satellite Hybrid (satelit + label jalan)
/// - Pencarian lokasi (Nominatim + riwayat)
/// - Radius kantor visual
/// - Validasi jarak dari kantor
/// - Crosshair center untuk akurasi
/// - Address overlay dengan info jarak
/// - Zoom controls + my location button
/// - Konfirmasi lokasi di luar radius
class MapPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final bool isProjectLocation;

  const MapPickerPage({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.isProjectLocation = true,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // ==================== CONTROLLERS ====================
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ==================== LOCATION STATE ====================
  LatLng? _pickedLocation;
  String _currentAddress = '';
  bool _isLoadingAddress = false;
  
  // ==================== RADIUS STATE ====================
  bool _isOutsideRadius = false;
  double _distanceFromOffice = 0.0;
  bool _showLocationWarning = false;
  
  // ==================== MAP STATE ====================
  bool _isSearching = false;
  String _currentMapType = 'hybrid'; // 'hybrid', 'satellite', 'map'
  bool _isMapReady = false;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _pickedLocation = LatLng(widget.initialLat, widget.initialLng);
    _initMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initMap() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isMapReady = true);
      _updateAddress();
      _checkRadius();
    }
  }

  // ==================== RADIUS CHECK ====================
  Future<void> _checkRadius() async {
    if (_pickedLocation == null) return;
    
    try {
      final isOutside = LocationService.isOutsideRadius(
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
      );
      
      final distance = LocationService.calculateDistance(
        LocationService.kantorLat,
        LocationService.kantorLng,
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
      );
      
      if (mounted) {
        setState(() {
          _isOutsideRadius = isOutside;
          _distanceFromOffice = distance;
          _showLocationWarning = isOutside && widget.isProjectLocation;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error checking radius: $e');
    }
  }

  // ==================== REVERSE GEOCODE ====================
  Future<void> _updateAddress() async {
    if (_pickedLocation == null) return;
    
    setState(() => _isLoadingAddress = true);
    
    try {
      // Cek lokasi kantor dulu
      if (LocationService.isKantorLocation(
          _pickedLocation!.latitude, _pickedLocation!.longitude)) {
        if (mounted) {
          setState(() {
            _currentAddress = LocationService.alamatKantor;
            _isLoadingAddress = false;
          });
        }
        return;
      }

      final result = await LocationService.reverseGeocode(
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
      );
      
      if (mounted) {
        setState(() {
          _currentAddress = result != null
              ? (result['address']?.toString() ?? _formatCoordinate(_pickedLocation!))
              : _formatCoordinate(_pickedLocation!);
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Reverse geocode error: $e');
      if (mounted) {
        setState(() {
          _currentAddress = _formatCoordinate(_pickedLocation!);
          _isLoadingAddress = false;
        });
      }
    }
  }

  // ==================== FORMAT HELPERS ====================
  String _formatCoordinate(LatLng pos) {
    return '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
  }

  String _formatDistance(double meter) {
    if (meter >= 1000) {
      return '${(meter / 1000).toStringAsFixed(2)} km';
    }
    return '${meter.toStringAsFixed(0)} m';
  }

  // ==================== SEARCH ====================
  Future<void> _searchAndGo(String query) async {
    if (query.trim().isEmpty) {
      _showSnackBar('Masukkan kata kunci pencarian', isError: true);
      return;
    }
    
    setState(() => _isSearching = true);
    _searchFocusNode.unfocus();
    
    try {
      final results = await LocationService.searchLocation(query);
      
      if (!mounted) return;
      
      if (results == null || results.isEmpty) {
        _showSnackBar('Lokasi proyek tidak ditemukan. Coba kata kunci lain.', isError: true);
        setState(() => _isSearching = false);
        return;
      }
      
      final first = results.first;
      final lat = (first['lat'] as num).toDouble();
      final lng = (first['lng'] as num).toDouble();
      final newPos = LatLng(lat, lng);
      
      setState(() {
        _pickedLocation = newPos;
        _showLocationWarning = false;
      });
      
      _mapController.move(newPos, 18.0);
      await _updateAddress();
      await _checkRadius();
      
      if (mounted) {
        _showSnackBar(
          'Lokasi ditemukan: ${first['name'] ?? first['address'] ?? query}',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal mencari lokasi. Periksa koneksi internet.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ==================== SNACKBAR ====================
  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.orange.shade800 : isSuccess ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== VALIDATION ====================
  bool _validateBeforeSubmit() {
    if (_pickedLocation == null) {
      _showSnackBar('Pilih lokasi terlebih dahulu', isError: true);
      return false;
    }
    
    if (widget.isProjectLocation && _currentAddress.isEmpty) {
      _showSnackBar('Alamat lokasi tidak valid, pilih lokasi lain', isError: true);
      return false;
    }
    
    return true;
  }

  // ==================== CONFIRM LOCATION ====================
  Future<void> _confirmLocation() async {
    if (!_validateBeforeSubmit()) return;
    
    // Jika di luar radius & mode proyek, tampilkan konfirmasi
    if (_isOutsideRadius && widget.isProjectLocation) {
      final confirmed = await _showOutsideRadiusDialog();
      if (confirmed != true) return;
    }
    
    // Simpan lokasi ke riwayat
    if (mounted && _currentAddress.isNotEmpty) {
      LocationService.saveLocationToHistory(
        lat: _pickedLocation!.latitude,
        lng: _pickedLocation!.longitude,
        address: _currentAddress,
      );
    }
    
    if (mounted) {
      Navigator.pop(context, {
        'lat': _pickedLocation!.latitude,
        'lng': _pickedLocation!.longitude,
        'address': _currentAddress.isNotEmpty ? _currentAddress : _formatCoordinate(_pickedLocation!),
        'is_outside_radius': _isOutsideRadius,
        'distance_from_office': _distanceFromOffice,
      });
    }
  }

  Future<bool?> _showOutsideRadiusDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Lokasi di Luar Radius',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info jarak
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.straighten_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jarak: ${_formatDistance(_distanceFromOffice)} dari kantor',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Radius kantor: ${LocationService.radiusKm} km',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Apakah Anda yakin ingin memilih lokasi ini?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Pengajuan lembur dengan lokasi di luar radius akan ditandai khusus dan memerlukan persetujuan tambahan.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('YA, PILIH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  // ==================== MAP TYPE ====================
  String _getTileUrl() {
    switch (_currentMapType) {
      case 'hybrid':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'; // Satellite + labels
      case 'satellite':
        return 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'; // Satellite only
      case 'map':
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'; // Map/roads
      default:
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
    }
  }

  void _cycleMapType() {
    setState(() {
      switch (_currentMapType) {
        case 'hybrid':
          _currentMapType = 'satellite';
          break;
        case 'satellite':
          _currentMapType = 'map';
          break;
        case 'map':
          _currentMapType = 'hybrid';
          break;
      }
    });
  }

  IconData _getMapTypeIcon() {
    switch (_currentMapType) {
      case 'hybrid':
        return Icons.satellite_alt_rounded;
      case 'satellite':
        return Icons.satellite_rounded;
      case 'map':
        return Icons.map_rounded;
      default:
        return Icons.satellite_alt_rounded;
    }
  }

  String _getMapTypeLabel() {
    switch (_currentMapType) {
      case 'hybrid':
        return 'Satelit + Jalan';
      case 'satellite':
        return 'Satelit';
      case 'map':
        return 'Peta';
      default:
        return 'Satelit';
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isSearching) const LinearProgressIndicator(minHeight: 3, color: Color(0xFF1976D2)),
          if (_showLocationWarning) _buildRadiusWarning(),
          Expanded(child: _isMapReady ? _buildMap() : _buildMapLoading()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.isProjectLocation ? "Pilih Lokasi Proyek" : "Pilih Lokasi",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0D47A1),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Map type switcher
        IconButton(
          icon: Icon(_getMapTypeIcon(), color: Colors.white, size: 20),
          tooltip: _getMapTypeLabel(),
          onPressed: _cycleMapType,
        ),
        // Confirm button
        TextButton.icon(
          onPressed: _confirmLocation,
          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          label: const Text("PILIH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMapLoading() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1976D2), strokeWidth: 3),
            SizedBox(height: 16),
            Text('Memuat peta...', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lokasi ${_formatDistance(_distanceFromOffice)} dari kantor (radius ${LocationService.radiusKm} km)',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showLocationWarning = false),
            child: Icon(Icons.close_rounded, size: 16, color: Colors.orange.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari lokasi...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF718096)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _searchAndGo,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _isSearching ? null : () => _searchAndGo(_searchController.text),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: _isSearching
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        // ========== PETA UTAMA ==========
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _pickedLocation!,
            initialZoom: 18.0,
            minZoom: 5,
            maxZoom: 21,
            onTap: (_, latLng) {
              setState(() {
                _pickedLocation = latLng;
                _showLocationWarning = false;
              });
              _updateAddress();
              _checkRadius();
            },
          ),
          children: [
            // 🔥🔥🔥 GOOGLE SATELLITE HYBRID (UTAMA)
            TileLayer(
              urlTemplate: _getTileUrl(),
              userAgentPackageName: 'com.pge.overtimeapp',
              maxZoom: 21,
              maxNativeZoom: 20,
              fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            
            // 🔥 RADIUS KANTOR
            if (widget.isProjectLocation)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: const LatLng(LocationService.kantorLat, LocationService.kantorLng),
                    radius: LocationService.radiusKantor.toDouble(),
                    color: Colors.blue.withAlpha(20),
                    borderColor: Colors.blue.withAlpha(80),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            
            // 🔥 MARKERS
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        
        // 🔥 CROSSHAIR CENTER
        const IgnorePointer(child: Center(child: _CrosshairWidget())),
        
        // 🔥 ZOOM BUTTONS
        _buildZoomControls(),
        
        // 🔥 ADDRESS OVERLAY
        _buildAddressOverlay(),
        
        // 🔥 MAP TYPE INDICATOR
        _buildMapTypeIndicator(),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    return [
      // Marker Kantor
      Marker(
        point: const LatLng(LocationService.kantorLat, LocationService.kantorLng),
        width: 80,
        height: 50,
        child: GestureDetector(
          onTap: () {
            _mapController.move(
              const LatLng(LocationService.kantorLat, LocationService.kantorLng),
              17.0,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('KANTOR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Icon(Icons.arrow_drop_down_rounded, color: Colors.blue.shade700, size: 16),
            ],
          ),
        ),
      ),
      
      // Marker Lokasi Dipilih
      Marker(
        point: _pickedLocation!,
        width: 50,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: _isOutsideRadius ? Colors.orange : Colors.red.shade600,
              size: 40,
              shadows: [Shadow(color: Colors.black.withAlpha(80), blurRadius: 6)],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 12,
      bottom: 150,
      child: Column(
        children: [
          _ZoomButton(
            icon: Icons.add_rounded,
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              if (zoom < 21) _mapController.move(_mapController.camera.center, zoom + 1);
            },
          ),
          const SizedBox(height: 4),
          _ZoomButton(
            icon: Icons.remove_rounded,
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              if (zoom > 3) _mapController.move(_mapController.camera.center, zoom - 1);
            },
          ),
          const SizedBox(height: 4),
          _ZoomButton(
            icon: Icons.my_location_rounded,
            color: const Color(0xFF1976D2),
            onPressed: () {
              _mapController.move(LatLng(widget.initialLat, widget.initialLng), 18.0);
              setState(() => _pickedLocation = LatLng(widget.initialLat, widget.initialLng));
              _updateAddress();
              _checkRadius();
            },
          ),
          const SizedBox(height: 4),
          _ZoomButton(
            icon: Icons.gps_fixed_rounded,
            color: Colors.green.shade600,
            onPressed: () async {
              try {
                final position = await LocationService.getCurrentPosition();
                final newPos = LatLng(position.latitude, position.longitude);
                _mapController.move(newPos, 18.0);
                setState(() => _pickedLocation = newPos);
                _updateAddress();
                _checkRadius();
                _showSnackBar('Lokasi GPS saat ini', isSuccess: true);
              } catch (e) {
                _showSnackBar('Gagal mendapatkan lokasi GPS', isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(160)],
          ),
        ),
        child: _isLoadingAddress
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Mencari alamat...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Petunjuk
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text("Tap peta untuk memilih lokasi", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
                  const SizedBox(height: 6),
                  
                  // Address Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Alamat
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded, color: _isOutsideRadius ? Colors.orange : const Color(0xFF1976D2), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentAddress.isNotEmpty ? _currentAddress : _formatCoordinate(_pickedLocation!),
                                style: const TextStyle(fontSize: 12, height: 1.3),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        // Info Jarak & Radius
                        if (_distanceFromOffice > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Jarak
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isOutsideRadius ? Colors.orange.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.straighten_rounded, size: 12, color: _isOutsideRadius ? Colors.orange : Colors.grey.shade600),
                                    const SizedBox(width: 3),
                                    Text(_formatDistance(_distanceFromOffice), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isOutsideRadius ? Colors.orange.shade800 : Colors.grey.shade700)),
                                    const Text(' dari kantor', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Badge luar radius
                              if (_isOutsideRadius)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('LUAR RADIUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                ),
                              if (!_isOutsideRadius)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('DALAM RADIUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                ),
                            ],
                          ),
                        ],
                        
                        // Koordinat
                        const SizedBox(height: 6),
                        Text(
                          _formatCoordinate(_pickedLocation!),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMapTypeIndicator() {
    return Positioned(
      left: 12,
      top: 8,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 3,
        child: InkWell(
          onTap: _cycleMapType,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getMapTypeIcon(), size: 14, color: const Color(0xFF1976D2)),
                const SizedBox(width: 4),
                Text(_getMapTypeLabel(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
                const SizedBox(width: 2),
                const Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== CUSTOM WIDGETS ====================

/// Crosshair widget untuk center indicator
class _CrosshairWidget extends StatelessWidget {
  const _CrosshairWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: Colors.red.withAlpha(60),
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Zoom button widget
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color ?? Colors.black87),
        ),
      ),
    );
  }
}