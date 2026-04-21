// FILE: lib/screens/admin/system_logs_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

var logger = Logger();

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen>
    with TickerProviderStateMixin {
  
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== USER DATA ====================
  String? _userRole;
  String? _userId;
  String? _userName;
  
  bool get isSuperadmin => _userRole == 'superadmin';
  
  // ==================== LOG DATA ====================
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  
  // Log categories
  final Map<String, String> _logCategories = {
    'all': 'Semua Log',
    'system': 'System Logs',
    'user': 'User Logs',
    'overtime': 'Lembur Logs',
    'absensi': 'Absensi Logs',
    'broadcast': 'Broadcast Logs',
    'backup': 'Backup Logs',
    'export_import': 'Export/Import Logs',
    'error': 'Error Logs',
    'login': 'Login/Logout Logs',
    'audit': 'Audit Trail',
  };
  
  // Filter states
  String _selectedCategory = 'all';
  DateTimeRange? _selectedDateRange;
  String _selectedLevel = 'all';
  String _searchQuery = '';
  String _selectedUser = 'all';
  
  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isDarkMode = false;
  bool isGridView = false;
  final int _itemsPerPage = 30;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  
  // Statistics
  Map<String, int> _logStats = {};
  Map<String, int> _dailyLogs = {};
  Map<String, int> _topUsers = {};
  
  // Search debounce
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Colors
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);
  
  // Level colors
  final Map<String, Color> _levelColors = {
    'info': const Color(0xFF2196F3),
    'warning': const Color(0xFFFF9800),
    'error': const Color(0xFFF44336),
    'success': const Color(0xFF4CAF50),
    'debug': const Color(0xFF9C27B0),
  };
  
  // Category icons
  final Map<String, IconData> _categoryIcons = {
    'system': Icons.computer,
    'user': Icons.people,
    'overtime': Icons.work_history,
    'absensi': Icons.camera_alt,
    'broadcast': Icons.campaign,
    'backup': Icons.backup,
    'export_import': Icons.file_download,
    'error': Icons.error,
    'login': Icons.login,
    'audit': Icons.history,
  };
  
  // Level options
  final List<Map<String, dynamic>> _levelOptions = const [
    {'value': 'all', 'label': 'Semua Level', 'color': Colors.grey},
    {'value': 'info', 'label': 'Info', 'color': Color(0xFF2196F3)},
    {'value': 'warning', 'label': 'Warning', 'color': Color(0xFFFF9800)},
    {'value': 'error', 'label': 'Error', 'color': Color(0xFFF44336)},
    {'value': 'success', 'label': 'Success', 'color': Color(0xFF4CAF50)},
    {'value': 'debug', 'label': 'Debug', 'color': Color(0xFF9C27B0)},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreData();
    }
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      
      _userId = user.uid;
      _userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _userRole = userData['role'] ?? 'mitra';
      }
      
      if (!isSuperadmin && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akses ditolak. Hanya Superadmin yang dapat mengakses halaman ini.')),
        );
        return;
      }
      
      await _loadLogs();
      await _loadStatistics();
      
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackbar('Gagal memuat data user');
      }
    }
  }
  
  Future<void> _loadLogs({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _allLogs.clear();
        _filteredLogs.clear();
        _lastDocument = null;
        _hasMoreData = true;
        _isLoadingMore = false;
      });
    }
    
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('system_logs');
      
      // Apply date filter
      if (_selectedDateRange != null) {
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end));
      }
      
      query = query.orderBy('timestamp', descending: true);
      
      if (_lastDocument != null && !refresh) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.limit(_itemsPerPage).get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        if (snapshot.docs.length < _itemsPerPage) {
          _hasMoreData = false;
        }
        
        final newLogs = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'timestamp_local': (data['timestamp'] as Timestamp?)?.toDate(),
          };
        }).toList();
        
        setState(() {
          _allLogs.addAll(newLogs);
          _applyFilters();
        });
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      logger.e('Error loading logs: $e');
    }
  }
  
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    setState(() => _isLoadingMore = true);
    await _loadLogs();
    if (mounted) setState(() => _isLoadingMore = false);
  }
  
  Future<void> _loadStatistics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      
      final snapshot = await _firestore
          .collection('system_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();
      
      final Map<String, int> stats = {};
      final Map<String, int> daily = {};
      final Map<String, int> topUsers = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] ?? 'unknown';
        final user = data['user'] ?? 'system';
        final timestamp = data['timestamp'] as Timestamp?;
        
        // Category stats
        String category = _getCategoryFromType(type);
        stats[category] = (stats[category] ?? 0) + 1;
        
        // Daily stats
        if (timestamp != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
          daily[dateKey] = (daily[dateKey] ?? 0) + 1;
        }
        
        // Top users
        if (user != 'system' && user != null && user.toString().isNotEmpty) {
          topUsers[user.toString()] = (topUsers[user] ?? 0) + 1;
        }
      }
      
      if (mounted) {
        setState(() {
          _logStats = stats;
          _dailyLogs = daily;
          _topUsers = Map.fromEntries(
            topUsers.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
          );
        });
      }
    } catch (e) {
      logger.e('Error loading statistics: $e');
    }
  }
  
  String _getCategoryFromType(String type) {
    if (type.contains('user') || type.contains('login') || type.contains('logout')) return 'user';
    if (type.contains('overtime') || type.contains('lembur')) return 'overtime';
    if (type.contains('absensi')) return 'absensi';
    if (type.contains('broadcast')) return 'broadcast';
    if (type.contains('backup')) return 'backup';
    if (type.contains('export') || type.contains('import')) return 'export_import';
    if (type.contains('error')) return 'error';
    if (type.contains('audit')) return 'audit';
    return 'system';
  }
  
  String _getLevelFromType(String type) {
    if (type.contains('error')) return 'error';
    if (type.contains('warning')) return 'warning';
    if (type.contains('success') || type.contains('approved') || type.contains('completed')) return 'success';
    if (type.contains('debug')) return 'debug';
    return 'info';
  }
  
  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        // Category filter
        if (_selectedCategory != 'all') {
          final logCategory = _getCategoryFromType(log['type'] ?? '');
          if (logCategory != _selectedCategory) return false;
        }
        
        // Level filter
        if (_selectedLevel != 'all') {
          final logLevel = _getLevelFromType(log['type'] ?? '');
          if (logLevel != _selectedLevel) return false;
        }
        
        // User filter
        if (_selectedUser != 'all') {
          final logUser = log['user'] ?? 'system';
          if (logUser.toString() != _selectedUser) return false;
        }
        
        // Search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final description = (log['description'] ?? '').toString().toLowerCase();
          final user = (log['user'] ?? '').toString().toLowerCase();
          final type = (log['type'] ?? '').toString().toLowerCase();
          
          if (!description.contains(query) && !user.contains(query) && !type.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }
  
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      _allLogs.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    await Future.wait([
      _loadLogs(refresh: true),
      _loadStatistics(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }
  
  // ==================== EXPORT FUNCTIONS (MOBILE ONLY) ====================
  Future<void> _exportToExcel() async {
    try {
      _showInfoSnackbar('Menyiapkan data untuk export...');
      
      if (_filteredLogs.isEmpty) {
        _showErrorSnackbar('Tidak ada data untuk diexport');
        return;
      }
      
      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['System_Logs'];
      
      final headers = [
        'No', 'Waktu', 'Tipe', 'Level', 'User', 'User Role',
        'Target User', 'Session ID', 'Deskripsi', 'Data'
      ];
      sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());
      
      for (var i = 0; i < _filteredLogs.length; i++) {
        final log = _filteredLogs[i];
        final timestamp = log['timestamp_local'] as DateTime?;
        
        sheet.appendRow([
          excel.TextCellValue((i + 1).toString()),
          excel.TextCellValue(timestamp != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp) : '-'),
          excel.TextCellValue(log['type'] ?? '-'),
          excel.TextCellValue(_getLevelFromType(log['type'] ?? '')),
          excel.TextCellValue(log['user'] ?? 'system'),
          excel.TextCellValue(log['user_role'] ?? '-'),
          excel.TextCellValue(log['target_user'] ?? '-'),
          excel.TextCellValue(log['session_id'] ?? '-'),
          excel.TextCellValue(log['description'] ?? '-'),
          excel.TextCellValue(log['data'] != null ? log['data'].toString() : '-'),
        ]);
      }
      
      // Mobile only - simpan ke temporary directory dan share
      final dir = await getTemporaryDirectory();
      final fileName = 'System_Logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excelFile.encode()!);
      await Share.shareXFiles([XFile(file.path)], text: 'Data System Logs');
      
      _showSuccessSnackbar('File Excel berhasil dibuat');
    } catch (e) {
      _showErrorSnackbar('Gagal export ke Excel: ${e.toString()}');
    }
  }
  
  Future<void> _exportToPDF() async {
    try {
      _showInfoSnackbar('Menyiapkan PDF...');
      
      final pdf = pw.Document();
      
      pw.Font? ttf;
      pw.Font? boldTtf;
      try {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
        final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        boldTtf = pw.Font.ttf(boldFontData);
      } catch (e) {
        ttf = pw.Font.helvetica();
        boldTtf = pw.Font.helveticaBold();
      }
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Laporan System Logs',
                  style: pw.TextStyle(font: boldTtf, fontSize: 24),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Periode: ${_selectedDateRange != null ? "${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}" : "Semua Waktu"}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Total Data: ${_filteredLogs.length}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Waktu', 'Tipe', 'User', 'Deskripsi'],
              data: List.generate(_filteredLogs.length.clamp(0, 30).toInt(), (index) {
                final log = _filteredLogs[index];
                final timestamp = log['timestamp_local'] as DateTime?;
                return [
                  (index + 1).toString(),
                  timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp) : '-',
                  log['type'] ?? '-',
                  log['user'] ?? 'system',
                  (log['description'] ?? '').length > 50 
                      ? '${log['description'].substring(0, 50)}...' 
                      : (log['description'] ?? '-'),
                ];
              }),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerStyle: pw.TextStyle(font: boldTtf, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
            ),
            pw.SizedBox(height: 30),
            pw.Text('Ringkasan Statistik:', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (var entry in _logStats.entries.take(5))
                        pw.Text('${_logCategories[entry.key] ?? entry.key}: ${entry.value}',
                            style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      
      // Mobile only - simpan ke temporary directory dan share
      final dir = await getTemporaryDirectory();
      final fileName = 'System_Logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan System Logs');
      
      _showSuccessSnackbar('File PDF berhasil dibuat');
    } catch (e) {
      _showErrorSnackbar('Gagal export ke PDF: ${e.toString()}');
    }
  }
  
  Future<void> _clearOldLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Log Lama', style: GoogleFonts.poppins()),
        content: Text(
          'Anda akan menghapus semua log yang berusia lebih dari 30 hari. Tindakan ini tidak dapat dibatalkan. Lanjutkan?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      _showInfoSnackbar('Menghapus log lama...');
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _firestore
          .collection('system_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      _showSuccessSnackbar('Berhasil menghapus ${snapshot.docs.length} log lama');
      await _refreshData();
    } catch (e) {
      _showErrorSnackbar('Gagal menghapus log: $e');
    }
  }
  
  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    if (!isSuperadmin && !isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('System Logs')),
        body: const Center(child: Text('Akses ditolak. Hanya Superadmin.')),
      );
    }
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F9FF),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingIndicator()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: accentBlue,
              backgroundColor: Colors.white,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          _buildHeader(),
                          _buildStatsCards(),
                          _buildCategoryTabs(),
                          _buildFilterBar(),
                          _buildSearchBar(),
                        ],
                      ),
                    ),
                  ),
                  _buildLogsList(),
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'System Logs',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: primaryBlue,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'export_excel') _exportToExcel();
            if (value == 'export_pdf') _exportToPDF();
            if (value == 'clear_old') _clearOldLogs();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'export_excel', child: Text('Export ke Excel')),
            const PopupMenuItem(value: 'export_pdf', child: Text('Export ke PDF')),
            const PopupMenuItem(value: 'clear_old', child: Text('Hapus Log Lama (>30 hari)')),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showDateRangePicker,
      backgroundColor: accentBlue,
      child: const Icon(Icons.date_range, color: Colors.white),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue, const Color(0xFF2A4F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Logs Monitor',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pantau aktivitas sistem, pengguna, lembur, dan absensi',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storage, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  'Total Log: ${_filteredLogs.length}',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Total Log', _allLogs.length, Icons.list, Colors.blue, _allLogs.length),
          const SizedBox(width: 12),
          _buildStatCard('User Activity', _logStats['user'] ?? 0, Icons.people, Colors.green, _logStats['user'] ?? 0),
          const SizedBox(width: 12),
          _buildStatCard('Lembur', _logStats['overtime'] ?? 0, Icons.work_history, Colors.orange, _logStats['overtime'] ?? 0),
          const SizedBox(width: 12),
          _buildStatCard('Absensi', _logStats['absensi'] ?? 0, Icons.camera_alt, Colors.purple, _logStats['absensi'] ?? 0),
          const SizedBox(width: 12),
          _buildStatCard('Error', _logStats['error'] ?? 0, Icons.error, Colors.red, _logStats['error'] ?? 0),
          const SizedBox(width: 12),
          _buildStatCard('Broadcast', _logStats['broadcast'] ?? 0, Icons.campaign, Colors.teal, _logStats['broadcast'] ?? 0),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, int count, IconData icon, Color color, int total) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          Text(title, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
  
  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _logCategories.entries.map((entry) {
          final isSelected = _selectedCategory == entry.key;
          final count = _logStats[entry.key] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_categoryIcons[entry.key] != null)
                    Icon(_categoryIcons[entry.key], size: 14, color: isSelected ? Colors.white : primaryBlue),
                  if (_categoryIcons[entry.key] != null) const SizedBox(width: 4),
                  Text(entry.value, style: GoogleFonts.poppins(fontSize: 12)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white24 : primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count', style: GoogleFonts.poppins(fontSize: 9)),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _selectedCategory = entry.key;
                _applyFilters();
              }),
              backgroundColor: Colors.white,
              selectedColor: primaryBlue,
              checkmarkColor: Colors.white,
              labelStyle: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedLevel,
              decoration: InputDecoration(
                labelText: 'Level',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _levelOptions.map((level) {
                return DropdownMenuItem(
                  value: level['value'] as String,
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: level['color'] as Color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(level['label'] as String, style: GoogleFonts.poppins(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() { _selectedLevel = value!; _applyFilters(); }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedUser,
              decoration: InputDecoration(
                labelText: 'User',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Semua User')),
                ..._topUsers.keys.take(10).map((user) => DropdownMenuItem(value: user, child: Text(user, style: GoogleFonts.poppins(fontSize: 12)))),
              ],
              onChanged: (value) => setState(() { _selectedUser = value!; _applyFilters(); }),
            ),
          ),
          const SizedBox(width: 12),
          if (_selectedDateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 14, color: accentBlue),
                  const SizedBox(width: 4),
                  Text('${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                      style: GoogleFonts.poppins(fontSize: 10, color: accentBlue)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() { _selectedDateRange = null; _refreshData(); }),
                    child: Icon(Icons.close, size: 12, color: accentBlue),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            setState(() { _searchQuery = value; _applyFilters(); });
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari log berdasarkan deskripsi, user, atau tipe...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _searchQuery = ''; _applyFilters(); }); })
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildLogsList() {
    if (_filteredLogs.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }
    
    if (isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildLogGridCard(_filteredLogs[index]),
            childCount: _filteredLogs.length,
          ),
        ),
      );
    }
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildLogCard(_filteredLogs[index]),
        childCount: _filteredLogs.length,
      ),
    );
  }
  
  Widget _buildLogCard(Map<String, dynamic> log) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = _getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;
    final user = log['user'] ?? 'system';
    final description = log['description'] ?? 'No description';
    final targetUser = log['target_user'];
    final sessionId = log['session_id'];
    final category = _getCategoryFromType(type);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showLogDetail(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_categoryIcons[category] ?? Icons.info, color: levelColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(type.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: levelColor)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(level, style: GoogleFonts.poppins(fontSize: 8, color: levelColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(description, style: GoogleFonts.poppins(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timestamp != null ? DateFormat('HH:mm:ss').format(timestamp) : '-', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text(user, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: primaryBlue)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (targetUser != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text('Target: $targetUser', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[600])),
                    ),
                  if (sessionId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text('Session: ${sessionId.substring(0, sessionId.length > 8 ? 8 : sessionId.length)}...', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[600])),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogGridCard(Map<String, dynamic> log) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = _getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;
    final description = log['description'] ?? '';
    final user = log['user'] ?? 'system';
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showLogDetail(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.info, color: levelColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: levelColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(timestamp != null ? DateFormat('HH:mm').format(timestamp) : '-', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: GoogleFonts.poppins(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(user, style: GoogleFonts.poppins(fontSize: 9, color: primaryBlue)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Tidak ada log ditemukan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Coba ubah filter atau cari dengan kata kunci lain', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentBlue)),
          const SizedBox(height: 16),
          Text('Memuat data log...', style: GoogleFonts.poppins(color: Colors.grey[600])),
        ],
      ),
    );
  }
  
  void _showLogDetail(Map<String, dynamic> log) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = _getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.info, color: levelColor, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Text('Detail Log', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue))),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('ID', log['id'] ?? '-'),
                    _buildDetailRow('Tipe', type),
                    _buildDetailRow('Level', level, color: levelColor),
                    _buildDetailRow('Waktu', timestamp != null ? DateFormat('EEEE, dd MMMM yyyy HH:mm:ss', 'id_ID').format(timestamp) : '-'),
                    _buildDetailRow('User', log['user'] ?? 'system'),
                    _buildDetailRow('User Role', log['user_role'] ?? '-'),
                    if (log['target_user'] != null) _buildDetailRow('Target User', log['target_user']),
                    if (log['session_id'] != null) _buildDetailRow('Session ID', log['session_id']),
                    _buildDetailRow('Deskripsi', log['description'] ?? '-', isLong: true),
                    if (log['data'] != null) _buildDetailRow('Data', log['data'].toString(), isLong: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Tutup'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool isLong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: color ?? Colors.black87), maxLines: isLong ? 10 : 3, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
  
  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() { _selectedDateRange = picked; });
      await _refreshData();
    }
  }
  
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
  
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
      backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
  
  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.info, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
      backgroundColor: accentBlue, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}