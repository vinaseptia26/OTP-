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

class _StatsGridState extends State<StatsGrid>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  StreamSubscription? _usersSubscription;
  StreamSubscription? _pendingSubscription;
  StreamSubscription? _overtimeSubscription;
  StreamSubscription? _onlineSubscription;

  // =========================
  // DATA
  // =========================

  int _totalUsers = 0;
  int _activeToday = 0;
  int _pendingApprovals = 0;
  int _totalOvertime = 0;
  int _verifiedUsers = 0;
  int _onlineNow = 0;
  int _lockedAccounts = 0;
  int _newUsersToday = 0;

  // previous data for trend
  int _prevTotalUsers = 0;
  int _prevPendingApprovals = 0;
  int _prevTotalOvertime = 0;

  bool _isLoading = true;
  String? _error;

  // =========================
  // INIT
  // =========================

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
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.useRealtime) {
        _loadStatsOnce();
      }
    }
  }

  // =========================
  // REALTIME LISTENERS
  // =========================

  void _setupRealtimeListeners() {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();

    final startOfMonth =
        DateTime(now.year, now.month, 1);

    // USERS
    _usersSubscription = _firestore
        .collection('users')
        .orderBy(
          'last_login',
          descending: true,
        )
        .limit(500)
        .snapshots()
        .listen(
      (snapshot) {
        _processUsersData(snapshot.docs);
      },
      onError: (e) {
        debugPrint('Users stream error: $e');

        if (mounted) {
          setState(() {
            _error = 'Gagal memuat data users';
            _isLoading = false;
          });
        }
      },
    );

    // PENDING Persetujuan
    Query<Map<String, dynamic>> pendingQuery =
        _firestore
            .collection('pengajuan_lembur')
            .where(
              'status',
              isEqualTo: 'pending',
            );

    if (widget.roleFilter != null &&
        widget.roleFilter!.isNotEmpty &&
        widget.roleFilter != 'semua') {
      pendingQuery = pendingQuery.where(
        'pengawas_fungsi',
        isEqualTo: widget.roleFilter,
      );
    }

    _pendingSubscription =
        pendingQuery.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _prevPendingApprovals =
              _pendingApprovals;

          _pendingApprovals =
              snapshot.docs.length;
        });
      },
      onError: (e) {
        debugPrint('Pending stream error: $e');
      },
    );

    // OVERTIME
    _overtimeSubscription = _firestore
        .collection('lembur_mitra')
        .where(
          'tanggal',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(
            startOfMonth,
          ),
        )
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _prevTotalOvertime =
              _totalOvertime;

          _totalOvertime =
              snapshot.docs.length;
        });
      },
      onError: (e) {
        debugPrint('Overtime stream error: $e');
      },
    );

    // ONLINE USERS
    _onlineSubscription = _firestore
        .collection('online_users')
        .where(
          'is_online',
          isEqualTo: true,
        )
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _onlineNow =
              snapshot.docs.length;
        });
      },
      onError: (e) {
        debugPrint('Online stream error: $e');
      },
    );
  }

  // =========================
  // PROCESS USERS
  // =========================

  void _processUsersData(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (!mounted) return;

    final now = DateTime.now();

    final startOfDay =
        DateTime(now.year, now.month, now.day);

    int activeToday = 0;
    int verifiedUsers = 0;
    int lockedAccounts = 0;
    int newUsersToday = 0;

    for (final doc in docs) {
      final data =
          doc.data() as Map<String, dynamic>;

      if (data['is_verified'] == true) {
        verifiedUsers++;
      }

      if (data['account_locked'] == true) {
        lockedAccounts++;
      }

      final lastLogin = data['last_login'];

      if (lastLogin != null) {
        DateTime loginDate;

        if (lastLogin is Timestamp) {
          loginDate = lastLogin.toDate();
        } else if (lastLogin is String) {
          loginDate =
              DateTime.tryParse(lastLogin) ??
                  DateTime(2000);
        } else {
          loginDate = DateTime(2000);
        }

        if (loginDate.isAfter(startOfDay)) {
          activeToday++;
        }
      }

      final createdAt = data['created_at'];

      if (createdAt != null) {
        DateTime createDate;

        if (createdAt is Timestamp) {
          createDate = createdAt.toDate();
        } else if (createdAt is String) {
          createDate =
              DateTime.tryParse(createdAt) ??
                  DateTime(2000);
        } else {
          createDate = DateTime(2000);
        }

        if (createDate.isAfter(startOfDay)) {
          newUsersToday++;
        }
      }
    }

    if (!mounted) return;

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

  // =========================
  // LOAD ONCE
  // =========================

  Future<void> _loadStatsOnce() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();

    final startOfMonth =
        DateTime(now.year, now.month, 1);

    try {
      Query<Map<String, dynamic>> pendingQuery =
          _firestore
              .collection(
                'pengajuan_lembur',
              )
              .where(
                'status',
                isEqualTo: 'pending',
              );

      if (widget.roleFilter != null &&
          widget.roleFilter!.isNotEmpty &&
          widget.roleFilter != 'semua') {
        pendingQuery = pendingQuery.where(
          'pengawas_fungsi',
          isEqualTo: widget.roleFilter,
        );
      }

      final results = await Future.wait([
        _firestore
            .collection('users')
            .orderBy(
              'last_login',
              descending: true,
            )
            .limit(500)
            .get(),

        pendingQuery.count().get(),

        _firestore
            .collection('lembur_mitra')
            .where(
              'tanggal',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(
                startOfMonth,
              ),
            )
            .count()
            .get(),

        _firestore
            .collection('online_users')
            .where(
              'is_online',
              isEqualTo: true,
            )
            .count()
            .get(),
      ]);

      final usersSnapshot =
          results[0] as QuerySnapshot;

      final pendingCount =
          (results[1]
                  as AggregateQuerySnapshot)
              .count;

      final overtimeCount =
          (results[2]
                  as AggregateQuerySnapshot)
              .count;

      final onlineCount =
          (results[3]
                  as AggregateQuerySnapshot)
              .count;

      _processUsersData(usersSnapshot.docs);

      if (!mounted) return;

      setState(() {
        _pendingApprovals =
            pendingCount ?? 0;

        _totalOvertime =
            overtimeCount ?? 0;

        _onlineNow = onlineCount ?? 0;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load stats error: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Gagal memuat statistik';
        _isLoading = false;
      });
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

  // =========================
  // HELPERS
  // =========================

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }

    return number.toString();
  }

  String _calculateTrend(
    int current,
    int previous,
  ) {
    if (previous == 0) {
      return current > 0
          ? '+100%'
          : '0%';
    }

    final change =
        ((current - previous) /
                    previous *
                    100)
                .round();

    return change >= 0
        ? '+$change%'
        : '$change%';
  }

  bool _isTrendUp(
    int current,
    int previous,
  ) {
    return current >= previous;
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingGrid();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildStatsGrid();
  }

  // =========================
  // LOADING
  // =========================

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.20,
      ),

      itemCount: 4,

      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius:
                BorderRadius.circular(22),
          ),

          child: Center(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: 70,
                  height: 18,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      4,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  width: 90,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // ERROR
  // =========================

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: Colors.red.shade100,
        ),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade300,
            size: 42,
          ),

          const SizedBox(height: 12),

          Text(
            _error ?? 'Terjadi kesalahan',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade700,
            ),
          ),

          const SizedBox(height: 14),

          TextButton.icon(
            onPressed: () {
              if (widget.useRealtime) {
                _setupRealtimeListeners();
              } else {
                _loadStatsOnce();
              }
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // =========================
  // GRID
  // =========================

  Widget _buildStatsGrid() {
    final width =
        MediaQuery.of(context).size.width;

    final crossAxisCount =
        width >= 1200
            ? 4
            : width >= 900
                ? 3
                : 2;

    final childAspectRatio =
        width < 360
            ? 1.02
            : width < 430
                ? 1.10
                : 1.22;

    final stats = [
      _StatItem(
        title: 'Total Pengguna',
        value: _formatNumber(_totalUsers),
        icon: Icons.people_alt_rounded,
        subtitle:
            '$_verifiedUsers terverifikasi',
        gradientColors: const [
          Color(0xFF1E3C72),
          Color(0xFF2A5298),
        ],
        trend: _calculateTrend(
          _totalUsers,
          _prevTotalUsers,
        ),
        trendUp: _isTrendUp(
          _totalUsers,
          _prevTotalUsers,
        ),
        badge: _newUsersToday > 0
            ? '+$_newUsersToday hari ini'
            : null,
      ),

      _StatItem(
        title: 'Online Sekarang',
        value: _formatNumber(_onlineNow),
        icon:
            Icons.online_prediction_rounded,
        subtitle:
            '$_activeToday aktif hari ini',
        gradientColors: const [
          Color(0xFF11998E),
          Color(0xFF38EF7D),
        ],
        trend:
            _onlineNow > 0
                ? 'LIVE'
                : 'OFF',
        trendUp: _onlineNow > 0,
      ),

      _StatItem(
        title: 'Pending Persetujuan',
        value:
            _formatNumber(_pendingApprovals),
        icon:
            Icons.pending_actions_rounded,
        subtitle:
            _pendingApprovals > 0
                ? 'Perlu tindakan'
                : 'Tidak ada pending',
        gradientColors: const [
          Color(0xFFF12711),
          Color(0xFFF5AF19),
        ],
        trend: _calculateTrend(
          _pendingApprovals,
          _prevPendingApprovals,
        ),
        trendUp: _isTrendUp(
          _pendingApprovals,
          _prevPendingApprovals,
        ),
        badge:
            _pendingApprovals >= 5
                ? 'Urgent'
                : null,
      ),

      _StatItem(
        title: 'Total Lembur',
        value:
            _formatNumber(_totalOvertime),
        icon:
            Icons.work_history_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [
          Color(0xFF7F00FF),
          Color(0xFFE100FF),
        ],
        trend: _calculateTrend(
          _totalOvertime,
          _prevTotalOvertime,
        ),
        trendUp: _isTrendUp(
          _totalOvertime,
          _prevTotalOvertime,
        ),
        badge: _lockedAccounts > 0
            ? '$_lockedAccounts blocked'
            : null,
      ),
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,

          physics:
              const NeverScrollableScrollPhysics(),

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                childAspectRatio,
          ),

          itemCount: stats.length,

          itemBuilder: (context, index) {
            return _buildStatCard(
              stats[index],
            );
          },
        ),

        if (widget.useRealtime)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 10,
              right: 6,
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,

              children: [
                Container(
                  width: 8,
                  height: 8,

                  decoration:
                      const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  'Realtime Monitoring',
                  style:
                      GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =========================
  // CARD
  // =========================

  Widget _buildStatCard(
    _StatItem item,
  ) {
    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 250),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                item.gradientColors.first
                    .withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,

            children: [
              Container(
                padding:
                    const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color:
                      Colors.white.withAlpha(
                    45,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              Flexible(
                child:
                    _buildTrendBadge(item),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment:
                    Alignment.centerLeft,

                child: Text(
                  item.value,
                  maxLines: 1,
                  style:
                      GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                item.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                item.subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // TREND BADGE
  // =========================

  Widget _buildTrendBadge(
    _StatItem item,
  ) {
    Color bgColor =
        Colors.white.withAlpha(45);

    if (item.badge == 'Urgent') {
      bgColor = Colors.red.withAlpha(90);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.trendUp
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: Colors.white,
            size: 11,
          ),

          const SizedBox(width: 3),

          Text(
            item.trend,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          if (item.badge != null) ...[
            const SizedBox(width: 4),

            Flexible(
              child: Text(
                item.badge!,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =========================
// MODEL
// =========================

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String trend;
  final bool trendUp;
  final String? badge;

  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    required this.trend,
    required this.trendUp,
    this.badge,
  });
}