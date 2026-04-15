import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ==================== MODEL CLASSES ====================

class ReportData {
  final String id;
  final String type;
  final DateTime createdAt;
  final String status;
  final Map<String, dynamic> data;
  
  ReportData({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.status,
    required this.data,
  });
  
  factory ReportData.fromLembur(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportData(
      id: doc.id,
      type: 'lembur',
      createdAt: (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      data: data,
    );
  }
  
  factory ReportData.fromAbsensi(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportData(
      id: doc.id,
      type: 'absensi',
      createdAt: (data['waktu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['absensi_status'] ?? 'completed',
      data: data,
    );
  }
  
  factory ReportData.fromSystemLog(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportData(
      id: doc.id,
      type: 'system_log',
      createdAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: 'completed',
      data: data,
    );
  }
}

class AuditTrail {
  final String id;
  final String action;
  final String user;
  final String userId;
  final String userRole;
  final String targetId;
  final String targetType;
  final Map<String, dynamic> changes;
  final DateTime timestamp;
  
  AuditTrail({
    required this.id,
    required this.action,
    required this.user,
    required this.userId,
    required this.userRole,
    required this.targetId,
    required this.targetType,
    required this.changes,
    required this.timestamp,
  });
  
  factory AuditTrail.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditTrail(
      id: doc.id,
      action: data['action'] ?? 'unknown',
      user: data['user'] ?? 'Unknown',
      userId: data['user_id'] ?? '',
      userRole: data['user_role'] ?? '',
      targetId: data['target_id'] ?? '',
      targetType: data['target_type'] ?? '',
      changes: Map<String, dynamic>.from(data['changes'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ==================== MAIN PAGE ====================

class ReportAuditPage extends StatefulWidget {
  const ReportAuditPage({super.key});

  @override
  State<ReportAuditPage> createState() => _ReportAuditPageState();
}

class _ReportAuditPageState extends State<ReportAuditPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  String _selectedTab = 'laporan';
  String _selectedReportType = 'lembur';
  String _selectedStatus = 'semua';
  String _selectedFungsi = 'semua';
  String _searchQuery = '';
  
  List<ReportData> _reports = [];
  List<AuditTrail> _auditTrails = [];
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _statistics = {};
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<String> _reportTypes = ['lembur', 'absensi', 'system_log'];
  final List<String> _statusOptions = ['semua', 'pending', 'disetujui', 'ditolak'];
  final List<String> _fungsiOptions = ['semua', 'operation', 'lab', 'maintenance', 'hsse', 'gpr', 'bs'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      if (_selectedTab == 'laporan') {
        await _loadReports();
      } else if (_selectedTab == 'audit') {
        await _loadAuditTrails();
      } else if (_selectedTab == 'statistik') {
        await _loadStatistics();
      }
    } catch (e) {
      _showError('Gagal memuat data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadReports() async {
    final List<ReportData> loadedReports = [];
    
    if (_selectedReportType == 'lembur' || _selectedReportType == 'semua') {
      Query query = _firestore.collection('lembur')
          .where('tanggal', isGreaterThanOrEqualTo: _dateRange.start)
          .where('tanggal', isLessThanOrEqualTo: _dateRange.end);
      
      if (_selectedStatus != 'semua') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
      
      if (_selectedFungsi != 'semua') {
        query = query.where('pengawas_fungsi', isEqualTo: _selectedFungsi);
      }
      
      final snapshot = await query.orderBy('tanggal', descending: true).get();
      for (var doc in snapshot.docs) {
        loadedReports.add(ReportData.fromLembur(doc));
      }
    }
    
    if (_selectedReportType == 'absensi' || _selectedReportType == 'semua') {
      Query query = _firestore.collection('absensi')
          .where('waktu', isGreaterThanOrEqualTo: _dateRange.start)
          .where('waktu', isLessThanOrEqualTo: _dateRange.end);
      
      final snapshot = await query.orderBy('waktu', descending: true).get();
      for (var doc in snapshot.docs) {
        loadedReports.add(ReportData.fromAbsensi(doc));
      }
    }
    
    if (_selectedReportType == 'system_log' || _selectedReportType == 'semua') {
      Query query = _firestore.collection('system_logs')
          .where('timestamp', isGreaterThanOrEqualTo: _dateRange.start)
          .where('timestamp', isLessThanOrEqualTo: _dateRange.end);
      
      final snapshot = await query.orderBy('timestamp', descending: true).limit(500).get();
      for (var doc in snapshot.docs) {
        loadedReports.add(ReportData.fromSystemLog(doc));
      }
    }
    
    setState(() {
      _reports = loadedReports;
    });
  }
  
  Future<void> _loadAuditTrails() async {
    final snapshot = await _firestore
        .collection('activity_logs')
        .where('timestamp', isGreaterThanOrEqualTo: _dateRange.start)
        .where('timestamp', isLessThanOrEqualTo: _dateRange.end)
        .orderBy('timestamp', descending: true)
        .limit(500)
        .get();
    
    setState(() {
      _auditTrails = snapshot.docs.map((doc) => AuditTrail.fromFirestore(doc)).toList();
    });
  }
  
  Future<void> _loadStatistics() async {
    final startDate = _dateRange.start;
    final endDate = _dateRange.end;
    
    final lemburSnapshot = await _firestore
        .collection('lembur')
        .where('tanggal', isGreaterThanOrEqualTo: startDate)
        .where('tanggal', isLessThanOrEqualTo: endDate)
        .get();
    
    int totalLembur = lemburSnapshot.docs.length;
    int pendingLembur = lemburSnapshot.docs.where((d) => d['status'] == 'pending').length;
    int approvedLembur = lemburSnapshot.docs.where((d) => d['status'] == 'disetujui').length;
    int rejectedLembur = lemburSnapshot.docs.where((d) => d['status'] == 'ditolak').length;
    
    double totalJamLembur = 0;
    for (var doc in lemburSnapshot.docs) {
      totalJamLembur += (doc['total_jam_desimal'] ?? 0).toDouble();
    }
    
    final absensiSnapshot = await _firestore
        .collection('absensi')
        .where('waktu', isGreaterThanOrEqualTo: startDate)
        .where('waktu', isLessThanOrEqualTo: endDate)
        .get();
    
    int totalAbsensi = absensiSnapshot.docs.length;
    
    final usersSnapshot = await _firestore.collection('users').get();
    int totalUsers = usersSnapshot.docs.length;
    
    setState(() {
      _statistics = {
        'totalReports': totalLembur + totalAbsensi,
        'totalLembur': totalLembur,
        'pendingLembur': pendingLembur,
        'approvedLembur': approvedLembur,
        'rejectedLembur': rejectedLembur,
        'totalJamLembur': totalJamLembur,
        'totalAbsensi': totalAbsensi,
        'totalUsers': totalUsers,
      };
    });
  }
  
  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    
    try {
      final excel.Excel excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Laporan'];
      
      sheet.appendRow([
        excel.TextCellValue('Tipe'),
        excel.TextCellValue('Tanggal'),
        excel.TextCellValue('Status'),
        excel.TextCellValue('User'),
        excel.TextCellValue('Detail')
      ]);
      
      for (var report in _reports) {
        String user = '';
        String detail = '';
        
        if (report.type == 'lembur') {
          user = report.data['nama_mitra']?.toString() ?? '-';
          detail = 'Jam: ${report.data['total_jam'] ?? 0} jam, Alasan: ${report.data['alasan'] ?? '-'}';
        } else if (report.type == 'absensi') {
          user = report.data['user_name']?.toString() ?? '-';
          detail = 'Lokasi: ${report.data['lokasi_nama']?.toString() ?? '-'}';
        } else {
          user = report.data['user']?.toString() ?? '-';
          detail = report.data['description']?.toString() ?? '-';
        }
        
        sheet.appendRow([
          excel.TextCellValue(_getTypeLabel(report.type)),
          excel.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt)),
          excel.TextCellValue(_getStatusLabel(report.status)),
          excel.TextCellValue(user),
          excel.TextCellValue(detail),
        ]);
      }
      
      final bytes = excelFile.encode();
      if (bytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        final path = '${directory.path}/$fileName';
        await File(path).writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: 'Export Laporan');
        _showSuccess('Export berhasil');
      }
    } catch (e) {
      _showError('Gagal export: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }
  
  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Text('LAPORAN SISTEM\n\nPeriode: ${DateFormat('dd MMM yyyy').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}\n\nTotal Laporan: ${_reports.length}'),
            );
          },
        ),
      );
      
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'laporan_audit.pdf');
      _showSuccess('PDF siap dibagikan');
    } catch (e) {
      _showError('Gagal export PDF: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }
  
  Future<void> _approveReport(String reportId) async {
    try {
      await _firestore.collection('lembur').doc(reportId).update({
        'status': 'disetujui',
        'approved_by': _auth.currentUser?.email,
        'approved_at': FieldValue.serverTimestamp(),
      });
      
      _showSuccess('Laporan disetujui');
      _loadData();
    } catch (e) {
      _showError('Gagal approve: $e');
    }
  }
  
  Future<void> _rejectReport(String reportId) async {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Laporan'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Alasan penolakan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('lembur').doc(reportId).update({
                  'status': 'ditolak',
                  'rejected_reason': reasonController.text,
                  'rejected_at': FieldValue.serverTimestamp(),
                });
                _showSuccess('Laporan ditolak');
                _loadData();
              } catch (e) {
                _showError('Gagal tolak: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  String _getTypeLabel(String type) {
    switch (type) {
      case 'lembur': return 'Lembur';
      case 'absensi': return 'Absensi';
      case 'system_log': return 'System Log';
      default: return type;
    }
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      default: return status;
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  void _showDetailDialog(ReportData report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail ${_getTypeLabel(report.type)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${report.id}'),
              Text('Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(report.createdAt)}'),
              Text('Status: ${_getStatusLabel(report.status)}'),
              const Divider(),
              if (report.type == 'lembur') ...[
                Text('Mitra: ${report.data['nama_mitra'] ?? '-'}'),
                Text('Pengawas: ${report.data['nama_pengawas'] ?? '-'}'),
                Text('Jam: ${report.data['jam_mulai'] ?? '-'} - ${report.data['jam_selesai'] ?? '-'}'),
                Text('Alasan: ${report.data['alasan'] ?? '-'}'),
              ],
              if (report.type == 'absensi') ...[
                Text('User: ${report.data['user_name'] ?? '-'}'),
                Text('Lokasi: ${report.data['lokasi_nama'] ?? '-'}'),
              ],
            ],
          ),
        ),
        actions: [
          if (report.status == 'pending' && report.type == 'lembur') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _approveReport(report.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Setujui'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectReport(report.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Tolak'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Laporan & Audit'),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            onSelected: (value) {
              if (value == 'excel') _exportToExcel();
              if (value == 'pdf') _exportToPDF();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'excel', child: Row(
                children: [Icon(Icons.table_chart), SizedBox(width: 8), Text('Export Excel')],
              )),
              const PopupMenuItem(value: 'pdf', child: Row(
                children: [Icon(Icons.picture_as_pdf), SizedBox(width: 8), Text('Export PDF')],
              )),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _selectedTab = index == 0 ? 'laporan' : index == 1 ? 'audit' : 'statistik';
            });
            _loadData();
          },
          tabs: const [
            Tab(text: 'Laporan', icon: Icon(Icons.description)),
            Tab(text: 'Audit Trail', icon: Icon(Icons.history)),
            Tab(text: 'Statistik', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedTab == 'laporan')
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedReportType,
                            decoration: const InputDecoration(
                              labelText: 'Tipe',
                              border: OutlineInputBorder(),
                            ),
                            items: _reportTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(_getTypeLabel(type)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedReportType = value);
                                _loadData();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(_getStatusLabel(status)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedStatus = value);
                                _loadData();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFungsi,
                            decoration: const InputDecoration(
                              labelText: 'Fungsi',
                              border: OutlineInputBorder(),
                            ),
                            items: _fungsiOptions.map((fungsi) {
                              return DropdownMenuItem(
                                value: fungsi,
                                child: Text(fungsi == 'semua' ? 'Semua Fungsi' : fungsi.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedFungsi = value);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedTab == 'laporan'
                          ? _buildReportList()
                          : _selectedTab == 'audit'
                              ? _buildAuditList()
                              : _buildStatisticsView(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildReportList() {
    if (_reports.isEmpty) {
      return const Center(child: Text('Tidak ada data laporan'));
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _showDetailDialog(report),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          report.type == 'lembur' ? Icons.work_history : Icons.checklist,
                          size: 20,
                          color: _getStatusColor(report.status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTypeLabel(report.type),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(report.createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(report.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(report.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.type == 'lembur' 
                        ? (report.data['nama_mitra']?.toString() ?? 'Unknown')
                        : (report.data['user_name']?.toString() ?? 'Unknown'),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.type == 'lembur'
                        ? (report.data['alasan']?.toString() ?? '-')
                        : (report.data['lokasi_nama']?.toString() ?? '-'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (report.status == 'pending' && report.type == 'lembur')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _approveReport(report.id),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Setujui'),
                            style: TextButton.styleFrom(foregroundColor: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _rejectReport(report.id),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Tolak'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAuditList() {
    if (_auditTrails.isEmpty) {
      return const Center(child: Text('Tidak ada data audit trail'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _auditTrails.length,
      itemBuilder: (context, index) {
        final audit = _auditTrails[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.history, size: 20, color: Colors.blue),
            ),
            title: Text(audit.action, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('User: ${audit.user} (${audit.userRole})\nTarget: ${audit.targetId}'),
            trailing: Text(
              DateFormat('dd/MM HH:mm').format(audit.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
  
  Widget _buildStatisticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Laporan', '${_statistics['totalReports'] ?? 0}', Colors.blue, Icons.description)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total User', '${_statistics['totalUsers'] ?? 0}', Colors.green, Icons.people)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Lembur', '${_statistics['totalLembur'] ?? 0}', Colors.orange, Icons.work_history)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total Absensi', '${_statistics['totalAbsensi'] ?? 0}', Colors.purple, Icons.checklist)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Pending', '${_statistics['pendingLembur'] ?? 0}', Colors.orange, Icons.pending_actions)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Disetujui', '${_statistics['approvedLembur'] ?? 0}', Colors.green, Icons.check_circle)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Ditolak', '${_statistics['rejectedLembur'] ?? 0}', Colors.red, Icons.cancel)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Jam Lembur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${(_statistics['totalJamLembur'] ?? 0).toStringAsFixed(1)} jam',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ((_statistics['totalJamLembur'] ?? 0) / 500).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}