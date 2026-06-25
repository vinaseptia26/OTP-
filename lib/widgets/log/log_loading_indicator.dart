import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogLoadingIndicator extends StatelessWidget {
  final Color accentBlue;

  const LogLoadingIndicator({
    super.key,
    required this.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data log...',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}