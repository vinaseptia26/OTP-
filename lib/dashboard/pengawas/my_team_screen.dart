// lib/features/pengawas/my_team_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/my_team_service.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final MyTeamService _teamService = MyTeamService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String? _userFungsi;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserFungsi();
  }

  Future<void> _loadUserFungsi() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userFungsi = userDoc.data()?['fungsi']?.toString().toLowerCase();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user fungsi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          'Tim Saya',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userFungsi == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat data fungsi',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildTeamHeader(),
                    _buildSearchBar(),
                    Expanded(child: _buildTeamList()),
                  ],
                ),
    );
  }

  Widget _buildTeamHeader() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _teamService.getTeamStats(fungsi: _userFungsi!),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final fungsiLabel = _getFungsiLabel(_userFungsi!);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tim $fungsiLabel',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${stats?['total'] ?? 0} anggota tim',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Aktif', stats?['active'] ?? 0, Colors.green),
                  _buildStatItem('Nonaktif', stats?['inactive'] ?? 0, Colors.orange),
                  _buildStatItem('Login 7H', stats?['recentlyActive'] ?? 0, Colors.lightBlue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari anggota tim...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E3C72)),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamList() {
    return StreamBuilder<List<TeamMember>>(
      stream: _teamService.getTeamMembersStream(fungsi: _userFungsi!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('Gagal memuat data tim', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        var members = snapshot.data ?? [];

        // Filter search
        if (_searchQuery.isNotEmpty) {
          members = members.where((m) {
            return m.namaLengkap.toLowerCase().contains(_searchQuery) ||
                m.email.toLowerCase().contains(_searchQuery) ||
                m.phone.contains(_searchQuery);
          }).toList();
        }

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty ? 'Tidak ditemukan' : 'Belum ada anggota tim',
                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildMemberCard(member);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(TeamMember member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: member.isActive
                      ? [const Color(0xFF1E3C72), const Color(0xFF2A4F8C)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  member.inisial,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                        child: Text(
                          member.namaLengkap,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: member.isActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          member.isActive ? 'Aktif' : 'Nonaktif',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: member.isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          member.email,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        member.phone.isNotEmpty ? member.phone : '-',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text(
                        member.lastLoginFormatted,
                        style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi.toUpperCase();
    }
  }
}