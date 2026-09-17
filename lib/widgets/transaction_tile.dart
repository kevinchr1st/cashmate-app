import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/string_utils.dart';
import 'app_badge.dart';

/// Model tampilan transaksi agar widget tidak bergantung pada bentuk JSON API.
/// Dipakai bersama oleh modul Owner & Staff.
class TransactionItem {
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;

  const TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
  });
}

/// Baris transaksi seragam untuk Owner & Staff (bagian dari shared widgets).
class TransactionTile extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = item.isIncome ? AppColors.success : AppColors.danger;
    final Color titleColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          AppIconBadge(
            icon: item.isIncome
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            color: color,
            size: 38,
            iconSize: 17,
            radius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  htmlUnescape(item.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subheading.copyWith(color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  htmlUnescape(item.subtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${item.isIncome ? '+' : '-'}${Rupiah.format(item.amount)}',
            style: AppTextStyles.subheading.copyWith(color: color),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: row,
    );
  }
}
