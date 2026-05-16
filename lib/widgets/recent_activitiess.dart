// lib/widgets/recent_activities.dart
import 'package:flutter/material.dart';

class RecentActivitiesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final String Function(dynamic) getTimeAgo;
  final Color Function(String) getRoleColor;

  const RecentActivitiesWidget({
    super.key,
    required this.activities,
    required this.getTimeAgo,
    required this.getRoleColor,
  });

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN 1: Filter aktivitas untuk memastikan tidak ada data superadmin
    final filteredActivities = activities.where((activity) {
      final userRole = (activity['userRole'] ?? 'system').toString().toLowerCase();
      // Jangan tampilkan aktivitas SuperAdmin (double protection)
      return userRole != 'superadmin';
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
          // Header with better styling
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Aktivitas Terbaru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredActivities.length} aktivitas',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content with better empty state
          if (filteredActivities.isEmpty)
            _buildEmptyState()
          else
            ...filteredActivities.take(8).map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  // PERBAIKAN 2: Empty state yang lebih informatif
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Tidak ada aktivitas terbaru',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Aktivitas akan muncul di sini',
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // PERBAIKAN 3: Build activity item dengan validasi lebih baik
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    // Validasi dan default values untuk mencegah error
    final type = _getValidatedType(activity['type'] ?? 'info');
    final role = _getValidatedRole(activity['userRole'] ?? 'system');
    final description = _getValidatedDescription(activity['description']);
    final userName = _getValidatedUserName(activity['user']);
    final timestamp = activity['timestamp'];
    final color = _getActivityColor(type, role);
    final icon = _getActivityIcon(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // PERBAIKAN 4: Add tap feedback for debugging (optional)
          debugPrint('Activity tapped: $type - $description');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with better visibility
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),

              // Content with better text handling
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // User role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: getRoleColor(role).withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getRoleLabel(role),
                            style: TextStyle(
                              fontSize: 8,
                              color: getRoleColor(role),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // User name with tooltip
 Flexible(
                          child: Tooltip(
                            message: userName,
                            child: Text(
                              userName,
                              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time with better formatting
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    getTimeAgo(timestamp),
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTypeLabel(type),
                      style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PERBAIKAN 5: Validasi type activity
  String _getValidatedType(dynamic type) {
    if (type == null) return 'info';
    final typeStr = type.toString().toLowerCase();
    final validTypes = ['approve_lembur', 'approved', 'reject_lembur', 'rejected', 
                        'pending', 'login', 'logout', 'dashboard_view', 'refresh', 
                        'team_activity', 'system'];
    if (validTypes.contains(typeStr)) return typeStr;
    return 'info';
  }

  // PERBAIKAN 6: Validasi role
  String _getValidatedRole(dynamic role) {
    if (role == null) return 'system';
    final roleStr = role.toString().toLowerCase();
    final validRoles = ['superadmin', 'manager', 'pengawas', 'mitra', 'system', 'team'];
    if (validRoles.contains(roleStr)) return roleStr;
    return 'system';
  }

  // PERBAIKAN 7: Validasi description
  String _getValidatedDescription(dynamic description) {
    if (description == null) return 'Tidak ada deskripsi';
    final desc = description.toString().trim();
    if (desc.isEmpty) return 'Tidak ada deskripsi';
    return desc;
  }

  // PERBAIKAN 8: Validasi user name
  String _getValidatedUserName(dynamic user) {
    if (user == null) return 'System';
    final name = user.toString().trim();
    if (name.isEmpty) return 'System';
    return name;
  }

  // PERBAIKAN 9: Get human-readable type label
  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'approve_lembur':
      case 'approved':
        return 'Disetujui';
      case 'reject_lembur':
      case 'rejected':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'dashboard_view':
        return 'Dashboard';
      case 'refresh':
        return 'Refresh';
      case 'team_activity':
        return 'Tim';
      case 'system':
        return 'Sistem';
      default:
        return type;
    }
  }

  Color _getActivityColor(String type, String role) {
    // Prioritaskan berdasarkan type dulu
    switch (type.toLowerCase()) {
      case 'approve_lembur':
      case 'approved':
        return Colors.green;
      case 'reject_lembur':
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'login':
      case 'logout':
        return Colors.blue;
      case 'dashboard_view':
      case 'refresh':
        return const Color(0xFFFF6B35);
      case 'team_activity':
        return Colors.teal;
      case 'system':
        return Colors.grey;
      default:
        // Fallback ke role color
        return getRoleColor(role);
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'approve_lembur':
      case 'approved':
        return Icons.check_circle;
      case 'reject_lembur':
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'dashboard_view':
        return Icons.dashboard;
      case 'refresh':
        return Icons.refresh;
      case 'team_activity':
        return Icons.people;
      case 'system':
        return Icons.computer;
      default:
        return Icons.info;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return 'Super Admin';
      case 'manager': return 'Manager';
      case 'pengawas': return 'Pengawas';
      case 'mitra': return 'Mitra';
      case 'team': return 'Tim';
      case 'system': return 'System';
      default: return role;
    }
  }
}