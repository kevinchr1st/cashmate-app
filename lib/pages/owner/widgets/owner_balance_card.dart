import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_badge.dart';

/// Kartu saldo utama Owner dengan tombol sembunyikan/tampilkan.
class OwnerBalanceCard extends StatelessWidget {
  final double totalBalance;
  final double netCashflow;
  final bool balanceVisible;
  final bool isOwner;
  final VoidCallback onToggleVisibility;

  const OwnerBalanceCard({
    super.key,
    required this.totalBalance,
    required this.netCashflow,
    required this.balanceVisible,
    required this.isOwner,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final bool positive = netCashflow >= 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.darken(),
            AppColors.primary,
            AppColors.primary.lighten(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.rSm,
                ),
                child: const Icon(Icons.savings_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Saldo saat ini',
                style: AppTextStyles.label.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              InkWell(
                onTap: onToggleVisibility,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    balanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              !isOwner
                  ? 'Disembunyikan'
                  : (balanceVisible ? Rupiah.format(totalBalance) : 'Rp ••••••••'),
              style: AppTextStyles.display.copyWith(
                color: Colors.white,
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppBadge(
                label: isOwner ? Rupiah.compact(netCashflow) : '—',
                color: Colors.white,
                icon: positive ? Icons.trending_up : Icons.trending_down,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'arus kas bersih bulan ini',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
