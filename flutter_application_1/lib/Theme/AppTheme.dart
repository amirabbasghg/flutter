import 'package:flutter/material.dart';

/// تم روشن و تیره‌ی اپ.
///
/// هدف این است که صفحه‌ها رنگ را از تم بگیرند، نه اینکه هر کدام رنگ خودش را
/// hard-code کند. هر چیزی که از Theme.of(context) خوانده شود در هر دو حالت
/// درست در می‌آید؛ رنگ ثابت (مثلاً Colors.white) در حالت تیره می‌شکند.
class AppTheme {
  AppTheme._();

  /// سبز برند — همان رنگی که از ابتدا در صفحه‌های ورود استفاده می‌شد.
  static const Color brand = Color(0xff00dd94);
  static const Color brandDark = Color(0xff00b377);

  // رنگ‌های معنایی که در کل اپ یکسان‌اند (در هر دو تم خوانا هستند).
  static const Color positive = Color(0xff16a34a); // طلبکار
  static const Color negative = Color(0xffdc2626); // بدهکار
  static const Color warning = Color(0xfff59e0b);
  static const Color info = Color(0xff2563eb);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: brandDark,
      secondary: brand,
      surface: Colors.white,
    );
    return _build(scheme, const Color(0xffF4F6F8));
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brand,
      secondary: brand,
      surface: const Color(0xff1C1F22),
    );
    return _build(scheme, const Color(0xff121416));
  }

  static ThemeData _build(ColorScheme scheme, Color scaffoldBackground) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      // صفحه‌های قدیمی هنوز primaryColor/cardColor را مستقیم می‌خوانند،
      // پس این‌ها هم صریح ست می‌شوند تا آن‌ها هم با تم هماهنگ بمانند.
      primaryColor: scheme.primary,
      cardColor: scheme.surface,
      canvasColor: scaffoldBackground,
      dividerColor: scheme.outlineVariant,
      disabledColor: isDark ? Colors.white38 : Colors.black38,
      // فونت سراسری ست نمی‌شود: تنها فونت فارسیِ پروژه (vazir) فقط وزن Bold
      // دارد و کل اپ را بولد می‌کرد.

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? scheme.surface : scheme.primary,
        foregroundColor: isDark ? scheme.onSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? scheme.onSurface : Colors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xff24282C) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black45,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
