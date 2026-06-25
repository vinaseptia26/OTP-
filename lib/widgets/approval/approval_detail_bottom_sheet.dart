// lib/widgets/approval/manager/approval_detail_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/services/overtime_rate_service.dart';

class ApprovalDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> mitraList;
  final bool isDarkMode;
  final String userRole;
  final String userName;
  final bool isManager;
  final bool isSuperadmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onPreviewSpkl;

  const ApprovalDetailBottomSheet({
    super.key,
    required this.data,
    required this.mitraList,
    required this.isDarkMode,
    required this.userRole,
    required this.userName,
    required this.isManager,
    required this.isSuperadmin,
    required this.onApprove,
    required this.onReject,
    this.onPreviewSpkl,
  });

  @override
  State<ApprovalDetailBottomSheet> createState() => _ApprovalDetailBottomSheetState();
}

class _ApprovalDetailBottomSheetState extends State<ApprovalDetailBottomSheet> {
  // 🔥 STATIC CACHE - Dibuat sekali, dipakai selamanya
  static final _rateService = OvertimeRateService();
  static final Map<String, String> _fungsiLabelCache = {};

  // 🔥 STATE UNTUK DATA PENGAWAS
  Map<String, dynamic>? _pengawasData;
  bool _isLoadingPengawas = true;

  @override
  void initState() {
    super.initState();
    _loadPengawasData();
  }

  // 🔥 AMBIL DATA PENGAWAS DARI COLLECTION USERS
  Future<void> _loadPengawasData() async {
    try {
      final pengawasId = widget.data['pengawas_id']?.toString() ?? '';
      
      if (pengawasId.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingPengawas = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(pengawasId)
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists && doc.data() != null) {
            _pengawasData = doc.data()!;
          }
          _isLoadingPengawas = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading pengawas data: $e');
      if (mounted) {
        setState(() => _isLoadingPengawas = false);
      }
    }
  }

  // ✅ HELPER: Parse tanggal (support DateTime & Timestamp)
  DateTime _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Gunakan static _rateService, bukan buat baru
    final status = widget.data['status'] ?? 'pending';
    final isPending = status == 'pending';
    final urgensi = widget.data['urgensi'] ?? 'normal';
    final isOverride = widget.data['is_override'] ?? false;
    final isWeekend = widget.data['jenis_lembur'] == 'hari_libur';

    final lokasiData = widget.data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;

    final totalMitra = widget.data['total_mitra'] ?? 1;
    final biayaTotal = (widget.data['estimasi_biaya_total'] ?? 0).toDouble();
    final biayaPerMitra = widget.mitraList.isNotEmpty ? biayaTotal / widget.mitraList.length : 0.0;
    final canApprove = isPending && (widget.isManager || widget.isSuperadmin);

    // 🔥 Cache MediaQuery height
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Header
          _buildHeader(status, urgensi, isWeekend, isOverride, isOutside),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informasi Pengawas
                  _buildInfoCard(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Informasi Pengawas',
                    children: [
                      _buildInfoRow('Nama', _pengawasData?['nama_lengkap'] ?? widget.data['nama_pengawas'] ?? '-'),
                      _buildInfoRow('Fungsi', _getFungsiLabelCached(widget.data['pengawas_fungsi'])),
                      _buildInfoRow(
                        'Email',
                        _isLoadingPengawas 
                            ? 'Memuat...' 
                            : _pengawasData?['email'] ?? '-',
                      ),
                      if (_pengawasData?['phone'] != null && _pengawasData!['phone'].toString().isNotEmpty)
                        _buildInfoRow('No. HP', _pengawasData!['phone']),
                      if (_pengawasData?['nip'] != null && _pengawasData!['nip'].toString().isNotEmpty)
                        _buildInfoRow('NIP', _pengawasData!['nip']),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Waktu Lembur
                  _buildInfoCard(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Waktu Lembur',
                    children: [
                      _buildInfoRow(
                        'Tanggal',
                        widget.data['tanggal'] != null 
                            ? DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_toDate(widget.data['tanggal'])) // ✅ FIX
                            : '-',
                      ),
                      _buildInfoRow('Jam', '${widget.data['jam_mulai']} - ${widget.data['jam_selesai']}'),
                      _buildInfoRow(
                        'Durasi',
                        '${(widget.data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                        isBold: true,
                        valueColor: const Color(0xFF6366F1),
                      ),
                      _buildInfoRow('Jenis', isWeekend ? 'Hari Libur' : 'Hari Kerja'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lokasi
                  if (lokasiMap.isNotEmpty) ...[
                    _buildLokasiCard(lokasiMap),
                    const SizedBox(height: 12),
                  ],

                  // Estimasi Biaya
                  _buildBiayaCard(totalMitra, biayaPerMitra, biayaTotal),
                  const SizedBox(height: 12),

                  // Alasan
                  _buildInfoCard(
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Alasan Lembur',
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.data['alasan'] ?? '-',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Catatan Tambahan
                  if (widget.data['catatan_tambahan'] != null && widget.data['catatan_tambahan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.note_add_rounded,
                      iconColor: Colors.amber,
                      title: 'Catatan Tambahan',
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            widget.data['catatan_tambahan'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Daftar Mitra
                  if (widget.mitraList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMitraCard(),
                  ],

                  // SPKL
                  if (widget.data['spkl_nomor'] != null && !isPending) ...[
                    const SizedBox(height: 12),
                    _buildSpklCard(),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action Buttons
          if (canApprove) _buildActionButtons(),
        ],
      ),
    );
  }

  // ============== HEADER ==============
  Widget _buildHeader(String status, String urgensi, bool isWeekend, bool isOverride, bool isOutside) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Pengajuan',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.tag, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${(widget.data['group_id'] ?? '').toString().substring(0, 10)}...',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Icons
              if (widget.onPreviewSpkl != null && status != 'pending')
                _buildHeaderAction(
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.blue,
                  onTap: widget.onPreviewSpkl,
                ),
              _buildHeaderAction(
                icon: Icons.close_rounded,
                color: Colors.grey[600]!,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildStatusBadge(_getStatusLabel(status), _getStatusColor(status)),
              _buildStatusBadge(urgensi.toUpperCase(), _getUrgensiColor(urgensi)),
              if (isWeekend) _buildStatusBadge('HARI LIBUR', Colors.purple),
              if (isOverride) _buildStatusBadge('OVERRIDE', Colors.orange),
              if (isOutside) _buildStatusBadge('LUAR RADIUS', Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({required IconData icon, required Color color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ============== INFO CARD ==============
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor ?? (widget.isDarkMode ? Colors.white : const Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== LOKASI CARD ==============
  Widget _buildLokasiCard(Map<String, dynamic> lokasi) {
    String alamat = lokasi['alamat'] ?? '';
    final rt = lokasi['rt'] ?? '';
    final rw = lokasi['rw'] ?? '';
    if (rt.toString().isNotEmpty) alamat += ' RT $rt';
    if (rw.toString().isNotEmpty) alamat += ' RW $rw';
    final isOutside = lokasi['is_outside_radius'] == true;
    final lat = lokasi['latitude'];
    final lng = lokasi['longitude'];
    final hasCoordinates = lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Lokasi Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              _buildRadiusBadge(isOutside),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alamat.isNotEmpty ? alamat : 'Tidak diketahui',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (hasCoordinates) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.pin_drop_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${(lat as num).toDouble().toStringAsFixed(6)}, ${(lng as num).toDouble().toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showLokasiOnMap(context, (lat).toDouble(), (lng).toDouble(), alamat),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_rounded, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(
                            'Peta',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadiusBadge(bool isOutside) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutside 
            ? Colors.orange.withValues(alpha: 0.1) 
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutside 
              ? Colors.orange.withValues(alpha: 0.3) 
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOutside ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            size: 12,
            color: isOutside ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            isOutside ? 'LUAR' : 'DALAM',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isOutside ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ============== BIAYA CARD ==============
  Widget _buildBiayaCard(int totalMitra, double biayaPerMitra, double biayaTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Estimasi Biaya',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCostRow('Per Mitra', _rateService.formatRupiah(biayaPerMitra)),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 8),
          _buildCostRow('Total ($totalMitra mitra)', _rateService.formatRupiah(biayaTotal), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 13 : 12,
            color: Colors.white.withValues(alpha: isTotal ? 1.0 : 0.8),
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.w700,
            color: isTotal ? const Color(0xFFFCD34D) : Colors.white,
          ),
        ),
      ],
    );
  }

  // ============== MITRA CARD ==============
  Widget _buildMitraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Daftar Mitra',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.mitraList.length} orang',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMitraTable(),
        ],
      ),
    );
  }

  Widget _buildMitraTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            _tableCellHeader('Nama'),
            _tableCellHeader('Fungsi'),
            _tableCellHeader('Biaya', textAlign: TextAlign.end),
          ],
        ),
        ...widget.mitraList.map((mitra) {
          final biaya = (mitra['estimasi_biaya_per_mitra'] ?? mitra['estimasi_biaya'] ?? 0).toDouble();
          return TableRow(
            children: [
              _tableCell(mitra['nama_mitra'] ?? '-', isBold: true),
              _tableCell(_getFungsiLabelCached(mitra['fungsi_mitra'])),
              _tableCell(
                _rateService.formatRupiah(biaya),
                textAlign: TextAlign.end,
                isBold: true,
                textColor: const Color(0xFF10B981),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableCellHeader(String text, {TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: widget.isDarkMode ? Colors.grey[300] : const Color(0xFF64748B),
        ),
        textAlign: textAlign,
      ),
    );
  }

  Widget _tableCell(String text, {bool isBold = false, Color? textColor, TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: textColor ?? (widget.isDarkMode ? Colors.white70 : const Color(0xFF334155)),
        ),
        textAlign: textAlign,
      ),
    );
  }

  // ============== SPKL CARD ==============
  Widget _buildSpklCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPKL',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data['spkl_nomor'] ?? '-',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onPreviewSpkl != null)
            ElevatedButton.icon(
              onPressed: widget.onPreviewSpkl,
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: const Text('Lihat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============== ACTION BUTTONS ==============
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Tolak',
                icon: Icons.close_rounded,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEF4444),
                borderColor: const Color(0xFFEF4444),
                onPressed: widget.onReject,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildActionButton(
                label: 'Setujui Pengajuan',
                icon: Icons.check_rounded,
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                onPressed: widget.onApprove,
                hasShadow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
    bool hasShadow = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
            boxShadow: hasShadow
                ? [BoxShadow(color: backgroundColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: foregroundColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============== STATUS BADGE ==============
  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  // ============== MAP DIALOG ==============
  void _showLokasiOnMap(BuildContext context, double lat, double lng, String alamat) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildMapHeader(alamat, lat, lng, ctx),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 18.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.pge.overtimeapp',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 120,
                          height: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Text('📍 Lokasi Lembur', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              ),
                              Container(width: 2, height: 4, color: Colors.red.withValues(alpha: 0.5)),
                              const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 32, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildMapBottomBar(ctx, lat, lng, alamat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapHeader(String alamat, double lat, double lng, BuildContext dialogContext) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lokasi Lembur', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                if (alamat.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(alamat, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(dialogContext),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBottomBar(BuildContext dialogContext, double lat, double lng, String alamat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Zoom in/out untuk melihat detail area sekitar', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(dialogContext);
                _showLokasiOnMap(context, lat, lng, alamat);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.center_focus_strong_rounded, size: 14, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text('Reset', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER: Parse tanggal (support DateTime & Timestamp) ==============
  

  // ============== HELPER METHODS (CACHED) ==============
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_bottom_rounded;
      case 'disetujui': return Icons.check_circle_rounded;
      case 'ditolak': return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'disetujui': return const Color(0xFF10B981);
      case 'ditolak': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      default: return s;
    }
  }

  Color _getUrgensiColor(String s) {
    switch (s) {
      case 'normal': return Colors.blue;
      case 'tinggi': return Colors.orange;
      case 'kritis': return const Color(0xFFEF4444);
      default: return Colors.blue;
    }
  }

  // 🔥 CACHED VERSION
  String _getFungsiLabelCached(String? f) {
    final key = f?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}