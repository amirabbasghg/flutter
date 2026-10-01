import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// حالت تم (سیستم / روشن / تیره) و ذخیره‌ی آن بین اجراها.
///
/// در همان Hive ای ذخیره می‌شود که TokenStore استفاده می‌کند، ولی در باکس
/// جدا؛ چون خروج از حساب باکس احراز هویت را پاک می‌کند و انتخاب تم کاربر
/// نباید با logout از بین برود.
class ThemeVM extends ChangeNotifier {
  static const String boxName = 'settingsBox';
  static const String _key = 'themeMode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  ThemeVM() {
    _load();
  }

  void _load() {
    if (!Hive.isBoxOpen(boxName)) return;
    switch (Hive.box<String>(boxName).get(_key)) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        _mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<String>(boxName).put(_key, mode.name);
    }
  }

  /// برای دکمه‌ی سریع تغییر تم: روشن ↔ تیره.
  /// وقتی روی «سیستم» است، خلافِ چیزی که الان دیده می‌شود انتخاب می‌شود.
  Future<void> toggle(BuildContext context) {
    final isDarkNow = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return setMode(isDarkNow ? ThemeMode.light : ThemeMode.dark);
  }

  String get label => switch (_mode) {
        ThemeMode.light => 'روشن',
        ThemeMode.dark => 'تیره',
        ThemeMode.system => 'خودکار (سیستم)',
      };

  IconData get icon => switch (_mode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };
}
