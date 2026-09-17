import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_card.dart';

/// Daftar kantong kas aktif milik toko, ditampilkan horizontal.
/// Untuk role Staff, `showBalance: false` menyembunyikan nominal saldo
/// dan hanya menampilkan teks status termask ("••••") — RBAC anti-bocor.
class StaffWalletStrip extends StatelessWidget {
  final List<Map<String, dynamic>> wallets;
  final bool showBalance;

  const StaffWalletStrip({
    super.key,
    required this.wallets,
    this.showBalance = true,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final items = wallets.take(4).toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KANTONG KAS TOKO',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (items.isEmpty)
            Text(
              'Belum ada kantong kas aktif.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final w = items[i];
                  return Container(
                    width: 128,
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: isDark ? null : AppColors.indigoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          w['name']?.toString() ?? 'Kantong',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (showBalance)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Rupiah.format(_toDouble(w['balance'])),
                              style: AppTextStyles.subheading.copyWith(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 12,
                                color: theme.hintColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '••••',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
