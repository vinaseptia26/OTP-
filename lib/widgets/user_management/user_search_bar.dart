// lib/features/superadmin/widgets/user_search_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final int activeFilterCount;
  final bool showFilterPanel;
  final VoidCallback onFilterToggle;
  final VoidCallback onClearSearch;

  const UserSearchBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.activeFilterCount,
    required this.showFilterPanel,
    required this.onFilterToggle,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchField(),
          ),
          const SizedBox(width: 10),
          _FilterButton(
            activeCount: activeFilterCount,
            isActive: showFilterPanel,
            onTap: onFilterToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: UserHelpers.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UserHelpers.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.inter(fontSize: 13, color: UserHelpers.textPrimary),
        cursorColor: UserHelpers.headerBlue,
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: UserHelpers.textHint),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: UserHelpers.headerBlue.withOpacity(0.5),
            size: 22,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: UserHelpers.textLight),
                  onPressed: onClearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.activeCount,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeCount > 0;
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        gradient: hasFilters
            ? const LinearGradient(
                colors: [UserHelpers.headerBlue, Color(0xFF2A5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasFilters ? null : UserHelpers.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFilters ? UserHelpers.headerBlue : UserHelpers.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: hasFilters
                ? UserHelpers.headerBlue.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(
              Icons.filter_list_rounded,
              color: hasFilters ? Colors.white : UserHelpers.textLight,
              size: 22,
            ),
          ),
          if (hasFilters)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: UserHelpers.accentRed,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    activeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}