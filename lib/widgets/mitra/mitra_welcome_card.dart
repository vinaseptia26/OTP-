// lib/widgets/mitra/mitra_welcome_card.dart
import 'package:flutter/material.dart';

class MitraWelcomeCard extends StatelessWidget {
  final String greeting;
  final String motivation;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final String formattedDate;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  const MitraWelcomeCard({
    super.key,
    required this.greeting,
    required this.motivation,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
    required this.formattedDate,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withAlpha(70),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Profile Photo + Greeting + Action Buttons
          Row(
            children: [
              // Enhanced Profile Photo
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFAB40), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFAB40).withAlpha(80),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                        ? NetworkImage(userPhotoUrl!)
                        : null,
                    child: userPhotoUrl == null || userPhotoUrl!.isEmpty
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              
              // Greeting & Motivation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '⚡ ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Expanded(
                          child: Text(
                            greeting,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivation,
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFFFFAB40).withAlpha(230),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action Buttons Column
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reload Button
                  isRefreshing                                    // ✅ FIX: _isRefreshing -> isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(4),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFFFAB40),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: onRefresh,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withAlpha(50),
                              ),
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  // Notification Button
                  GestureDetector(
                    onTap: onNotificationsTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAB40).withAlpha(180),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFAB40).withAlpha(100),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                // Role Chip
                _buildStatusChip(
                  Icons.shield_rounded,
                  userRole.isNotEmpty ? userRole.toUpperCase() : 'MITRA',
                  const Color(0xFFFFAB40),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.white30),
                const SizedBox(width: 12),
                // Date Chip
                _buildStatusChip(
                  Icons.calendar_today_rounded,
                  formattedDate,
                  Colors.white70,
                ),
                const Spacer(),
                // Online Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withAlpha(180),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Status Chip
  Widget _buildStatusChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}