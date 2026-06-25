// lib/screens/location_menu_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '/core/services/live_location_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

class LocationMenuScreen extends StatefulWidget {
  final String userRole;

  const LocationMenuScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<LocationMenuScreen> createState() => _LocationMenuScreenState();
}

class _LocationMenuScreenState extends State<LocationMenuScreen>
    with TickerProviderStateMixin {

  final LiveLocationService _locationService = LiveLocationService();

  late TabController _tabController;
  Map<String, dynamic>? selectedLocation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'Semua';
  String _sortBy = 'recent';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Map<String, LiveLocationData> _liveLocations = {};
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;

  late VoidCallback _locationListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _locationService.listenToAllActiveLocations();

    _locationListener = () {
      if (!mounted) return;
      setState(() {
        _liveLocations = Map.from(_locationService.latestLocations);
        _isLoading = false;
      });
    };

    _locationService.addListener(_locationListener);

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _liveLocations = Map.from(_locationService.latestLocations);
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _locationService.removeListener(_locationListener);

    _locationService.stopListening();

    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    _locationService.listenToAllActiveLocations();
    if (mounted) {
      setState(() {
        _liveLocations = Map.from(_locationService.latestLocations);
        _isRefreshing = false;
      });
    }
  }

  // ==========================================================================
  // DATA PROCESSING
  // ==========================================================================

  List<Map<String, dynamic>> get _filteredLocations {
    var filtered = _liveLocations.entries.map((entry) {
      final loc = entry.value;
      final status = _determineStatus(loc);
      final distance = loc.accuracy != null ? '${loc.accuracy!.toStringAsFixed(1)}m' : '--';

      return {
        'id': entry.key,
        'name': loc.userName,
        'address': '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
        'lat': loc.latitude,
        'lng': loc.longitude,
        'status': status,
        'workers': 1,
        'cctv': 'Online',
        'battery': loc.batteryLevel?.toStringAsFixed(0) ?? '--',
        'signal': 'Kuat',
        'accuracy': distance,
        'lastUpdate': loc.timestamp,
        'warning': _getWarningMessage(loc),
        'heading': loc.heading ?? 0,
        'speed': loc.speed ?? 0,
        'altitude': loc.altitude ?? 0,
        'isActive': loc.isActive,
        'userRole': loc.userRole ?? 'mitra',
        'fungsi': loc.userFungsi ?? '',
      };
    }).toList();

    if (_statusFilter != 'Semua') {
      filtered = filtered.where((l) => l['status'] == _statusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final name = (l['name'] as String).toLowerCase();
        final address = (l['address'] as String).toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      case 'recent':
        filtered.sort((a, b) {
          final aTime = a['lastUpdate'] as DateTime;
          final bTime = b['lastUpdate'] as DateTime;
          return bTime.compareTo(aTime);
        });
        break;
      case 'status':
        final order = {'Warning': 0, 'Normal': 1};
        filtered.sort((a, b) {
          final aVal = order[a['status']] ?? 99;
          final bVal = order[b['status']] ?? 99;
          return aVal.compareTo(bVal);
        });
        break;
    }

    return filtered;
  }

  String _determineStatus(LiveLocationData loc) {
    if (!loc.isActive) return 'Warning';
    final diff = DateTime.now().difference(loc.timestamp);
    if (diff.inMinutes > 10) return 'Warning';
    final battery = loc.batteryLevel ?? 100;
    if (battery < 30) return 'Warning';
    return 'Normal';
  }

  String? _getWarningMessage(LiveLocationData loc) {
    final diff = DateTime.now().difference(loc.timestamp);
    if (diff.inMinutes > 10) return 'Update terakhir > 10 menit';
    final battery = loc.batteryLevel ?? 100;
    if (battery >= 15 && battery < 30) return 'Battery rendah (${battery.toStringAsFixed(0)}%)';
    if (battery < 15) return 'Battery sangat rendah (${battery.toStringAsFixed(0)}%)';
    if (!loc.isActive) return 'Tracking tidak aktif';
    return null;
  }

  Map<String, int> get _stats {
    final locs = _liveLocations.values.toList();
    return {
      'total': locs.length,
      'normal': locs.where((l) => _determineStatus(l) == 'Normal').length,
      'warning': locs.where((l) => _determineStatus(l) == 'Warning').length,
    };
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

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
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()} bln';
    if (difference.inDays > 0) return '${difference.inDays} hr';
    if (difference.inHours > 0) return '${difference.inHours} jam';
    if (difference.inMinutes > 0) return '${difference.inMinutes} mnt';
    return 'br saja';
  }

  Future<void> _launchMaps(double lat, double lng) async {
    try {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka maps')),
        );
      }
    }
  }

  // ==========================================================================
  // LOCATION DETAIL
  // ==========================================================================

  void _showLocationDetail(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getStatusGradient(location['status']),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(location['status']).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            location['status'] == 'Warning'
                                ? Icons.warning_rounded
                                : Icons.location_on_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                location['address'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(location['status'], large: true),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSectionTitle('Informasi Lokasi'),
                    const SizedBox(height: 8),
                    _buildDetailCard([
                      _buildDetailItem(Icons.explore_rounded, 'Koordinat',
                          '${(location['lat'] as double).toStringAsFixed(4)}, ${(location['lng'] as double).toStringAsFixed(4)}'),
                      _buildDetailItem(Icons.access_time_rounded, 'Update Terakhir',
                          _getTimeAgo(location['lastUpdate'])),
                      _buildDetailItem(Icons.precision_manufacturing_rounded, 'Akurasi',
                          location['accuracy'] ?? '--'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Status Perangkat'),
                    const SizedBox(height: 8),
                    _buildDetailCard([
                      _buildDetailItem(Icons.battery_charging_full_rounded, 'Battery',
                          '${location['battery']}%'),
                      _buildDetailItem(Icons.signal_cellular_alt_rounded, 'Sinyal',
                          location['signal']),
                      _buildDetailItem(Icons.speed_rounded, 'Kecepatan',
                          '${(location['speed'] as double).toStringAsFixed(1)} m/s'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Info Tracking'),
                    const SizedBox(height: 8),
                    _buildDetailCard([
                      _buildDetailItem(Icons.navigation_rounded, 'Heading',
                          '${(location['heading'] as double).toStringAsFixed(0)}°'),
                      _buildDetailItem(Icons.height_rounded, 'Altitude',
                          '${(location['altitude'] as double).toStringAsFixed(1)}m'),
                      _buildDetailItem(Icons.badge_rounded, 'Role',
                          location['userRole'] ?? 'mitra'),
                    ]),
                    if (location['warning'] != null) ...[
                      const SizedBox(height: 12),
                      _buildAlertBox(
                        icon: Icons.warning_amber_rounded,
                        message: location['warning'],
                        color: Colors.orange,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchMaps(
                              location['lat'],
                              location['lng'],
                            ),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Google Maps'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFF1976D2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Tutup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // UI COMPONENTS
  // ==========================================================================

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'Warning':
        return [const Color(0xFFF57C00), const Color(0xFFFF9800)];
      case 'Normal':
        return [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
      default:
        return [const Color(0xFF1976D2), const Color(0xFF42A5F5)];
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Warning':
        return const Color(0xFFFF9800);
      case 'Normal':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF1976D2);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1976D2), size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBox({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool large = false}) {
    final color = status == 'Normal'
        ? const Color(0xFF00C853)
        : const Color(0xFFFF9800);

    final bgColor = status == 'Normal'
        ? const Color(0xFF00C853).withValues(alpha: 0.15)
        : const Color(0xFFFF9800).withValues(alpha: 0.15);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withValues(alpha: 0.5)],
        ),
        borderRadius: BorderRadius.circular(large ? 20 : 12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 6,
            height: large ? 10 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.poppins(
              fontSize: large ? 13 : 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 8 * value,
          height: 8 * value,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676).withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPulsingDot(),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FILTER CHIPS
  // ==========================================================================

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Normal', 'Warning'];
    final colors = {
      'Semua': const Color(0xFF1976D2),
      'Normal': const Color(0xFF00C853),
      'Warning': const Color(0xFFFF9800),
    };

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _statusFilter == filter;
          final color = colors[filter]!;

          return GestureDetector(
            onTap: () => setState(() => _statusFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                      )
                    : LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(
                      filter == 'Semua'
                          ? Icons.filter_list_rounded
                          : filter == 'Normal'
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    filter == 'Semua'
                        ? 'Semua (${_stats['total']})'
                        : '$filter (${_stats[filter.toLowerCase()]})',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // SEARCH BAR
  // ==========================================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari lokasi...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : _buildSortButton(),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort_rounded, color: Colors.grey.shade600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => setState(() => _sortBy = value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'recent',
          child: Row(
            children: [
              Icon(Icons.access_time_rounded,
                  color: _sortBy == 'recent' ? const Color(0xFF1976D2) : Colors.grey),
              const SizedBox(width: 10),
              const Text('Terbaru'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(Icons.warning_rounded,
                  color: _sortBy == 'status' ? const Color(0xFF1976D2) : Colors.grey),
              const SizedBox(width: 10),
              const Text('Prioritas'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'name',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded,
                  color: _sortBy == 'name' ? const Color(0xFF1976D2) : Colors.grey),
              const SizedBox(width: 10),
              const Text('Nama (A-Z)'),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Lokasi',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                if (!_isLoading)
                  Text(
                    '${_liveLocations.length} lokasi aktif',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (!_isLoading) _buildLiveIndicator(),
          IconButton(
            icon: Icon(_isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded, size: 20, color: Colors.white),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Peta'),
                  ],
                )),
                Tab(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Daftar'),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1976D2),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildStatsOverview(),
                    _buildFilterChips(),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMapView(),
                          _buildListView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AppBottomNav(
        userRole: widget.userRole,
        currentIndex: 2,
      ),
    );
  }

  // ==========================================================================
  // STATS OVERVIEW
  // ==========================================================================

  Widget _buildStatsOverview() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.location_city_rounded,
              label: 'Total',
              value: _stats['total'].toString(),
              gradient: const [Color(0xFF1976D2), Color(0xFF1565C0)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_rounded,
              label: 'Normal',
              value: _stats['normal'].toString(),
              gradient: const [Color(0xFF00C853), Color(0xFF69F0AE)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.warning_rounded,
              label: 'Warning',
              value: _stats['warning'].toString(),
              gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Text(
                '$val',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MAP VIEW
  // ==========================================================================

  Widget _buildMapView() {
    final filtered = _filteredLocations;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada lokasi aktif',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final centerLat = filtered.map((l) => l['lat'] as double).reduce((a, b) => a + b) / filtered.length;
    final centerLng = filtered.map((l) => l['lng'] as double).reduce((a, b) => a + b) / filtered.length;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 12,
            maxZoom: 18,
            minZoom: 3,
            onTap: (_, __) => setState(() => selectedLocation = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: filtered.map((location) {
                final isSelected = selectedLocation != null &&
                    selectedLocation!['id'] == location['id'];
                return Marker(
                  point: LatLng(location['lat'], location['lng']),
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  child: GestureDetector(
                    onTap: () => setState(() => selectedLocation = location),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(isSelected ? 10 : 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getStatusGradient(location['status']),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(location['status']).withValues(alpha: 0.5),
                            blurRadius: isSelected ? 16 : 8,
                            spreadRadius: isSelected ? 3 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        location['status'] == 'Warning'
                            ? Icons.warning_rounded
                            : Icons.location_on_rounded,
                        color: Colors.white,
                        size: isSelected ? 22 : 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        if (selectedLocation != null)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: GestureDetector(
                      onTap: () => _showLocationDetail(selectedLocation!),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getStatusGradient(selectedLocation!['status']),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(selectedLocation!['status'])
                                  .withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedLocation!['name'],
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Tap untuk detail',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusChip(selectedLocation!['status']),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================================================
  // LIST VIEW
  // ==========================================================================

  Widget _buildListView() {
    final filtered = _filteredLocations;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ditemukan "$_searchQuery"'
                  : 'Tidak ada lokasi',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final location = filtered[index];
        return _buildLocationCard(location, index);
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(location['status']).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showLocationDetail(location),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: const Color(0xFF1976D2).withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getStatusGradient(location['status']),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            location['status'] == 'Warning'
                                ? Icons.warning_rounded
                                : Icons.location_on_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location['address'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildMiniInfo(Icons.access_time_rounded,
                                      _getTimeAgo(location['lastUpdate'])),
                                  const SizedBox(width: 12),
                                  _buildMiniInfo(Icons.battery_charging_full_rounded,
                                      '${location['battery']}%'),
                                  const SizedBox(width: 12),
                                  _buildMiniInfo(Icons.precision_manufacturing_rounded,
                                      location['accuracy'] ?? '--'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            _buildStatusChip(location['status']),
                            const SizedBox(height: 8),
                            Icon(Icons.chevron_right_rounded,
                                color: Colors.grey.shade400, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}