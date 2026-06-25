import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserFilterPanel extends StatelessWidget {
  final String selectedRole;
  final String selectedStatus;
  final String selectedFungsi;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onFungsiChanged;
  final VoidCallback onReset;

  const UserFilterPanel({
    super.key,
    required this.selectedRole,
    required this.selectedStatus,
    required this.selectedFungsi,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onFungsiChanged,
    required this.onReset,
  });

  bool get _hasActiveFilters =>
      selectedRole != 'Semua' || selectedStatus != 'Semua' || selectedFungsi != 'Semua';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UserHelpers.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UserHelpers.dividerColor),
        boxShadow: [
          BoxShadow(
            color: UserHelpers.headerBlue.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _FilterSection(
            title: 'Role',
            icon: Icons.shield_rounded,
            children: _buildRoleChips(),
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: 'Status',
            icon: Icons.toggle_on_rounded,
            children: _buildStatusChips(),
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: 'Department',
            icon: Icons.business_rounded,
            children: _buildFungsiChips(),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: UserHelpers.accentRed),
                label: Text(
                  'Reset Filters',
                  style: GoogleFonts.inter(color: UserHelpers.accentRed, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRoleChips() {
    final roles = UserHelpers.roleList;
    final labels = UserHelpers.roleLabelList;
    final colors = [
      UserHelpers.accentIndigo,
      UserHelpers.accentBlue,
      UserHelpers.accentCyan,
      UserHelpers.accentOrange,
      UserHelpers.accentDeepPurple,
    ];

    return [
      _FilterChip(
        label: 'All',
        isSelected: selectedRole == 'Semua',
        onTap: () => onRoleChanged('Semua'),
      ),
      ...List.generate(roles.length, (i) {
        return _FilterChip(
          label: labels[i],
          isSelected: selectedRole == roles[i],
          onTap: () => onRoleChanged(roles[i]),
          color: colors[i],
        );
      }),
    ];
  }

  List<Widget> _buildStatusChips() {
    final statuses = UserHelpers.statusList;
    final labels = UserHelpers.statusLabelList;
    final colors = [
      UserHelpers.accentGreen,
      UserHelpers.accentOrange,
      UserHelpers.accentRed,
    ];

    return [
      _FilterChip(
        label: 'All',
        isSelected: selectedStatus == 'Semua',
        onTap: () => onStatusChanged('Semua'),
      ),
      ...List.generate(statuses.length, (i) {
        return _FilterChip(
          label: labels[i],
          isSelected: selectedStatus == statuses[i],
          onTap: () => onStatusChanged(statuses[i]),
          color: colors[i],
        );
      }),
    ];
  }

  List<Widget> _buildFungsiChips() {
    final fungsis = UserHelpers.fungsiList;
    final labels = UserHelpers.fungsiLabelList;
    final colors = [
      UserHelpers.accentBlue,
      UserHelpers.accentIndigo,
      UserHelpers.accentOrange,
      UserHelpers.accentGreen,
      UserHelpers.accentCyan,
      UserHelpers.accentPink,
    ];

    return [
      _FilterChip(
        label: 'All',
        isSelected: selectedFungsi == 'Semua',
        onTap: () => onFungsiChanged('Semua'),
      ),
      ...List.generate(fungsis.length, (i) {
        return _FilterChip(
          label: labels[i],
          isSelected: selectedFungsi == fungsis[i],
          onTap: () => onFungsiChanged(fungsis[i]),
          color: colors[i],
        );
      }),
    ];
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FilterSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: UserHelpers.headerBlue.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UserHelpers.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: children
                .map((chip) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: chip,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? UserHelpers.headerBlue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.1) : UserHelpers.bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipColor : UserHelpers.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? chipColor : UserHelpers.textLight,
          ),
        ),
      ),
    );
  }
}