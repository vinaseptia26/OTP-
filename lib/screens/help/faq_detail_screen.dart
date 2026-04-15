import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQDetailScreen extends StatefulWidget {
  final Map<String, dynamic> faqData;

  const FAQDetailScreen({
    super.key,
    required this.faqData,
  });

  @override
  State<FAQDetailScreen> createState() => _FAQDetailScreenState();
}

class _FAQDetailScreenState extends State<FAQDetailScreen> {
  bool isHelpful = false;
  bool isNotHelpful = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Detail FAQ',
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.faqData['category'] ?? 'General',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E3C72),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Question
                  Text(
                    widget.faqData['question'] ?? 'Pertanyaan',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.faqData['views']} views',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.update, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Diperbarui 2 hari lalu',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Answer Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jawaban',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.faqData['answer'] ?? 'Tidak ada jawaban',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),

            // Related FAQs
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pertanyaan Terkait',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(3, (index) {
                    return ListTile(
                      leading: Icon(Icons.help_outline, color: Colors.grey[400], size: 20),
                      title: Text(
                        'Pertanyaan terkait ${index + 1}?',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        // Navigate to related FAQ
                      },
                    );
                  }),
                ],
              ),
            ),

            // Feedback
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Apakah jawaban ini membantu?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFeedbackButton(
                        icon: Icons.thumb_up,
                        label: 'Ya',
                        isSelected: isHelpful,
                        color: Colors.green,
                        onTap: () {
                          setState(() {
                            isHelpful = true;
                            isNotHelpful = false;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildFeedbackButton(
                        icon: Icons.thumb_down,
                        label: 'Tidak',
                        isSelected: isNotHelpful,
                        color: Colors.red,
                        onTap: () {
                          setState(() {
                            isNotHelpful = true;
                            isHelpful = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? color : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}