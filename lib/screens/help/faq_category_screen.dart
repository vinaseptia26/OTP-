import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'faq_detail_screen.dart';

class FAQCategoryScreen extends StatelessWidget {
  final String categoryName;

  const FAQCategoryScreen({
    super.key,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          categoryName,
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
      body: Column(
        children: [
          // Category Info
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3C72).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(categoryName),
                    color: const Color(0xFF1E3C72),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '12 pertanyaan umum',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search in Category
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari di $categoryName...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              itemBuilder: (context, index) {
                return _buildFAQItem(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FAQDetailScreen(
                faqData: {
                  'id': '$index',
                  'question': 'Contoh pertanyaan $categoryName nomor ${index + 1}?',
                  'answer': 'Ini adalah jawaban dari pertanyaan tersebut. Jawaban bisa berisi penjelasan detail, langkah-langkah, atau informasi lainnya yang relevan dengan pertanyaan.',
                  'category': categoryName,
                  'views': 150 - index,
                  'isHelpful': true,
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pertanyaan ${index + 1}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ini adalah contoh pertanyaan umum tentang $categoryName...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${150 - index} views',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.thumb_up, size: 12, color: Colors.green[300]),
                        const SizedBox(width: 4),
                        Text(
                          '${50 + index}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.green[300],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'akun & profil':
        return Icons.account_circle;
      case 'pembayaran':
        return Icons.payment;
      case 'pengiriman':
        return Icons.delivery_dining;
      case 'teknis':
        return Icons.computer;
      default:
        return Icons.help;
    }
  }
}