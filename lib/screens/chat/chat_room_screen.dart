// lib/screens/chat/chat_room_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '/core/services/faq_model_service.dart';
import '/core/services/location_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String? chatRoomName;

  const ChatRoomScreen({super.key, required this.chatRoomId, this.chatRoomName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  String _chatRoomName = '';
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Map<String, dynamic>? _chatRoomData;
  Map<String, dynamic>? _recipientUserData;
  bool _showScrollButton = false;
  String? _currentUserId;
  bool _isNearBottom = true; // 🔥 Track posisi scroll

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = _auth.currentUser?.uid;
    _loadChatRoomInfo();
    _loadRecipientInfo();
    _markMessagesAsRead();

    _scrollController.addListener(() {
      if (_scrollController.hasClients && mounted) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        // 🔥 Tampilkan tombol scroll jika tidak di bawah
        setState(() {
          _showScrollButton = (maxScroll - currentScroll) > 200;
          _isNearBottom = (maxScroll - currentScroll) < 50;
        });
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markMessagesAsRead();
  }

  Future<void> _loadChatRoomInfo() async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId).get();
      if (roomDoc.exists && mounted) {
        final data = roomDoc.data();
        setState(() {
          _chatRoomData = data;
          _chatRoomName = widget.chatRoomName ?? data?['userName'] ?? 'Chat';
          _isLoading = false;
        });
      } else {
        setState(() { _chatRoomName = widget.chatRoomName ?? 'Chat'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Gagal memuat info chat'; _chatRoomName = widget.chatRoomName ?? 'Chat'; _isLoading = false; });
    }
  }

  Future<void> _loadRecipientInfo() async {
    try {
      if (_chatRoomData == null) return;
      final recipientId = _chatRoomData!['userId'];
      if (recipientId == null || recipientId == _currentUserId) return;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
      if (userDoc.exists && mounted) setState(() => _recipientUserData = userDoc.data());
    } catch (e) { debugPrint('Error loading recipient: $e'); }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.chatRoomId);
  }

  bool _canAccessChat() {
    if (_chatRoomData == null) return false;
    final userRole = _chatRoomData!['userRole']?.toString() ?? '';
    if (['superadmin', 'manager', 'pengawas', 'officer_safety'].contains(userRole)) return true;
    return _chatRoomData!['userId'] == _currentUserId;
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    if (!_canAccessChat()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akses ditolak'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(chatRoomId: widget.chatRoomId, message: message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSending = false); }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (image == null) return;
      await _chatService.sendMessage(chatRoomId: widget.chatRoomId, message: '📷 Gambar', type: MessageType.image, fileUrl: image.path, fileName: image.name);
      _scrollToBottom();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gambar terkirim'), backgroundColor: Colors.green));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red)); }
  }

  Future<void> _takeAndSendPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (photo == null) return;
      await _chatService.sendMessage(chatRoomId: widget.chatRoomId, message: '📸 Foto', type: MessageType.image, fileUrl: photo.path, fileName: photo.name);
      _scrollToBottom();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Foto terkirim'), backgroundColor: Colors.green));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red)); }
  }

  // 🔥 SCROLL KE BAWAH (PALING BAWAH)
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makePhoneCall() async {
    if (_recipientUserData == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data kontak tidak tersedia'))); return; }
    final phoneNumber = _recipientUserData!['phone'] ?? _recipientUserData!['no_hp'] ?? '';
    if (phoneNumber.toString().isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor tidak tersedia'))); return; }
    _showCallConfirmation(phoneNumber.toString());
  }

  void _showCallConfirmation(String phoneNumber) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [const Icon(Icons.call, color: Color(0xFF4CAF50), size: 24), const SizedBox(width: 12), Text('Panggil ${_chatRoomName}?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text(phoneNumber, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 8), Text('Pastikan Anda memiliki izin.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _launchPhoneCall(phoneNumber); }, icon: const Icon(Icons.call, size: 18), label: const Text('Panggil'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))],
    ));
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber.replaceAll(RegExp(r'[^0-9+]'), ''));
    try { if (await canLaunchUrl(phoneUri)) { await launchUrl(phoneUri); } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat menelepon'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); }
  }

  void _reportRisk() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReportRiskSheet(chatRoomId: widget.chatRoomId, chatRoomName: _chatRoomName, recipientData: _recipientUserData),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: const Color(0xFFF0F2F5), appBar: _buildAppBar(), body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E3C72))));
    if (_errorMessage != null) return Scaffold(backgroundColor: const Color(0xFFF0F2F5), appBar: _buildAppBar(), body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage!, textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton.icon(onPressed: () { setState(() { _isLoading = true; _errorMessage = null; }); _loadChatRoomInfo(); }, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi'))]))));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              if (_chatRoomData != null) _buildSecurityBadge(),
              Expanded(child: _buildMessagesList()),
              _buildInputBar(),
            ],
          ),
          // 🔥 Tombol scroll ke bawah
          if (_showScrollButton)
            Positioned(
              right: 16,
              bottom: 80,
              child: _buildScrollToBottomButton(),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
      title: GestureDetector(
        onTap: _showChatInfo,
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _chatRoomData != null ? _getRoleColor(ChatRole.fromString(_chatRoomData!['userRole'] ?? 'mitra')) : const Color(0xFF1E3C72), child: Text(_chatRoomName.isNotEmpty ? _chatRoomName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_chatRoomName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
            if (_chatRoomData != null) Text(_getRoleLabel(_chatRoomData!['userRole'] ?? ''), style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          ])),
        ]),
      ),
      backgroundColor: const Color(0xFF1E3C72), foregroundColor: Colors.white, elevation: 1,
      actions: [
        IconButton(icon: const Icon(Icons.warning_amber_outlined, size: 22, color: Colors.orangeAccent), onPressed: _reportRisk, tooltip: 'Lapor Risiko'),
        IconButton(icon: const Icon(Icons.call_outlined, size: 22), onPressed: _makePhoneCall, tooltip: 'Panggil'),
      ],
    );
  }

  Widget _buildSecurityBadge() {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: Colors.white, child: Row(children: [
      _buildBadge(Icons.shield_outlined, _getRoleLabel(_chatRoomData!['userRole'] ?? ''), _getRoleColor(ChatRole.fromString(_chatRoomData!['userRole'] ?? 'mitra'))),
      const SizedBox(width: 6),
      _buildBadge(Icons.lock_outlined, 'Terenskripsi', Colors.green),
      const Spacer(),
      if (_recipientUserData != null && _recipientUserData!['isOnline'] == true)
        Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)), const SizedBox(width: 4), Text('Online', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF4CAF50)))]),
    ]));
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 10, color: color), const SizedBox(width: 4), Text(text, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color))]));
  }

  // 🔥 MESSAGES LIST - PESAN BARU DI BAWAH
  Widget _buildMessagesList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessagesStream(widget.chatRoomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3C72)));
        if (snapshot.hasError) return Center(child: Text('Gagal memuat pesan', style: GoogleFonts.poppins(fontSize: 14)));

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) return _buildEmptyChat();

        // 🔥 Sort by timestamp ASCENDING (terlama di atas, terbaru di bawah)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return GestureDetector(
          onTap: () => _focusNode.unfocus(),
          child: ListView.builder(
            controller: _scrollController,
            // 🔥 TIDAK PAKAI reverse: true - agar pesan baru di bawah
            reverse: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              final isMe = m.senderId == _currentUserId;
              final showAvatar = index == 0 || messages[index - 1].senderId != m.senderId;
              final showDate = index == 0 || (index > 0 && messages[index - 1].timestamp.day != m.timestamp.day);
              return Column(children: [
                if (showDate) _buildDateSeparator(m.timestamp),
                _buildChatBubble(m, isMe, showAvatar),
              ]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF1E3C72).withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFF1E3C72))),
      const SizedBox(height: 20), Text('Percakapan Aman', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 8), Text('Kirim pesan atau gambar untuk memulai.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
    ])));
  }

  Widget _buildChatBubble(ChatMessage message, bool isMe, bool showAvatar) {
    if (message.senderId == 'system') return _buildSystemMessage(message);
    final showName = !isMe && showAvatar;
    final isImage = message.type == MessageType.image && message.fileUrl != null;

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 12 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[_buildAvatar(message.senderName, message.senderRole, 16), const SizedBox(width: 8)]
          else if (!isMe) const SizedBox(width: 32),
          Flexible(
            child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (showName) Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: Text(message.senderName, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _getRoleColor(message.senderRole)))),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: isImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1E3C72) : Colors.white,
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
                ),
                clipBehavior: Clip.antiAlias,
                child: isImage
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18)), child: Image.file(File(message.fileUrl!), fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))))),
                        Padding(padding: const EdgeInsets.all(10), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatMessageTime(message.timestamp), style: GoogleFonts.poppins(fontSize: 9.5, color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey[500])), if (isMe) ...[const SizedBox(width: 4), Icon(message.isRead ? Icons.done_all : Icons.done, size: 13, color: message.isRead ? const Color(0xFF82B1FF) : Colors.white.withValues(alpha: 0.7))]])),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(message.message, style: GoogleFonts.poppins(fontSize: 13.5, color: isMe ? Colors.white : const Color(0xFF1A1A1A), height: 1.5)),
                        const SizedBox(height: 2),
                        Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatMessageTime(message.timestamp), style: GoogleFonts.poppins(fontSize: 9.5, color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey[500])), if (isMe) ...[const SizedBox(width: 4), Icon(message.isRead ? Icons.done_all : Icons.done, size: 13, color: message.isRead ? const Color(0xFF82B1FF) : Colors.white.withValues(alpha: 0.7))]]),
                      ]),
              ),
            ]),
          ),
          if (isMe && showAvatar) ...[const SizedBox(width: 8), _buildAvatar(message.senderName, message.senderRole, 16)]
          else if (isMe) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, ChatRole role, double size) => Container(width: size * 2, height: size * 2, decoration: BoxDecoration(color: _getRoleColor(role), shape: BoxShape.circle), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.7))));

  Widget _buildSystemMessage(ChatMessage message) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 14, color: Colors.grey), const SizedBox(width: 6), Flexible(child: Text(message.message, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center))]))));

  Widget _buildDateSeparator(DateTime date) {
    String dateText;
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) dateText = 'Hari ini';
    else if (date.day == now.day - 1 && date.month == now.month) dateText = 'Kemarin';
    else dateText = '${date.day}/${date.month}/${date.year}';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(children: [Expanded(child: Container(height: 0.5, color: Colors.grey[300])), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Text(dateText, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)))), Expanded(child: Container(height: 0.5, color: Colors.grey[300]))]));
  }

  Widget _buildScrollToBottomButton() => GestureDetector(
    onTap: _scrollToBottom,
    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1E3C72), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]), child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24)),
  );

  Widget _buildInputBar() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -1), blurRadius: 4)]), child: SafeArea(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IconButton(icon: const Icon(Icons.image_outlined, color: Color(0xFF1E3C72), size: 22), onPressed: _pickAndSendImage, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), tooltip: 'Gambar'),
      IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E3C72), size: 22), onPressed: _takeAndSendPhoto, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), tooltip: 'Kamera'),
      Expanded(child: Container(constraints: const BoxConstraints(maxHeight: 100), decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)), child: TextField(controller: _messageController, focusNode: _focusNode, maxLines: 4, minLines: 1, textInputAction: TextInputAction.newline, enabled: !_isSending, style: GoogleFonts.poppins(fontSize: 14), decoration: InputDecoration(hintText: 'Ketik pesan...', hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))))),
      const SizedBox(width: 4),
      Container(width: 38, height: 38, margin: const EdgeInsets.only(bottom: 2), decoration: BoxDecoration(color: _isSending ? Colors.grey[400] : const Color(0xFF1E3C72), shape: BoxShape.circle), child: IconButton(icon: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18), onPressed: _isSending ? null : _sendMessage, padding: EdgeInsets.zero)),
    ])));
  }

  void _showChatInfo() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 70, height: 70, decoration: BoxDecoration(color: _chatRoomData != null ? _getRoleColor(ChatRole.fromString(_chatRoomData!['userRole'] ?? 'mitra')) : const Color(0xFF1E3C72), shape: BoxShape.circle), child: Center(child: Text(_chatRoomName.isNotEmpty ? _chatRoomName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 12), Text(_chatRoomName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
      if (_chatRoomData != null) ...[const SizedBox(height: 12), _buildInfoRow('Role', _getRoleLabel(_chatRoomData!['userRole'] ?? '')), _buildInfoRow('Fungsi', _chatRoomData!['userFunction'] ?? '-'), if (_recipientUserData != null && _recipientUserData!['phone'] != null) _buildInfoRow('Telepon', _recipientUserData!['phone'].toString())],
      const SizedBox(height: 12), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.lock, size: 12, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text('Chat dienkripsi end-to-end.', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[700])))])),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _makePhoneCall(); }, icon: const Icon(Icons.call, size: 16), label: const Text('Hubungi'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
    ]))));
  }

  Widget _buildInfoRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [SizedBox(width: 70, child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))), Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)))]));

  Color _getRoleColor(ChatRole role) { switch (role) { case ChatRole.superadmin: return Colors.red; case ChatRole.manager: return Colors.blue; case ChatRole.pengawas: return Colors.green; case ChatRole.officerSafety: return Colors.orange; case ChatRole.mitra: return Colors.purple; } }
  String _getRoleLabel(String role) { try { return ChatRole.fromString(role).label; } catch (e) { return role; } }
  String _formatMessageTime(DateTime time) { final now = DateTime.now(); final diff = now.difference(time); if (diff.inMinutes < 1) return 'Baru saja'; if (diff.inMinutes < 60) return '${diff.inMinutes}m'; if (time.day == now.day) return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'; if (time.day == now.day - 1) return 'Kemarin'; return '${time.day}/${time.month}/${time.year}'; }
}

// 🔥 WIDGET LAPOR RISIKO (ringkas, tanpa perubahan besar)
class _ReportRiskSheet extends StatefulWidget {
  final String chatRoomId; final String chatRoomName; final Map<String, dynamic>? recipientData;
  const _ReportRiskSheet({required this.chatRoomId, required this.chatRoomName, this.recipientData});
  @override State<_ReportRiskSheet> createState() => _ReportRiskSheetState();
}

class _ReportRiskSheetState extends State<_ReportRiskSheet> {
  final _descController = TextEditingController();
  String _riskLevel = 'low'; String _location = ''; bool _isSubmitting = false;
  bool _isLoadingLocation = false; Map<String, dynamic>? _currentLocationData; String? _locationError;
  final _riskLevels = ['low', 'medium', 'high', 'critical'];
  final _locations = ['Area Sumur', 'Area Pipa', 'Workshop', 'Kantor', 'Laboratorium', 'Gudang', 'Jalan Akses', 'Area Produksi', 'Lainnya'];

  @override void initState() { super.initState(); _getCurrentLocation(); }
  @override void dispose() { _descController.dispose(); super.dispose(); }

  Future<void> _getCurrentLocation() async {
    setState(() { _isLoadingLocation = true; _locationError = null; });
    try {
      final position = await LocationService.getCurrentPosition(highAccuracy: true, timeout: const Duration(seconds: 10));
      final geocodeData = await LocationService.reverseGeocode(position.latitude, position.longitude);
      if (mounted) setState(() { _currentLocationData = {'lat': position.latitude, 'lng': position.longitude, 'address': geocodeData?['address'] ?? 'Lokasi tidak diketahui', 'distance_from_kantor': LocationService.getDistanceFromKantor(position.latitude, position.longitude), 'is_kantor': LocationService.isKantorLocation(position.latitude, position.longitude), 'maps_url': LocationService.getGoogleMapsUrl(position.latitude, position.longitude)}; _isLoadingLocation = false; });
    } catch (e) {
      if (mounted) setState(() { _locationError = 'Gagal: $e'; _isLoadingLocation = false; _currentLocationData = {'lat': LocationService.kantorLat, 'lng': LocationService.kantorLng, 'address': LocationService.alamatKantor, 'distance_from_kantor': 0.0, 'is_kantor': true, 'maps_url': LocationService.getGoogleMapsUrl(LocationService.kantorLat, LocationService.kantorLng)}; });
    }
  }

  Future<void> _openMaps() async {
    if (_currentLocationData == null) return;
    final Uri uri = Uri.parse(_currentLocationData!['maps_url'] as String);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); }
  }

  Future<void> _submitReport() async {
    if (_descController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deskripsi harus diisi'), backgroundColor: Colors.red)); return; }
    setState(() => _isSubmitting = true);
    try {
      final locData = _currentLocationData != null ? {'latitude': _currentLocationData!['lat'], 'longitude': _currentLocationData!['lng'], 'address': _currentLocationData!['address'], 'distance_from_kantor': _currentLocationData!['distance_from_kantor'], 'is_kantor': _currentLocationData!['is_kantor'], 'maps_url': _currentLocationData!['maps_url']} : null;
      await FirebaseFirestore.instance.collection('risk_reports').add({'chatRoomId': widget.chatRoomId, 'reportedBy': FirebaseAuth.instance.currentUser?.uid, 'reportedByName': FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown', 'relatedTo': widget.recipientData?['userId'], 'relatedToName': widget.chatRoomName, 'riskLevel': _riskLevel, 'location': _location, 'description': _descController.text.trim(), 'gps_location': locData, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
      final chatService = ChatService();
      final locInfo = _currentLocationData != null ? '\n📍 ${_currentLocationData!['address']}\n📏 ${LocationService.formatDistance(_currentLocationData!['distance_from_kantor'])}\n🗺️ ${_currentLocationData!['maps_url']}' : '';
      await chatService.sendMessage(chatRoomId: widget.chatRoomId, message: '⚠️ LAPORAN RISIKO\n📊 ${_riskLevel.toUpperCase()}\n🏭 ${_location.isNotEmpty ? _location : "N/A"}\n📝 ${_descController.text.trim()}$locInfo');
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Laporan terkirim'), backgroundColor: Colors.green)); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.warning_amber, color: Colors.orange, size: 22), const SizedBox(width: 8), Text('Lapor Risiko', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 4), Text('Terkait: ${widget.chatRoomName}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      const SizedBox(height: 16), Text('Level Risiko', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), const SizedBox(height: 6),
      Row(children: _riskLevels.map((level) { final isSel = _riskLevel == level; final Color c; final IconData ic; switch(level) { case 'low': c = Colors.green; ic = Icons.check_circle_outline; break; case 'medium': c = Colors.orange; ic = Icons.warning_amber; break; case 'high': c = Colors.red; ic = Icons.error_outline; break; default: c = Colors.purple; ic = Icons.dangerous; } return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: GestureDetector(onTap: () => setState(() => _riskLevel = level), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isSel ? c : c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.3))), child: Column(children: [Icon(ic, size: 18, color: isSel ? Colors.white : c), const SizedBox(height: 2), Text(level.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: isSel ? Colors.white : c))]))))); }).toList()),
      const SizedBox(height: 16), Text('Area Lokasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), const SizedBox(height: 6),
      Wrap(spacing: 4, runSpacing: 4, children: _locations.map((loc) => ChoiceChip(label: Text(loc, style: GoogleFonts.poppins(fontSize: 10)), selected: _location == loc, onSelected: (v) => setState(() => _location = v ? loc : ''), selectedColor: const Color(0xFF1E3C72).withValues(alpha: 0.15), avatar: _location == loc ? const Icon(Icons.check, size: 12, color: Color(0xFF1E3C72)) : null, visualDensity: VisualDensity.compact)).toList()),
      const SizedBox(height: 16),
      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withValues(alpha: 0.08))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.blue), const SizedBox(width: 4), Text('Lokasi GPS', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.blue[700])), const Spacer(), GestureDetector(onTap: _getCurrentLocation, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.refresh, size: 12, color: Colors.blue)))]),
        const SizedBox(height: 8),
        if (_isLoadingLocation) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_currentLocationData != null) ...[
          Text(_currentLocationData!['address'] ?? '', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${_currentLocationData!['lat']?.toStringAsFixed(6)}, ${_currentLocationData!['lng']?.toStringAsFixed(6)}', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Row(children: [Icon(_currentLocationData!['is_kantor'] == true ? Icons.business : Icons.location_city, size: 10, color: _currentLocationData!['is_kantor'] == true ? Colors.green : Colors.orange), const SizedBox(width: 4), Text(_currentLocationData!['is_kantor'] == true ? 'Kantor PGE' : '${LocationService.formatDistance(_currentLocationData!['distance_from_kantor'])}', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[600]))]),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _openMaps, icon: const Icon(Icons.map_outlined, size: 14), label: Text('Google Maps', style: GoogleFonts.poppins(fontSize: 10)), style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), padding: const EdgeInsets.symmetric(vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), minimumSize: Size.zero))),
        ],
      ])),
      const SizedBox(height: 16),
      Text('Deskripsi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), const SizedBox(height: 6),
      TextField(controller: _descController, maxLines: 3, style: GoogleFonts.poppins(fontSize: 12), decoration: InputDecoration(hintText: 'Jelaskan risiko...', hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey[50], contentPadding: const EdgeInsets.all(10), isDense: true)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isSubmitting ? null : _submitReport, icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 16), label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Laporan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      const SizedBox(height: 8),
    ])));
  }
}