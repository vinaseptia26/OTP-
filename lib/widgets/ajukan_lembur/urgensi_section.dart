// lib/widgets/ajukan_lembur/urgensi_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class UrgensiSection extends StatelessWidget {
  final String urgensi;
  final Function(String) onUrgensiChanged;

  const UrgensiSection({
    super.key,
    required this.urgensi,
    required this.onUrgensiChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SectionCard(
      title: 'Tingkat Urgensi',
      icon: Icons.priority_high_rounded,
      iconColor: const Color(0xFFE65100),
      children: [
        // Header Info - Compact & Clean
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.shade200.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pilih tingkat urgensi sesuai lokasi dan kebutuhan lembur Anda',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Urgensi Cards - Vertical on very small screens
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 280) {
              return Column(
                children: [
                  _buildUrgensiCard(
                    icon: Icons.business_rounded,
                    title: 'Normal',
                    subtitle: 'Lembur di Kantor',
                    description: 'Pekerjaan rutin di dalam kantor',
                    value: 'normal',
                    color: Colors.blue,
                    isSelected: urgensi == 'normal',
                    onTap: () => onUrgensiChanged('normal'),
                  ),
                  const SizedBox(height: 10),
                  _buildUrgensiCard(
                    icon: Icons.warning_rounded,
                    title: 'Tinggi',
                    subtitle: 'Lembur di Proyek',
                    description: 'Pekerjaan mendesak/berisiko di lapangan',
                    value: 'tinggi',
                    color: Colors.red,
                    isSelected: urgensi == 'tinggi',
                    onTap: () => onUrgensiChanged('tinggi'),
                  ),
                ],
              );
            }
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildUrgensiCard(
                    icon: Icons.business_rounded,
                    title: 'Normal',
                    subtitle: 'Lembur di Kantor',
                    description: 'Pekerjaan rutin\ndi dalam kantor',
                    value: 'normal',
                    color: Colors.blue,
                    isSelected: urgensi == 'normal',
                    onTap: () => onUrgensiChanged('normal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildUrgensiCard(
                    icon: Icons.warning_rounded,
                    title: 'Tinggi',
                    subtitle: 'Lembur di Proyek',
                    description: 'Pekerjaan mendesak\n/berisiko di lapangan',
                    value: 'tinggi',
                    color: Colors.red,
                    isSelected: urgensi == 'tinggi',
                    onTap: () => onUrgensiChanged('tinggi'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        
        // Info Detail - Adaptive
        _buildInfoDetail(),
      ],
    );
  }

  Widget _buildUrgensiCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required String value,
    required MaterialColor color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.shade50
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color.shade400 : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with check indicator
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? color.shade100
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? color.shade200
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: isSelected ? color.shade700 : Colors.grey.shade400,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color.shade700 : Colors.grey.shade800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              
              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? color.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected 
                        ? color.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected 
                      ? color.shade600
                      : Colors.grey.shade500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoDetail() {
    final isNormal = urgensi == 'normal';
    final color = isNormal ? Colors.blue : Colors.red;
    final icon = isNormal
        ? Icons.check_circle_outline_rounded
        : Icons.warning_amber_rounded;
    final title = isNormal ? 'Pengajuan Reguler' : 'Pengajuan Prioritas';
    final description = isNormal
        ? 'Diproses sesuai antrian normal. Verifikasi dalam 1-2 hari kerja.'
        : 'Diproses prioritas untuk persetujuan segera. Verifikasi dalam 1-4 jam.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNormal 
            ? Colors.blue.shade50
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNormal 
              ? Colors.blue.shade100
              : Colors.red.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isNormal 
                      ? Colors.blue.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color.shade800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Time badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isNormal 
                      ? Colors.blue.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNormal 
                          ? Icons.schedule_rounded
                          : Icons.speed_rounded,
                      size: 12,
                      color: color.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNormal ? '1-2 hari' : '1-4 jam',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Description text
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: color.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          
          // Progress indicator
          Row(
            children: [
              _buildProgressDot(color, true),
              _buildProgressLine(color, true),
              _buildProgressDot(color, isNormal ? false : true),
              _buildProgressLine(color, false),
              _buildProgressDot(color, false),
            ],
          ),
          const SizedBox(height: 8),
          
          // Status labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diajukan',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.shade700,
                ),
              ),
              Text(
                'Verifikasi',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isNormal 
                      ? Colors.grey.shade500
                      : color.shade700,
                ),
              ),
              Text(
                'Selesai',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDot(MaterialColor color, bool isActive) {
    return Container(
      width: isActive ? 10 : 7,
      height: isActive ? 10 : 7,
      decoration: BoxDecoration(
        color: isActive ? color.shade500 : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildProgressLine(MaterialColor color, bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? color.shade300 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}