import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OvertimeSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  const OvertimeSearchBar({
    super.key,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<OvertimeSearchBar> createState() => _OvertimeSearchBarState();
}

class _OvertimeSearchBarState extends State<OvertimeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() => _isSearching = value.isNotEmpty);
          widget.onSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'Cari mitra atau pengawas...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(
            Icons.search,
            color: _isSearching ? const Color(0xFF1976D2) : Colors.grey[400],
            size: 20,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _isSearching = false);
                    widget.onClear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 13),
      ),
    );
  }
}