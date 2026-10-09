import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// A small coloured label showing someone's role (Teacher, Class
/// Representative, ...), used in the chat list and chat headers.
class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});

  final UserRole role;

  static Color colorOf(UserRole r) => switch (r) {
    UserRole.admin => const Color(0xFFB71C1C),
    UserRole.adminStaff => const Color(0xFFE65100),
    UserRole.teacher => const Color(0xFF1B5E20),
    UserRole.classRep => const Color(0xFF6A1B9A),
    UserRole.libraryStaff => const Color(0xFF00695C),
    UserRole.grievanceCommittee => const Color(0xFF4E342E),
    UserRole.busDriver => const Color(0xFF37474F),
    UserRole.student => const Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(role);
    return Container(
      key: ValueKey('badge-${role.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
