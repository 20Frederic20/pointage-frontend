import 'package:flutter/material.dart';

import '../../../core/role.dart';
import '../../../core/theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) => _Pill(label: role.label, color: Theme.of(context).colorScheme.primary);
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: isActive ? 'Actif' : 'Inactif', color: isActive ? AppColors.green : AppColors.red);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}
