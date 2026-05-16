// lib/widgets/key_metrics.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KeyMetrics extends StatefulWidget {
  final String title;

  const KeyMetrics({
    super.key,
    this.title = 'Ringkasan',
  });

  @override
  State<KeyMetrics> createState() => _KeyMetricsState();
}

class _KeyMetricsState extends State<KeyMetrics> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<MetricItem> _metrics = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMetricsData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMetricsData() async {
    if (!mounted) return; // ✅ Early return jika sudah dispose

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Ambil data user untuk mengetahui role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!mounted) return; // ✅ Check mounted setelah await
      
      if (!userDoc.exists) throw Exception('User data not found');

      final userData = userDoc.data()!;
      final userRole = (userData['role'] ?? 'mitra').toString().toLowerCase();

      // Load metrics berdasarkan role
      switch (userRole) {
        case 'superadmin':
          await _loadSuperAdminMetrics();
          break;
        case 'manager':
          await _loadManagerMetrics(userData);
          break;
        case 'pengawas':
          await _loadPengawasMetrics(userData);
          break;
        case 'mitra':
          await _loadMitraMetrics(userData);
          break;
        default:
          throw Exception('Unknown role: $userRole');
      }
    } catch (e) {
      if (!mounted) return; // ✅ Check mounted sebelum setState error
      
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ==================== SUPERADMIN METRICS ====================
  Future<void> _loadSuperAdminMetrics() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Ambil data users
    final usersSnapshot = await _firestore.collection('users').get();
    
    if (!mounted) return; // ✅ Check mounted
    
    // Hitung new users today
    int newUsersToday = 0;
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final createdAt = data['created_at'];
      if (createdAt is Timestamp) {
        if (createdAt.toDate().isAfter(startOfDay)) {
          newUsersToday++;
        }
      }
    }

    // Hitung locked accounts
    int lockedAccounts = usersSnapshot.docs
        .where((doc) => doc.data()['account_locked'] == true)
        .length;

    // Hitung total lembur bulan ini
    final lemburSnapshot = await _firestore
        .collection('lembur')
        .where('created_at', isGreaterThanOrEqualTo: firstDayOfMonth)
        .get();
    
    if (!mounted) return; // ✅ Check mounted
    
    final totalOvertime = lemburSnapshot.docs.length;

    setState(() {
      _metrics = [
        MetricItem(
          label: 'Pengguna Baru',
          value: '$newUsersToday',
          icon: Icons.person_add,
          color: Colors.green,
          tooltip: 'User baru yang registrasi hari ini',
        ),
        MetricItem(
          label: 'Akun Terkunci',
          value: '$lockedAccounts',
          icon: Icons.lock,
          color: Colors.red,
          tooltip: 'Akun yang sedang terkunci',
        ),
        MetricItem(
          label: 'Total Lembur',
          value: _formatNumber(totalOvertime),
          icon: Icons.work_history,
          color: Colors.blue,
          tooltip: 'Total pengajuan lembur bulan ini',
        ),
      ];
      _isLoading = false;
    });
  }

  // ==================== MANAGER METRICS ====================
  Future<void> _loadManagerMetrics(Map<String, dynamic> userData) async {
    final fungsi = userData['fungsi'] ?? 'operation';
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Ambil team members (pengawas & mitra dengan fungsi yang sama)
    final teamSnapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['pengawas', 'mitra'])
        .where('fungsi', isEqualTo: fungsi)
        .get();

    if (!mounted) return; // ✅ Check mounted

    final teamMembers = teamSnapshot.docs;
    final totalTeamMembers = teamMembers.length;
    final onlineMembers = teamMembers.where((doc) => doc.data()['isOnline'] == true).length;

    // Ambil lembur data
    final lemburSnapshot = await _firestore
        .collection('lembur')
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .get();

    if (!mounted) return; // ✅ Check mounted

    int pendingApprovals = 0;
    double totalHoursThisMonth = 0;
    int overtimeThreshold = 60;

    for (var doc in lemburSnapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      
      if (status == 'pending') {
        pendingApprovals++;
      }
      
      if (status == 'disetujui' || status == 'approved') {
        final tanggal = data['tanggal'];
        if (tanggal is Timestamp) {
          if (tanggal.toDate().isAfter(firstDayOfMonth)) {
            final jam = _toDouble(data['total_jam_desimal']);
            totalHoursThisMonth += jam;
          }
        }
      }
    }

    // Ambil overtime threshold dari settings
    try {
      final settingsDoc = await _firestore
          .collection('system_settings')
          .doc('lembur_config')
          .get();
      
      if (!mounted) return; // ✅ Check mounted
      
      if (settingsDoc.exists) {
        overtimeThreshold = settingsDoc.data()?['max_jam_per_bulan'] ?? 60;
      }
    } catch (_) {}

    if (!mounted) return; // ✅ Check mounted

    final utilization = totalHoursThisMonth / overtimeThreshold;
    final utilizationPercent = (utilization * 100).toStringAsFixed(0);
    final utilizationColor = utilization > 0.8 ? Colors.red : 
                             utilization > 0.6 ? Colors.orange : 
                             Colors.purple;

    setState(() {
      _metrics = [
        MetricItem(
          label: 'Tim',
          value: '$totalTeamMembers',
          subtitle: '$onlineMembers online',
          icon: Icons.people,
          color: Colors.blue,
          tooltip: 'Total anggota tim (pengawas & mitra)',
        ),
        MetricItem(
          label: 'Pending',
          value: '$pendingApprovals',
          icon: Icons.pending_actions,
          color: Colors.orange,
          tooltip: 'Pengajuan lembur menunggu persetujuan',
        ),
        MetricItem(
          label: 'Total Lembur',
          value: _formatHours(totalHoursThisMonth),
          icon: Icons.timer,
          color: Colors.green,
          tooltip: 'Total jam lembur bulan ini',
        ),
        MetricItem(
          label: 'Utilisasi',
          value: '$utilizationPercent%',
          icon: Icons.speed,
          color: utilizationColor,
          tooltip: 'Persentase penggunaan quota lembur ($overtimeThreshold jam)',
        ),
      ];
      _isLoading = false;
    });
  }

  // ==================== PENGAWAS METRICS ====================
  Future<void> _loadPengawasMetrics(Map<String, dynamic> userData) async {
    final pengawasId = _auth.currentUser!.uid;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Ambil lembur milik pengawas ini
    final lemburSnapshot = await _firestore
        .collection('lembur')
        .where('pengawas_id', isEqualTo: pengawasId)
        .get();

    if (!mounted) return; // ✅ Check mounted

    int totalPengajuan = lemburSnapshot.docs.length;
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;
    double totalJam = 0;

    for (var doc in lemburSnapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      
      switch (status) {
        case 'pending':
          pendingCount++;
          break;
        case 'disetujui':
        case 'approved':
          approvedCount++;
          final tanggal = data['tanggal'];
          if (tanggal is Timestamp) {
            if (tanggal.toDate().isAfter(firstDayOfMonth)) {
              totalJam += _toDouble(data['total_jam_desimal']);
            }
          }
          break;
        case 'ditolak':
        case 'rejected':
          rejectedCount++;
          break;
      }
    }

    setState(() {
      _metrics = [
        MetricItem(
          label: 'Total',
          value: '$totalPengajuan',
          icon: Icons.assignment,
          color: Colors.blue,
          tooltip: 'Total pengajuan lembur',
        ),
        MetricItem(
          label: 'Pending',
          value: '$pendingCount',
          icon: Icons.pending,
          color: Colors.orange,
          tooltip: 'Menunggu persetujuan manager',
        ),
        MetricItem(
          label: 'Disetujui',
          value: '$approvedCount',
          icon: Icons.check_circle,
          color: Colors.green,
          tooltip: 'Pengajuan yang sudah disetujui',
        ),
        MetricItem(
          label: 'Ditolak',
          value: '$rejectedCount',
          icon: Icons.cancel,
          color: Colors.red,
          tooltip: 'Pengajuan yang ditolak',
        ),
        MetricItem(
          label: 'Total Jam',
          value: _formatHours(totalJam),
          icon: Icons.timer,
          color: Colors.purple,
          tooltip: 'Total jam lembur bulan ini',
        ),
      ];
      _isLoading = false;
    });
  }

  // ==================== MITRA METRICS ====================
  Future<void> _loadMitraMetrics(Map<String, dynamic> userData) async {
    final mitraId = _auth.currentUser!.uid;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Cari lembur yang melibatkan mitra ini
    final lemburSnapshot = await _firestore
        .collection('lembur')
        .where('mitra_ids', arrayContains: mitraId)
        .get();

    if (!mounted) return; // ✅ Check mounted

    int totalPengajuan = lemburSnapshot.docs.length;
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;
    double totalJam = 0;

    for (var doc in lemburSnapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      
      switch (status) {
        case 'pending':
          pendingCount++;
          break;
        case 'disetujui':
        case 'approved':
          approvedCount++;
          final tanggal = data['tanggal'];
          if (tanggal is Timestamp) {
            if (tanggal.toDate().isAfter(firstDayOfMonth)) {
              totalJam += _toDouble(data['total_jam_desimal']);
            }
          }
          break;
        case 'ditolak':
        case 'rejected':
          rejectedCount++;
          break;
      }
    }

    setState(() {
      _metrics = [
        MetricItem(
          label: 'Pengajuan',
          value: '$totalPengajuan',
          icon: Icons.assignment,
          color: Colors.blue,
          tooltip: 'Total pengajuan lembur Anda',
        ),
        MetricItem(
          label: 'Pending',
          value: '$pendingCount',
          icon: Icons.pending,
          color: Colors.orange,
          tooltip: 'Pengajuan menunggu approval',
        ),
        MetricItem(
          label: 'Disetujui',
          value: '$approvedCount',
          icon: Icons.check_circle,
          color: Colors.green,
          tooltip: 'Pengajuan yang sudah disetujui',
        ),
        MetricItem(
          label: 'Ditolak',
          value: '$rejectedCount',
          icon: Icons.cancel,
          color: Colors.red,
          tooltip: 'Pengajuan yang ditolak',
        ),
        MetricItem(
          label: 'Total Jam',
          value: _formatHours(totalJam),
          icon: Icons.timer,
          color: Colors.purple,
          tooltip: 'Total jam lembur Anda bulan ini',
        ),
      ];
      _isLoading = false;
    });
  }

  // ==================== HELPER METHODS ====================
  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String _formatHours(double hours) {
    if (hours >= 100) return '${hours.toStringAsFixed(0)} jam';
    if (hours >= 10) return '${hours.toStringAsFixed(1)} jam';
    return '${hours.toStringAsFixed(1)} jam';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(Icons.speed, color: const Color(0xFF1E3C72), size: 20),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Gagal memuat data',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadMetricsData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: _metrics.map((metric) => _buildMetricCard(metric)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(MetricItem metric) {
    return Tooltip(
      message: metric.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: metric.color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: metric.color.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(metric.icon, size: 18, color: metric.color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: metric.color,
                  ),
                ),
                if (metric.subtitle != null)
                  Text(
                    metric.subtitle!,
                    style: TextStyle(
                      fontSize: 9,
                      color: metric.color.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              metric.label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DATA CLASS ====================

class MetricItem {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String tooltip;

  const MetricItem({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.tooltip = '',
  });
}