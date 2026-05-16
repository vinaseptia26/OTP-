// lib/features/pengawas/lembur/widgets/location_picker.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';

class LocationPicker extends StatefulWidget {
  final Function(LatLng, String) onLocationSelected;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedLocation;
  String? _selectedAddress;

  bool _isSearching = false;
  bool _isLoadingRecommendations = false;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recommendedLocations = [];

  String _locationChoice = 'kantor';

  static const double _kantorLat = -7.134711;
  static const double _kantorLng = 107.799540;
  static const double _radiusKantor = 300;

  @override
  void initState() {
    super.initState();
    _setDefaultLocation();
    _loadRecommendedLocations();
  }

  void _setDefaultLocation() {
    _selectedLocation = LatLng(_kantorLat, _kantorLng);
    _selectedAddress = LocationService.alamatKantor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveMapToLocation();
    });
  }

  Future<void> _loadRecommendedLocations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final recommendations = await LocationService.getRecommendedLocations();
      
      if (mounted) {
        setState(() {
          _recommendedLocations = recommendations;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  void _moveMapToLocation() {
    if (_selectedLocation != null && mounted) {
      _mapController.move(_selectedLocation!, 16);
    }
  }

  void _selectKantor() {
    setState(() {
      _locationChoice = 'kantor';
      _selectedLocation = LatLng(_kantorLat, _kantorLng);
      _selectedAddress = LocationService.alamatKantor;
    });

    _moveMapToLocation();

    widget.onLocationSelected(
      _selectedLocation!,
      _selectedAddress!,
    );
  }

  Future<void> _selectRecommendedLocation(Map<String, dynamic> location) async {
    setState(() {
      _locationChoice = 'recommended';
      _selectedLocation = LatLng(
        location['lat'],
        location['lng'],
      );
      _selectedAddress = location['address'];
    });

    _moveMapToLocation();

    widget.onLocationSelected(
      _selectedLocation!,
      _selectedAddress!,
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final isFake = await LocationService.detectFakeGPS();

      if (isFake) {
        final confirm = await _showFakeGpsDialog();

        if (!confirm) {
          setState(() {
            _isSearching = false;
          });
          return;
        }
      }

      final position = await LocationService.getCurrentPosition();

      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (address != null && mounted) {
        setState(() {
          _selectedLocation = LatLng(
            position.latitude,
            position.longitude,
          );

          _selectedAddress = address['address'];
          _locationChoice = 'custom';
          _isSearching = false;
        });

        _moveMapToLocation();

        widget.onLocationSelected(
          _selectedLocation!,
          _selectedAddress!,
        );
      } else {
        setState(() {
          _isSearching = false;
        });

        _showErrorDialog();
      }
    } catch (e) {
      debugPrint("Error GPS: $e");

      setState(() {
        _isSearching = false;
      });

      _showErrorDialog();
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });

      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await LocationService.searchLocation(query);

      if (results != null && mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    setState(() {
      _selectedLocation = LatLng(
        result['lat'],
        result['lng'],
      );

      _selectedAddress = result['address'];
      _locationChoice = 'custom';

      _searchResults = [];

      _searchController.clear();
    });

    _moveMapToLocation();

    widget.onLocationSelected(
      _selectedLocation!,
      _selectedAddress!,
    );
  }

  bool get _isOutsideRadius {
    if (_selectedLocation == null) return false;

    return LocationService.isOutsideRadius(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  double get _distanceFromKantor {
    if (_selectedLocation == null) return 0;

    return LocationService.calculateDistance(
      _kantorLat,
      _kantorLng,
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildLocationOptions(),
          const SizedBox(height: 14),
          _buildRecommendedSection(),
          const SizedBox(height: 14),
          _buildSearchBar(),
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          const SizedBox(height: 14),
          _buildGpsButton(),
          const SizedBox(height: 14),
          _buildMap(),
          if (_selectedLocation != null) ...[
            const SizedBox(height: 10),
            _buildLocationInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_on,
            color: Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "Lokasi Lembur",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationOptions() {
    return Row(
      children: [
        Expanded(
          child: _buildOptionButton(
            icon: Icons.business,
            label: "Kantor",
            isSelected: _locationChoice == 'kantor',
            onTap: _selectKantor,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1976D2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF1976D2),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection() {
    if (_isLoadingRecommendations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recommendedLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history,
              size: 16,
              color: Color(0xFF1976D2),
            ),
            const SizedBox(width: 6),
            Text(
              "Lokasi yang sering dipakai",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendedLocations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final location = _recommendedLocations[index];
              final isSelected = _locationChoice == 'recommended' &&
                  _selectedLocation?.latitude == location['lat'] &&
                  _selectedLocation?.longitude == location['lng'];
              
              return GestureDetector(
                onTap: () => _selectRecommendedLocation(location),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1976D2).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location['name'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF1976D2)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: _searchLocation,
      decoration: InputDecoration(
        hintText: "Cari lokasi...",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _isSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF1976D2),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final result = _searchResults[index];

          return ListTile(
            leading: const Icon(
              Icons.place,
              color: Color(0xFF1976D2),
            ),
            title: Text(
              result['name'],
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              result['address'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11),
            ),
            onTap: () {
              _selectSearchResult(result);
            },
          );
        },
      ),
    );
  }

  Widget _buildGpsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            _isSearching ? null : _getCurrentLocation,
        icon: _isSearching
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.gps_fixed),
        label: Text(
          _isSearching
              ? "Mengambil lokasi..."
              : "Gunakan GPS Saat Ini",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(
            color: Color(0xFF1976D2),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedLocation ??
                LatLng(_kantorLat, _kantorLng),
            initialZoom: 16,
            onTap: (_, point) {
              setState(() {
                _selectedLocation = point;
                _locationChoice = 'custom';
              });

              _getAddressFromLocation();
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName:
                  'com.example.project_otp_kmj',
            ),

            CircleLayer(
              circles: [
                CircleMarker(
                  point: LatLng(
                    _kantorLat,
                    _kantorLng,
                  ),
                  radius: _radiusKantor,
                  useRadiusInMeter: true,
                  color: const Color(0xFF1976D2)
                      .withOpacity(0.15),
                  borderStrokeWidth: 2,
                  borderColor:
                      const Color(0xFF1976D2),
                ),
              ],
            ),

            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation!,
                    width: 90,
                    height: 75,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOutsideRadius
                              ? Icons.warning
                              : Icons.location_pin,
                          color: _isOutsideRadius
                              ? Colors.orange
                              : Colors.red,
                          size: 34,
                        ),

                        const SizedBox(height: 2),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            _isOutsideRadius
                                ? "Luar Radius"
                                : "Lokasi",
                            textAlign: TextAlign.center,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isOutsideRadius
            ? Colors.orange.withOpacity(0.1)
            : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOutsideRadius
              ? Colors.orange
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isOutsideRadius
                    ? Icons.warning_amber
                    : Icons.location_on,
                color: _isOutsideRadius
                    ? Colors.orange
                    : const Color(0xFF1976D2),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _selectedAddress ??
                      "Memuat alamat...",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (_isOutsideRadius) ...[
            const SizedBox(height: 6),
            Text(
              "⚠️ Lokasi berada di luar radius kantor "
              "(${(_distanceFromKantor / 1000).toStringAsFixed(1)} km)",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _getAddressFromLocation() async {
    if (_selectedLocation == null) return;

    final address =
        await LocationService.reverseGeocode(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );

    if (address != null && mounted) {
      setState(() {
        _selectedAddress = address['address'];
      });

      widget.onLocationSelected(
        _selectedLocation!,
        _selectedAddress!,
      );
    }
  }

  Future<bool> _showFakeGpsDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                "⚠️ Fake GPS Terdeteksi",
              ),
              content: const Text(
                "Sistem mendeteksi penggunaan Fake GPS.\n\n"
                "Apakah Anda ingin melanjutkan?",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text("BATAL"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text("LANJUTKAN"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("❌ Gagal"),
          content: const Text(
            "Tidak dapat mendapatkan lokasi GPS.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("TUTUP"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}