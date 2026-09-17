import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_badge.dart';
import '../../../widgets/app_card.dart';

/// Ringkasan "Dompet & Kantong" di Beranda Owner: total saldo plus
/// pratinjau kantong teratas, minimal kata untuk layar utama.
class OwnerWalletPreviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> wallets;
  final double total;
  final VoidCallback onManage;

  const OwnerWalletPreviewCard({
    super.key,
    required this.wallets,
    required this.total,
    required this.onManage,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final preview = wallets.take(3).toList();

    return AppCard(
      color: isDark ? null : AppColors.indigoSoft,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icons.savings_rounded,
                color: AppColors.accent,
                size: 36,
                iconSize: 18,
                radius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Dompet & Kantong',
                  style: AppTextStyles.heading.copyWith(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              if (total > 0)
                Text(
                  Rupiah.compact(total),
                  style: AppTextStyles.subheading.copyWith(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (int i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview[i]['name']?.toString() ?? 'Kantong',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview[i].containsKey('balance')
                              ? Rupiah.compact(_toDouble(preview[i]['balance']))
                              : '••••',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subheading.copyWith(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onManage,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
