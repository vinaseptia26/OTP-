// lib/widgets/stats_grid.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsGrid extends StatefulWidget {
  final String? roleFilter;
  final bool useRealtime;

  const StatsGrid({
    super.key,
    this.roleFilter,
    this.useRealtime = true,
  });

  @override
  State<StatsGrid> createState() => _StatsGridState();
}

class _StatsGridState extends State<StatsGrid> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _usersSubscription;
  StreamSubscription? _pendingSubscription;   // pengajuan_lembur (pending)
  StreamSubscription? _overtimeSubscription;  // lembur_mitra bulan ini
  StreamSubscription? _onlineSubscription;

  // Data asli dari Firestore
  int _totalUsers = 0;
  int _activeToday = 0;
  int _pendingApprovals = 0;
  int _totalOvertime = 0;
  int _verifiedUsers = 0;
  int _onlineNow = 0;
  int _lockedAccounts = 0;
  int _newUsersToday = 0;

  // Data sebelumnya untuk kalkulasi trend
  int _prevTotalUsers = 0;
  int _prevPendingApprovals = 0;
  int _prevTotalOvertime = 0;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.useRealtime) {
      _setupRealtimeListeners();
    } else {
      _loadStatsOnce();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usersSubscription?.cancel();
    _pendingSubscription?.cancel();
    _overtimeSubscription?.cancel();
    _onlineSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.useRealtime) _loadStatsOnce();
    }
  }

  // ==================== REALTIME LISTENERS ====================

  void _setupRealtimeListeners() {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // 1. Users stream
    _usersSubscription = _firestore
        .collection('users')
        .orderBy('last_login', descending: true)
        .limit(500)
        .snapshots()
        .listen(
          (snapshot) => _processUsersData(snapshot.docs),
          onError: (e) {
            debugPrint('StatsGrid users error: $e');
            if (mounted) setState(() { _error = 'Gagal memuat data users'; _isLoading = false; });
          },
        );

    // 2. Pending approvals dari pengajuan_lembur (dengan filter fungsi)
    Query<Map<String, dynamic>> pendingQuery = _firestore
        .collection('pengajuan_lembur')
        .where('status', isEqualTo: 'pending');

    if (widget.roleFilter != null && widget.roleFilter!.isNotEmpty && widget.roleFilter != 'semua') {
      pendingQuery = pendingQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
    }

    _pendingSubscription = pendingQuery.snapshots().listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _prevPendingApprovals = _pendingApprovals;
            _pendingApprovals = snapshot.docs.length;
          });
        }
      },
      onError: (e) => debugPrint('StatsGrid pending error: $e'),
    );

    // 3. Total lembur bulan ini dari lembur_mitra
    _overtimeSubscription = _firestore
        .collection('lembur_mitra')
        .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _prevTotalOvertime = _totalOvertime;
                _totalOvertime = snapshot.docs.length;
              });
            }
          },
          onError: (e) => debugPrint('StatsGrid overtime error: $e'),
        );

    // 4. Online users stream
    _onlineSubscription = _firestore
        .collection('online_users')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) setState(() => _onlineNow = snapshot.docs.length);
          },
          onError: (e) => debugPrint('StatsGrid online error: $e'),
        );
  }

  // ==================== PROCESS DATA ====================

  void _processUsersData(List<QueryDocumentSnapshot> docs) {
    if (!mounted) return;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    int activeToday = 0;
    int verifiedUsers = 0;
    int lockedAccounts = 0;
    int newUsersToday = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['is_verified'] == true) verifiedUsers++;
      if (data['account_locked'] == true) lockedAccounts++;

      final lastLogin = data['last_login'];
      if (lastLogin != null) {
        DateTime loginDate;
        if (lastLogin is Timestamp) {
          loginDate = lastLogin.toDate();
        } else if (lastLogin is String) {
          loginDate = DateTime.tryParse(lastLogin) ?? DateTime(2000);
        } else {
          loginDate = DateTime(2000);
        }
        if (loginDate.isAfter(startOfDay)) activeToday++;
      }

      final createdAt = data['created_at'];
      if (createdAt != null) {
        DateTime createDate;
        if (createdAt is Timestamp) {
          createDate = createdAt.toDate();
        } else if (createdAt is String) {
          createDate = DateTime.tryParse(createdAt) ?? DateTime(2000);
        } else {
          createDate = DateTime(2000);
        }
        if (createDate.isAfter(startOfDay)) newUsersToday++;
      }
    }

    if (mounted) {
      setState(() {
        _prevTotalUsers = _totalUsers;
        _totalUsers = docs.length;
        _activeToday = activeToday;
        _verifiedUsers = verifiedUsers;
        _lockedAccounts = lockedAccounts;
        _newUsersToday = newUsersToday;
        _isLoading = false;
        _error = null;
      });
    }
  }

  // ==================== ONE-TIME LOAD ====================

  Future<void> _loadStatsOnce() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      Query<Map<String, dynamic>> pendingQuery = _firestore
          .collection('pengajuan_lembur')
          .where('status', isEqualTo: 'pending');
      if (widget.roleFilter != null && widget.roleFilter!.isNotEmpty && widget.roleFilter != 'semua') {
        pendingQuery = pendingQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
      }

      final results = await Future.wait([
        _firestore.collection('users').orderBy('last_login', descending: true).limit(500).get(),
        pendingQuery.count().get(),
        _firestore.collection('lembur_mitra').where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)).count().get(),
        _firestore.collection('online_users').where('is_online', isEqualTo: true).count().get(),
      ]);

      final usersSnapshot = results[0] as QuerySnapshot;
      final pendingCount = (results[1] as AggregateQuerySnapshot).count;
      final overtimeCount = (results[2] as AggregateQuerySnapshot).count;
      final onlineCount = (results[3] as AggregateQuerySnapshot).count;

      _processUsersData(usersSnapshot.docs);

      if (mounted) {
        setState(() {
          _pendingApprovals = pendingCount ?? 0;
          _totalOvertime = overtimeCount ?? 0;
          _onlineNow = onlineCount ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StatsGrid load error: $e');
      if (mounted) setState(() { _error = 'Gagal memuat statistik'; _isLoading = false; });
    }
  }

  Future<void> refreshStats() async {
    if (widget.useRealtime) {
      _usersSubscription?.cancel();
      _pendingSubscription?.cancel();
      _overtimeSubscription?.cancel();
      _onlineSubscription?.cancel();
      _setupRealtimeListeners();
    } else {
      await _loadStatsOnce();
    }
  }

  // ==================== HELPERS ====================

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String _calculateTrend(int current, int previous) {
    if (previous == 0) return current > 0 ? '+100%' : '0%';
    final change = ((current - previous) / previous * 100).round();
    return change >= 0 ? '+$change%' : '$change%';
  }

  bool _isTrendUp(int current, int previous) => current >= previous;

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingGrid();
    if (_error != null) return _buildErrorState();
    return _buildStatsGrid();
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 12),
          Container(width: 60, height: 18, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
        ])),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red[100]!)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 40),
        const SizedBox(height: 12),
        Text(_error ?? 'Terjadi kesalahan', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton.icon(onPressed: () => widget.useRealtime ? _setupRealtimeListeners() : _loadStatsOnce(), icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Coba Lagi'), style: TextButton.styleFrom(foregroundColor: Colors.red[700])),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatItem(
        title: 'Total Users',
        value: _formatNumber(_totalUsers),
        icon: Icons.people_rounded,
        subtitle: '$_verifiedUsers terverifikasi',
        gradientColors: const [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        trend: _calculateTrend(_totalUsers, _prevTotalUsers),
        trendUp: _isTrendUp(_totalUsers, _prevTotalUsers),
        badge: _newUsersToday > 0 ? '+$_newUsersToday hari ini' : null,
      ),
      _StatItem(
        title: 'Online Sekarang',
        value: _formatNumber(_onlineNow),
        icon: Icons.online_prediction_rounded,
        subtitle: _activeToday > 0 ? '$_activeToday aktif hari ini' : 'Tidak ada',
        gradientColors: const [Color(0xFF00b09b), Color(0xFF96c93d)],
        trend: _onlineNow > 0 ? 'Online' : 'Offline',
        trendUp: _onlineNow > 0,
        badge: _onlineNow > 0 ? null : 'Idle',
      ),
      _StatItem(
        title: 'Pending Approval',
        value: _formatNumber(_pendingApprovals),
        icon: Icons.pending_actions_rounded,
        subtitle: _pendingApprovals > 0 ? 'Perlu tindakan' : 'Tidak ada',
        gradientColors: const [Color(0xFFf12711), Color(0xFFf5af19)],
        trend: _calculateTrend(_pendingApprovals, _prevPendingApprovals),
        trendUp: _isTrendUp(_pendingApprovals, _prevPendingApprovals),
        badge: _pendingApprovals > 5 ? '⚠️ Urgent' : (_pendingApprovals > 0 ? 'Normal' : null),
      ),
      _StatItem(
        title: 'Total Lembur',
        value: _formatNumber(_totalOvertime),
        icon: Icons.work_history_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [Color(0xFF834d9b), Color(0xFFd04ed6)],
        trend: _calculateTrend(_totalOvertime, _prevTotalOvertime),
        trendUp: _isTrendUp(_totalOvertime, _prevTotalOvertime),
        badge: _lockedAccounts > 0 ? '$_lockedAccounts diblokir' : null,
      ),
    ];

    return Column(mainAxisSize: MainAxisSize.min, children: [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) => _buildStatCard(stats[index]),
      ),
      if (widget.useRealtime)
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Realtime', style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w500)),
          ]),
        ),
    ]);
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: item.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: item.gradientColors[0].withAlpha(77), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: Colors.white, size: 20)),
          _buildTrendBadge(item),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text(item.title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
          Text(item.subtitle, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        ]),
      ]),
    );
  }

  Widget _buildTrendBadge(_StatItem item) {
    if (item.title == 'Online Sekarang') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: (_onlineNow > 0 ? Colors.green : Colors.grey).withAlpha(60), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _onlineNow > 0 ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(_onlineNow > 0 ? 'Live' : 'Off', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (item.badge != null && item.badge!.contains('⚠️')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.withAlpha(60), borderRadius: BorderRadius.circular(10)),
        child: Text(item.badge!, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(item.trendUp ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white, size: 10),
        const SizedBox(width: 2),
        Text(item.trend, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
        if (item.badge != null) ...[
          const SizedBox(width: 4),
          Text(item.badge!, style: const TextStyle(fontSize: 8, color: Colors.white70)),
        ],
      ]),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String trend;
  final bool trendUp;
  final String? badge;

  _StatItem({required this.title, required this.value, required this.icon, required this.subtitle, required this.gradientColors, required this.trend, required this.trendUp, this.badge});
}