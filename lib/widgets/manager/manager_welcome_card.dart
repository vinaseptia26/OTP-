// lib/widgets/manager/manager_welcome_card.dart

import 'package:flutter/material.dart';

class ManagerWelcomeCard extends StatelessWidget {
  final String greeting;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final String formattedDate;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onNotificationsTap;

  const ManagerWelcomeCard({
    super.key,
    required this.greeting,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
    required this.formattedDate,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 8),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage: (userPhotoUrl != null && userPhotoUrl!.isNotEmpty)
                      ? NetworkImage(userPhotoUrl!)
                      : null,
                  child: (userPhotoUrl == null || userPhotoUrl!.isEmpty)
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3C72),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola tim & persetujuan lembur',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(204),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Notification & Refresh
              Column(
                children: [
                  GestureDetector(
                    onTap: onNotificationsTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : GestureDetector(
                          onTap: onRefresh,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role and Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Role: ${userRole.isNotEmpty ? userRole.toUpperCase() : 'MANAGER'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 14, color: Colors.white30),
                const SizedBox(width: 10),
                const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}