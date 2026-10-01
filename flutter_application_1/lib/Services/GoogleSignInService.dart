import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show Widget;
import 'package:google_sign_in/google_sign_in.dart';

import 'GoogleWebButton.dart';

/// فقط لایه‌ی نازک روی google_sign_in — بدون Firebase.
///
/// کاری که انجام می‌دهد: گرفتن `id_token` از گوگل. اعتبارسنجی آن توکن روی
/// Cloudflare Worker (`POST /api/auth/google`) انجام می‌شود، نه Firebase Auth.
/// به همین دلیل ورود با گوگل دیگر به دامنه‌های بسته‌ی Firebase وابسته نیست.
///
/// دو فلوی متفاوت:
///   • اندروید/iOS → `authenticate()` که خودش پنجره‌ی انتخاب حساب را باز
///     می‌کند و اکانت را برمی‌گرداند.
///   • وب → `authenticate()` اصلاً پشتیبانی نمی‌شود. باید دکمه‌ی خود گوگل
///     رندر شود (`webButton()`) و نتیجه از استریم [authenticationEvents]
///     بیاید.
class GoogleSignInService {
  /// همان «Web client (type 3)» در google-services.json.
  /// مقدار `aud` داخل id_token دقیقاً همین است و باید با GOOGLE_CLIENT_ID
  /// در backend/wrangler.jsonc یکی باشد، وگرنه ورکر توکن را رد می‌کند.
  ///
  /// روی وب همین مقدار به‌عنوان clientId می‌رود و روی موبایل به‌عنوان
  /// serverClientId — پس توکنِ هر دو پلتفرم همان audience را دارد و بک‌اند
  /// نیازی به تغییر ندارد.
  static const String webClientId =
      '277889096548-56031v6p9lomnmifk7brqhm09733mpai.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isInitialized = false;

  static Future<void> initSignIn() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      // پیاده‌سازی وب صراحتاً assert می‌کند که serverClientId باید null باشد
      // و در عوض clientId لازم دارد.
      await _googleSignIn.initialize(clientId: webClientId);
    } else {
      await _googleSignIn.initialize(serverClientId: webClientId);
    }
    _isInitialized = true;
  }

  /// روی وب false است — یعنی باید از [webButton] استفاده شود.
  static bool get supportsDirectAuthenticate =>
      !kIsWeb && GoogleSignIn.instance.supportsAuthenticate();

  /// رویدادهای ورود/خروج. روی وب تنها راهِ گرفتن نتیجه‌ی دکمه‌ی گوگل همین است.
  static Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  /// دکمه‌ی رسمی گوگل برای وب. روی موبایل ویجت خالی برمی‌گرداند (استفاده نمی‌شود).
  static Widget webButton() => googleWebSignInButton();

  /// احراز هویت گوگل و برگرداندن اکانت (برای ارسال idToken به بک‌اند).
  /// اگر کاربر لغو کند یا خطایی رخ دهد null برمی‌گردد.
  /// فقط روی موبایل؛ روی وب همیشه null برمی‌گرداند.
  static Future<GoogleSignInAccount?> authenticateAndGetAccount() async {
    if (kIsWeb) return null;
    await initSignIn();
    try {
      return await _googleSignIn.authenticate();
    } catch (_) {
      return null;
    }
  }

  /// خروج محلی از حساب گوگل. نشست خود اپ با ApiService.logout() پاک می‌شود.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
