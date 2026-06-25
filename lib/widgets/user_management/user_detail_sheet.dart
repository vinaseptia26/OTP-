// lib/features/superadmin/widgets/user_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool canEdit;
  final bool isCurrentUser;
  final VoidCallback onEdit;

  const UserDetailSheet({
    super.key,
    required this.user,
    required this.canEdit,
    required this.isCurrentUser,
    required this.onEdit,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> user,
    required bool canEdit,
    required bool isCurrentUser,
    required VoidCallback onEdit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => UserDetailSheet(
        user: user,
        canEdit: canEdit,
        isCurrentUser: isCurrentUser,
        onEdit: onEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? '-';
    final status = user['status_akun'] ?? 'active';
    final roleColor = UserHelpers.roleColor(role);
    final statusColor = UserHelpers.statusColor(status);
    final nama = user['nama_lengkap'] ?? '-';
    final email = user['email'] ?? '-';
    final phone = user['phone'] ?? '-';
    final fungsi = user['fungsi'] ?? '-';
    final idPekerja = user['id_pekerja']; // 🔥 ID PEKERJA
    final created = user['created_at'];
    final lastLogin = user['last_login'];
    final isVerified = user['is_verified'] ?? false;
    final initials = _getInitials(nama);

    return Stack(
      children: [
        // 🔥 DRAG HANDLE (di luar container utama)
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),

        // 🔥 MAIN CONTAINER
        Container(
          margin: const EdgeInsets.only(top: 28),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.35,
            maxChildSize: 0.88,
            expand: false,
            builder: (context, scrollController) => CustomScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 🔥 HEADER DENGAN GRADIENT
                SliverToBoxAdapter(
                  child: _buildHeader(initials, nama, email, role, roleColor, status, statusColor, isVerified, idPekerja),
                ),

                // 🔥 CONTACT & INFO CARDS
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSectionTitle('📋 Informasi Akun'),
                        const SizedBox(height: 10),
                        _buildInfoGrid(roleColor, statusColor, phone, fungsi, idPekerja, created, lastLogin),
                        const SizedBox(height: 16),

                        // 🔥 QUICK STATS
                        if (user['total_lembur'] != null || user['absensi_count'] != null) ...[
                          _buildSectionTitle('📊 Statistik Cepat'),
                          const SizedBox(height: 10),
                          _buildQuickStats(user),
                          const SizedBox(height: 16),
                        ],

                        // 🔥 ACTION BUTTONS
                        if (canEdit && !isCurrentUser) ...[
                          _buildActionButtons(context),
                          const SizedBox(height: 24),
                        ],

                        // 🔥 CLOSE BUTTON
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                            label: const Text('Tutup'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== HEADER CARD ====================
  Widget _buildHeader(
    String initials,
    String nama,
    String email,
    String role,
    Color roleColor,
    String status,
    Color statusColor,
    bool isVerified,
    String? idPekerja,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔥 AVATAR DENGAN INISIAL + BADGE STATUS
          Stack(
            children: [
              // Avatar Circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [roleColor.withOpacity(0.4), roleColor.withOpacity(0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: roleColor.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),

              // 🔥 BADGE VERIFIED
              if (isVerified)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E293B), width: 3),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔥 NAMA
          Text(
            nama,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 🔥 EMAIL
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  email,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔥 CHIPS: ROLE + STATUS + ID PEKERJA
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildChip(
                icon: UserHelpers.roleIcon(role),
                label: UserHelpers.roleLabel(role),
                backgroundColor: roleColor.withOpacity(0.2),
                textColor: Colors.white,
                borderColor: roleColor.withOpacity(0.4),
              ),
              _buildChip(
                icon: UserHelpers.statusIcon(status),
                label: UserHelpers.statusLabel(status),
                backgroundColor: statusColor.withOpacity(0.25),
                textColor: Colors.white,
                borderColor: statusColor.withOpacity(0.5),
                isAnimated: true,
              ),
              // 🔥🔥🔥 CHIP ID PEKERJA
              if (idPekerja != null && idPekerja.toString().isNotEmpty)
                _buildChip(
                  icon: Icons.badge_rounded,
                  label: 'ID: $idPekerja',
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.25),
                  textColor: Colors.white,
                  borderColor: const Color(0xFF818CF8).withOpacity(0.5),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 CHIP STYLE
  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    bool isAnimated = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SECTION TITLE ====================
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // ==================== INFO GRID ====================
  Widget _buildInfoGrid(
    Color roleColor,
    Color statusColor,
    String phone,
    String fungsi,
    String? idPekerja,
    dynamic created,
    dynamic lastLogin,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.phone_rounded,
                label: 'Telepon',
                value: phone,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.business_rounded,
                label: 'Fungsi',
                value: UserHelpers.fungsiLabel(fungsi),
                color: UserHelpers.fungsiColor(fungsi),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.badge_rounded,
                label: 'ID Pekerja', // 🔥🔥🔥 ID PEKERJA CARD
                value: idPekerja?.toString().isNotEmpty == true ? idPekerja.toString() : 'Belum diatur',
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.calendar_today_rounded,
                label: 'Terdaftar',
                value: UserHelpers.formatDate(created),
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        if (lastLogin != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.login_rounded,
                  label: 'Login Terakhir',
                  value: UserHelpers.formatDate(lastLogin),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox.shrink()), // spacer
            ],
          ),
        ],
      ],
    );
  }

  // 🔥 INFO CARD (GLASS EFFECT)
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== QUICK STATS ====================
  Widget _buildQuickStats(Map<String, dynamic> user) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_rounded,
            label: 'Total Lembur',
            value: '${user['total_lembur'] ?? 0}',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.fingerprint_rounded,
            label: 'Absensi',
            value: '${user['absensi_count'] ?? 0}',
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // 🔥 EDIT BUTTON - FULL WIDTH GRADIENT
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
            label: Text(
              '✏️  Edit User',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== HELPER ====================
  String _getInitials(String name) {
    if (name.isEmpty || name == '-') return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}