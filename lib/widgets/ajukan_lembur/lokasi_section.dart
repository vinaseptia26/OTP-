// lib/widgets/ajukan_lembur/lokasi_section.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '/core/services/location_service.dart';
import 'section_card.dart';

class LokasiSection extends StatelessWidget {
  final String locationType;
  final LatLng? selectedLocation;
  final String? selectedAddress;
  final bool isOutsideRadius;
  final TextEditingController rtController;
  final TextEditingController rwController;
  final Function(String) onLocationTypeChanged;
  final VoidCallback onPickMap;

  const LokasiSection({
    super.key,
    required this.locationType,
    this.selectedLocation,
    this.selectedAddress,
    required this.isOutsideRadius,
    required this.rtController,
    required this.rwController,
    required this.onLocationTypeChanged,
    required this.onPickMap,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Lokasi Lembur',
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFF0D47A1),
      children: [
        // Location type selection cards
        Row(
          children: [
            Expanded(
              child: _buildLocationTypeCard(
                icon: Icons.business_rounded,
                title: 'Kantor',
                subtitle: 'PGE Area Kamojang',
                isSelected: locationType == 'kantor',
                onTap: () => onLocationTypeChanged('kantor'),
                color: const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLocationTypeCard(
                icon: Icons.construction_rounded,
                title: 'Proyek',
                subtitle: 'Luar Kantor',
                isSelected: locationType == 'proyek',
                onTap: () => onLocationTypeChanged('proyek'),
                color: const Color(0xFFE65100),
              ),
            ),
          ],
        ),
        
        // Proyek location picker
        if (locationType == 'proyek') ...[
          const SizedBox(height: 16),
          _buildPickMapButton(),
          if (selectedLocation != null) ...[
            const SizedBox(height: 14),
            _buildAddressInfo(),
            const SizedBox(height: 12),
            _buildRtRwFields(),
          ],
        ],
        
        // Radius info
        if (selectedLocation != null) ...[
          const SizedBox(height: 14),
          _buildRadiusInfo(),
        ],
        
        // Location info summary
        if (selectedLocation == null && locationType == 'proyek') ...[
          const SizedBox(height: 12),
          _buildLocationHint(),
        ],
      ],
    );
  }

  Widget _buildLocationTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE0E0E0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Dipilih',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickMapButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.map_rounded, size: 20),
        label: const Text(
          'Pilih Lokasi dari Peta Satelit',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPickMap,
      ),
    );
  }

  Widget _buildAddressInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF1976D2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alamat Lokasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedAddress ?? 'Alamat belum didapat',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRtRwFields() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: rtController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'RT',
              hintText: '001',
              prefixIcon: const Icon(Icons.home_rounded, size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: rwController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'RW',
              hintText: '001',
              prefixIcon: const Icon(Icons.home_rounded, size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusInfo() {
    double distance = 0;
    if (selectedLocation != null) {
      distance = LocationService.calculateDistance(
        LocationService.kantorLat,
        LocationService.kantorLng,
        selectedLocation!.latitude,
        selectedLocation!.longitude,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOutsideRadius
              ? [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)]
              : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutsideRadius
              ? Colors.orange.shade300
              : Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOutsideRadius
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOutsideRadius
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (isOutsideRadius ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isOutsideRadius
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: isOutsideRadius ? Colors.orange : Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutsideRadius
                      ? 'Di Luar Radius Kantor'
                      : 'Dalam Radius Kantor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isOutsideRadius
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jarak: ${(distance / 1000).toStringAsFixed(2)} km dari kantor',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOutsideRadius
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isOutsideRadius) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Memerlukan persetujuan khusus',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Silakan pilih lokasi proyek dari peta untuk melanjutkan',
              style: TextStyle(
                fontSize: 13,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}