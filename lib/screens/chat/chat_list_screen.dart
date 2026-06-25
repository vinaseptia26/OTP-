// lib/screens/chat/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/core/services/faq_model_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  ChatRole? _userRole;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      final role = await _chatService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoading = false;
        });
        debugPrint('✅ ChatList: User role = ${role.name}');
      }
    } catch (e) {
      debugPrint('❌ Error getting user role: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data user: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat Support',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          // 🔥 Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeScreen();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1E3C72)),
            SizedBox(height: 16),
            Text('Memuat chat...'),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeScreen();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No role
    if (_userRole == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Tidak dapat mendeteksi role user',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final isAdmin = _userRole == ChatRole.superadmin ||
        _userRole == ChatRole.manager ||
        _userRole == ChatRole.pengawas ||
        _userRole == ChatRole.officerSafety;

    debugPrint('🔍 ChatList: isAdmin = $isAdmin, role = ${_userRole?.name}');

    return StreamBuilder<List<ChatRoom>>(
      stream: isAdmin
          ? _chatService.getAdminChatRoomsStream()
          : _chatService.getUserChatRoomsStream(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF1E3C72)),
                const SizedBox(height: 16),
                Text(
                  'Memuat percakapan...',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Error
        if (snapshot.hasError) {
          debugPrint('❌ ChatList stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat chat: ${snapshot.error}',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        // Data
        final chatRooms = snapshot.data ?? [];
        debugPrint('📊 ChatList: ${chatRooms.length} chat rooms found');

        // Empty state
        if (chatRooms.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada percakapan',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'User akan muncul di sini saat mereka memulai chat'
                        : 'Mulai chat dari halaman FAQ untuk bertanya ke support',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Kembali ke FAQ
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Kembali ke FAQ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Chat room list
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final room = chatRooms[index];
            debugPrint('📝 Chat room ${index + 1}: ${room.userName} (${room.userRole.name})');
            return _buildChatRoomItem(room);
          },
        );
      },
    );
  }

  Widget _buildChatRoomItem(ChatRoom room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getRoleColor(room.userRole),
          child: Text(
            room.userName.isNotEmpty ? room.userName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          room.userName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Last message preview
            if (room.lastMessage != null)
              Text(
                room.lastMessage!.message.length > 50
                    ? '${room.lastMessage!.message.substring(0, 50)}...'
                    : room.lastMessage!.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            else
              Text(
                'Mulai percakapan...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 2),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(room.userRole).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                room.userRole.label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: _getRoleColor(room.userRole),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (room.lastMessage != null)
              Text(
                _formatTime(room.lastMessage!.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            if (room.unreadCount > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          debugPrint('🚀 Opening chat room: ${room.id}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                chatRoomId: room.id,
                chatRoomName: room.userName,
              ),
            ),
          ).then((_) {
            // Refresh saat kembali dari chat room
            setState(() {});
          });
        },
      ),
    );
  }

  Color _getRoleColor(ChatRole role) {
    switch (role) {
      case ChatRole.superadmin:
        return Colors.red;
      case ChatRole.manager:
        return Colors.blue;
      case ChatRole.pengawas:
        return Colors.green;
      case ChatRole.officerSafety:
        return Colors.orange;
      case ChatRole.mitra:
        return Colors.purple;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (time.day == now.day - 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}h';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}