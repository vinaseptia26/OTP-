// lib/screens/faq/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/faq_model_service.dart';
import 'faq_detail_screen.dart';
import 'add_faq_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_room_screen.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart'; // 🔥 Import Bottom Nav

class FAQScreen extends StatefulWidget {
  final bool isSuperAdmin;

  const FAQScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> with TickerProviderStateMixin {
  final FAQChatService _faqChatService = FAQChatService();
  final TextEditingController _searchController = TextEditingController();
  
  TabController? _tabController;
  String _searchQuery = '';
  List<String> _categories = ['Semua'];
  bool _isSuperAdmin = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkUserRole();
    _loadCategories();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final isAdmin = await _faqChatService.faqService.isCurrentUserSuperAdmin();
      if (mounted) {
        setState(() {
          _isSuperAdmin = isAdmin || widget.isSuperAdmin;
        });
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      if (mounted) {
        setState(() {
          _isSuperAdmin = widget.isSuperAdmin;
        });
      }
    }
  }

  void _loadCategories() {
    try {
      _faqChatService.faqService.getCategoriesStream().listen(
        (categories) {
          if (mounted) {
            _tabController?.dispose();
            setState(() {
              _categories = categories.isEmpty ? ['Semua'] : categories;
              _tabController = TabController(
                length: _categories.length,
                vsync: this,
              );
            });
          }
        },
        onError: (error) {
          debugPrint('Error loading categories: $error');
          if (mounted) {
            setState(() {
              _categories = ['Semua'];
              _tabController?.dispose();
              _tabController = TabController(length: 1, vsync: this);
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error in _loadCategories: $e');
      if (mounted) {
        setState(() {
          _categories = ['Semua'];
          _tabController = TabController(length: 1, vsync: this);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startChatIfNotFound(String question) async {
    try {
      final chatRoomId = await _faqChatService.autoCreateChatIfNeeded(question);
      
      if (chatRoomId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(chatRoomId: chatRoomId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai chat: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Loading screen dengan Bottom Nav
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: const SuperAdminBottomNav(currentIndex: 0), // 🔥 Tambahin
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF1E3C72),
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat FAQ...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const SuperAdminBottomNav(currentIndex: 0), // 🔥 Tambahin
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
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
        actions: [
          // Chat button
          StreamBuilder<int>(
            stream: Stream.fromFuture(
              _faqChatService.chatService.getTotalUnreadCount().catchError((e) {
                debugPrint('Error getting unread count: $e');
                return 0;
              }),
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Add FAQ button for superadmin only
          if (_isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFAQScreen(
                      faqService: _faqChatService.faqService,
                    ),
                  ),
                );
              },
            ),
        ],
        bottom: _tabController != null && _categories.length > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: _categories.map((cat) {
                  return Tab(
                    child: Text(
                      cat,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
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
                        _searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _startChatIfNotFound(value);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari pertanyaan atau tanyakan sesuatu...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _startChatIfNotFound(_searchQuery),
                    icon: const Icon(Icons.chat),
                    tooltip: 'Tanyakan via Chat',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : _buildCategoryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent() {
    if (_categories.length <= 1 || _tabController == null) {
      return _buildFAQList(null);
    }

    return TabBarView(
      controller: _tabController,
      children: _categories.map((category) {
        return _buildFAQList(category == 'Semua' ? null : category);
      }).toList(),
    );
  }

  Widget _buildFAQList(String? category) {
    Stream<List<FAQModel>> faqStream;
    
    try {
      if (category != null) {
        faqStream = _faqChatService.faqService.getFAQsByCategoryStream(category);
      } else {
        faqStream = _faqChatService.faqService.getPopularFAQsStream();
      }
    } catch (e) {
      debugPrint('Error getting FAQ stream: $e');
      return _buildErrorWidget(e.toString());
    }

    return StreamBuilder<List<FAQModel>>(
      stream: faqStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF1E3C72),
                ),
                const SizedBox(height: 16),
                Text(
                  'Memuat pertanyaan...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Stream error: ${snapshot.error}');
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyWidget(category);
        }

        final faqs = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: category == null ? faqs.length + 1 : faqs.length,
          itemBuilder: (context, index) {
            if (category == null && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pertanyaan Populer',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            final faqIndex = category == null ? index - 1 : index;
            if (faqIndex >= 0 && faqIndex < faqs.length) {
              return _buildFAQItem(faqs[faqIndex]);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<FAQModel>>(
      stream: _faqChatService.faqService.searchFAQsStream(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E3C72)),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        final faqs = snapshot.data ?? [];

        if (faqs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada hasil untuk "$_searchQuery"',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _startChatIfNotFound(_searchQuery),
                    icon: const Icon(Icons.chat),
                    label: const Text('Tanyakan via Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${faqs.length} hasil untuk "$_searchQuery"',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _startChatIfNotFound(_searchQuery),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Tidak membantu? Chat'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: faqs.length,
                itemBuilder: (context, index) => _buildFAQItem(faqs[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFAQItem(FAQModel faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _faqChatService.faqService.incrementView(faq.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FAQDetailScreen(
                faqData: faq,
                isSuperAdmin: _isSuperAdmin,
                faqService: _faqChatService.faqService,
                chatService: _faqChatService.chatService,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isSuperAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleFAQAction(value, faq),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCategoryChip(faq.category),
                  const SizedBox(width: 8),
                  _buildStatItem(Icons.remove_red_eye, '${faq.views}', Colors.grey),
                  if (faq.helpfulBy.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildStatItem(Icons.thumb_up, '${faq.helpfulBy.length}', Colors.green),
                  ],
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: const Color(0xFF1E3C72),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 10, color: color),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Terjadi kesalahan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isInitialized = false;
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

  Widget _buildEmptyWidget(String? category) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_answer_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              category != null
                  ? 'Belum ada FAQ untuk kategori $category'
                  : 'Belum ada pertanyaan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_isSuperAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddFAQScreen(
                        faqService: _faqChatService.faqService,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah FAQ'),
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

  void _handleFAQAction(String action, FAQModel faq) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddFAQScreen(
              faqService: _faqChatService.faqService,
              faqToEdit: faq,
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(faq);
        break;
    }
  }

  void _showDeleteConfirmation(FAQModel faq) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus FAQ'),
        content: Text('Apakah Anda yakin ingin menghapus FAQ "${faq.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _faqChatService.faqService.deactivateFAQ(faq.id);
                if (mounted) {
                  Navigator.pop(context);
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