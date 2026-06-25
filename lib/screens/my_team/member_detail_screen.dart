import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/my_team_service.dart';
import '../../widgets/my_team/team_helpers.dart';
import '../../widgets/bottom_nav/app_bottom_nav.dart';

class MemberDetailScreen extends StatelessWidget {
  final TeamMember member;
  final String userRole;

  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ========== HEADER ==========
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0D47A1),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Avatar Besar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: member.isActive
                              ? [const Color(0xFF1976D2), const Color(0xFF42A5F5)]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: member.isActive
                                ? const Color(0xFF1976D2).withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          member.inisial,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Nama
                    Text(
                      member.namaLengkap,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        TeamHelpers.getRoleLabel(member.role),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Tombol Back
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            
            // Tombol Aksi (More/Restore)
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    member.isActive ? Icons.more_vert : Icons.restore_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  _showMemberOptions(context);
                },
              ),
            ],
          ),

          // ========== CONTENT ==========
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  
                  // Informasi Kontak
                  _buildSectionTitle('Informasi Kontak'),
                  const SizedBox(height: 12),
                  _buildContactCard(),
                  const SizedBox(height: 20),
                  
                  // Informasi Akun
                  _buildSectionTitle('Informasi Akun'),
                  const SizedBox(height: 12),
                  _buildAccountCard(),
                  const SizedBox(height: 20),
                  
                  // Aktivitas
                  _buildSectionTitle('Aktivitas'),
                  const SizedBox(height: 12),
                  _buildActivityCard(),
                  const SizedBox(height: 30),
                  
                  // Action Buttons
                  _buildActionButtons(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ========== BOTTOM NAVBAR DINAMIS ==========
      bottomNavigationBar: AppBottomNav(
        userRole: userRole,
        currentIndex: 0,
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A2B4C),
      ),
    );
  }

  // =========================================================
  // STATUS CARD
  // =========================================================
  
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: member.isActive
                  ? const Color(0xFF00C853).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              member.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: member.isActive ? const Color(0xFF00C853) : Colors.grey,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Akun',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.isActive ? 'Aktif' : 'Nonaktif',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: member.isActive ? const Color(0xFF00C853) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.isActive
                      ? 'Dapat mengakses semua fitur'
                      : 'Tidak dapat mengakses aplikasi',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Online/Offline Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: member.isActive
                  ? const Color(0xFF00C853).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: member.isActive ? const Color(0xFF00C853) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  member.isActive ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: member.isActive ? const Color(0xFF00C853) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CONTACT CARD
  // =========================================================
  
  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF1976D2),
            label: 'Email',
            value: member.email,
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF059669),
            label: 'Telepon',
            value: member.phone.isNotEmpty ? member.phone : '-',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACCOUNT CARD
  // =========================================================
  
  Widget _buildAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF7C3AED),
            label: 'Role',
            value: TeamHelpers.getRoleLabel(member.role),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.work_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Fungsi',
            value: TeamHelpers.getFungsiLabel(
              member.fungsi.isNotEmpty ? member.fungsi : 'operation',
            ),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF6366F1),
            label: 'Bergabung Sejak',
            value: DateFormat('dd MMMM yyyy', 'id_ID').format(member.createdAt),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INFO TILE (Reusable)
  // =========================================================
  
  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A2B4C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTIVITY CARD
  // =========================================================
  
  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActivityItem(
            icon: Icons.login_rounded,
            label: 'Login Terakhir',
            value: member.lastLoginFormatted,
            color: const Color(0xFF1976D2),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.access_time_rounded,
            label: 'Total Jam Kerja Bulan Ini',
            value: '- jam',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.assignment_turned_in_rounded,
            label: 'Pengajuan Bulan Ini',
            value: '- pengajuan',
            color: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2B4C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ACTION BUTTONS
  // =========================================================
  
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.message_rounded,
            label: 'Kirim Pesan',
            color: const Color(0xFF1976D2),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat dengan ${member.namaLengkap}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.call_rounded,
            label: 'Telepon',
            color: const Color(0xFF059669),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Menelpon ${member.phone.isNotEmpty ? member.phone : member.namaLengkap}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MEMBER OPTIONS (More/Restore menu)
  // =========================================================
  
  void _showMemberOptions(BuildContext context) {
    if (member.isActive) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Opsi Anggota',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildOptionItem(
                icon: Icons.edit_rounded,
                title: 'Edit Profil',
                color: const Color(0xFF1976D2),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              _buildOptionItem(
                icon: Icons.block_rounded,
                title: 'Nonaktifkan Akun',
                color: const Color(0xFFDC2626),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeactivateConfirmation(context);
                },
              ),
              _buildOptionItem(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Reset Password',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _showReactivateConfirmation(context);
    }
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeactivateConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Nonaktifkan Akun',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menonaktifkan akun ${member.namaLengkap}?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.namaLengkap} telah dinonaktifkan'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Nonaktifkan',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactivateConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Aktifkan Kembali',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin mengaktifkan kembali akun ${member.namaLengkap}?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.namaLengkap} telah diaktifkan kembali'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Aktifkan',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}