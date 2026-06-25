// lib/dashboard/manager/member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class MemberDetailScreen extends StatefulWidget {
  final String? memberId;
  final Map<String, dynamic>? memberData;

  const MemberDetailScreen({
    super.key,
    this.memberId,
    this.memberData,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  Map<String, dynamic> _member = {};
  String _memberId = '';
  bool _isLoading = true;
  int totalHariKerja = 0;
  bool isLoadingHariKerja = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Ambil data dari parameter widget (GoRouter)
    if (widget.memberData != null) {
      _member = widget.memberData!;
      _memberId = widget.memberId ?? widget.memberData!['id'] ?? widget.memberData!['userId'] ?? '';
      setState(() {
        _isLoading = false;
      });
      _fetchTotalHariKerja();
    } else if (widget.memberId != null) {
      _memberId = widget.memberId!;
      _fetchMemberData();
    } else {
      // Fallback ke ModalRoute (cara lama)
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _member = args['member'] as Map<String, dynamic>? ?? {};
        _memberId = args['memberId'] as String? ?? _member['id'] ?? _member['userId'] ?? '';
        setState(() {
          _isLoading = false;
        });
        _fetchTotalHariKerja();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMemberData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_memberId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _member = doc.data() ?? {};
          _member['id'] = doc.id;
          _isLoading = false;
        });
        _fetchTotalHariKerja();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  Future<void> _fetchTotalHariKerja() async {
    if (_memberId.isEmpty) {
      setState(() {
        isLoadingHariKerja = false;
      });
      return;
    }

    try {
      // Ambil semua dokumen lembur dengan jenis hari_kerja untuk user ini
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('lembur')
          .where('jenis_lembur', isEqualTo: 'hari_kerja')
          .where('pengawas_id', isEqualTo: _memberId)
          .get();

      if (mounted) {
        setState(() {
          totalHariKerja = snapshot.docs.length;
          isLoadingHariKerja = false;
        });
      }
    } catch (e) {
      // Jika user adalah mitra, coba cari dengan mitra_id
      try {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('lembur')
            .where('jenis_lembur', isEqualTo: 'hari_kerja')
            .where('mitra_id', isEqualTo: _memberId)
            .get();

        if (mounted) {
          setState(() {
            totalHariKerja = snapshot.docs.length;
            isLoadingHariKerja = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoadingHariKerja = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Detail Member'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isOnline = _member['isOnline'] == true || _member['is_online'] == true;
    final String namaLengkap = _member['nama'] ?? _member['nama_lengkap'] ?? 'Nama Member';
    final String initial = namaLengkap.isNotEmpty ? namaLengkap[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Detail Member',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card Utama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1565C0),
                              Color(0xFF42A5F5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Status indicator
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: (isOnline ? Colors.green : Colors.grey)
                                    .withValues(alpha: 0.3),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nama
                  Text(
                    namaLengkap,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _member['role'] ?? '-',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Informasi Personal Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline, color: Color(0xFF1565C0), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Informasi Personal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.email_outlined, 'Email', _member['email'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.work_outline, 'Fungsi', 
                      _member['fungsi'] ?? _member['fungsi_label'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.phone_outlined, 'Phone', 
                      _member['phone'] ?? _member['no_hp'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.badge_outlined, 'Member ID', 
                      _memberId.isNotEmpty ? _memberId : (_member['id'] ?? '-')),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistik Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF1565C0), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Statistik',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.timer_outlined,
                          value: '${_member['totalLembur'] ?? 0}',
                          label: 'Jam Lembur',
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.calendar_month_outlined,
                          value: isLoadingHariKerja ? '...' : '$totalHariKerja',
                          label: 'Hari Kerja',
                          color: const Color(0xFF42A5F5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}