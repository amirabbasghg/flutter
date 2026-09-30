// lib/Services/ApiConfig.dart
// آدرس بک‌اند Cloudflare Workers.
// - در شبیه‌ساز Android: 10.0.2.2 یعنی localhost کامپیوتر (wrangler dev)
// - روی گوشی واقعی: IP لوکال کامپیوتر + wrangler dev --host
// - بعد از دیپلوی: https://backend.<your-subdomain>.workers.dev
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8787/api',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
