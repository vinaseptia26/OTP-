// lib/widgets/team_summary.dart

import 'package:flutter/material.dart';

class TeamSummary extends StatelessWidget {
  final List<Map<String, dynamic>> teamMembers;
  final int totalMembers;
  final int onlineMembers;
  final Color Function(String) getRoleColor;
  final Color? accentColor;
  final VoidCallback? onViewAll;

  const TeamSummary({
    super.key,
    required this.teamMembers,
    required this.totalMembers,
    required this.onlineMembers,
    required this.getRoleColor,
    this.accentColor,
    this.onViewAll,
  });

  // ==================== FIELD EXTRACTORS ====================
  
  /// Extract nama anggota dengan multiple fallback
  String _getMemberName(Map<String, dynamic> member) {
    return (member['nama_lengkap']?.toString() ?? '').isNotEmpty
        ? member['nama_lengkap']!.toString()
        : (member['nama']?.toString() ?? '').isNotEmpty
            ? member['nama']!.toString()
            : (member['name']?.toString() ?? '').isNotEmpty
                ? member['name']!.toString()
                : (member['display_name']?.toString() ?? '').isNotEmpty
                    ? member['display_name']!.toString()
                    : (member['displayName']?.toString() ?? '').isNotEmpty
                        ? member['displayName']!.toString()
                        : (member['full_name']?.toString() ?? '').isNotEmpty
                            ? member['full_name']!.toString()
                            : (member['fullName']?.toString() ?? '').isNotEmpty
                                ? member['fullName']!.toString()
                                : (member['email']?.toString() ?? '').isNotEmpty
                                    ? member['email']!.toString().split('@')[0]
                                    : 'Unknown';
  }

  /// Extract role dengan multiple fallback
  String _getMemberRole(Map<String, dynamic> member) {
    return (member['role']?.toString() ?? '').isNotEmpty
        ? member['role']!.toString()
        : (member['user_role']?.toString() ?? '').isNotEmpty
            ? member['user_role']!.toString()
            : (member['jabatan']?.toString() ?? '').isNotEmpty
                ? member['jabatan']!.toString()
                : (member['position']?.toString() ?? '').isNotEmpty
                    ? member['position']!.toString()
                    : 'mitra';
  }

  /// Extract photo URL dengan multiple fallback
  String? _getMemberPhotoUrl(Map<String, dynamic> member) {
    return (member['photo_url']?.toString() ?? '').isNotEmpty
        ? member['photo_url']!.toString()
        : (member['photoUrl']?.toString() ?? '').isNotEmpty
            ? member['photoUrl']!.toString()
            : (member['avatar']?.toString() ?? '').isNotEmpty
                ? member['avatar']!.toString()
                : (member['profile_picture']?.toString() ?? '').isNotEmpty
                    ? member['profile_picture']!.toString()
                    : (member['image_url']?.toString() ?? '').isNotEmpty
                        ? member['image_url']!.toString()
                        : null;
  }

  /// Extract isOnline dengan multiple fallback
  bool _getMemberIsOnline(Map<String, dynamic> member) {
    if (member.containsKey('isOnline')) return member['isOnline'] == true;
    if (member.containsKey('is_online')) return member['is_online'] == true;
    if (member.containsKey('online')) return member['online'] == true;
    if (member.containsKey('status_online')) return member['status_online'] == true;
    if (member.containsKey('isActive')) return member['isActive'] == true;
    return false;
  }

  /// Extract email dengan multiple fallback
  String _getMemberEmail(Map<String, dynamic> member) {
    return (member['email']?.toString() ?? '').isNotEmpty
        ? member['email']!.toString()
        : (member['email_address']?.toString() ?? '').isNotEmpty
            ? member['email_address']!.toString()
            : '-';
  }

  /// Extract phone dengan multiple fallback
  String _getMemberPhone(Map<String, dynamic> member) {
    return (member['phone']?.toString() ?? '').isNotEmpty
        ? member['phone']!.toString()
        : (member['phone_number']?.toString() ?? '').isNotEmpty
            ? member['phone_number']!.toString()
            : (member['no_hp']?.toString() ?? '').isNotEmpty
                ? member['no_hp']!.toString()
            : '-';
  }

  /// Get initial character untuk avatar fallback
  String _getInitial(String name) {
    if (name.isEmpty || name == 'Unknown') return '?';
    // Ambil karakter pertama, hapus spasi di depan
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  /// Get color for avatar background based on name (consistent color per person)
  Color _getAvatarColor(String name) {
    if (name.isEmpty || name == 'Unknown') return Colors.grey;
    final hash = name.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = accentColor ?? const Color(0xFF1E3C72);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(isDark ? 30 : 15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Total + Online + Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Total & Online
              Row(
                children: [
                  // Total Members
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalMembers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        'Anggota',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Online Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$onlineMembers Online',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Right: Lihat Semua
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Member List
          if (teamMembers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline, 
                      size: 40, 
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada anggota tim',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400], 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...teamMembers.take(5).map((member) {
              // ✅ GUNAKAN EXTRACTORS DENGAN MULTIPLE FALLBACK
              final role = _getMemberRole(member);
              final roleColor = getRoleColor(role);
              final isOnline = _getMemberIsOnline(member);
              final photoUrl = _getMemberPhotoUrl(member);
              final name = _getMemberName(member);
              final email = _getMemberEmail(member);
              final phone = _getMemberPhone(member);
              final initial = _getInitial(name);
              final avatarColor = _getAvatarColor(name);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: roleColor.withAlpha(isDark ? 50 : 30),
                            border: Border.all(
                              color: isOnline 
                                  ? Colors.green 
                                  : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => 
                                        Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(roleColor),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Name & Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A2332),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              // Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withAlpha(isDark ? 40 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role.isNotEmpty ? role.toUpperCase() : '-',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: roleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Email tooltip (optional, muncul di expanded view)
                              if (email != '-' && email.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Online Indicator
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline 
                                ? Colors.green 
                                : (isDark ? Colors.grey[600] : Colors.grey[300]),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 8,
                            color: isOnline 
                                ? Colors.green 
                                : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          // Jika lebih dari 5, tampilkan "+X lainnya"
          if (teamMembers.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(isDark ? 30 : 10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${teamMembers.length - 5} anggota lainnya',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // ✅ TAMBAHAN: Quick stats jika ada data
          if (teamMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Online percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_rounded,
                  size: 12,
                  color: Colors.green.withAlpha(180),
                ),
                const SizedBox(width: 4),
                Text(
                  '${totalMembers > 0 ? ((onlineMembers / totalMembers) * 100).toStringAsFixed(0) : 0}% online',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}