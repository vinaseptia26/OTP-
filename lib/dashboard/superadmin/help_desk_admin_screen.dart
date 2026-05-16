// FILE: lib/screens/super_admin/help_desk_admin_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class HelpDeskAdminScreen extends StatefulWidget {
  const HelpDeskAdminScreen({super.key});

  @override
  State<HelpDeskAdminScreen> createState() => _HelpDeskAdminScreenState();
}

class _HelpDeskAdminScreenState extends State<HelpDeskAdminScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tab Controller
  late TabController _tabController;
  
  // Filters
  String selectedFilter = 'all';
  String selectedPriority = 'all';
  String searchQuery = '';
  
  // Stats
  Map<String, int> ticketStats = {
    'open': 0,
    'in_progress': 0,
    'resolved': 0,
    'closed': 0,
    'total': 0,
  };

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Loading state
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTicketStats();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    _firestore.collection('help_requests').snapshots().listen((snapshot) {
      _loadTicketStats();
    });
  }

  Future<void> _loadTicketStats() async {
    try {
      final snapshot = await _firestore.collection('help_requests').get();
      
      int open = 0;
      int inProgress = 0;
      int resolved = 0;
      int closed = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'open';
        switch (status) {
          case 'open':
            open++;
            break;
          case 'in_progress':
            inProgress++;
            break;
          case 'resolved':
            resolved++;
            break;
          case 'closed':
            closed++;
            break;
        }
      }

      setState(() {
        ticketStats = {
          'open': open,
          'in_progress': inProgress,
          'resolved': resolved,
          'closed': closed,
          'total': snapshot.docs.length,
        };
        isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading ticket stats: $e');
      setState(() => isLoading = false);
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 3) return Colors.orange;
    return Colors.green;
  }

  String _getPriorityLabel(int priority) {
    if (priority >= 5) return 'URGENT';
    if (priority >= 3) return 'High';
    if (priority >= 2) return 'Medium';
    return 'Low';
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
        return 'OPEN';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'resolved':
        return 'RESOLVED';
      case 'closed':
        return 'CLOSED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Help Desk Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C), Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'OPEN', icon: Icon(Icons.email)),
            Tab(text: 'IN PROGRESS', icon: Icon(Icons.hourglass_empty)),
            Tab(text: 'RESOLVED', icon: Icon(Icons.check_circle)),
            Tab(text: 'CLOSED', icon: Icon(Icons.archive)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _loadTicketStats();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildStatCard('Total', '${ticketStats['total']}', Colors.blue, Icons.confirmation_number),
                      _buildStatCard('Open', '${ticketStats['open']}', Colors.red, Icons.email),
                      _buildStatCard('Progress', '${ticketStats['in_progress']}', Colors.orange, Icons.hourglass_empty),
                      _buildStatCard('Resolved', '${ticketStats['resolved']}', Colors.green, Icons.check_circle),
                    ],
                  ),
                ),

                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Cari tiket...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: selectedPriority,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.filter_list),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua Prioritas')),
                            DropdownMenuItem(value: 'high', child: Text('High Priority')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                            DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedPriority = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Ticket List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTicketList('open'),
                      _buildTicketList('in_progress'),
                      _buildTicketList('resolved'),
                      _buildTicketList('closed'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketList(String status) {
    Query query = _firestore
        .collection('help_requests')
        .where('status', isEqualTo: status)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var tickets = snapshot.data!.docs.where((doc) {
          if (searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final question = (data['question'] ?? '').toLowerCase();
          final userName = (data['userName'] ?? '').toLowerCase();
          final query = searchQuery.toLowerCase();
          return question.contains(query) || userName.contains(query);
        }).toList();

        // Filter by priority
        if (selectedPriority != 'all') {
          tickets = tickets.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final priority = data['priority'] ?? 3;
            if (selectedPriority == 'high') return priority >= 4;
            if (selectedPriority == 'medium') return priority == 3;
            if (selectedPriority == 'low') return priority <= 2;
            return true;
          }).toList();
        }

        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada tiket',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final doc = tickets[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTicketCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(String ticketId, Map<String, dynamic> data) {
    final priority = data['priority'] ?? 3;
    final priorityColor = _getPriorityColor(priority);
    final statusColor = _getStatusColor(data['status'] ?? 'open');
    final createdAt = data['createdAt'] as Timestamp? ?? Timestamp.now();
    final isUnassigned = data['assignedTo'] == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticketId: ticketId,
                ticketData: data,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isUnassigned
                ? Border.all(color: Colors.orange, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Text(
                      (data['userName']?[0] ?? '?').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['userName'] ?? 'Unknown User',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          data['userRole'] ?? 'Unknown Role',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 12,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPriorityLabel(priority),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Question
              Text(
                data['question'] ?? 'No Title',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                data['description'] ?? 'No Description',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['category'] ?? 'General',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // Status & Time
                  Row(
                    children: [
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(data['status'] ?? 'open'),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Time
                      Text(
                        _getTimeAgo(createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Unassigned Warning
              if (isUnassigned) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Belum diassign - Klik untuk mengambil tiket ini',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// TICKET DETAIL SCREEN
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool isSending = false;
  String? selectedStatus;
  int? selectedPriority;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.ticketData['status'] ?? 'open';
    selectedPriority = widget.ticketData['priority'] ?? 3;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _assignTicket() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('help_requests').doc(widget.ticketId).update({
        'assignedTo': user.uid,
        'assignedToName': user.email,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add system message
      await _firestore.collection('help_messages').add({
        'ticketId': widget.ticketId,
        'senderId': 'system',
        'senderName': 'System',
        'senderRole': 'system',
        'message': 'Tiket diambil oleh ${user.email}',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiket berhasil diassign'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedStatus = 'in_progress';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _firestore.collection('help_requests').doc(widget.ticketId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Add system message
      final user = _auth.currentUser;
      await _firestore.collection('help_messages').add({
        'ticketId': widget.ticketId,
        'senderId': 'system',
        'senderName': 'System',
        'senderRole': 'system',
        'message': 'Status tiket diubah menjadi ${newStatus.toUpperCase()} oleh ${user?.email}',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });

      setState(() {
        selectedStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status diubah menjadi $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePriority(int newPriority) async {
    try {
      await _firestore.collection('help_requests').doc(widget.ticketId).update({
        'priority': newPriority,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        selectedPriority = newPriority;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prioritas diubah menjadi $newPriority'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => isSending = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      await _firestore.collection('help_messages').add({
        'ticketId': widget.ticketId,
        'senderId': user.uid,
        'senderName': userData['nama_lengkap'] ?? user.email,
        'senderRole': userData['role'] ?? 'admin',
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update ticket's last activity
      await _firestore.collection('help_requests').doc(widget.ticketId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': _messageController.text.trim().substring(0, 
            _messageController.text.trim().length > 50 ? 50 : _messageController.text.trim().length),
      });

      _messageController.clear();
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSending = false);
    }
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 3) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isAssigned = widget.ticketData['assignedTo'] != null;
    final isCurrentUserAssigned = widget.ticketData['assignedTo'] == _auth.currentUser?.uid;

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
          if (!isAssigned)
            TextButton.icon(
              onPressed: _assignTicket,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(
                'Ambil Tiket',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Ticket Info Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: Text(
                        (widget.ticketData['userName']?[0] ?? '?').toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.ticketData['userName'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.ticketData['userRole'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(selectedPriority ?? 3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PRIORITY ${selectedPriority ?? 3}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(selectedPriority ?? 3),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Question
                Text(
                  widget.ticketData['question'] ?? 'No Title',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ticketData['description'] ?? 'No Description',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 16),

                // Metadata
                Row(
                  children: [
                    Icon(Icons.category, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      widget.ticketData['category'] ?? 'General',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(
                        (widget.ticketData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                if (isAssigned) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ditangani oleh: ${widget.ticketData['assignedToName'] ?? 'Admin'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Admin Controls (only for assigned admin)
                if (isCurrentUserAssigned) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Status Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'open', child: Text('OPEN')),
                            DropdownMenuItem(value: 'in_progress', child: Text('IN PROGRESS')),
                            DropdownMenuItem(value: 'resolved', child: Text('RESOLVED')),
                            DropdownMenuItem(value: 'closed', child: Text('CLOSED')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _updateStatus(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Priority Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedPriority,
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('P1 - Low')),
                            DropdownMenuItem(value: 2, child: Text('P2 - Low+')),
                            DropdownMenuItem(value: 3, child: Text('P3 - Medium')),
                            DropdownMenuItem(value: 4, child: Text('P4 - High')),
                            DropdownMenuItem(value: 5, child: Text('P5 - URGENT')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _updatePriority(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Chat Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('help_messages')
                  .where('ticketId', isEqualTo: widget.ticketId)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada pesan',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          'Mulai percakapan dengan user',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == _auth.currentUser?.uid;
                    final isSystem = msg['senderRole'] == 'system';
                    
                    if (isSystem) {
                      return _buildSystemMessage(msg);
                    }
                    
                    return _buildChatBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Message Input (only for assigned admin)
          if (isCurrentUserAssigned) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: isSending ? Colors.grey : const Color(0xFF1E3C72),
                    child: IconButton(
                      icon: Icon(
                        isSending ? Icons.hourglass_empty : Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isAssigned) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Center(
                child: Text(
                  'Tiket ini sedang ditangani oleh admin lain',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              child: Text(
                (message['senderName']?[0] ?? '?').toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1E3C72) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message['senderName'] ?? 'User',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      color: isMe ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message['message'] ?? '',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}