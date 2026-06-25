// lib/screens/faq/add_faq_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/faq_model_service.dart';

class AddFAQScreen extends StatefulWidget {
  final FAQService faqService;
  final FAQModel? faqToEdit;

  const AddFAQScreen({
    super.key,
    required this.faqService,
    this.faqToEdit,
  });

  @override
  State<AddFAQScreen> createState() => _AddFAQScreenState();
}

class _AddFAQScreenState extends State<AddFAQScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  String _selectedCategory = 'Lembur & Kompensasi';
  
  // 🔥 Kategori sesuai konteks PGE Kamojang
  final List<String> _categories = [
    'Lembur & Kompensasi',
    'Absensi & Kehadiran',
    'Pengajuan Lembur',
    'Persetujuan Kerja Lembur',
    'Jadwal & Shift Kerja',
    'HSSE & Keselamatan',
    'Aplikasi & Teknis',
    'Akun & Profil',
    'Kebijakan Perusahaan',
    'Umum',
  ];

  // 🔥 Template jawaban untuk membantu superadmin
  final Map<String, List<Map<String, String>>> _templates = {
    'Lembur & Kompensasi': [
      {
        'question': 'Bagaimana cara menghitung kompensasi lembur?',
        'answer': 'Kompensasi lembur dihitung berdasarkan rate yang telah ditetapkan:\n\n'
            '1. Hari Kerja Biasa:\n'
            '   - 1 jam pertama: 1.5x upah sejam\n'
            '   - Jam berikutnya: 2x upah sejam\n\n'
            '2. Hari Libur/Hari Raya:\n'
            '   - 1-8 jam pertama: 2x upah sejam\n'
            '   - Jam ke-9: 3x upah sejam\n'
            '   - Jam ke-10-11: 4x upah sejam\n\n'
            'Rate ini mengikuti ketentuan Depnaker dan kebijakan internal PGE.'
      },
      {
        'question': 'Kapan kompensasi lembur dibayarkan?',
        'answer': 'Pembayaran kompensasi lembur dilakukan bersamaan dengan gaji bulanan pada '
            'tanggal 25 setiap bulannya. Pastikan data lembur sudah diapprove oleh Pengawas '
            'dan Manager sebelum tanggal 20 agar dapat diproses tepat waktu.'
      },
    ],
    'Absensi & Kehadiran': [
      {
        'question': 'Bagaimana cara melakukan absensi lembur?',
        'answer': 'Absensi lembur dapat dilakukan melalui aplikasi dengan langkah:\n\n'
            '1. Buka menu "Absensi" di dashboard\n'
            '2. Pilih "Check-in Lembur"\n'
            '3. Ambil foto selfie di lokasi kerja\n'
            '4. Sistem akan mencatat waktu dan lokasi GPS\n'
            '5. Saat selesai, lakukan "Check-out Lembur"\n\n'
            'Pastikan GPS dan kamera dalam keadaan aktif.'
      },
    ],
    'Pengajuan Lembur': [
      {
        'question': 'Bagaimana prosedur pengajuan lembur?',
        'answer': 'Prosedur pengajuan lembur di PGE Area Kamojang:\n\n'
            '1. Pengawas mengajukan lembur melalui menu "Ajukan Lembur"\n'
            '2. Pilih mitra yang akan lembur\n'
            '3. Tentukan tanggal, jam mulai, dan jam selesai\n'
            '4. Jelaskan alasan dan pekerjaan yang akan dilakukan\n'
            '5. Submit pengajuan untuk approval Manager\n'
            '6. Jika ada risiko HSSE tinggi, perlu approval Manager HSSE\n\n' // 🔥 UBAH
            'Pengajuan sebaiknya dilakukan minimal H-1 sebelum pelaksanaan.'
      },
    ],
    'HSSE & Keselamatan': [
      {
        'question': 'Apa saja persyaratan HSSE untuk kerja lembur?',
        'answer': 'Persyaratan HSSE untuk kerja lembur di PGE Area Kamojang:\n\n'
            '1. Toolbox meeting sebelum memulai pekerjaan\n'
            '2. JSA (Job Safety Analysis) untuk pekerjaan berisiko\n'
            '3. APD lengkap sesuai area kerja\n'
            '4. Working Permit untuk area terbatas\n'
            '5. Minimal 2 orang untuk pekerjaan berisiko tinggi\n'
            '6. Komunikasi radio dengan control room\n'
            '7. P3K dan emergency response plan\n\n'
            'Pelanggaran HSSE dapat mengakibatkan pembatalan lembur.'
      },
    ],
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.faqToEdit != null) {
      _questionController.text = widget.faqToEdit!.question;
      _answerController.text = widget.faqToEdit!.answer;
      _selectedCategory = widget.faqToEdit!.category;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _saveFAQ() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final faq = FAQModel(
        id: widget.faqToEdit?.id ?? '',
        question: _questionController.text.trim(),
        answer: _answerController.text.trim(),
        category: _selectedCategory,
        views: widget.faqToEdit?.views ?? 0,
        createdBy: 'superadmin',
        createdAt: widget.faqToEdit?.createdAt,
        updatedAt: DateTime.now(),
        helpfulBy: widget.faqToEdit?.helpfulBy ?? [],
        notHelpfulBy: widget.faqToEdit?.notHelpfulBy ?? [],
      );

      if (widget.faqToEdit != null) {
        await widget.faqService.updateFAQ(faq);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ FAQ berhasil diperbarui'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } else {
        await widget.faqService.addFAQ(faq);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ FAQ berhasil ditambahkan'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: _saveFAQ,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyTemplate(Map<String, String> template) {
    setState(() {
      _questionController.text = template['question'] ?? '';
      _answerController.text = template['answer'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.faqToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit FAQ' : 'Tambah FAQ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteConfirmation(),
              tooltip: 'Hapus FAQ',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E3C72)),
                  SizedBox(height: 16),
                  Text('Menyimpan FAQ...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔥 Header Info
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
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF1E3C72),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit FAQ yang sudah ada. Perubahan akan langsung terlihat oleh semua pengguna.'
                                  : 'Tambahkan FAQ baru untuk membantu mitra dan pengawas di PGE Area Kamojang.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF1E3C72),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔥 Kategori Dropdown
                    Text(
                      'Kategori',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : _categories.first,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih kategori';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // 🔥 Template (hanya saat tambah baru)
                    if (!isEditing && _templates.containsKey(_selectedCategory)) ...[
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'Template Cepat',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _templates[_selectedCategory]!
                              .map((template) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => _applyTemplate(template),
                                      child: Container(
                                        width: 200,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.orange.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.description_outlined,
                                              size: 16,
                                              color: Colors.orange[700],
                                            ),
                                            const SizedBox(height: 4),
                                            Expanded(
                                              child: Text(
                                                template['question'] ?? '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 🔥 Pertanyaan Field
                    Text(
                      'Pertanyaan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _questionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Bagaimana prosedur pengajuan lembur di hari libur?',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.help_outline),
                        ),
                        counterText: '${_questionController.text.length}/200 karakter',
                      ),
                      maxLength: 200,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Pertanyaan tidak boleh kosong';
                        }
                        if (value.trim().length < 10) {
                          return 'Pertanyaan minimal 10 karakter';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 16),

                    // 🔥 Jawaban Field
                    Text(
                      'Jawaban',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _answerController,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText:
                            'Tulis jawaban yang jelas dan informatif...\n\n'
                            'Tips:\n'
                            '• Gunakan poin-poin (1, 2, 3)\n'
                            '• Sertakan langkah-langkah detail\n'
                            '• Cantumkan kontak terkait jika perlu\n'
                            '• Gunakan bahasa yang mudah dipahami',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[400],
                          height: 1.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Jawaban tidak boleh kosong';
                        }
                        if (value.trim().length < 20) {
                          return 'Jawaban minimal 20 karakter';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // 🔥 Preview Card (jika sudah diisi)
                    if (_questionController.text.isNotEmpty &&
                        _answerController.text.isNotEmpty) ...[
                      Text(
                        'Preview',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3C72)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _selectedCategory,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: const Color(0xFF1E3C72),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Preview',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _questionController.text,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: const Color(0xFF1E3C72),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _answerController.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 🔥 Submit Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: Color(0xFF1E3C72),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: const Color(0xFF1E3C72),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _saveFAQ,
                            icon: Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(
                              isEditing ? 'Update FAQ' : 'Simpan FAQ',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3C72),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Hapus FAQ',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus FAQ:\n\n"${widget.faqToEdit?.question}"?\n\nTindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.faqService.deleteFAQ(widget.faqToEdit!.id);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Return to FAQ list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ FAQ berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Gagal menghapus: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}