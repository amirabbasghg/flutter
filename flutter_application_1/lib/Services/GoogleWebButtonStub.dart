import 'package:flutter/widgets.dart';

/// نسخه‌ی غیر وب. روی اندروید/iOS هیچ‌وقت رندر نمی‌شود چون صفحه‌ها با kIsWeb
/// دکمه‌ی خودشان را نشان می‌دهند؛ این فقط برای کامپایل شدن conditional import
/// لازم است.
Widget googleWebSignInButton() => const SizedBox.shrink();
