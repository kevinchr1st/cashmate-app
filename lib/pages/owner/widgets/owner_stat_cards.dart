import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_badge.dart';

/// Dua kartu ringkas: uang masuk & uang keluar bulan berjalan.
class OwnerStatCards extends StatelessWidget {
  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;

  const OwnerStatCards({
    super.key,
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Uang masuk',
            value: income,
            caption: '$incomeCount transaksi',
            icon: Icons.south_west_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'Uang keluar',
            value: expense,
            caption: '$expenseCount transaksi',
            icon: Icons.north_east_rounded,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final String caption;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: icon, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Rupiah.format(value),
              style: AppTextStyles.subheading.copyWith(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}
