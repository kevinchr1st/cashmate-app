import 'package:flutter/material.dart';

/// ============================================================================
/// CashMate Design System
/// ----------------------------------------------------------------------------
/// Sumber tunggal untuk warna, tipografi, spacing, radius, dan dekorasi kartu.
/// Dipakai bersama oleh modul Owner & Staff supaya bahasa desainnya konsisten.
/// ============================================================================

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1155D9);
  static const Color primarySoft = Color(0xFFE8F0FE);
  static const Color indigoSoft = Color(0xFFEEF2FF);
  static const Color accent = Color(0xFFF5A524);

  // Semantic
  static const Color success = Color(0xFF12B76A);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF2E90FA);

  // Surface
  static const Color bgLight = Color(0xFFF7F9FC);
  static const Color bgDark = Color(0xFF121212);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textHint = Color(0xFF98A2B3);

  /// Warna garis tipis yang menyesuaikan tema terang/gelap.
  static Color border(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE7ECF3);

  /// Bayangan kartu yang lembut (dipakai `AppCard`).
  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.04,
          ),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Skala jarak (whitespace) 4-pt supaya ritme layout rapi di semua halaman.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const double page = 20;
  static const double bottomInset = 110;

  static const EdgeInsets pagePadding =
      EdgeInsets.fromLTRB(page, lg, page, bottomInset);

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);

  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
}

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}

/// Kumpulan ThemeData terang & gelap berbasis token di atas.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
        brightness: Brightness.light,
        background: AppColors.bgLight,
        card: AppColors.cardLight,
        onSurface: AppColors.textPrimary,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        background: AppColors.bgDark,
        card: AppColors.cardDark,
        onSurface: Colors.white,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color card,
    required Color onSurface,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final Color hint = isDark ? AppColors.textSecondary : AppColors.textHint;
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE7ECF3);

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      cardColor: card,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: card,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: AppTextStyles.title.copyWith(color: onSurface),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      iconTheme: IconThemeData(color: hint),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        hintStyle: AppTextStyles.body.copyWith(color: hint),
        border: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: AppTextStyles.subheading.copyWith(color: Colors.white),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1D2939),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rSm),
      ),
      useMaterial3: false,
    );
  }
}

/// Bantuan kecil untuk menurunkan/menaikkan kecerahan warna token.
extension AppColorShade on Color {
  /// Menambah porsi hitam (digelapkan) sebesar [amount] (0–1).
  Color darken([double amount = 0.18]) => Color.lerp(this, Colors.black, amount)!;

  /// Menambah porsi putih (diterangkan) sebesar [amount] (0–1).
  Color lighten([double amount = 0.18]) => Color.lerp(this, Colors.white, amount)!;
}
