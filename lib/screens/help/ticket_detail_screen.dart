import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticketData;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.ticketData,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool isUpdating = false;

  Future<void> _cancelTicket() async {
    setState(() => isUpdating = true);

    try {
      await _firestore.collection('help_requests').doc(widget.ticketId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': 'user',
      });

      // Add system message
      await _firestore.collection('help_messages').add({
        'ticketId': widget.ticketId,
        'senderId': 'system',
        'senderName': 'System',
        'senderRole': 'system',
        'message': 'Tiket ditutup oleh pengguna',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiket berhasil ditutup'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isUpdating = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'MENUNGGU';
      case 'in_progress':
        return 'DIPROSES';
      case 'resolved':
        return 'SELESAI';
      case 'closed':
        return 'DITUTUP';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.ticketData['status'] ?? 'open';
    final statusColor = _getStatusColor(status);
    final createdAt = (widget.ticketData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Tiket',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
        actions: [
          if (status == 'open' || status == 'in_progress')
            TextButton.icon(
              onPressed: isUpdating ? null : _cancelTicket,
              icon: Icon(
                Icons.cancel,
                color: isUpdating ? Colors.grey : Colors.white,
              ),
              label: Text(
                'Tutup Tiket',
                style: GoogleFonts.poppins(
                  color: isUpdating ? Colors.grey : Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: statusColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${_getStatusLabel(status)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        if (widget.ticketData['assignedToName'] != null)
                          Text(
                            'Ditangani oleh: ${widget.ticketData['assignedToName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: statusColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PRIORITY ${widget.ticketData['priority'] ?? 3}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(widget.ticketData['priority'] ?? 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Ticket Info
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.ticketData['question'] ?? 'No Title',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category & Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.ticketData['category'] ?? 'General',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF1E3C72),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Deskripsi',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ticketData['description'] ?? 'Tidak ada deskripsi',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),

                  if (widget.ticketData['attachmentUrl'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lampiran',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Icon(Icons.download, color: const Color(0xFF1E3C72)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chat Section
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.chat, color: const Color(0xFF1E3C72)),
                        const SizedBox(width: 8),
                        Text(
                          'Percakapan',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  ticketId: widget.ticketId,
                                  ticketData: widget.ticketData,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_full, size: 16),
                          label: Text(
                            'Buka Chat',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Chat Preview
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('help_messages')
                          .where('ticketId', isEqualTo: widget.ticketId)
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final messages = snapshot.data!.docs;

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat, size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text(
                                  'Belum ada pesan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index].data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF1E3C72) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['message'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('HH:mm').format(
                                      (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now()
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: isMe ? Colors.white70 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // View All Messages Button
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              ticketId: widget.ticketId,
                              ticketData: widget.ticketData,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: Text('Lihat Semua Pesan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.email;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.archive;
      default:
        return Icons.help;
    }
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 3) return Colors.orange;
    return Colors.green;
  }
}