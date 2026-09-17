import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_card.dart';

/// Ringkasan aktivitas hari ini untuk Kasir: pemasukan, pengeluaran,
/// dan jumlah transaksi. Kosong total = tampilkan state netral "—".
class StaffSummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final int transactionCount;

  const StaffSummaryCard({
    super.key,
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AKTIVITAS HARI INI',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: _metric(
                  context,
                  label: 'Pemasukan',
                  value: Rupiah.compact(income),
                  valueColor: AppColors.success,
                  prefixIcon: Icons.south_west_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.dividerColor,
              ),
              Expanded(
                child: _metric(
                  context,
                  label: 'Pengeluaran',
                  value: Rupiah.compact(expense),
                  valueColor: AppColors.danger,
                  prefixIcon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 15,
                color: theme.textTheme.bodyLarge?.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$transactionCount transaksi tercatat hari ini',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    required IconData prefixIcon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.heading.copyWith(
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}