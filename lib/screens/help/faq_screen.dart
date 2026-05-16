import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'faq_detail_screen.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  // Sample FAQ data - nanti diganti dengan data dari Firebase
  final List<Map<String, dynamic>> popularFAQs = [
    {
      'id': '1',
      'question': 'Bagaimana cara mengganti password?',
      'answer': 'Anda dapat mengganti password melalui menu Profil > Pengaturan > Ubah Password. Masukkan password lama Anda, kemudian password baru dua kali untuk konfirmasi.',
      'category': 'Akun & Profil',
      'views': 1234,
      'isHelpful': true,
    },
    {
      'id': '2',
      'question': 'Cara melakukan top up saldo',
      'answer': 'Untuk melakukan top up saldo, buka menu Dompet > Top Up. Pilih metode pembayaran yang tersedia (transfer bank, e-wallet, atau kartu kredit) dan ikuti instruksi selanjutnya.',
      'category': 'Pembayaran',
      'views': 987,
      'isHelpful': true,
    },
    {
      'id': '3',
      'question': 'Kapan dana akan masuk setelah transfer?',
      'answer': 'Dana biasanya akan masuk dalam waktu 1x24 jam setelah pembayaran berhasil. Untuk transfer antar bank, proses bisa memakan waktu hingga 2 jam.',
      'category': 'Pembayaran',
      'views': 876,
      'isHelpful': true,
    },
  ];

  final List<Map<String, dynamic>> categories = [
    {'name': 'Semua', 'icon': Icons.list},
    {'name': 'Akun & Profil', 'icon': Icons.account_circle},
    {'name': 'Pembayaran', 'icon': Icons.payment},
    {'name': 'Pengiriman', 'icon': Icons.delivery_dining},
    {'name': 'Teknis', 'icon': Icons.computer},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: categories.map((cat) {
            return Tab(
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, size: 16),
                  const SizedBox(width: 4),
                  Text(cat['name'] as String),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari pertanyaan...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Popular FAQs
          if (searchQuery.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.orange, size: 20),
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
                  const SizedBox(height: 12),
                  ...popularFAQs.map((faq) {
                    return _buildFAQItem(faq);
                  }).toList(),
                ],
              ),
            ),

          // FAQ List by Category
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categories.map((cat) {
                if (cat['name'] == 'Semua') {
                  return _buildAllFAQs();
                } else {
                  return _buildCategoryFAQs(cat['name'] as String);
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(Map<String, dynamic> faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FAQDetailScreen(faqData: faq),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                faq['question'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      faq['category'],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: const Color(0xFF1E3C72),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.remove_red_eye, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${faq['views']}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
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

  Widget _buildAllFAQs() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Semua Pertanyaan',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(20, (index) {
          return _buildFAQItem({
            'id': '$index',
            'question': 'Contoh pertanyaan FAQ $index?',
            'category': index % 2 == 0 ? 'Akun & Profil' : 'Pembayaran',
            'views': 100 + index,
          });
        }),
      ],
    );
  }

  Widget _buildCategoryFAQs(String category) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'FAQ - $category',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(10, (index) {
          return _buildFAQItem({
            'id': '$index',
            'question': 'Pertanyaan tentang $category nomor ${index + 1}?',
            'category': category,
            'views': 50 + index,
          });
        }),
      ],
    );
  }
}