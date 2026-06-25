// lib/widgets/approval/pending_approval_list.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/services/overtime_approval_service.dart';
import '/widgets/approval/approval_card.dart';

class PendingApprovalList extends StatefulWidget {
  final bool isSuperadmin;
  final String? fungsiFilterSuperadmin;
  final String? userFungsi;
  final String? userRole; // 🔥 TAMBAHAN: Untuk deteksi role user
  final String searchQuery;
  final bool isBulkMode;
  final Set<String> selectedIds;
  final Function(String) onShowDetail;
  final Function(String, bool) onSelectionChanged;
  final Function(List<Map<String, dynamic>>) onDataLoaded;

  // 🔥 Explicit flag untuk HSSE Manager
  final bool isHSSEManagerMode;

  const PendingApprovalList({
    super.key,
    required this.isSuperadmin,
    this.fungsiFilterSuperadmin,
    this.userFungsi,
    this.userRole,
    required this.searchQuery,
    required this.isBulkMode,
    required this.selectedIds,
    required this.onShowDetail,
    required this.onSelectionChanged,
    required this.onDataLoaded,
    this.isHSSEManagerMode = false,
  });

  @override
  State<PendingApprovalList> createState() => _PendingApprovalListState();
}

class _PendingApprovalListState extends State<PendingApprovalList> {
  final _approvalService = OvertimeApprovalService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _lastSearchQuery = '';
  bool _hasLoaded = false;
  bool _isApplyingFilter = false;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color hsseColor = Color(0xFF9C27B0);
  static const Color textSecondary = Color(0xFF64748B);

  // ================================================================
  // 🔥 DETEKSI HSSE MANAGER (DIPERBAIKI)
  //
  // Manager dengan fungsi 'hsse' = HSSE Manager lintas fungsi
  // karena di aplikasi ini, Manager HSSE menggunakan role 'manager'
  // dengan fungsi 'hsse', bukan role khusus 'manager_hsse'.
  // ================================================================
  bool get _isHSSEManager {
    // Prioritas 1: Explicit flag dari parameter
    if (widget.isHSSEManagerMode) {
      debugPrint('🟣 HSSE Manager: via isHSSEManagerMode=true');
      return true;
    }

    // Prioritas 2: Bukan superadmin
    if (widget.isSuperadmin) return false;

    // Prioritas 3: Deteksi dari role & fungsi
    final role = widget.userRole?.toLowerCase() ?? '';
    final fungsi = widget.userFungsi?.toLowerCase() ?? '';

    // 🔥 Manager dengan fungsi 'hsse' = HSSE Manager lintas fungsi
    // (data production: role='manager', fungsi='hsse')
    if (fungsi == 'hsse') {
      debugPrint('🟣 HSSE Manager: via fungsi=hsse (role=$role)');
      return true;
    }

    // 🔥 Role khusus 'manager_hsse' (untuk ke depannya)
    if (role == 'manager_hsse') {
      debugPrint('🟣 HSSE Manager: via role=manager_hsse');
      return true;
    }

    // Kalau fungsi null/empty (fallback, untuk jaga-jaga)
    if (fungsi.isEmpty) {
      debugPrint('🟣 HSSE Manager: via fungsi kosong (fallback)');
      return true;
    }

    debugPrint('🔵 Manager Biasa: role=$role, fungsi=$fungsi');
    return false;
  }

  @override
  void didUpdateWidget(PendingApprovalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _lastSearchQuery = widget.searchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFilter();
      });
    }
  }

  void _applyFilter() {
    if (_isApplyingFilter) return;
    _isApplyingFilter = true;

    if (widget.searchQuery.isEmpty) {
      _filteredData = List.from(_allData);
    } else {
      final query = widget.searchQuery.toLowerCase();
      _filteredData = _allData.where((data) {
        final nama = (data['nama_pengawas'] ?? '').toString().toLowerCase();
        final groupId = (data['group_id'] ?? '').toString().toLowerCase();
        final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
        return nama.contains(query) ||
            groupId.contains(query) ||
            fungsi.contains(query);
      }).toList();
    }

    _isApplyingFilter = false;
    if (mounted) setState(() {});
  }

  // ================================================================
  // 🔥 STREAM SELECTOR (DIPERBAIKI)
  //
  // HSSE Manager (fungsi='hsse') → getHssePendingList() LINTAS FUNGSI
  // Manager biasa → getApprovalListForManager() fungsi sendiri
  // Superadmin → getApprovalListForSuperadmin()
  // ================================================================
  Stream<List<Map<String, dynamic>>> _getStream() {
    // ============================================================
    // SUPERADMIN
    // ============================================================
    if (widget.isSuperadmin) {
      debugPrint('🟠 Superadmin: Query pending dengan filter fungsi');
      return _approvalService.getApprovalListForSuperadmin(
        status: 'pending',
        fungsiFilter: widget.fungsiFilterSuperadmin,
      );
    }

    // ============================================================
    // 🔥 HSSE MANAGER (fungsi='hsse' atau role='manager_hsse')
    //    Gunakan method getHssePendingList() yang sudah include
    //    SEMUA status pending HSSE lintas fungsi:
    //    - 'pending_hsse'
    //    - 'manager_approval_pending_hsse'
    //    - 'manager_approved_pending_hsse' (legacy)
    // ============================================================
    if (_isHSSEManager) {
      debugPrint('🟣 HSSE Manager: getHssePendingList() - LINTAS FUNGSI');
      debugPrint('   → Mencari status: ${OvertimeApprovalService.allPendingHSSEStatuses}');
      return _approvalService.getHssePendingList(
        fungsiFilter: widget.fungsiFilterSuperadmin,
      );
    }

    // ============================================================
    // MANAGER BIASA (fungsi spesifik: operation, lab, dll)
    // ============================================================
    debugPrint('🔵 Manager ${widget.userFungsi}: Query pending fungsi sendiri');
    return _approvalService.getApprovalListForManager(
      status: 'pending',
      fungsiManager: widget.userFungsi ?? '',
    );
  }

  // ================================================================
  // 🔥 MANUAL FALLBACK QUERY (DEBUG)
  //    Kalau method getHssePendingList() masih error, coba query manual
  // ================================================================
  void _debugManualQuery() {
    if (_isHSSEManager) {
      _firestore
          .collection('pengajuan_lembur')
          .where('status', whereIn: [
            'pending_hsse',
            'manager_approval_pending_hsse',
            'manager_approved_pending_hsse',
          ])
          .limit(5)
          .get()
          .then((snapshot) {
        debugPrint('📊 DEBUG: Manual query result: ${snapshot.docs.length} docs');
        for (final doc in snapshot.docs) {
          final data = doc.data();
          debugPrint('   - ${doc.id}: status=${data['status']}, fungsi=${data['pengawas_fungsi']}');
        }
      }).catchError((e) {
        debugPrint('❌ DEBUG: Manual query error: $e');
      });
    }
  }

  bool _listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['group_id'] != b[i]['group_id']) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Debug: coba manual query untuk lihat data yang ada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugManualQuery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_hasLoaded) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isHSSEManager ? hsseColor : primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isHSSEManager ? 'Memuat pengajuan K3...' : 'Memuat pengajuan...',
                  style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('❌ Stream error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.hasData) {
          final newData = snapshot.data!;
          debugPrint('📊 Stream data received: ${newData.length} items');
          if (!_listsEqual(_allData, newData)) {
            _allData = List.from(newData);
            _hasLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _applyFilter();
                widget.onDataLoaded(_allData);
              }
            });
          }
          if (_filteredData.isEmpty && _allData.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applyFilter();
            });
          }
        }

        if (_filteredData.isEmpty && _allData.isEmpty) {
          return _buildEmptyState();
        }

        if (_filteredData.isEmpty && _allData.isNotEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                _isHSSEManager ? hsseColor : primaryColor,
              ),
            ),
          );
        }

        return Column(
          children: [
            if (_isHSSEManager && _filteredData.isNotEmpty) _buildHSSEInfoHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _filteredData.length,
                itemBuilder: (context, index) {
                  final data = _filteredData[index];
                  final groupId = data['group_id'] ?? '';
                  return ApprovalCard(
                    data: data,
                    groupId: groupId,
                    isBulkMode: widget.isBulkMode,
                    isSelected: widget.selectedIds.contains(groupId),
                    onTap: () => widget.onShowDetail(groupId),
                    onSelectionChanged: widget.onSelectionChanged,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // 🔥 HSSE INFO HEADER
  // ================================================================
  Widget _buildHSSEInfoHeader() {
    int flaggedCount = 0;
    int pendingCount = 0;
    int legacyCount = 0;

    // Hitung per fungsi
    Map<String, int> perFungsi = {};

    for (final data in _filteredData) {
      final status = data['status']?.toString() ?? '';
      final fungsi = data['pengawas_fungsi']?.toString() ?? 'unknown';

      if (status == 'pending_hsse') flaggedCount++;
      else if (status == 'manager_approval_pending_hsse') pendingCount++;
      else if (status == 'manager_approved_pending_hsse') legacyCount++;

      perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            hsseColor.withValues(alpha: 0.08),
            hsseColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hsseColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row pertama: Icon + title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hsseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety, color: hsseColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'K3 Lintas Fungsi • ${_filteredData.length} pengajuan',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hsseColor,
                  ),
                ),
              ),
              if (flaggedCount > 0) _buildMiniBadge('K3', flaggedCount, Colors.orange),
              if (pendingCount > 0) _buildMiniBadge('PND', pendingCount, Colors.blue),
              if (legacyCount > 0) _buildMiniBadge('LGC', legacyCount, Colors.grey),
            ],
          ),
          // Row kedua: Breakdown per fungsi
          if (perFungsi.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: perFungsi.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.key.toUpperCase()}: ${entry.value}',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label:$count',
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ================================================================
  // 🔥 ERROR STATE
  // ================================================================
  Widget _buildErrorState(String errorMessage) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.error_outline, size: 32, color: Colors.red.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Data',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _isHSSEManager ? 'Tidak dapat mengambil pengajuan K3.' : 'Tidak dapat mengambil data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
            ),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(errorMessage, textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.red[300])),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _hasLoaded = false;
                _allData = [];
                _filteredData = [];
              }),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Coba Lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isHSSEManager ? hsseColor : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // 🔥 EMPTY STATE
  // ================================================================
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (_isHSSEManager ? hsseColor : primaryColor).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isHSSEManager ? Icons.health_and_safety : Icons.inbox_outlined,
                size: 36,
                color: (_isHSSEManager ? hsseColor : primaryColor).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isHSSEManager ? 'Tidak Ada Pengajuan K3' : 'Tidak Ada Pengajuan',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _isHSSEManager
                  ? 'Semua pengajuan berisiko telah divalidasi.\nData akan muncul saat ada pengajuan baru yang memerlukan review K3.'
                  : 'Semua pengajuan telah diproses.\nData akan muncul saat ada pengajuan baru.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
            if (widget.fungsiFilterSuperadmin != null &&
                widget.fungsiFilterSuperadmin!.isNotEmpty &&
                widget.fungsiFilterSuperadmin != 'semua') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt, size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Filter: ${widget.fungsiFilterSuperadmin!.toUpperCase()}',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}