// lib/screens/faq/faq_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otp_apk/screens/faq/add_faq_screen.dart';
import '/core/services/faq_model_service.dart';
import '../chat/chat_room_screen.dart';

class FAQDetailScreen extends StatefulWidget {
  final FAQModel faqData;
  final bool isSuperAdmin;
  final FAQService faqService;
  final ChatService chatService;

  const FAQDetailScreen({
    super.key,
    required this.faqData,
    required this.isSuperAdmin,
    required this.faqService,
    required this.chatService,
  });

  @override
  State<FAQDetailScreen> createState() => _FAQDetailScreenState();
}

class _FAQDetailScreenState extends State<FAQDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _hasVoted = false;
  String? _voteType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail FAQ',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isSuperAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddFAQScreen(
                        faqService: widget.faqService,
                        faqToEdit: widget.faqData,
                      ),
                    ),
                  );
                } else if (value == 'delete') {
                  _showDeleteConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.faqData.category,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF1E3C72),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye,
                                size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.faqData.views} dilihat',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pertanyaan:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.faqData.question,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3C72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Answer
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Jawaban:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.faqData.answer,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Helpful section
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
                    Text(
                      'Apakah informasi ini membantu?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasVoted
                                ? null
                                : () => _vote('helpful'),
                            icon: Icon(
                              Icons.thumb_up,
                              size: 20,
                              color: _voteType == 'helpful'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            label: Text(
                              'Membantu (${widget.faqData.helpfulBy.length})',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _voteType == 'helpful'
                                  ? Colors.green
                                  : Colors.grey[600],
                              side: BorderSide(
                                color: _voteType == 'helpful'
                                    ? Colors.green
                                    : Colors.grey[300]!,
                              ),
                              backgroundColor: _voteType == 'helpful'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasVoted
                                ? null
                                : () => _vote('not_helpful'),
                            icon: Icon(
                              Icons.thumb_down,
                              size: 20,
                              color: _voteType == 'not_helpful'
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            label: Text(
                              'Tidak Membantu (${widget.faqData.notHelpfulBy.length})',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _voteType == 'not_helpful'
                                  ? Colors.red
                                  : Colors.grey[600],
                              side: BorderSide(
                                color: _voteType == 'not_helpful'
                                    ? Colors.red
                                    : Colors.grey[300]!,
                              ),
                              backgroundColor: _voteType == 'not_helpful'
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Still need help section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: const Color(0xFF1E3C72).withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.support_agent,
                            color: const Color(0xFF1E3C72), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Masih butuh bantuan?',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3C72),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jika jawaban di atas belum membantu, Anda dapat menghubungi tim support kami melalui chat.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat dengan Support'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _vote(String type) async {
    try {
      if (type == 'helpful') {
        await widget.faqService.markAsHelpful(widget.faqData.id);
      } else {
        await widget.faqService.markAsNotHelpful(widget.faqData.id);
      }
      
      setState(() {
        _hasVoted = true;
        _voteType = type;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terima kasih atas feedback Anda!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memberikan feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat() async {
    try {
      final userInfo = await widget.chatService.getCurrentUserInfo();
      final role = await widget.chatService.getCurrentUserRole();
      final currentUser = _auth.currentUser;
      
      if (userInfo != null && currentUser != null) {
        final chatRoomId = await widget.chatService.createChatRoom(
          userId: currentUser.uid,
          userName: userInfo['nama_lengkap'] ?? 'User',
          userRole: role,
          userFunction: userInfo['fungsi'] ?? '',
        );
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                chatRoomId: chatRoomId,
                chatRoomName: 'Support Chat',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda harus login terlebih dahulu'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus FAQ'),
        content: Text(
          'Apakah Anda yakin ingin menghapus FAQ "${widget.faqData.question}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.faqService.deactivateFAQ(widget.faqData.id);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to FAQ list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FAQ berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus FAQ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}