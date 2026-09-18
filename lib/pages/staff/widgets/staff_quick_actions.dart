import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../widgets/app_card.dart';

/// Dua tombol aksi utama Kasir: catat Pemasukan / Pengeluaran.
class StaffQuickActions extends StatelessWidget {
  final VoidCallback onIncome;
  final VoidCallback onExpense;

  const StaffQuickActions({
    super.key,
    required this.onIncome,
    required this.onExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _actionButton(
          context,
          icon: Icons.south_west_rounded,
          label: 'Pemasukan',
          color: AppColors.success,
          onTap: onIncome,
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _actionButton(
          context,
          icon: Icons.north_east_rounded,
          label: 'Pengeluaran',
          color: AppColors.danger,
          onTap: onExpense,
        )),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                textAlign: TextAlign.start,
                style: AppTextStyles.subheading.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}