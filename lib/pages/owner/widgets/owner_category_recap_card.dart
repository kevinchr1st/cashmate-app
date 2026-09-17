import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_empty_state.dart';

/// Satu irisan kategori untuk kartu rekap.
class CategorySlice {
  final String name;
  final double amount;
  final double ratio;
  final Color color;

  const CategorySlice({
    required this.name,
    required this.amount,
    required this.ratio,
    required this.color,
  });
}

/// Rekap alokasi kas per kategori (bulan berjalan).
class OwnerCategoryRecapCard extends StatelessWidget {
  final List<CategorySlice> slices;
  final double total;

  const OwnerCategoryRecapCard({
    super.key,
    required this.slices,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekap kategori',
                      style: AppTextStyles.heading.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Alokasi kas toko bulan ini',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Text(
                Rupiah.compact(total),
                style: AppTextStyles.subheading.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (slices.isEmpty)
            const AppEmptyState(
              icon: Icons.donut_large_rounded,
              title: 'Belum ada transaksi bulan ini',
            )
          else
            for (int i = 0; i < slices.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _CategoryBar(slice: slices[i]),
            ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final CategorySlice slice;

  const _CategoryBar({required this.slice});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                slice.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subheading.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Text(
              Rupiah.format(slice.amount),
              style: AppTextStyles.subheading.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 34,
              child: Text(
                '${(slice.ratio * 100).round()}%',
                textAlign: TextAlign.right,
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: slice.ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border(context),
            valueColor: AlwaysStoppedAnimation<Color>(slice.color),
          ),
        ),
      ],
    );
  }
}
