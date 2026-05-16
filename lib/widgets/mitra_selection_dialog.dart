// lib/features/pengawas/lembur/widgets/mitra_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MitraSelectionDialog extends StatefulWidget {
  final String fungsi;
  final List<String> selectedIds;

  const MitraSelectionDialog({
    super.key,
    required this.fungsi,
    required this.selectedIds,
  });

  @override
  State<MitraSelectionDialog> createState() => _MitraSelectionDialogState();
}

class _MitraSelectionDialogState extends State<MitraSelectionDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _mitras = [];
  List<Map<String, dynamic>> _recommendedMitras = [];
  List<String> _selectedIds = [];
  bool _isLoading = true;
  bool _isLoadingRecommendations = true;
  String _searchQuery = '';
  String _activeTab = 'semua'; // 'semua' or 'rekomendasi'

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedIds);
    _loadMitras();
    _loadRecommendedMitras();
  }

  Future<void> _loadMitras() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mitra')
          .where('fungsi', isEqualTo: widget.fungsi)
          .where('status_akun', isEqualTo: 'active')
          .orderBy('nama_lengkap')
          .get();

      _mitras = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nama_lengkap': data['nama_lengkap'] ?? 'Tanpa Nama',
          'fungsi': data['fungsi'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading mitras: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadRecommendedMitras() async {
    setState(() => _isLoadingRecommendations = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoadingRecommendations = false);
        return;
      }

      // Ambil riwayat lembur dari pengawas ini
      final snapshot = await _firestore
          .collection('lembur')
          .where('pengawas_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      // Hitung frekuensi setiap mitra
      final Map<String, Map<String, dynamic>> mitraFrequency = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mitraId = data['mitra_id'];
        final namaMitra = data['nama_mitra'];
        final fungsiMitra = data['fungsi_mitra'];
        
        if (mitraId != null && namaMitra != null && fungsiMitra == widget.fungsi) {
          if (mitraFrequency.containsKey(mitraId)) {
            mitraFrequency[mitraId]!['count'] = (mitraFrequency[mitraId]!['count'] as int) + 1;
          } else {
            mitraFrequency[mitraId] = {
              'id': mitraId,
              'nama_lengkap': namaMitra,
              'fungsi': fungsiMitra,
              'count': 1,
            };
          }
        }
      }

      // Konversi ke list dan urutkan berdasarkan frekuensi
      List<Map<String, dynamic>> recommendations = mitraFrequency.values.toList();
      recommendations.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      // Ambil 10 rekomendasi teratas
      _recommendedMitras = recommendations.take(10).toList();
      
    } catch (e) {
      debugPrint('Error loading recommended mitras: $e');
    }
    setState(() => _isLoadingRecommendations = false);
  }

  List<Map<String, dynamic>> get _filteredMitras {
    if (_searchQuery.isEmpty) return _mitras;
    return _mitras.where((mitra) {
      return mitra['nama_lengkap'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRecommendedMitras {
    if (_searchQuery.isEmpty) return _recommendedMitras;
    return _recommendedMitras.where((mitra) {
      return mitra['nama_lengkap'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (_selectedIds.isNotEmpty) _buildSelectedCount(),
            _buildTabSelector(),
            Expanded(child: _buildContent()),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1976D2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Pilih Mitra",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Cari mitra...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF718096)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildSelectedCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 18),
            const SizedBox(width: 8),
            Text(
              "${_selectedIds.length} mitra dipilih",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    if (_recommendedMitras.isEmpty && !_isLoadingRecommendations) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'semua'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 'semua'
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  "Semua Mitra",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: _activeTab == 'semua' ? FontWeight.w600 : FontWeight.w400,
                    color: _activeTab == 'semua'
                        ? const Color(0xFF1976D2)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'rekomendasi'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 'rekomendasi'
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: _activeTab == 'rekomendasi'
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Rekomendasi",
                      style: GoogleFonts.poppins(
                        fontWeight: _activeTab == 'rekomendasi' ? FontWeight.w600 : FontWeight.w400,
                        color: _activeTab == 'rekomendasi'
                            ? const Color(0xFF1976D2)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_activeTab == 'rekomendasi') {
      if (_isLoadingRecommendations) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      if (_recommendedMitras.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                "Belum ada riwayat mitra",
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                "Mitra yang sering dipakai akan muncul di sini",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }
      
      final displayList = _filteredRecommendedMitras;
      if (displayList.isEmpty) {
        return Center(
          child: Text(
            "Mitra tidak ditemukan",
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final mitra = displayList[index];
          final isSelected = _selectedIds.contains(mitra['id']);
          return _buildMitraItem(mitra, isSelected, showStar: true);
        },
      );
    }
    
    // Tab 'semua'
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_filteredMitras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              "Tidak ada mitra ditemukan",
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMitras.length,
      itemBuilder: (context, index) {
        final mitra = _filteredMitras[index];
        final isSelected = _selectedIds.contains(mitra['id']);
        return _buildMitraItem(mitra, isSelected, showStar: false);
      },
    );
  }

  Widget _buildMitraItem(Map<String, dynamic> mitra, bool isSelected, {bool showStar = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(mitra['id']);
            } else {
              _selectedIds.add(mitra['id']);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: _getFungsiColor(mitra['fungsi']),
                    radius: 20,
                    child: Text(
                      (mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  if (showStar)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(Icons.star, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mitra['nama_lengkap'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showStar && mitra['count'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${mitra['count']}x",
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getFungsiColor(mitra['fungsi']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getFungsiLabel(mitra['fungsi']).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _getFungsiColor(mitra['fungsi']),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _selectedIds.clear());
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Hapus Semua"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final selectedMitras = _mitras
                    .where((m) => _selectedIds.contains(m['id']))
                    .toList();
                Navigator.pop(context, selectedMitras);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Simpan"),
            ),
          ),
        ],
      ),
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
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'lab': return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'BS';
      default: return fungsi;
    }
  }
}