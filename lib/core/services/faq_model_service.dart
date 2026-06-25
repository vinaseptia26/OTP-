// lib/models/faq_model_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// ENUM & DATA CLASSES
// ============================================================

enum ChatRole {
  superadmin,
  manager,
  pengawas,
  mitra,
  officerSafety;

  String get label {
    switch (this) {
      case ChatRole.superadmin:
        return 'Super Admin';
      case ChatRole.manager:
        return 'Manager';
      case ChatRole.pengawas:
        return 'Pengawas';
      case ChatRole.mitra:
        return 'Mitra';
      case ChatRole.officerSafety:
        return 'Officer Safety';
    }
  }

  static ChatRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return ChatRole.superadmin;
      case 'manager':
        return ChatRole.manager;
      case 'pengawas':
        return ChatRole.pengawas;
      case 'mitra':
        return ChatRole.mitra;
      case 'officer_safety':
      case 'officersafety':
        return ChatRole.officerSafety;
      default:
        return ChatRole.mitra;
    }
  }
}

enum MessageType {
  text,
  image,
  file;

  static MessageType fromString(String type) {
    switch (type) {
      case 'MessageType.image':
        return MessageType.image;
      case 'MessageType.file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}

// ============================================================
// FAQ MODEL
// ============================================================

class FAQModel {
  final String id;
  final String question;
  final String answer;
  final String category;
  final int views;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> helpfulBy;
  final List<String> notHelpfulBy;

  FAQModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.views = 0,
    this.isActive = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? helpfulBy,
    List<String>? notHelpfulBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        helpfulBy = helpfulBy ?? [],
        notHelpfulBy = notHelpfulBy ?? [];

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'views': views,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'helpfulBy': helpfulBy,
      'notHelpfulBy': notHelpfulBy,
    };
  }

  factory FAQModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FAQModel(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      category: data['category'] ?? 'Umum',
      views: data['views'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      helpfulBy: List<String>.from(data['helpfulBy'] ?? []),
      notHelpfulBy: List<String>.from(data['notHelpfulBy'] ?? []),
    );
  }

  FAQModel copyWith({
    String? id,
    String? question,
    String? answer,
    String? category,
    int? views,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? helpfulBy,
    List<String>? notHelpfulBy,
  }) {
    return FAQModel(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      views: views ?? this.views,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulBy: helpfulBy ?? this.helpfulBy,
      notHelpfulBy: notHelpfulBy ?? this.notHelpfulBy,
    );
  }
}

// ============================================================
// CHAT MESSAGE MODEL
// ============================================================

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final ChatRole senderRole;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? fileUrl;
  final String? fileName;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    DateTime? timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.fileUrl,
    this.fileName,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type.name,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: ChatRole.fromString(data['senderRole'] ?? 'mitra'),
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: MessageType.fromString(data['type'] ?? 'text'),
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
    );
  }
}

// ============================================================
// CHAT ROOM MODEL
// ============================================================

class ChatRoom {
  final String id;
  final String userId;
  final String userName;
  final ChatRole userRole;
  final String userFunction;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.userFunction = '',
    this.lastMessage,
    this.unreadCount = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole.name,
      'userFunction': userFunction,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userRole: ChatRole.fromString(data['userRole'] ?? 'mitra'),
      userFunction: data['userFunction'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============================================================
// FAQ SERVICE
// ============================================================

class FAQService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _faqCollection =>
      _firestore.collection('faq');

  // Get all active FAQs with real-time updates
  Stream<List<FAQModel>> getFAQsStream() {
    return _faqCollection
        .where('isActive', isEqualTo: true)
        .orderBy('views', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FAQModel.fromFirestore(doc)).toList());
  }

  // Get FAQs by category
  Stream<List<FAQModel>> getFAQsByCategoryStream(String category) {
    Query<Map<String, dynamic>> query = _faqCollection.where('isActive', isEqualTo: true);

    if (category != 'Semua') {
      query = query.where('category', isEqualTo: category);
    }

    return query
        .orderBy('views', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FAQModel.fromFirestore(doc)).toList());
  }

  // Search FAQs
  Stream<List<FAQModel>> searchFAQsStream(String query) {
    final searchQuery = query.toLowerCase();
    return _faqCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FAQModel.fromFirestore(doc))
          .where((faq) =>
              faq.question.toLowerCase().contains(searchQuery) ||
              faq.answer.toLowerCase().contains(searchQuery))
          .toList();
    });
  }

  // Get popular FAQs
  Stream<List<FAQModel>> getPopularFAQsStream() {
    return _faqCollection
        .where('isActive', isEqualTo: true)
        .orderBy('views', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FAQModel.fromFirestore(doc)).toList());
  }

  // Get all categories
  Stream<List<String>> getCategoriesStream() {
    return _faqCollection.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['category'] as String?;
          })
          .where((category) => category != null && category.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return ['Semua', ...categories.cast<String>()];
    });
  }

  // Add new FAQ (SuperAdmin only - sesuai Firebase rules)
  Future<void> addFAQ(FAQModel faq) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');

      await _faqCollection.add(faq.toMap());
      
      // Log aktivitas
      await _firestore.collection('activity_logs').add({
        'action': 'create_faq',
        'userId': user.uid,
        'faqQuestion': faq.question,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menambahkan FAQ: $e');
    }
  }

  // Update FAQ (SuperAdmin only)
  Future<void> updateFAQ(FAQModel faq) async {
    try {
      await _faqCollection.doc(faq.id).update({
        ...faq.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal mengupdate FAQ: $e');
    }
  }

  // Delete/Deactivate FAQ (SuperAdmin only)
  Future<void> deactivateFAQ(String faqId) async {
    try {
      await _faqCollection.doc(faqId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menghapus FAQ: $e');
    }
  }

  // Permanent delete FAQ (SuperAdmin only)
  Future<void> deleteFAQ(String faqId) async {
    try {
      await _faqCollection.doc(faqId).delete();
    } catch (e) {
      throw Exception('Gagal menghapus permanen FAQ: $e');
    }
  }

  // Increment view count
  Future<void> incrementView(String faqId) async {
    try {
      await _faqCollection.doc(faqId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      // Silent fail for view increment
      print('Error incrementing view: $e');
    }
  }

  // Mark as helpful
  Future<void> markAsHelpful(String faqId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _faqCollection.doc(faqId).update({
        'helpfulBy': FieldValue.arrayUnion([user.uid]),
        'notHelpfulBy': FieldValue.arrayRemove([user.uid]),
      });
    } catch (e) {
      throw Exception('Gagal menandai sebagai membantu: $e');
    }
  }

  // Mark as not helpful
  Future<void> markAsNotHelpful(String faqId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _faqCollection.doc(faqId).update({
        'notHelpfulBy': FieldValue.arrayUnion([user.uid]),
        'helpfulBy': FieldValue.arrayRemove([user.uid]),
      });
    } catch (e) {
      throw Exception('Gagal menandai sebagai tidak membantu: $e');
    }
  }

  // Check if current user is SuperAdmin
  Future<bool> isCurrentUserSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['role'] == 'superadmin';
    } catch (e) {
      return false;
    }
  }
}

// ============================================================
// CHAT SERVICE
// ============================================================

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chatRoomsCollection =>
      _firestore.collection('chat_rooms');

  CollectionReference<Map<String, dynamic>> _messagesCollection(String chatRoomId) =>
      _chatRoomsCollection.doc(chatRoomId).collection('messages');

  // Get current user role
  Future<ChatRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return ChatRole.mitra;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'] ?? 'mitra';
      return ChatRole.fromString(role);
    } catch (e) {
      return ChatRole.mitra;
    }
  }

  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data();
    } catch (e) {
      return null;
    }
  }

  // Get user's chat rooms with real-time updates
  Stream<List<ChatRoom>> getUserChatRoomsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _chatRoomsCollection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatRoom> rooms = [];
      for (var doc in snapshot.docs) {
        final lastMessage = await _getLastMessage(doc.id);
        final unreadCount = await _getUnreadCount(doc.id);
        final room = ChatRoom.fromFirestore(doc);
        rooms.add(ChatRoom(
          id: room.id,
          userId: room.userId,
          userName: room.userName,
          userRole: room.userRole,
          userFunction: room.userFunction,
          lastMessage: lastMessage,
          unreadCount: unreadCount,
          isActive: room.isActive,
          createdAt: room.createdAt,
          updatedAt: room.updatedAt,
        ));
      }
      return rooms;
    });
  }

  // Get admin chat rooms (for superadmin/manager/pengawas/officer_safety)
  Stream<List<ChatRoom>> getAdminChatRoomsStream() {
    return _chatRoomsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatRoom> rooms = [];
      for (var doc in snapshot.docs) {
        final lastMessage = await _getLastMessage(doc.id);
        final unreadCount = await _getUnreadCount(doc.id);
        final room = ChatRoom.fromFirestore(doc);
        rooms.add(ChatRoom(
          id: room.id,
          userId: room.userId,
          userName: room.userName,
          userRole: room.userRole,
          userFunction: room.userFunction,
          lastMessage: lastMessage,
          unreadCount: unreadCount,
          isActive: room.isActive,
          createdAt: room.createdAt,
          updatedAt: room.updatedAt,
        ));
      }
      return rooms;
    });
  }

  // Create new chat room
  Future<String> createChatRoom({
    required String userId,
    required String userName,
    required ChatRole userRole,
    String userFunction = '',
  }) async {
    try {
      // Check if room already exists
      final existingRoom = await _chatRoomsCollection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (existingRoom.docs.isNotEmpty) {
        return existingRoom.docs.first.id;
      }

      final roomData = {
        'userId': userId,
        'userName': userName,
        'userRole': userRole.name,
        'userFunction': userFunction,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _chatRoomsCollection.add(roomData);
      
      // Send welcome message
      await _messagesCollection(docRef.id).add({
        'chatRoomId': docRef.id,
        'senderId': 'system',
        'senderName': 'System',
        'senderRole': 'system',
        'message': 'Selamat datang di chat support! Silakan sampaikan pertanyaan Anda.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      });
      
      return docRef.id;
    } catch (e) {
      throw Exception('Gagal membuat chat room: $e');
    }
  }

  // Send message
  Future<void> sendMessage({
    required String chatRoomId,
    required String message,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');

      final userInfo = await getCurrentUserInfo();
      final role = await getCurrentUserRole();

      final messageData = {
        'chatRoomId': chatRoomId,
        'senderId': user.uid,
        'senderName': userInfo?['nama_lengkap'] ?? user.displayName ?? 'Unknown',
        'senderRole': role.name,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type.name,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
      };

      await _messagesCollection(chatRoomId).add(messageData);
      
      // Update chat room timestamp
      await _chatRoomsCollection.doc(chatRoomId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to admin if sender is mitra
      if (role == ChatRole.mitra) {
        await _sendNotificationToAdmins(chatRoomId, message);
      }
    } catch (e) {
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // Get messages stream for a specific chat room
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    return _messagesCollection(chatRoomId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final batch = _firestore.batch();
      final unreadMessages = await _messagesCollection(chatRoomId)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get total unread messages across all chat rooms
  Future<int> getTotalUnreadCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    try {
      final chatRooms = await _chatRoomsCollection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      int totalUnread = 0;
      for (var room in chatRooms.docs) {
        final unread = await _messagesCollection(room.id)
            .where('isRead', isEqualTo: false)
            .where('senderId', isNotEqualTo: userId)
            .count()
            .get();
        totalUnread += unread.count ?? 0;
      }
      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  // Deactivate chat room
  Future<void> deactivateChatRoom(String chatRoomId) async {
    try {
      await _chatRoomsCollection.doc(chatRoomId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menonaktifkan chat room: $e');
    }
  }

  // Private methods
  Future<ChatMessage?> _getLastMessage(String chatRoomId) async {
    try {
      final messages = await _messagesCollection(chatRoomId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messages.docs.isEmpty) return null;
      return ChatMessage.fromFirestore(messages.docs.first);
    } catch (e) {
      return null;
    }
  }

  Future<int> _getUnreadCount(String chatRoomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final unread = await _messagesCollection(chatRoomId)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .count()
          .get();
      
      return unread.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _sendNotificationToAdmins(String chatRoomId, String message) async {
    try {
      // Get admins (superadmin, manager, pengawas, officer_safety)
      final admins = await _firestore
          .collection('users')
          .where('role', whereIn: ['superadmin', 'manager', 'pengawas', 'officer_safety'])
          .get();

      final notificationData = {
        'title': 'Pesan Baru dari Mitra',
        'message': message.length > 100 ? '${message.substring(0, 100)}...' : message,
        'type': 'chat',
        'chatRoomId': chatRoomId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      for (var admin in admins.docs) {
        await _firestore
            .collection('notifications')
            .add({
              ...notificationData,
              'userId': admin.id,
            });
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

// ============================================================
// COMBINED SERVICE PROVIDER
// ============================================================

class FAQChatService {
  final FAQService faqService = FAQService();
  final ChatService chatService = ChatService();

  // Check if question exists in FAQ, if not, suggest chat
  Future<Map<String, dynamic>> findAnswerOrSuggestChat(String question) async {
    try {
      // Search in FAQ
      final faqs = await FAQService()._faqCollection
          .where('isActive', isEqualTo: true)
          .get();

      final results = faqs.docs
          .map((doc) => FAQModel.fromFirestore(doc))
          .where((faq) =>
              faq.question.toLowerCase().contains(question.toLowerCase()) ||
              question.toLowerCase().contains(faq.question.toLowerCase()))
          .toList();

      return {
        'found': results.isNotEmpty,
        'faqs': results,
        'suggestChat': results.isEmpty,
      };
    } catch (e) {
      return {
        'found': false,
        'faqs': [],
        'suggestChat': true,
      };
    }
  }

  // Auto-create chat if question not found in FAQ
  Future<String?> autoCreateChatIfNeeded(String question) async {
    final result = await findAnswerOrSuggestChat(question);
    
    if (result['suggestChat'] == true) {
      final user = chatService._auth.currentUser;
      final userInfo = await chatService.getCurrentUserInfo();
      
      if (user != null && userInfo != null) {
        final role = await chatService.getCurrentUserRole();
        return await chatService.createChatRoom(
          userId: user.uid,
          userName: userInfo['nama_lengkap'] ?? 'Unknown',
          userRole: role,
          userFunction: userInfo['fungsi'] ?? '',
        );
      }
    }
    
    return null;
  }
}