import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../widgets/app_badge.dart';
import '../../../widgets/app_card.dart';

/// Entry satu baris "Catat transaksi" — ringkas, tanpa teks berlebih.
class OwnerQuickActionCard extends StatelessWidget {
  final VoidCallback onRecord;

  const OwnerQuickActionCard({super.key, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.brightness == Brightness.dark ? null : AppColors.primarySoft,
      padding: EdgeInsets.zero,
      onTap: onRecord,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            AppIconBadge(
              icon: Icons.add_circle_rounded,
              color: AppColors.primary,
              size: 36,
              iconSize: 19,
              radius: AppRadius.sm,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Catat transaksi',
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
