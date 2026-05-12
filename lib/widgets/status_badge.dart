import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge(this.status, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final bgColor = AppTheme.statusBgColor(status);
    final label = AppTheme.statusLabel(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class ItemStatusBadge extends StatelessWidget {
  final String status;

  const ItemStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.itemStatusColor(status);
    final label = AppTheme.itemStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
