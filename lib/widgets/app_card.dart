import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Kartu standar CashMate: sudut membulat, border tipis, dan bayangan halus.
/// Semua halaman Owner & Staff memakai widget ini agar tampilan seragam.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool bordered;
  final bool shadowed;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.color,
    this.bordered = true,
    this.shadowed = true,
    this.radius = AppRadius.lg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget content = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: borderRadius,
        border: bordered ? Border.all(color: AppColors.border(context)) : null,
        boxShadow: shadowed ? AppColors.softShadow(context) : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
            ),
    );
  }
}
