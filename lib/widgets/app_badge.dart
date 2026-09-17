import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Pill label kecil (mis. "Pemilik Toko", "Pemasukan").
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = solid ? Colors.white : color;
    final Color bg = solid ? color : color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Kotak ikon membulat dengan latar lembut.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 18,
    this.radius = AppRadius.sm + 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
