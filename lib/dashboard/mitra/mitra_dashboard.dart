// lib/dashboard/mitra/mitra_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/mitra_service.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/live_location_service.dart';
import '/widgets/stats_grid_mitra.dart';
import '/widgets/calendar_card.dart';
import '/widgets/recent_activitiess.dart';
import '/widgets/menu/mitra_menu.dart';
import '/widgets/absensi/absensi_dialog.dart';

class MitraDashboard extends StatelessWidget {
  const MitraDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider(
      create: (_) => MitraProvider(),
      child: _MitraBody(user: user),
    );
  }
}

class _MitraBody extends StatefulWidget {
  final User? user;
  const _MitraBody({required this.user});

  @override
  State<_MitraBody> createState() => _MitraBodyState();
}

class _MitraBodyState extends State<_MitraBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = MitraService();
  final _scrollController = ScrollController();
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  // ==================== GREETING STATE ====================
  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;

  bool _isRefreshing = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    );
    _fadeController!.forward();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    await _loadGreetingAndProfile();
    await _loadDataWithMessage();
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final results = await Future.wait([
        _service.getGreetingWithNameAndEmoji(),
        _service.getGreetingMotivation(),
        _service.getCurrentUserProfile(),
      ]);

      final greeting = results[0] as String;
      final motivation = results[1] as String;
      final profile = results[2] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _greeting = greeting;
          _motivation = motivation;
          _isGreetingLoading = false;

          if (profile != null) {
            _userName = profile['nama_lengkap']?.toString() ?? '';
            _userRole = profile['role']?.toString() ?? 'mitra';
            _userPhotoUrl = profile['photo_url']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting = '${_service.getGreeting()}, ${widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? 'Mitra'}! 👋';
          _motivation = 'Semangat bekerja hari ini! 💪';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataWithMessage() async {
    setState(() => _loadingMessage = 'Memuat data mitra...');
    final provider = context.read<MitraProvider>();
    await provider.loadData();
    if (mounted && provider.data != null) {
      setState(() => _loadingMessage = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<MitraProvider>();
      provider.clearCache();
      await provider.loadData();
      await _loadGreetingAndProfile();
      _fadeController?.reset();
      _fadeController?.forward();
      if (mounted) _showSnackBar('✅ Data berhasil diperbarui', success: true);
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui data: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  Future<void> _showNotifications() async {
    final notifs = await _service.getNotifications();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.notifications, color: Color(0xFF1565C0), size: 24),
                    const SizedBox(width: 12),
                    const Text('Notifikasi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (notifs.any((n) => n['isRead'] == false))
                      TextButton.icon(
                        onPressed: () async {
                          await _service.markAllNotificationsRead();
                          if (mounted) context.read<MitraProvider>().loadData();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnackBar('✅ Semua notifikasi telah dibaca');
                        },
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Tandai Semua'),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.notifications_none, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tidak ada notifikasi', style: TextStyle(color: Colors.grey[400])),
                          ]))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: notifs.length,
                            itemBuilder: (ctx, index) {
                              final n = notifs[index];
                              final isRead = n['isRead'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : const Color(0xFF1565C0).withAlpha(13),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isRead ? Colors.grey[200]! : const Color(0xFF1565C0).withAlpha(51)),
                                ),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isRead ? Colors.grey : const Color(0xFF1565C0)).withAlpha(26),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.notifications, size: 16, color: isRead ? Colors.grey : const Color(0xFF1565C0)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(n['title'] ?? 'Notifikasi', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(n['body'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2),
                                    const SizedBox(height: 4),
                                    Text(_service.getTimeAgo(n['createdAt']), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                                  ])),
                                  if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle)),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== WAKTU & HANDLER BARU ====================

  /// Cek apakah sekarang sudah >= jam_mulai - 1 jam
  bool _canCheckInNow(String jamMulai) {
    final now = DateTime.now();
    final parts = jamMulai.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final todayStart = DateTime(now.year, now.month, now.day, hour, minute);
    final canCheckInFrom = todayStart.subtract(const Duration(hours: 1));
    return now.isAfter(canCheckInFrom) || now.isAtSameMomentAs(canCheckInFrom);
  }

  /// Format waktu 1 jam sebelum jam mulai untuk ditampilkan
  String _formatCheckInTime(String jamMulai) {
    final parts = jamMulai.split(':');
    if (parts.length != 2) return jamMulai;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final checkInFrom = DateTime(2024, 1, 1, hour, minute)
        .subtract(const Duration(hours: 1));
    return '${checkInFrom.hour.toString().padLeft(2, '0')}:${checkInFrom.minute.toString().padLeft(2, '0')}';
  }

  /// Handler check‑in yang WAJIB melalui dialog absensi
  Future<void> _handleCheckIn(Map<String, dynamic> overtime) async {
    // 1. Ambil data lengkap overtime
    final overtimeItem = await OvertimeHistoryService().getOvertimeById(overtime['id']);
    if (overtimeItem == null) {
      if (mounted) _showSnackBar('Data lembur tidak ditemukan', success: false);
      return;
    }

    // 2. Buka dialog absensi (foto + lokasi, dll.)
    final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
    if (absensiSuccess != true || !mounted) return;

    // 3. Lakukan check‑in ke backend
    await _service.checkInLembur(overtime['id'], _userName);

    // 4. Mulai live tracking
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await LiveLocationService().startTracking(
          userId: currentUser.uid,
          overtimeId: overtime['id'],
        );
      } catch (e) {
        debugPrint('Gagal mulai live tracking: $e');
      }
    }

    // 5. Refresh dashboard
    if (mounted) {
      context.read<MitraProvider>().loadData();
      _showSnackBar('✅ Check‑in berhasil! (Live tracking aktif)');
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MitraProvider>();

    if (provider.isLoading || _isGreetingLoading) {
      return _buildLoadingScreen(provider.errorMessage);
    }
    if (provider.data == null) {
      return _buildErrorScreen(provider.errorMessage);
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      floatingActionButton: data.hasTodayOvertime
          ? (data.isLemburCheckedIn
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.red,
                  icon: const Icon(Icons.logout),
                  label: const Text('Check-out'),
                  onPressed: () async {
                    final overtimeItem = await OvertimeHistoryService()
                        .getOvertimeById(data.todayOvertime!['id']);
                    if (overtimeItem == null) {
                      if (mounted) _showSnackBar('Data lembur tidak ditemukan', success: false);
                      return;
                    }
                    final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
                    if (absensiSuccess == true && mounted) {
                      await LiveLocationService().stopTracking();
                      final income = await _service.checkOutLembur(
                        data.todayOvertime!['id'],
                        data.userName,
                        data.overtimeSettings,
                      );
                      if (mounted) {
                        provider.loadData();
                        _showSnackBar('✅ Check‑out! Pendapatan: Rp ${NumberFormat('#,###').format(income)}');
                      }
                    }
                  },
                )
              : FloatingActionButton.extended(
                  backgroundColor: const Color(0xFFFFAB40),
                  icon: const Icon(Icons.login),
                  label: const Text('Check-in'),
                  onPressed: () => _handleCheckIn(data.todayOvertime!),
                ))
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF1565C0),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 10,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _buildSliverAppBar(),
            _buildContentSliver(data),
          ],
        ),
      ),
    );
  }

  // ==================== SCREENS ====================

  Widget _buildLoadingScreen(String? errorMessage) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(13))),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(13))),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withAlpha(77), blurRadius: 40, spreadRadius: 5)]),
                        child: const Icon(Icons.engineering_rounded, size: 65, color: Color(0xFF1565C0)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                const Text('MITRA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
                const SizedBox(height: 8),
                const Text('DASHBOARD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: Colors.white70, letterSpacing: 6)),
                const SizedBox(height: 40),
                SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(204))),
                ),
                const SizedBox(height: 20),
                if (_loadingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(20)),
                    child: Text(_loadingMessage!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String? errorMessage) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withAlpha(26), shape: BoxShape.circle), child: const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.white)),
                const SizedBox(height: 24),
                const Text('Gagal Memuat Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Text(errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.\nSilakan coba lagi.', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = context.read<MitraProvider>();
                    provider.clearCache();
                    provider.loadData();
                    _loadGreetingAndProfile();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 4),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: _logout, child: const Text('Kembali ke Login', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFFFFAB40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
        else
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22), onPressed: _refreshData, tooltip: 'Refresh data'),
        IconButton(icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22), onPressed: _showNotifications, tooltip: 'Notifikasi'),
        PopupMenuButton<String>(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(_userPhotoUrl!), fit: BoxFit.cover) : null,
            ),
            child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          offset: const Offset(0, 50),
          onSelected: (value) {
            switch (value) {
              case 'profile': Navigator.pushNamed(context, '/profile'); break;
              case 'settings': Navigator.pushNamed(context, '/settings'); break;
              case 'logout': _showLogoutConfirmation(); break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'profile', child: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withAlpha(26), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person_rounded, size: 16, color: Colors.blue)), const SizedBox(width: 10), const Text('Profil Saya', style: TextStyle(fontSize: 13))])),
            PopupMenuItem(value: 'settings', child: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.withAlpha(26), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.settings_rounded, size: 16, color: Colors.green)), const SizedBox(width: 10), const Text('Pengaturan', style: TextStyle(fontSize: 13))])),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(value: 'logout', child: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout_rounded, size: 16, color: Colors.red)), const SizedBox(width: 10), const Text('Logout', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600))])),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildContentSliver(MitraDashboardData data) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          FadeTransition(opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0), child: _buildPersonalWelcomeCard()),
          const SizedBox(height: 16),
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fadeAnimation ?? const AlwaysStoppedAnimation(0.0)),
            child: StatsGridMitra(data: data, onRefresh: () => _refreshData()),
          ),
          const SizedBox(height: 16),
          if (data.hasTodayOvertime) ...[
            _buildTodayOvertimeCard(data),
            const SizedBox(height: 16),
          ],
          _buildMitraKeyMetrics(data),
          const SizedBox(height: 16),
          MitraMenu(data: data, service: _service),
          const SizedBox(height: 16),
          const CalendarCard(primaryColor: Color(0xFF1565C0)),
          const SizedBox(height: 16),
          RecentActivitiesWidget(
            activities: data.allLembur.take(5).map((l) => {
              'type': l['status'] ?? 'pending',
              'description': '${l['alasan'] ?? 'Lembur'} - ${(l['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
              'timestamp': l['tanggal'] as dynamic,
              'user': l['nama_pengawas'] ?? 'Pengawas',
              'userRole': 'pengawas',
            }).toList(),
            getTimeAgo: _service.getTimeAgo,
            getRoleColor: (r) => _service.getStatusColor(r),
          ),
          const SizedBox(height: 24),
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildPersonalWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withAlpha(77), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 8)]),
            child: CircleAvatar(
              radius: 28, backgroundColor: Colors.white,
              backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty ? NetworkImage(_userPhotoUrl!) : null,
              child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'M', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
            const SizedBox(height: 4),
            Text(_motivation, style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(204), fontStyle: FontStyle.italic)),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shield_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text('Role: ${_userRole.isNotEmpty ? _userRole.toUpperCase() : 'MITRA'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5)),
            const SizedBox(width: 12),
            Container(width: 1, height: 16, color: Colors.white30),
            const SizedBox(width: 12),
            const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text(_formatDate(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
      ]),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ======================================================================
  // TODAY OVERTIME CARD (dengan pengingat & absensi)
  // ======================================================================
  Widget _buildTodayOvertimeCard(MitraDashboardData data) {
    final ot = data.todayOvertime!;
    final jamMulai = ot['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = ot['jam_selesai']?.toString() ?? '22:00';
    final canCheckIn = _canCheckInNow(jamMulai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.isLemburCheckedOut
              ? [Colors.green.shade700, Colors.green.shade500]
              : data.isLemburCheckedIn
                  ? [Colors.orange.shade700, Colors.orange.shade500]
                  : [const Color(0xFFFF6B35), const Color(0xFFFF8A5C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF6B35).withAlpha(77), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.isLemburCheckedOut
                      ? Icons.check_circle
                      : data.isLemburCheckedIn
                          ? Icons.access_time
                          : Icons.notifications_active,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.isLemburCheckedOut
                      ? '✅ Lembur Selesai!'
                      : data.isLemburCheckedIn
                          ? '🔵 Sedang Lembur'
                          : '📅 Jadwal Lembur Hari Ini!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$jamMulai - $jamSelesai',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (!data.isLemburCheckedOut) ...[
                  if (data.isLemburCheckedIn)
                    _buildActionButton('Check Out', Icons.logout, Colors.red, () async {
                      final overtimeItem = await OvertimeHistoryService()
                          .getOvertimeById(ot['id']);
                      if (overtimeItem == null) {
                        if (mounted) _showSnackBar('Data lembur tidak ditemukan', success: false);
                        return;
                      }
                      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
                      if (absensiSuccess == true && mounted) {
                        await LiveLocationService().stopTracking();
                        final income = await _service.checkOutLembur(
                          ot['id'],
                          data.userName,
                          data.overtimeSettings,
                        );
                        if (mounted) {
                          context.read<MitraProvider>().loadData();
                          _showSnackBar('✅ Check‑out! Pendapatan: Rp ${NumberFormat('#,###').format(income)}');
                        }
                      }
                    })
                  else if (!data.isLemburCheckedIn)
                    canCheckIn
                        ? _buildActionButton('Check In', Icons.login, Colors.green,
                            () => _handleCheckIn(ot))
                        : Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'Check‑in dapat dilakukan mulai pukul ${_formatCheckInTime(jamMulai)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withAlpha(77), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildMitraKeyMetrics(MitraDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔑 Metrik Saya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A2B4C))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildMetricItem(Icons.work_history, 'Total Lembur', '${data.totalLemburStat}', Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricItem(Icons.timer, 'Total Jam', '${data.totalJamStat} jam', Colors.teal)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildMetricItem(Icons.pending_actions, 'Pending', '${data.pendingStat}', Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricItem(Icons.check_circle, 'Disetujui', '${data.disetujuiStat}', Colors.green)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildMetricItem(Icons.monetization_on, 'Pendapatan', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data.totalIncomeStat), Colors.purple)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricItem(Icons.pie_chart, 'Sisa Kuota', '${data.sisaKuotaStat} jam', Colors.indigo)),
        ]),
      ]),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF6D00)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFE53935).withAlpha(77), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: _showLogoutConfirmation,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.zero),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, color: Colors.white, size: 22), SizedBox(width: 10), Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5))]),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.logout_rounded, size: 48, color: Colors.red),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () { Navigator.pop(context); _logout(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Ya, Logout')),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => PopScope(canPop: false, child: Center(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: Color(0xFF1565C0)), const SizedBox(height: 16), Text('Sedang logout...', style: TextStyle(color: Colors.grey[700], fontSize: 13))])))));
      await _service.logout();
      if (mounted) {
        final provider = context.read<MitraProvider>();
        provider.clearCache();
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSnackBar('Gagal logout: ${e.toString()}', success: false);
      }
    }
  }
}

// ==================== PROVIDER ====================
class MitraProvider extends ChangeNotifier {
  final _service = MitraService();
  bool isLoading = true;
  MitraDashboardData? data;
  String? errorMessage;

  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      data = await _service.loadDashboardData();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void clearCache() {
    data = null;
  }
}