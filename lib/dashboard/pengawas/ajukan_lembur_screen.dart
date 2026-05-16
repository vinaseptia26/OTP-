// lib/features/pengawas/lembur/ajukan_lembur_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '/core/services/overtime_service.dart';
import '/core/services/notification_service.dart';
import '/core/services/location_service.dart';
import '/core/services/mitra_limit_service.dart';
import '/widgets/rate_info_card.dart';
import '/widgets/mitra_selection_dialog.dart';

class AjukanLemburPage extends StatefulWidget {
  const AjukanLemburPage({super.key});

  @override
  State<AjukanLemburPage> createState() => _AjukanLemburPageState();
}

class _AjukanLemburPageState extends State<AjukanLemburPage>
    with SingleTickerProviderStateMixin {
  // ===========================================================================
  // SERVICES
  // ===========================================================================
  final OvertimeService _overtimeService = OvertimeService();
  final MitraLimitService _mitraLimitService = MitraLimitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===========================================================================
  // ANIMATION
  // ===========================================================================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ===========================================================================
  // DATA STATE
  // ===========================================================================
  bool isLoading = true;
  Map<String, dynamic>? _overtimeRates;
  List<Map<String, dynamic>> selectedMiras = [];
  List<String> selectedMitraIds = [];

  // ===========================================================================
  // FORM DATA
  // ===========================================================================
  DateTime? tanggalLembur;
  TimeOfDay? jamMulai;
  TimeOfDay? jamSelesai;
  double totalJam = 0.0;
  double totalBiaya = 0.0;
  String urgensi = "normal";
  String? fungsiPengawas;
  String? namaPengawas;
  Map<String, dynamic>? limitInfo;
  bool isOverride = false;

  // ===========================================================================
  // LOCATION DATA
  // ===========================================================================
  String _locationType = 'kantor';
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();

  // ===========================================================================
  // CONTROLLERS & KEYS
  // ===========================================================================
  final alasanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ===========================================================================
  // LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    alasanController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadUserData(), _loadOvertimeRates()]);
    setState(() => isLoading = false);
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          fungsiPengawas = data?['fungsi']?.toString().toLowerCase() ?? '';
          namaPengawas = data?['nama_lengkap'] ?? 'Pengawas';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadOvertimeRates() async {
    _overtimeRates = await _overtimeService.loadOvertimeRates();
  }

  // ===========================================================================
  // CALCULATION METHODS
  // ===========================================================================
  void _recalculateBiaya() {
    if (jamMulai == null ||
        jamSelesai == null ||
        tanggalLembur == null ||
        _overtimeRates == null) return;

    final isWeekend = tanggalLembur!.weekday == DateTime.saturday ||
        tanggalLembur!.weekday == DateTime.sunday;
    final startMinutes = jamMulai!.hour * 60 + jamMulai!.minute;
    final endMinutes = jamSelesai!.hour * 60 + jamSelesai!.minute;
    final diff = endMinutes - startMinutes;

    if (diff > 0) {
      totalJam = diff / 60.0;
      final biayaPerMitra = _overtimeService.calculateOvertimeCost(
        totalHours: totalJam,
        isHoliday: isWeekend,
        rates: _overtimeRates!,
      );
      setState(() {
        totalBiaya = biayaPerMitra * selectedMiras.length;
      });
    }
  }

  bool get _isOutsideRadius {
    if (_selectedLocation == null) return false;
    return LocationService.isOutsideRadius(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  bool _allDataComplete() {
    return selectedMiras.isNotEmpty &&
        tanggalLembur != null &&
        jamMulai != null &&
        jamSelesai != null &&
        _selectedLocation != null &&
        alasanController.text.isNotEmpty &&
        alasanController.text.length >= 20;
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F8FF),
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFF1E88E5)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE3F2FD), Color(0xFFF5F8FF)],
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: _buildForm(),
              ),
            ),
          ),
        ],
      ),
      appBar: _buildAppBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const Text("Pengajuan Lembur",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
          onPressed: () async {
            _overtimeService.clearCache();
            await _loadOvertimeRates();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Tarif lembur diperbarui"),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildProgressIndicator(),
          const SizedBox(height: 20),
          if (_overtimeRates != null) RateInfoCard(rates: _overtimeRates!),
          const SizedBox(height: 20),
          _buildMitraSection(),
          const SizedBox(height: 20),
          _buildWaktuSection(),
          const SizedBox(height: 20),
          _buildLokasiSection(),
          const SizedBox(height: 20),
          _buildAlasanSection(),
          const SizedBox(height: 20),
          _buildUrgensiSection(),
          const SizedBox(height: 30),
          _buildSubmitButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.add_alarm_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Halo, ${namaPengawas ?? 'Pengawas'}",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Ajukan lembur dengan mudah",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    int currentStep = 0;
    if (selectedMiras.isNotEmpty) currentStep = 1;
    if (tanggalLembur != null && jamMulai != null && jamSelesai != null) currentStep = 2;
    if (_selectedLocation != null) currentStep = 3;
    if (_allDataComplete()) currentStep = 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _buildStep(1, "Mitra", currentStep >= 1),
          Expanded(child: Container(height: 3, color: currentStep >= 2 ? const Color(0xFF4CAF50) : Colors.grey.shade300)),
          _buildStep(2, "Waktu", currentStep >= 2),
          Expanded(child: Container(height: 3, color: currentStep >= 3 ? const Color(0xFF4CAF50) : Colors.grey.shade300)),
          _buildStep(3, "Lokasi", currentStep >= 3),
          Expanded(child: Container(height: 3, color: currentStep >= 4 ? const Color(0xFF4CAF50) : Colors.grey.shade300)),
          _buildStep(4, "Selesai", currentStep >= 4),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
            boxShadow: isActive
                ? [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 6)]
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(number.toString(), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? const Color(0xFF2E7D32) : Colors.grey)),
      ],
    );
  }

  // ===========================================================================
  // MITRA SECTION
  // ===========================================================================
  Widget _buildMitraSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.people_alt_rounded, "Pilih Mitra", const Color(0xFF0D47A1)),
          const SizedBox(height: 12),
          if (selectedMiras.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedMiras.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildMitraItem(selectedMiras[index]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(selectedMiras.isEmpty ? "Tambah Mitra" : "Tambah Mitra Lain", style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: fungsiPengawas != null ? _showMitraSelectionDialog : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitraItem(Map<String, dynamic> mitra) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBDEFB)),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getFungsiColor(mitra['fungsi'] ?? ''),
            radius: 20,
            child: Text((mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mitra['nama_lengkap'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                selectedMiras.removeWhere((m) => m['id'] == mitra['id']);
                selectedMitraIds.remove(mitra['id']);
              });
              _recalculateBiaya();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFFEEBEE), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, size: 18, color: Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMitraSelectionDialog() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => MitraSelectionDialog(fungsi: fungsiPengawas!, selectedIds: selectedMitraIds),
    );
    if (result != null && mounted) {
      setState(() {
        selectedMiras = result;
        selectedMitraIds = result.map((m) => m['id'] as String).toList();
      });
      _recalculateBiaya();
    }
  }

  // ===========================================================================
  // WAKTU SECTION
  // ===========================================================================
  Widget _buildWaktuSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.access_time_filled, "Waktu Lembur", const Color(0xFF2E7D32)),
          const SizedBox(height: 12),
          _buildTanggalPicker(),
          if (tanggalLembur != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTimePicker("Jam Mulai", jamMulai, true)),
                const SizedBox(width: 12),
                Expanded(child: _buildTimePicker("Jam Selesai", jamSelesai, false)),
              ],
            ),
          ],
          if (totalJam > 0) _buildTimeSummary(),
        ],
      ),
    );
  }

  Widget _buildTanggalPicker() {
    return InkWell(
      onTap: _pilihTanggal,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: tanggalLembur == null ? const Color(0xFFE2E8F0) : const Color(0xFF1976D2)),
          borderRadius: BorderRadius.circular(14),
          color: tanggalLembur == null ? const Color(0xFFF8FAFF) : Colors.white,
          boxShadow: tanggalLembur != null
              ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.15), blurRadius: 6)]
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 22, color: tanggalLembur == null ? const Color(0xFFA0AEC0) : const Color(0xFF1976D2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tanggalLembur == null ? "Pilih tanggal lembur" : _formatTanggal(tanggalLembur!),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tanggalLembur == null ? const Color(0xFFA0AEC0) : const Color(0xFF212121)),
              ),
            ),
            if (tanggalLembur != null)
              InkWell(
                onTap: () => setState(() { tanggalLembur = null; jamMulai = null; jamSelesai = null; totalJam = 0; totalBiaya = 0; }),
                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFEEBEE)), child: const Icon(Icons.clear, size: 18, color: Color(0xFFD32F2F))),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pilihTanggal() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('id', 'ID'),
    );
    if (selectedDate != null && mounted) {
      setState(() { tanggalLembur = selectedDate; jamMulai = null; jamSelesai = null; totalJam = 0; totalBiaya = 0; });
    }
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, bool isJamMulai) {
    return InkWell(
      onTap: () => _pilihWaktu(isJamMulai),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: time == null ? const Color(0xFFE2E8F0) : const Color(0xFF1976D2)),
          borderRadius: BorderRadius.circular(14),
          color: time == null ? const Color(0xFFF8FAFF) : Colors.white,
          boxShadow: time != null ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.1), blurRadius: 5)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 20, color: time == null ? const Color(0xFFA0AEC0) : const Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    time == null ? "--:--" : _formatTime(time),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: time == null ? const Color(0xFFA0AEC0) : const Color(0xFF212121)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pilihWaktu(bool isJamMulai) async {
    if (tanggalLembur == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih tanggal terlebih dahulu"), behavior: SnackBarBehavior.floating));
      return;
    }
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: isJamMulai ? (jamMulai ?? const TimeOfDay(hour: 7, minute: 0)) : (jamSelesai ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (selectedTime != null && mounted) {
      if (isJamMulai) {
        setState(() => jamMulai = selectedTime);
      } else if (jamMulai != null) {
        final startMinutes = jamMulai!.hour * 60 + jamMulai!.minute;
        final endMinutes = selectedTime.hour * 60 + selectedTime.minute;
        if (endMinutes - startMinutes <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jam selesai harus setelah jam mulai"), behavior: SnackBarBehavior.floating));
          return;
        }
        setState(() => jamSelesai = selectedTime);
        _recalculateBiaya();
      }
    }
  }

  Widget _buildTimeSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.15), blurRadius: 8)],
      ),
      child: Column(
        children: [
          _buildSummaryRow("Durasi Lembur", "${totalJam.toStringAsFixed(1)} jam"),
          if (selectedMiras.isNotEmpty && _overtimeRates != null) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFA5D6A7)),
            const SizedBox(height: 10),
            _buildSummaryRow("Biaya per Mitra", _overtimeService.formatRupiah(selectedMiras.isNotEmpty ? totalBiaya / selectedMiras.length : 0)),
            if (selectedMiras.length > 1) ...[
              const SizedBox(height: 6),
              _buildSummaryRow("Total Biaya", _overtimeService.formatRupiah(totalBiaya), valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32))),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20))),
      ],
    );
  }

  // ===========================================================================
  // LOKASI SECTION
  // ===========================================================================
  Widget _buildLokasiSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.location_on_rounded, "Lokasi Lembur", const Color(0xFF0D47A1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLocationTypeCard(Icons.business_rounded, "Kantor", "PGE Area Kamojang", _locationType == 'kantor', () {
                setState(() {
                  _locationType = 'kantor';
                  _selectedLocation = LatLng(LocationService.kantorLat, LocationService.kantorLng);
                  _selectedAddress = "PGE Area Kamojang";
                  _rtController.clear();
                  _rwController.clear();
                });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildLocationTypeCard(Icons.construction_rounded, "Proyek", "Luar Kantor", _locationType == 'proyek', () {
                setState(() {
                  _locationType = 'proyek';
                  _selectedLocation = null;
                  _selectedAddress = null;
                });
              })),
            ],
          ),
          if (_locationType == 'proyek') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map_rounded),
                label: const Text("Pilih Lokasi dari Peta Satelit", style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                ),
                onPressed: _showMapPicker,
              ),
            ),
            if (_selectedLocation != null) ...[
              const SizedBox(height: 12),
              // Tampilkan alamat lengkap yang sudah didapat dari reverse geocode
              Text("📍 ${_selectedAddress ?? 'Alamat belum didapat'}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: TextFormField(controller: _rtController, decoration: _buildInputDecoration("RT", "001"))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: TextFormField(controller: _rwController, decoration: _buildInputDecoration("RW", "001"))),
                ],
              ),
              const SizedBox(height: 6),
              Text("Tambahkan RT/RW agar alamat lebih spesifik", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
          if (_selectedLocation != null) ...[
            const SizedBox(height: 14),
            _buildRadiusInfo(),
          ],
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  Widget _buildLocationTypeCard(IconData icon, String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)])
              : LinearGradient(colors: [Colors.white, Colors.grey.shade100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFFE0E0E0), width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.3), blurRadius: 10)]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white.withOpacity(0.85) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _isOutsideRadius
            ? const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)])
            : const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(_isOutsideRadius ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: _isOutsideRadius ? Colors.orange : Colors.green, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(_getLokasiInfo(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _isOutsideRadius ? Colors.orange.shade800 : Colors.green.shade800))),
        ],
      ),
    );
  }

  String _getLokasiInfo() {
    if (_selectedLocation == null) return "Belum dipilih";
    final isOutside = LocationService.isOutsideRadius(_selectedLocation!.latitude, _selectedLocation!.longitude);
    final distance = LocationService.calculateDistance(LocationService.kantorLat, LocationService.kantorLng, _selectedLocation!.latitude, _selectedLocation!.longitude);
    String alamatLengkap = _selectedAddress ?? "";
    if (_locationType == 'proyek') {
      if (_rtController.text.isNotEmpty) alamatLengkap += " RT ${_rtController.text}";
      if (_rwController.text.isNotEmpty) alamatLengkap += " RW ${_rwController.text}";
    }
    if (isOutside) {
      return "⚠️ Di luar radius (${(distance / 1000).toStringAsFixed(1)} km)\n$alamatLengkap";
    } else {
      return "✅ Dalam radius kantor\n$alamatLengkap";
    }
  }

  // ===========================================================================
  // PETA SATELIT (DENGAN SEARCH, REVERSE GEOCODE, ZOOM, PAN)
  // ===========================================================================
  Future<void> _showMapPicker() async {
    final initialLat = _selectedLocation?.latitude ?? LocationService.kantorLat;
    final initialLng = _selectedLocation?.longitude ?? LocationService.kantorLng;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MapPickerDialog(initialLat: initialLat, initialLng: initialLng),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(result['lat'], result['lng']);
        _selectedAddress = result['address'] ?? 'Lokasi dipilih dari peta';
      });
    }
  }

  // ===========================================================================
  // ALASAN SECTION
  // ===========================================================================
  Widget _buildAlasanSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.description_rounded, "Alasan Lembur", const Color(0xFF0D47A1)),
          const SizedBox(height: 12),
          TextFormField(
            controller: alasanController,
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Jelaskan alasan lembur secara detail...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2)),
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Alasan wajib diisi";
              if (value.length < 20) return "Minimal 20 karakter";
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text("${alasanController.text.length}/500 karakter",
                style: TextStyle(fontSize: 11, color: alasanController.text.length >= 20 ? Colors.green : Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // URGENSI SECTION
  // ===========================================================================
  Widget _buildUrgensiSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.priority_high_rounded, "Tingkat Urgensi", const Color(0xFFE65100)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildUrgensiChip("Normal", "normal", Icons.info_outline_rounded, Colors.blue),
              const SizedBox(width: 10),
              _buildUrgensiChip("Tinggi", "tinggi", Icons.warning_amber_rounded, Colors.orange),
              const SizedBox(width: 10),
              _buildUrgensiChip("Kritis", "kritis", Icons.report_rounded, Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: urgensi == "tinggi" ? Colors.orange.shade50 : urgensi == "kritis" ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              urgensi == "tinggi"
                  ? "⚠️ Pengajuan akan ditandai prioritas tinggi di Manager"
                  : urgensi == "kritis"
                      ? "🚨 Pengajuan kritis — memerlukan persetujuan segera"
                      : "Pengajuan reguler tanpa prioritas khusus",
              style: TextStyle(fontSize: 13, color: urgensi == "tinggi" ? Colors.orange.shade800 : urgensi == "kritis" ? Colors.red.shade800 : Colors.grey.shade700, fontStyle: urgensi != "normal" ? FontStyle.italic : FontStyle.normal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgensiChip(String label, String value, IconData icon, Color baseColor) {
    final isSelected = urgensi == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => urgensi = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: [baseColor.withOpacity(0.2), baseColor.withOpacity(0.05)]) : null,
            color: isSelected ? null : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? baseColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: isSelected ? baseColor : Colors.grey),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? baseColor : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUBMIT BUTTON
  // ===========================================================================
  Widget _buildSubmitButton() {
    final isComplete = _allDataComplete();
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isComplete
            ? const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)])
            : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500]),
        boxShadow: isComplete ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))] : null,
      ),
      child: ElevatedButton(
        onPressed: isComplete ? _submit : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        child: const Text("AJUKAN LEMBUR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white)),
      ),
    );
  }

  // ===========================================================================
  // SUBMIT LOGIC (tidak berubah)
  // ===========================================================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi semua data dengan benar"), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      return;
    }
    if (!_allDataComplete()) {
      String missingField = "";
      if (selectedMiras.isEmpty) missingField = "Pilih mitra terlebih dahulu";
      else if (tanggalLembur == null) missingField = "Pilih tanggal lembur";
      else if (jamMulai == null || jamSelesai == null) missingField = "Pilih waktu lembur";
      else if (_selectedLocation == null) missingField = "Pilih lokasi lembur";
      else if (alasanController.text.isEmpty) missingField = "Isi alasan lembur";
      else if (alasanController.text.length < 20) missingField = "Alasan minimal 20 karakter";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(missingField), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      return;
    }

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    bool hasLimitExceeded = false;
    final limitResults = <String, dynamic>{};
    for (final mitra in selectedMiras) {
      final result = await _mitraLimitService.checkMitraLimit(mitraId: mitra['id'], tanggal: tanggalLembur!, tambahanJam: totalJam);
      limitResults[mitra['id']] = result;
      if (result['is_exceeded']) hasLimitExceeded = true;
    }
    if (hasLimitExceeded) {
      final confirmed = await _showLimitWarningDialog(limitResults);
      if (!confirmed) return;
      setState(() => isOverride = true);
    }
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    _showLoadingDialog();
    try {
      await _saveOvertimeData(hasLimitExceeded, groupId);
      await _sendNotification(groupId);
      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(groupId);
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan: ${e.toString()}"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF1976D2)),
              SizedBox(height: 16),
              Text("Menyimpan data pengajuan...", style: TextStyle(fontSize: 14)),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _saveOvertimeData(bool hasLimitExceeded, String groupId) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || tanggalLembur!.weekday == DateTime.sunday;
    final isOutside = LocationService.isOutsideRadius(_selectedLocation!.latitude, _selectedLocation!.longitude);
    String alamatLengkap = _selectedAddress ?? '';
    if (_locationType == 'proyek') {
      if (_rtController.text.trim().isNotEmpty) alamatLengkap += ' RT ${_rtController.text.trim()}';
      if (_rwController.text.trim().isNotEmpty) alamatLengkap += ' RW ${_rwController.text.trim()}';
    }

    final pengajuanRef = _firestore.collection('pengajuan_lembur').doc(groupId);
    batch.set(pengajuanRef, {
      'group_id': groupId, 'tipe_dokumen': 'pengajuan', 'status': 'pending',
      'created_at': now, 'updated_at': now,
      'pengawas_id': _auth.currentUser?.uid, 'nama_pengawas': namaPengawas, 'pengawas_fungsi': fungsiPengawas,
      'tanggal_lembur': Timestamp.fromDate(tanggalLembur!), 'tahun_bulan': DateFormat('yyyy-MM').format(tanggalLembur!),
      'jam_mulai': _formatTime(jamMulai!), 'jam_selesai': _formatTime(jamSelesai!), 'total_jam_desimal': totalJam,
      'jenis_lembur': isWeekend ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude, 'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap, 'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside, 'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_total': totalBiaya, 'rate_snapshot': _overtimeRates,
      'total_mitra': selectedMiras.length, 'mitra_ids': selectedMitraIds,
      'detail_mitra': selectedMiras.map((m) => {'id': m['id'], 'nama': m['nama_lengkap'], 'fungsi': m['fungsi']}).toList(),
      'urgensi': urgensi, 'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded, 'is_multiple': selectedMiras.length > 1,
    });

    final baseMitraData = {
      'group_id': groupId, 'pengajuan_id': groupId, 'tipe_dokumen': 'lembur_mitra',
      'pengawas_id': _auth.currentUser?.uid, 'pengawas_fungsi': fungsiPengawas,
      'diajukan_oleh_id': _auth.currentUser?.uid, 'diajukan_oleh_nama': namaPengawas,
      'tanggal': Timestamp.fromDate(tanggalLembur!), 'tahun_bulan': DateFormat('yyyy-MM').format(tanggalLembur!),
      'jam_mulai': _formatTime(jamMulai!), 'jam_selesai': _formatTime(jamSelesai!), 'total_jam_desimal': totalJam,
      'jenis_lembur': isWeekend ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude, 'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap, 'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside, 'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_per_mitra': selectedMiras.isNotEmpty ? totalBiaya / selectedMiras.length : 0,
      'rate_snapshot': _overtimeRates, 'status': 'pending', 'absensi_status': 'belum_absen',
      'urgensi': urgensi, 'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded, 'created_at': now, 'updated_at': now,
    };

    for (final mitra in selectedMiras) {
      final docRef = _firestore.collection('lembur_mitra').doc('${groupId}_${mitra['id']}');
      batch.set(docRef, {
        ...baseMitraData,
        'mitra_id': mitra['id'], 'user_id': mitra['id'],
        'nama_mitra': mitra['nama_lengkap'], 'fungsi_mitra': mitra['fungsi'],
      });
    }
    await batch.commit();
  }

  Future<void> _sendNotification(String groupId) async {
    try {
      final isOutside = LocationService.isOutsideRadius(_selectedLocation!.latitude, _selectedLocation!.longitude);
      await NotificationService().sendManagerNotification(
        pengawasNama: namaPengawas ?? 'Pengawas', fungsi: fungsiPengawas ?? '',
        jumlahMitra: selectedMiras.length, tanggal: tanggalLembur!,
        totalBiaya: totalBiaya, urgensi: urgensi, isOutsideRadius: isOutside,
        lemburIds: [groupId], overtimeRates: _overtimeRates!,
      );
    } catch (e) { debugPrint('⚠️ Gagal kirim notifikasi: $e'); }
  }

  void _showSuccessDialog(String groupId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          SizedBox(height: 12),
          Text("Berhasil!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Pengajuan lembur berhasil dikirim."),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Text("ID Pengajuan: ${groupId.substring(0, 8)}...", style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(height: 8),
          Text("${selectedMiras.length} mitra telah didaftarkan", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("SELESAI"),
          )
        ],
      ),
    );
  }

  Future<bool> _showLimitWarningDialog(Map<String, dynamic> limitResults) async {
    final mitraOver = <String>[];
    limitResults.forEach((mitraId, info) {
      if (info['is_exceeded']) {
        final mitra = selectedMiras.firstWhere((m) => m['id'] == mitraId);
        mitraOver.add("• ${mitra['nama_lengkap']}: ${info['total_jam_bulan_ini'].toStringAsFixed(1)} jam + ${info['tambahan_jam'].toStringAsFixed(1)} jam");
      }
    });
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange, size: 28), SizedBox(width: 12), Text("Melebihi Batas Lembur")]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Beberapa mitra akan melebihi batas maksimal 60 jam/bulan:"),
          const SizedBox(height: 8),
          ...mitraOver.map((m) => Padding(padding: const EdgeInsets.only(left: 8, bottom: 4), child: Text(m, style: const TextStyle(fontSize: 13)))),
          const SizedBox(height: 12),
          const Text("Pengajuan akan ditandai sebagai KRITIS dan memerlukan persetujuan khusus.", style: TextStyle(fontSize: 12, color: Colors.orange)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("BATAL")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text("TETAP AJUKAN")),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showConfirmationDialog() async {
    final isWeekend = tanggalLembur!.weekday == DateTime.saturday || tanggalLembur!.weekday == DateTime.sunday;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Pengajuan", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildConfirmRow("👤 Pengawas", namaPengawas ?? '-'),
          _buildConfirmRow("👥 Mitra", "${selectedMiras.length} orang"),
          _buildConfirmRow("📅 Tanggal", _formatTanggal(tanggalLembur!)),
          _buildConfirmRow("📆 Jenis", isWeekend ? "Hari Libur" : "Hari Kerja"),
          _buildConfirmRow("⏰ Waktu", "${_formatTime(jamMulai!)} - ${_formatTime(jamSelesai!)}"),
          _buildConfirmRow("⏱️ Durasi", "${totalJam.toStringAsFixed(1)} jam"),
          _buildConfirmRow("💰 Total Biaya", _overtimeService.formatRupiah(totalBiaya)),
          _buildConfirmRow("⚡ Urgensi", urgensi.toUpperCase()),
          const Divider(height: 20),
          const Text("Apakah data sudah benar?", style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("PERIKSA KEMBALI")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)), child: const Text("YA, AJUKAN")),
        ],
      ),
    ) ?? false;
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))],
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
      ],
    );
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'lab': return const Color(0xFF4CAF50);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF607D8B);
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTanggal(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ===========================================================================
// WIDGET DIALOG PETA SATELIT (SEARCH, PAN, ZOOM, REVERSE GEOCODE, CROSSHAIR)
// ===========================================================================
class _MapPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  const _MapPickerDialog({required this.initialLat, required this.initialLng});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  LatLng? _pickedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _pickedLocation = LatLng(widget.initialLat, widget.initialLng);
    _updateAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateAddress() async {
    if (_pickedLocation == null) return;
    try {
      final result = await LocationService.reverseGeocode(
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = result != null ? result['address'] : _formatCoordinate(_pickedLocation!);
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  String _formatCoordinate(LatLng pos) =>
      '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';

  Future<void> _searchAndGo(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await LocationService.searchLocation(query);
      if (results != null && results.isNotEmpty) {
        final first = results.first;
        final lat = first['lat'] as double;
        final lng = first['lng'] as double;
        final newPos = LatLng(lat, lng);
        setState(() {
          _pickedLocation = newPos;
        });
        _mapController.move(newPos, 18.0);
        _updateAddress();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi tidak ditemukan')),
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal cari lokasi: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Lokasi Proyek", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          TextButton(
            onPressed: () {
              // Pastikan alamat terbaru sudah ada
              Navigator.pop(context, {
                'lat': _pickedLocation!.latitude,
                'lng': _pickedLocation!.longitude,
                'address': _currentAddress.isNotEmpty ? _currentAddress : _formatCoordinate(_pickedLocation!),
              });
            },
            child: const Text("PILIH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari alamat...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: _searchAndGo,
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          // Peta dengan crosshair, tombol zoom, dan alamat
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pickedLocation!,
                    initialZoom: 18.0,
                    maxZoom: 19.0,
                    minZoom: 3.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ), // izinkan semua gestur (pan, zoom, dll)
                    onTap: (_, latLng) {
                      setState(() => _pickedLocation = latLng);
                      _updateAddress();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.pge.overtimeapp',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: _pickedLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
                      )
                    ]),
                  ],
                ),
                // Crosshair tidak menghalangi sentuhan
                const IgnorePointer(
                  child: Center(
                    child: Icon(Icons.add, color: Colors.red, size: 40),
                  ),
                ),
                // Tombol zoom manual
                Positioned(
                  right: 12,
                  bottom: 100,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.black),
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          if (currentZoom < 19) {
                            _mapController.move(_mapController.camera.center, currentZoom + 1);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.black),
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          if (currentZoom > 3) {
                            _mapController.move(_mapController.camera.center, currentZoom - 1);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Alamat dan petunjuk geser
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Geser peta dan tap untuk memilih lokasi",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          _currentAddress.isNotEmpty ? _currentAddress : _formatCoordinate(_pickedLocation!),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}