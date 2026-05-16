// lib/dashboard/manager/member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  int totalHariKerja = 0;
  bool isLoadingHariKerja = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchTotalHariKerja();
  }

  Future<void> _fetchTotalHariKerja() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final member = args?['member'] as Map<String, dynamic>? ?? {};
    final userId = member['id'] ?? member['userId'] ?? '';

    try {
      // Ambil semua dokumen lembur dengan jenis hari_kerja untuk user ini
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('lembur')
          .where('jenis_lembur', isEqualTo: 'hari_kerja')
          .where('pengawas_id', isEqualTo: userId)
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
            .where('mitra_id', isEqualTo: userId)
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
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final member = args?['member'] as Map<String, dynamic>? ?? {};
    final memberId = args?['memberId'] as String? ?? '';

    final bool isOnline = member['isOnline'] == true;
    final String initial = (member['nama'] ?? member['nama_lengkap'] ?? '?')[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Detail Member'),
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
                    color: Colors.blue.withOpacity(0.08),
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
                              color: const Color(0xFF1565C0).withOpacity(0.3),
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
                                color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.3),
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
                    member['nama'] ?? member['nama_lengkap'] ?? 'Nama Member',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      member['role'] ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1565C0),
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
                        style: TextStyle(
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
                    color: Colors.blue.withOpacity(0.08),
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
                  _buildInfoRow(Icons.email_outlined, 'Email', member['email'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.work_outline, 'Fungsi', member['fungsi'] ?? member['fungsi_label'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.phone_outlined, 'Phone', member['phone'] ?? member['no_hp'] ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.badge_outlined, 'Member ID', memberId.isEmpty ? (member['id'] ?? '-') : memberId),
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
                    color: Colors.blue.withOpacity(0.08),
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
                          value: '${member['totalLembur'] ?? 0}',
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}