import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../widgets/app_badge.dart';

/// Kartu identitas Kasir di Beranda Staff: sapaan, avatar, nama toko,
/// dan badge peran. Bahasa desain serupa `OwnerBalanceCard`.
class StaffGreetingCard extends StatelessWidget {
  final String name;
  final String storeName;
  final String? photoUrl;
  final VoidCallback onTapProfile;

  const StaffGreetingCard({
    super.key,
    required this.name,
    required this.storeName,
    this.photoUrl,
    required this.onTapProfile,
  });

  String get _firstName {
    if (name.trim().isEmpty) return 'Kasir';
    return name.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.darken(0.2),
            AppColors.primary,
            AppColors.primary.lighten(0.15),
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
      child: Row(
        children: [
          InkWell(
            onTap: onTapProfile,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: _avatar(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName.isNotEmpty ? storeName : 'CashMate UMKM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  'Halo, $_firstName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppBadge(
                  label: 'STAFF',
                  color: AppColors.accent,
                  icon: Icons.storefront_rounded,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _avatar() {
    String? resolved = photoUrl;
    if (resolved != null && resolved.isEmpty) resolved = null;
    if (resolved == null) {
      return const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 28,
      );
    }
    return ClipOval(
      child: Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}