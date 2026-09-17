import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Empty state seragam dengan banyak ruang putih.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final Color hint = Theme.of(context).hintColor;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: hint.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: hint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.subheading.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: hint),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: hint),
            ),
          ],
        ],
      ),
    );
  }
}
