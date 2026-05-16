// lib/widgets/team_summary.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamSummary extends StatelessWidget {
  final List<Map<String, dynamic>> teamMembers;
  final int totalMembers;
  final int onlineMembers;
  final Color Function(String) getRoleColor;
  final VoidCallback? onViewAll;
  final Color? accentColor;

  const TeamSummary({
    super.key,
    required this.teamMembers,
    required this.totalMembers,
    required this.onlineMembers,
    required this.getRoleColor,
    this.onViewAll,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF4CAF50);

    // Filter tambahan untuk keamanan: pastikan tidak ada SuperAdmin di tim manager
    final filteredMembers = teamMembers.where((member) {
      final role = (member['role'] ?? '').toString().toLowerCase();
      return role != 'superadmin';
    }).toList();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(color, onlineMembers, totalMembers),

          const SizedBox(height: 12),

          // Progress bar
          if (totalMembers > 0) _buildProgressBar(onlineMembers, totalMembers),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Member list
          if (filteredMembers.isEmpty)
            _buildEmptyState()
          else
            ...filteredMembers.take(6).map(
                  (member) => _buildMemberCard(context, member),
                ),

          // View all button
          if (filteredMembers.length > 6 && onViewAll != null)
            _buildViewAllButton(filteredMembers.length),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color, int onlineMembers, int totalMembers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Tim Saya',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$onlineMembers/$totalMembers Online',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int onlineMembers, int totalMembers) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: onlineMembers / totalMembers,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(onlineMembers / totalMembers * 100).toStringAsFixed(0)}% online',
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.group_off, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'Belum ada anggota tim',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Tim akan muncul setelah ada pengawas/mitra',
              style: TextStyle(color: Colors.grey[350], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(int totalMembers) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: onViewAll,
          icon: const Icon(Icons.arrow_forward, size: 14),
          label: Text(
            'Lihat semua ($totalMembers)',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, Map<String, dynamic> member) {
    // Validasi data yang lebih aman
    final role = _getValidatedRole(member['role'] ?? 'mitra');
    final color = getRoleColor(role);
    final isOnline = member['isOnline'] == true;
    final nama = _getValidatedName(member);
    final phone = _getValidatedPhone(member);
    final totalLembur = _getValidatedTotalLembur(member);
    final lastActive = member['lastActive'] ?? member['last_login'];
    final fungsi = member['fungsi'] ?? '-';
    final email = member['email'] ?? '';
    final memberId = member['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withAlpha(13) : Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green.withAlpha(51) : Colors.grey.withAlpha(51),
        ),
      ),
      child: InkWell(
        onTap: () {
          // ✅ Navigasi ke halaman detail member
          if (memberId.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/member-detail',
              arguments: {
                'memberId': memberId,
                'member': member,
              },
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: email.isNotEmpty ? email : nama,
                          child: Text(
                            nama,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Role badge
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getRoleLabel(role),
                          style: TextStyle(
                            fontSize: 8,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Fungsi badge
                      if (fungsi != '-' && fungsi.isNotEmpty) ...[
                        Icon(Icons.business_center,
                            size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            fungsi.toUpperCase(),
                            style:
                                TextStyle(fontSize: 9, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Phone
                      if (phone != '-') ...[
                        Icon(Icons.phone, size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          phone,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Lembur
                      Icon(Icons.access_time,
                          size: 10, color: Colors.orange[300]),
                      const SizedBox(width: 2),
                      Text(
                        '${totalLembur.toStringAsFixed(1)} jam',
                        style:
                            TextStyle(fontSize: 10, color: Colors.orange[400]),
                      ),
                      const SizedBox(width: 8),
                      // Last active
                      if (lastActive != null) ...[
                        Icon(Icons.history, size: 8, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          _getLastActive(lastActive),
                          style:
                              TextStyle(fontSize: 8, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ✅ Tombol Detail (ganti dari telpon/message)
            Material(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {
                  if (memberId.isNotEmpty) {
                    Navigator.pushNamed(
                      context,
                      '/member-detail',
                      arguments: {
                        'memberId': memberId,
                        'member': member,
                      },
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER METHODS UNTUK VALIDASI ====================

  String _getValidatedRole(dynamic role) {
    final roleStr = (role ?? 'mitra').toString().toLowerCase();
    const validRoles = ['superadmin', 'manager', 'pengawas', 'mitra'];
    return validRoles.contains(roleStr) ? roleStr : 'mitra';
  }

  String _getValidatedName(Map<String, dynamic> member) {
    final nama = member['nama'] ?? member['name'] ?? member['nama_lengkap'];
    if (nama == null || nama.toString().isEmpty) return 'Unknown';
    return nama.toString();
  }

  String _getValidatedPhone(Map<String, dynamic> member) {
    final phone = member['phone'] ?? member['no_hp'];
    if (phone == null || phone.toString().isEmpty) return '-';
    return phone.toString();
  }

  double _getValidatedTotalLembur(Map<String, dynamic> member) {
    final total = member['totalLembur'];
    if (total is num) return total.toDouble();
    if (total is String) return double.tryParse(total) ?? 0.0;
    return 0.0;
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'Super Admin';
      case 'manager':
        return 'Manager';
      case 'pengawas':
        return 'Pengawas';
      case 'mitra':
        return 'Mitra';
      default:
        return role;
    }
  }

  String _getLastActive(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return '';
    }

    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} minggu lalu';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} bulan lalu';
    return '${diff.inDays ~/ 365} tahun lalu';
  }
}