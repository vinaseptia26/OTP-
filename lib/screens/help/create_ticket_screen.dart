import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Selected values
  String? selectedCategory;
  File? _selectedImage;
  bool isSubmitting = false;

  // Categories
  final List<Map<String, dynamic>> categories = [
    {'id': 'account', 'name': 'Akun & Profil', 'icon': Icons.account_circle},
    {'id': 'payment', 'name': 'Pembayaran', 'icon': Icons.payment},
    {'id': 'shipping', 'name': 'Pengiriman', 'icon': Icons.delivery_dining},
    {'id': 'technical', 'name': 'Masalah Teknis', 'icon': Icons.computer},
    {'id': 'product', 'name': 'Produk', 'icon': Icons.shopping_bag},
    {'id': 'other', 'name': 'Lainnya', 'icon': Icons.help},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak login');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create ticket
      final ticketData = {
        'userId': user.uid,
        'userName': userData['nama_lengkap'] ?? user.email,
        'userEmail': user.email,
        'userRole': userData['role'] ?? 'user',
        'question': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': selectedCategory,
        'priority': 3, // Default priority
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'hasAttachment': _selectedImage != null,
      };

      // Add attachment URL if needed (implement upload to storage)
      // if (_selectedImage != null) {
      //   final imageUrl = await _uploadImage(_selectedImage!);
      //   ticketData['attachmentUrl'] = imageUrl;
      // }

      final docRef = await _firestore.collection('help_requests').add(ticketData);

      // Add initial message
      await _firestore.collection('help_messages').add({
        'ticketId': docRef.id,
        'senderId': user.uid,
        'senderName': userData['nama_lengkap'] ?? user.email,
        'senderRole': userData['role'] ?? 'user',
        'message': _descriptionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tiket Berhasil Dibuat!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tim support kami akan segera merespons pertanyaan Anda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat tiket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Buat Tiket Baru',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: const Color(0xFF1E3C72)),
                    const SizedBox(height: 8),
                    Text(
                      'Jelaskan masalah Anda dengan detail agar kami dapat membantu lebih cepat',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category Selection
            Text(
              'Kategori *',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  hint: const Text('Pilih kategori'),
                  isExpanded: true,
                  items: categories.map<DropdownMenuItem<String>>((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'] as String,
                      child: Row(
                        children: [
                          Icon(category['icon'] as IconData, size: 20, color: const Color(0xFF1E3C72)),
                          const SizedBox(width: 8),
                          Text(category['name'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul / Pertanyaan *',
                hintText: 'Contoh: Cara mengganti password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Judul tidak boleh kosong';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Deskripsi *',
                hintText: 'Jelaskan masalah Anda secara detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Deskripsi tidak boleh kosong';
                }
                if (value.length < 10) {
                  return 'Deskripsi terlalu pendek (minimal 10 karakter)';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Attachment
            InkWell(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedImage != null ? Icons.image : Icons.attach_file,
                      color: _selectedImage != null ? Colors.green : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedImage != null
                            ? 'File: ${_selectedImage!.path.split('/').last}'
                            : 'Tambahkan lampiran (opsional)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _selectedImage != null ? Colors.green : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (_selectedImage != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Kirim Tiket',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}