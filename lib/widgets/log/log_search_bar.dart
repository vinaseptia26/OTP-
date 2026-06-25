import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onSearchCleared;

  const LogSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onSearchChanged,
        style: GoogleFonts.poppins(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari log berdasarkan deskripsi, user, atau tipe...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: onSearchCleared,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}