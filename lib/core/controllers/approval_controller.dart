// lib/features/approval/controllers/approval_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/overtime_approval_service.dart';
import '../../../core/services/overtime_rate_service.dart';

class ApprovalController extends ChangeNotifier {
  // ============ DEPENDENCIES (INJECTED) ============
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final OvertimeApprovalService _approvalService;
  final OvertimeRateService _rateService;

  // ============ CONSTRUCTOR DENGAN DI ============
  ApprovalController({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required OvertimeApprovalService approvalService,
    required OvertimeRateService rateService,
  })  : _auth = auth,
        _firestore = firestore,
        _approvalService = approvalService,
        _rateService = rateService;

  // ============ UI STATE ============
  bool _isLoading = true;
  String? _userId;
  String? _userRole;
  String? _userFungsi;
  String? _userName;
  String? _userEmail;
  String _searchQuery = '';
  String? _fungsiFilter;

  // ============ STATISTICS ============
  int _totalPending = 0;
  int _totalApproved = 0;
  int _totalRejected = 0;
  double _totalBiayaBulanIni = 0;
  double _totalJamBulanIni = 0;
  Map<String, int> _perFungsi = {};

  // ============ UI TAB STATE ============
  int _currentTabIndex = 0;

  // ============ BULK SELECTION STATE ============
  bool _isBulkMode = false;
  final Set<String> _selectedIds = {};
  bool _isSelectAll = false;
  List<Map<String, dynamic>> _allPendingData = [];

  // ============ GETTERS ============
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get userRole => _userRole;
  String? get userFungsi => _userFungsi;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String get searchQuery => _searchQuery;
  String? get fungsiFilter => _fungsiFilter;
  int get totalPending => _totalPending;
  int get totalApproved => _totalApproved;
  int get totalRejected => _totalRejected;
  double get totalBiayaBulanIni => _totalBiayaBulanIni;
  double get totalJamBulanIni => _totalJamBulanIni;
  Map<String, int> get perFungsi => _perFungsi;
  int get currentTabIndex => _currentTabIndex;
  bool get isBulkMode => _isBulkMode;
  Set<String> get selectedIds => _selectedIds;
  bool get isSelectAll => _isSelectAll;
  List<Map<String, dynamic>> get allPendingData => _allPendingData;
  bool get isSuperadmin => _userRole == 'superadmin';
  bool get isManager => _userRole == 'manager';
  
  // Computed getter untuk bulk selection
  int get selectedCount {
    if (_isSelectAll) return _allPendingData.length;
    return _selectedIds.length;
  }

  // ============ INITIALIZATION ============
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadUserData();
      await _loadStatistics();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
    }
    _setLoading(false);
  }

  // ============ REFRESH DATA ============
  Future<void> refresh() async {
    await _loadStatistics();
  }

  // ============ USER DATA LOADING ============
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in');
      return;
    }

    _userId = user.uid;
    _userEmail = user.email;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userRole = data['role']?.toString().toLowerCase();
        _userFungsi = data['fungsi']?.toString().toLowerCase();
        _userName = data['nama_lengkap']?.toString() ?? user.email ?? 'User';
        
        debugPrint('✅ User loaded: $_userName (${_userRole ?? 'unknown role'})');
      } else {
        _userName = user.email ?? 'User';
        debugPrint('⚠️ User document not found, using email as name');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      _userName = user.email ?? 'User';
    }
  }

  // ============ LOAD STATISTICS ============
  Future<void> _loadStatistics() async {
    try {
      if (isSuperadmin) {
        // Load superadmin statistics
        final stats = await _approvalService.getStatisticsForSuperadmin(
          fungsiFilter: _fungsiFilter,
        );
        _updateStats(stats);
      } else if (isManager && _userFungsi != null) {
        // Load manager statistics
        final stats = await _approvalService.getStatisticsForManager(
          _userFungsi!,
        );
        _updateStats(stats);
      } else {
        debugPrint('⚠️ Cannot load statistics: role=$_userRole, fungsi=$_userFungsi');
        _resetStats();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
      _resetStats();
      notifyListeners();
    }
  }

  // Helper: Update statistics from service response
  void _updateStats(Map<String, dynamic> stats) {
    _totalPending = stats['totalPending'] ?? 0;
    _totalApproved = stats['totalApproved'] ?? 0;
    _totalRejected = stats['totalRejected'] ?? 0;
    _totalBiayaBulanIni = (stats['totalEstimasiBiaya'] ?? 0).toDouble();
    _totalJamBulanIni = (stats['totalJamBulanIni'] ?? 0).toDouble();
    _perFungsi = Map<String, int>.from(stats['perFungsi'] ?? {});
  }

  // Helper: Reset statistics to zero
  void _resetStats() {
    _totalPending = 0;
    _totalApproved = 0;
    _totalRejected = 0;
    _totalBiayaBulanIni = 0;
    _totalJamBulanIni = 0;
    _perFungsi = {};
  }

  // ============ SEARCH & FILTER ============
  
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void setFungsiFilter(String? fungsi) {
    _fungsiFilter = (fungsi == 'semua' || fungsi?.isEmpty == true) 
        ? null 
        : fungsi;
    
    // Reset bulk selection when filter changes
    _resetBulkSelection();
    
    // Reload statistics with new filter
    _loadStatistics();
    notifyListeners();
  }

  void clearFilter() {
    _fungsiFilter = null;
    _resetBulkSelection();
    _loadStatistics();
    notifyListeners();
  }

  // ============ TAB CONTROL ============
  
  void setTabIndex(int index) {
    if (_currentTabIndex == index) return;
    
    _currentTabIndex = index;
    
    // Exit bulk mode when switching to non-pending tabs
    if (index != 0) {
      _resetBulkSelection();
    }
    
    notifyListeners();
  }

  // ============ BULK MODE OPERATIONS ============
  
  void toggleBulkMode() {
    _isBulkMode = !_isBulkMode;
    if (!_isBulkMode) {
      _resetBulkSelection();
    }
    notifyListeners();
  }

  void enableBulkMode() {
    if (!_isBulkMode) {
      _isBulkMode = true;
      notifyListeners();
    }
  }

  void disableBulkMode() {
    if (_isBulkMode) {
      _resetBulkSelection();
      notifyListeners();
    }
  }

  void _exitBulkMode() {
    _isBulkMode = false;
    _resetBulkSelection();
  }

  void _resetBulkSelection() {
    _isBulkMode = false;
    _selectedIds.clear();
    _isSelectAll = false;
  }

  // Toggle individual selection
  void toggleSelection(String groupId) {
    if (_selectedIds.contains(groupId)) {
      _selectedIds.remove(groupId);
      _isSelectAll = false; // Deselect all if manually deselecting
    } else {
      _selectedIds.add(groupId);
      
      // Auto select all if all items are manually selected
      if (_selectedIds.length == _allPendingData.length) {
        _isSelectAll = true;
      }
    }
    notifyListeners();
  }

  // Toggle select all
  void toggleSelectAll() {
    if (_isSelectAll) {
      // Deselect all
      _selectedIds.clear();
      _isSelectAll = false;
    } else {
      // Select all
      _selectedIds.addAll(
        _allPendingData.map((d) => d['group_id'] as String)
      );
      _isSelectAll = true;
    }
    notifyListeners();
  }

  // Get list of selected IDs (handles both select all and individual)
  List<String> getSelectedIds() {
    if (_isSelectAll) {
      return _allPendingData
          .map((d) => d['group_id'] as String)
          .toList();
    }
    return _selectedIds.toList();
  }

  // Update all pending data (for bulk mode reference)
  void setAllPendingData(List<Map<String, dynamic>> data) {
    _allPendingData = data;
    
    // If select all was active, update selected IDs
    if (_isSelectAll) {
      _selectedIds.addAll(
        data.map((d) => d['group_id'] as String)
      );
    }
    
    // Note: Don't call notifyListeners here because this is called from StreamBuilder
  }

  // ============ APPROVAL OPERATIONS ============
  
  Future<ApprovalResult> processApproval({
    required String groupId,
    required bool isApprove,
    required String notes,
  }) async {
    try {
      final result = await _approvalService.processApproval(
        groupId: groupId,
        isApprove: isApprove,
        notes: notes,
        userRole: _userRole ?? 'manager',
        userFungsi: _userFungsi,
        approverName: _userName ?? 'Unknown',
        approverEmail: _userEmail,
        approverId: _userId,
      );
      
      // Cleanup selection state
      _selectedIds.remove(groupId);
      _isSelectAll = false;
      
      // Refresh statistics
      await _loadStatistics();
      notifyListeners();
      
      return result;
    } catch (e) {
      debugPrint('❌ Process approval error: $e');
      rethrow;
    }
  }

  // Bulk process approval
  Future<Map<String, dynamic>> bulkProcess({
    required bool isApprove,
    required String notes,
    List<String>? groupIds,
  }) async {
    try {
      // Get IDs to process
      final idsToProcess = groupIds ?? getSelectedIds();
      
      if (idsToProcess.isEmpty) {
        return {
          'totalSuccess': 0,
          'totalFail': 0,
          'successGroups': [],
          'failedGroups': [],
        };
      }
      
      final result = await _approvalService.bulkApproval(
        groupIds: idsToProcess,
        isApprove: isApprove,
        notes: notes,
        approverName: _userName ?? 'Admin',
        approverEmail: _userEmail ?? '',
        approverId: _userId ?? '',
      );
      
      // Cleanup after bulk operation
      _resetBulkSelection();
      
      // Refresh statistics
      await _loadStatistics();
      notifyListeners();
      
      return result;
    } catch (e) {
      debugPrint('❌ Bulk process error: $e');
      rethrow;
    }
  }

  // ============ STREAM GETTERS ============
  
  Stream<List<Map<String, dynamic>>> getPendingStream() {
    if (isSuperadmin) {
      return _approvalService.getApprovalListForSuperadmin(
        status: 'pending',
        fungsiFilter: _fungsiFilter,
      );
    } else if (isManager && _userFungsi != null) {
      return _approvalService.getApprovalListForManager(
        status: 'pending',
        fungsiManager: _userFungsi!,
      );
    }
    // Return empty stream if no valid role
    return Stream.value([]);
  }

  Stream<List<Map<String, dynamic>>> getApprovedStream() {
    if (isSuperadmin) {
      return _approvalService.getApprovalListForSuperadmin(
        status: 'disetujui',
        fungsiFilter: _fungsiFilter,
      );
    } else if (isManager && _userFungsi != null) {
      return _approvalService.getApprovalListForManager(
        status: 'disetujui',
        fungsiManager: _userFungsi!,
      );
    }
    return Stream.value([]);
  }

  Stream<List<Map<String, dynamic>>> getRejectedStream() {
    if (isSuperadmin) {
      return _approvalService.getApprovalListForSuperadmin(
        status: 'ditolak',
        fungsiFilter: _fungsiFilter,
      );
    } else if (isManager && _userFungsi != null) {
      return _approvalService.getApprovalListForManager(
        status: 'ditolak',
        fungsiManager: _userFungsi!,
      );
    }
    return Stream.value([]);
  }

  // ============ DETAIL ============
  
  Future<Map<String, dynamic>?> getDetailPengajuan(String groupId) {
    return _approvalService.getDetailPengajuan(groupId);
  }

  // ============ SPKL ============
  
  Future<Map<String, dynamic>?> getSpkl(String groupId) {
    return _approvalService.getSpkl(groupId);
  }

  Stream<Map<String, dynamic>?> getSpklStream(String groupId) {
    return _approvalService.getSpklStream(groupId);
  }

  Future<String?> previewSpkl(String groupId) {
    return _approvalService.previewSpkl(groupId);
  }

  Future<String?> downloadSpkl(String groupId) {
    return _approvalService.downloadSpkl(groupId);
  }

  // ============ LOGS ============
  
  Stream<List<Map<String, dynamic>>> getApprovalLogs({
    String? fungsiFilter,
    int limit = 50,
  }) {
    return _approvalService.getApprovalLogs(
      fungsiFilter: fungsiFilter ?? _fungsiFilter,
      limit: limit,
    );
  }

  // ============ UTILS ============
  
  String formatRupiahCompact(double amount) {
    return _rateService.formatRupiahCompact(amount);
  }

  String formatRupiah(double amount) {
    return _rateService.formatRupiah(amount);
  }

  // ============ PRIVATE HELPERS ============
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ============ DISPOSE ============
  
  @override
  void dispose() {
    debugPrint('🧹 ApprovalController disposed');
    super.dispose();
  }
}