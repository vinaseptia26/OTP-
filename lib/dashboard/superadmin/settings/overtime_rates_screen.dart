// FILE: lib/dashboard/superadmin/settings/overtime_rates_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class OvertimeRatesScreen extends StatefulWidget {
  const OvertimeRatesScreen({super.key});

  @override
  State<OvertimeRatesScreen> createState() => _OvertimeRatesScreenState();
}

class _OvertimeRatesScreenState extends State<OvertimeRatesScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Data
  bool isLoading = true;
  bool isSaving = false;
  bool isDarkMode = false;

  // Default gaji untuk perhitungan
  final double defaultGaji = 3000000;
  
  // Hasil perhitungan
  late double upahPerJam;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _gajiController = TextEditingController();
  
  // Tarif lembur
  late OvertimeRate weekdayRate;
  late OvertimeRate holidayRate;
  
  // Riwayat perubahan
  List<RateHistory> rateHistory = [];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _initializeDefaultRates();
    _loadRatesFromFirestore();
  }

  void _initializeDefaultRates() {
    upahPerJam = defaultGaji / 173;
    
    weekdayRate = OvertimeRate(
      id: 'weekday',
      name: 'Lembur Hari Kerja',
      description: 'Senin - Jumat',
      baseRate: upahPerJam,
      firstHourMultiplier: 1.5,
      nextHoursMultiplier: 2.0,
      icon: Icons.business_center,
      color: const Color(0xFF2196F3),
    );

    holidayRate = OvertimeRate(
      id: 'holiday',
      name: 'Lembur Hari Libur',
      description: 'Sabtu, Minggu & Tanggal Merah',
      baseRate: upahPerJam,
      first8HoursMultiplier: 2.0,
      ninthHourMultiplier: 3.0,
      tenthPlusMultiplier: 4.0,
      icon: Icons.celebration,
      color: const Color(0xFF4CAF50),
    );

    _gajiController.text = NumberFormat('#,###').format(defaultGaji);
  }

  Future<void> _loadRatesFromFirestore() async {
    setState(() => isLoading = true);

    try {
      final docSnapshot = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        
        if (data['base_salary'] != null) {
          final gaji = (data['base_salary'] as num).toDouble();
          _gajiController.text = NumberFormat('#,###').format(gaji);
          upahPerJam = gaji / 173;
        }

        if (data['weekday_rate'] != null) {
          final wd = data['weekday_rate'] as Map<String, dynamic>;
          weekdayRate = weekdayRate.copyWith(
            firstHourMultiplier: (wd['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5,
            nextHoursMultiplier: (wd['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0,
            isActive: wd['is_active'] ?? true,
          );
        }

        if (data['holiday_rate'] != null) {
          final hd = data['holiday_rate'] as Map<String, dynamic>;
          holidayRate = holidayRate.copyWith(
            first8HoursMultiplier: (hd['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0,
            ninthHourMultiplier: (hd['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0,
            tenthPlusMultiplier: (hd['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0,
            isActive: hd['is_active'] ?? true,
          );
        }
      }

      final historySnapshot = await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .collection('history')
          .orderBy('changed_at', descending: true)
          .limit(10)
          .get();

      rateHistory = historySnapshot.docs.map((doc) {
        final data = doc.data();
        return RateHistory.fromMap(doc.id, data);
      }).toList();

    } catch (e) {
      logger.e('Error loading rates: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal memuat data tarif');
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveRates() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final gajiString = _gajiController.text.replaceAll(RegExp(r'[^\d]'), '');
      final gaji = double.parse(gajiString);
      
      upahPerJam = gaji / 173;

      final ratesData = {
        'base_salary': gaji,
        'rate_per_hour': upahPerJam,
        'last_updated': FieldValue.serverTimestamp(),
        'updated_by': _auth.currentUser?.email ?? 'system',
        'weekday_rate': {
          'first_hour_multiplier': weekdayRate.firstHourMultiplier,
          'next_hours_multiplier': weekdayRate.nextHoursMultiplier,
          'is_active': weekdayRate.isActive,
        },
        'holiday_rate': {
          'first_8_hours_multiplier': holidayRate.first8HoursMultiplier,
          'ninth_hour_multiplier': holidayRate.ninthHourMultiplier,
          'tenth_plus_multiplier': holidayRate.tenthPlusMultiplier,
          'is_active': holidayRate.isActive,
        },
      };

      await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .set(ratesData, SetOptions(merge: true));

      await _firestore
          .collection('settings')
          .doc('overtime_rates')
          .collection('history')
          .add({
        'base_salary': gaji,
        'rate_per_hour': upahPerJam,
        'weekday_rate': ratesData['weekday_rate'],
        'holiday_rate': ratesData['holiday_rate'],
        'changed_by': _auth.currentUser?.email ?? 'system',
        'changed_at': FieldValue.serverTimestamp(),
        'note': 'Perubahan tarif lembur',
      });

      await _loadRatesFromFirestore();

      if (mounted) {
        _showSuccessSnackbar('Tarif lembur berhasil disimpan');
      }

    } catch (e) {
      logger.e('Error saving rates: $e');
      if (mounted) {
        _showErrorSnackbar('Gagal menyimpan tarif: $e');
      }
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadRatesFromFirestore();
    if (mounted) {
      _showSuccessSnackbar('Data berhasil diperbarui');
    }
  }

  String _formatRupiah(double value) {
    return 'Rp ${NumberFormat('#,###').format(value)}';
  }

  Color _withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informasi Perhitungan', style: GoogleFonts.poppins()),
        content: Text(
          'Upah per jam dihitung berdasarkan rumus:\n'
          '1/173 × Gaji Pokok Bulanan\n\n'
          'Ketentuan Lembur:\n'
          '• Hari Kerja: Jam pertama 1,5x, jam berikutnya 2x\n'
          '• Hari Libur: 8 jam pertama 2x, jam ke-9 3x, jam ke-10 dst 4x',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gajiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Konfigurasi Tarif Lembur',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => setState(() => isDarkMode = !isDarkMode),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat konfigurasi tarif...',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                children: [
                  // Kartu Gaji Pokok
                  _buildSalaryCard(),
                  const SizedBox(height: 20),

                  // Kartu Tarif Hari Kerja
                  _buildRateCard(
                    title: 'Tarif Lembur Hari Kerja',
                    subtitle: 'Berlaku untuk Senin - Jumat',
                    rate: weekdayRate,
                    isHoliday: false,
                    onEdit: () => _showEditWeekdayRateDialog(),
                  ),
                  const SizedBox(height: 16),

                  // Kartu Tarif Hari Libur
                  _buildRateCard(
                    title: 'Tarif Lembur Hari Libur',
                    subtitle: 'Berlaku untuk Sabtu, Minggu & Tanggal Merah',
                    rate: holidayRate,
                    isHoliday: true,
                    onEdit: () => _showEditHolidayRateDialog(),
                  ),
                  const SizedBox(height: 24),

                  // Ringkasan Perhitungan
                  _buildSummaryCard(),
                  const SizedBox(height: 20),

                  // Riwayat Perubahan
                  if (rateHistory.isNotEmpty) _buildHistorySection(),
                  const SizedBox(height: 24),

                  // Tombol Simpan
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSalaryCard() {
    final gajiBersih = double.parse(
      _gajiController.text.replaceAll(RegExp(r'[^\d]'), '') == ''
          ? '0'
          : _gajiController.text.replaceAll(RegExp(r'[^\d]'), ''),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payments,
                  color: Color(0xFF1E3C72),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gaji Pokok Bulanan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _gajiController,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E3C72),
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Gaji tidak boleh kosong';
                    }
                    final number = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (number.isEmpty) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final number = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (number.isNotEmpty) {
                      final formatted = NumberFormat('#,###').format(
                        int.parse(number),
                      );
                      _gajiController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '/ bulan',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3C72).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nilai upah per jam',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatRupiah(gajiBersih / 173),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF1E3C72),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard({
    required String title,
    required String subtitle,
    required OvertimeRate rate,
    required bool isHoliday,
    required VoidCallback onEdit,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: rate.color.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: rate.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(rate.icon, color: rate.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: rate.isActive,
                      onChanged: (value) {
                        setState(() {
                          if (isHoliday) {
                            holidayRate = holidayRate.copyWith(isActive: value);
                          } else {
                            weekdayRate = weekdayRate.copyWith(isActive: value);
                          }
                        });
                      },
                      activeThumbColor: rate.color,
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!isHoliday) ...[
                      _buildRateRow(
                        'Jam pertama',
                        '${rate.firstHourMultiplier?.toStringAsFixed(1)}x',
                        _formatRupiah(upahPerJam * rate.firstHourMultiplier!),
                      ),
                      const SizedBox(height: 12),
                      _buildRateRow(
                        'Jam kedua dan seterusnya',
                        '${rate.nextHoursMultiplier?.toStringAsFixed(1)}x',
                        _formatRupiah(upahPerJam * rate.nextHoursMultiplier!),
                      ),
                    ] else ...[
                      _buildRateRow(
                        '8 jam pertama',
                        '${rate.first8HoursMultiplier?.toStringAsFixed(1)}x',
                        _formatRupiah(upahPerJam * rate.first8HoursMultiplier!),
                      ),
                      const SizedBox(height: 12),
                      _buildRateRow(
                        'Jam ke-9',
                        '${rate.ninthHourMultiplier?.toStringAsFixed(1)}x',
                        _formatRupiah(upahPerJam * rate.ninthHourMultiplier!),
                      ),
                      const SizedBox(height: 12),
                      _buildRateRow(
                        'Jam ke-10 dan seterusnya',
                        '${rate.tenthPlusMultiplier?.toStringAsFixed(1)}x',
                        _formatRupiah(upahPerJam * rate.tenthPlusMultiplier!),
                      ),
                    ],

                    const Divider(height: 24),

                    // Tombol Edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: Icon(Icons.edit, size: 16, color: rate.color),
                          label: Text(
                            'Edit Tarif',
                            style: GoogleFonts.poppins(
                              color: rate.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateRow(String label, String multiplier, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                multiplier,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ringkasan Tarif',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Upah per Jam',
                  _formatRupiah(upahPerJam),
                  Icons.access_time,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Berlaku sejak',
                  DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  Icons.update,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history,
                  color: Color(0xFF9C27B0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Riwayat Perubahan',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rateHistory.length > 3 ? 3 : rateHistory.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final history = rateHistory[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFF1E3C72),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatRupiah(history.baseSalary),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Diubah oleh: ${history.changedBy}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yy').format(history.changedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (rateHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  '+${rateHistory.length - 3} perubahan lainnya',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveRates,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Simpan Konfigurasi',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  void _showEditWeekdayRateDialog() {
    final firstHourController = TextEditingController(
      text: weekdayRate.firstHourMultiplier?.toStringAsFixed(1),
    );
    final nextHoursController = TextEditingController(
      text: weekdayRate.nextHoursMultiplier?.toStringAsFixed(1),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Tarif Hari Kerja',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstHourController,
                decoration: InputDecoration(
                  labelText: 'Multiplier Jam Pertama',
                  suffixText: 'x',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan multiplier';
                  }
                  final mult = double.tryParse(value);
                  if (mult == null || mult < 1) {
                    return 'Multiplier minimal 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nextHoursController,
                decoration: InputDecoration(
                  labelText: 'Multiplier Jam Kedua dst',
                  suffixText: 'x',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan multiplier';
                  }
                  final mult = double.tryParse(value);
                  if (mult == null || mult < 1) {
                    return 'Multiplier minimal 1';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  weekdayRate = weekdayRate.copyWith(
                    firstHourMultiplier: double.parse(firstHourController.text),
                    nextHoursMultiplier: double.parse(nextHoursController.text),
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
            ),
            child: Text('Simpan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showEditHolidayRateDialog() {
    final first8Controller = TextEditingController(
      text: holidayRate.first8HoursMultiplier?.toStringAsFixed(1),
    );
    final ninthController = TextEditingController(
      text: holidayRate.ninthHourMultiplier?.toStringAsFixed(1),
    );
    final tenthController = TextEditingController(
      text: holidayRate.tenthPlusMultiplier?.toStringAsFixed(1),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Tarif Hari Libur',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first8Controller,
                decoration: InputDecoration(
                  labelText: 'Multiplier 8 Jam Pertama',
                  suffixText: 'x',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan multiplier';
                  }
                  final mult = double.tryParse(value);
                  if (mult == null || mult < 1) {
                    return 'Multiplier minimal 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ninthController,
                decoration: InputDecoration(
                  labelText: 'Multiplier Jam ke-9',
                  suffixText: 'x',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan multiplier';
                  }
                  final mult = double.tryParse(value);
                  if (mult == null || mult < 1) {
                    return 'Multiplier minimal 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: tenthController,
                decoration: InputDecoration(
                  labelText: 'Multiplier Jam ke-10 dst',
                  suffixText: 'x',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan multiplier';
                  }
                  final mult = double.tryParse(value);
                  if (mult == null || mult < 1) {
                    return 'Multiplier minimal 1';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  holidayRate = holidayRate.copyWith(
                    first8HoursMultiplier: double.parse(first8Controller.text),
                    ninthHourMultiplier: double.parse(ninthController.text),
                    tenthPlusMultiplier: double.parse(tenthController.text),
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
            ),
            child: Text('Simpan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

// ==================== MODEL CLASSES ====================

class OvertimeRate {
  final String id;
  final String name;
  final String description;
  final double baseRate;
  final double? firstHourMultiplier;
  final double? nextHoursMultiplier;
  final double? first8HoursMultiplier;
  final double? ninthHourMultiplier;
  final double? tenthPlusMultiplier;
  final IconData icon;
  final Color color;
  final bool isActive;

  OvertimeRate({
    required this.id,
    required this.name,
    required this.description,
    required this.baseRate,
    this.firstHourMultiplier,
    this.nextHoursMultiplier,
    this.first8HoursMultiplier,
    this.ninthHourMultiplier,
    this.tenthPlusMultiplier,
    required this.icon,
    required this.color,
    this.isActive = true,
  });

  OvertimeRate copyWith({
    String? id,
    String? name,
    String? description,
    double? baseRate,
    double? firstHourMultiplier,
    double? nextHoursMultiplier,
    double? first8HoursMultiplier,
    double? ninthHourMultiplier,
    double? tenthPlusMultiplier,
    IconData? icon,
    Color? color,
    bool? isActive,
  }) {
    return OvertimeRate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      baseRate: baseRate ?? this.baseRate,
      firstHourMultiplier: firstHourMultiplier ?? this.firstHourMultiplier,
      nextHoursMultiplier: nextHoursMultiplier ?? this.nextHoursMultiplier,
      first8HoursMultiplier: first8HoursMultiplier ?? this.first8HoursMultiplier,
      ninthHourMultiplier: ninthHourMultiplier ?? this.ninthHourMultiplier,
      tenthPlusMultiplier: tenthPlusMultiplier ?? this.tenthPlusMultiplier,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
    );
  }
}

class RateHistory {
  final String id;
  final double baseSalary;
  final double ratePerHour;
  final String changedBy;
  final DateTime changedAt;

  RateHistory({
    required this.id,
    required this.baseSalary,
    required this.ratePerHour,
    required this.changedBy,
    required this.changedAt,
  });

  factory RateHistory.fromMap(String id, Map<String, dynamic> map) {
    return RateHistory(
      id: id,
      baseSalary: (map['base_salary'] as num?)?.toDouble() ?? 0,
      ratePerHour: (map['rate_per_hour'] as num?)?.toDouble() ?? 0,
      changedBy: map['changed_by'] as String? ?? 'system',
      changedAt: (map['changed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}