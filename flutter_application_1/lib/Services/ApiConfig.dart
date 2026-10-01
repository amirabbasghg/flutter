// lib/Services/ApiConfig.dart
// آدرس بک‌اند Cloudflare Workers.
//
// پیش‌فرض = ورکر دیپلوی‌شده روی Cloudflare. این دامنه از ایران بدون فیلترشکن
// در دسترس است، برخلاف Firebase/Firestore که توسط گوگل روی IP ایران بسته است.
// بنابراین ورود با ایمیل و ورود با گوگل هر دو از همین آدرس عبور می‌کنند.
//
// برای کار با wrangler dev محلی، موقع اجرا override کنید:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787/api   (شبیه‌ساز اندروید)
//   flutter run --dart-define=API_BASE_URL=http://<IP کامپیوتر>:8787/api  (گوشی واقعی،
//   به‌همراه `wrangler dev --ip 0.0.0.0`)
// توجه: آدرس http روی اندروید ۹ به بالا فقط در بیلد debug/profile کار می‌کند.
class ApiConfig {
  /// آدرس ورکر دیپلوی‌شده (بدون اسلش انتهایی، شامل پیشوند /api).
  static const String _deployedBaseUrl =
      'https://backend.mhsyny293.workers.dev/api';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _deployedBaseUrl,
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
