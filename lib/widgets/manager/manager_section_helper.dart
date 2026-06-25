// lib/widgets/manager/manager_section_helper.dart

import 'package:flutter/material.dart';

class ManagerSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget? trailing;

  const ManagerSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2332),
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ManagerCorporateDivider extends StatelessWidget {
  final String title;

  const ManagerCorporateDivider({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    const dividerGrey = Color(0xFFE2E8F0);

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: dividerGrey)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: dividerGrey),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: dividerGrey)),
      ],
    );
  }
}