// lib/Services/TokenStore.dart
import 'package:hive_flutter/hive_flutter.dart';

/// نگهداری accessToken / refreshToken و اطلاعات کاربر ورود.
/// accessToken فقط در حافظه نگه داشته می‌شود (امن‌تر)،
/// refreshToken و مشخصات کاربر در Hive ذخیره می‌شوند تا با ری‌استارت اپ
/// کاربر مهمان نماند.
class TokenStore {
  static const String _boxName = 'authBox';
  static const String _kRefresh = 'refreshToken';
  static const String _kUserId = 'userId';
  static const String _kName = 'name';
  static const String _kEmail = 'email';
  static const String _kPhoto = 'photoURL';
  static const String _kAccount = 'accountNumber';

  static String? _accessToken;

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _box.get(_kRefresh);
  static String? get userId => _box.get(_kUserId);
  static String? get name => _box.get(_kName);
  static String? get email => _box.get(_kEmail);
  static String? get photoURL => _box.get(_kPhoto);
  static String? get accountNumber => _box.get(_kAccount);

  static bool get hasSession => (refreshToken ?? '').isNotEmpty;

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String name,
    required String email,
    String? photoURL,
    String? accountNumber,
  }) async {
    _accessToken = accessToken;
    await _box.putAll({
      _kRefresh: refreshToken,
      _kUserId: userId,
      _kName: name,
      _kEmail: email,
      _kPhoto: photoURL ?? '',
      _kAccount: accountNumber ?? '',
    });
  }

  /// فقط access token جدید (بعد از refresh) — refreshToken عوض شده باشد هم ذخیره شود.
  static Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _box.put(_kRefresh, refreshToken);
    }
  }

  static void setAccessToken(String? token) => _accessToken = token;

  static Future<void> clear() async {
    _accessToken = null;
    await _box.clear();
  }
}
