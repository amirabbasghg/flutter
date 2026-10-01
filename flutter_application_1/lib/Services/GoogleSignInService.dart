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
  // هر پلتفرم OAuth client خودش را دارد، چون سایت و اپ اندروید در دو پروژه‌ی
  // جداگانه‌ی Google Cloud ثبت شده‌اند. مقدار `aud` داخل id_token همین شناسه
  // است، پس هر دو باید در GOOGLE_CLIENT_ID در backend/wrangler.jsonc باشند
  // (آنجا با ویرگول از هم جدا می‌شوند).

  /// client مخصوص سایت expense-app (پروژه‌ی 177838948520).
  /// دامنه‌ی سایت باید در Authorized JavaScript origins همین client ثبت شده
  /// باشد، وگرنه گوگل دکمه را رندر نمی‌کند.
  static const String webClientId =
      '177838948520-boe8qvmh1qcludvfcjdqhcm4fb8opujm.apps.googleusercontent.com';

  /// همان «Web client (type 3)» در google-services.json (پروژه‌ی 277889096548).
  /// روی اندروید به‌عنوان serverClientId می‌رود تا توکن برای بک‌اند صادر شود.
  static const String androidServerClientId =
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
      await _googleSignIn.initialize(serverClientId: androidServerClientId);
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
