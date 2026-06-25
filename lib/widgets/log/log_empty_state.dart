import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogEmptyState extends StatelessWidget {
  final Color accentBlue;
  final VoidCallback onRefresh;

  const LogEmptyState({
    super.key,
    required this.accentBlue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada log ditemukan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba ubah filter atau cari dengan kata kunci lain',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}