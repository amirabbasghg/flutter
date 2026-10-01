import 'package:google_sign_in/google_sign_in.dart';

/// فقط لایه‌ی نازک روی google_sign_in — بدون Firebase.
///
/// کاری که انجام می‌دهد: گرفتن `id_token` از گوگل. اعتبارسنجی آن توکن روی
/// Cloudflare Worker (`POST /api/auth/google`) انجام می‌شود، نه Firebase Auth.
/// به همین دلیل ورود با گوگل دیگر به دامنه‌های بسته‌ی Firebase وابسته نیست.
class GoogleSignInService {
  /// همان «Web client (type 3)» در google-services.json.
  /// مقدار `aud` داخل id_token دقیقاً همین است و باید با GOOGLE_CLIENT_ID
  /// در backend/wrangler.jsonc یکی باشد، وگرنه ورکر توکن را رد می‌کند.
  static const String serverClientId =
      '277889096548-56031v6p9lomnmifk7brqhm09733mpai.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isInitialized = false;

  static Future<void> initSignIn() async {
    if (_isInitialized) return;
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _isInitialized = true;
  }

  /// احراز هویت گوگل و برگرداندن اکانت (برای ارسال idToken به بک‌اند).
  /// اگر کاربر لغو کند یا خطایی رخ دهد null برمی‌گردد.
  static Future<GoogleSignInAccount?> authenticateAndGetAccount() async {
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
      print('Error signing out: $e');
    }
  }
}
