import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

/// دکمه‌ی رسمی Google Identity Services. خودِ گوگل آن را رندر می‌کند و بعد از
/// ورود موفق، نتیجه از طریق GoogleSignIn.instance.authenticationEvents
/// به اپ می‌رسد (نه با return مستقیم).
///
/// ⚠️ Directionality.ltr اینجا لازم است و تزئینی نیست: دکمه یک HtmlElementView
/// است و موقعیت DOM آن داخل یک درخت RTL اشتباه حساب می‌شود — اندازه‌گیری شد که
/// در صفحه‌ای به عرض ۹۶۶ پیکسل، iframe روی x=1079 یعنی کاملاً بیرون از کادر
/// قرار می‌گرفت (ارتفاعش درست بود). با LTR کردنِ همین زیردرخت، جای دکمه درست
/// می‌شود و چون محتوای دکمه را خود گوگل رندر می‌کند، روی ظاهر فارسی صفحه اثری
/// ندارد.
///
/// SizedBox هم برای این است که iframe گوگل ۲۶۰×۴۴ است؛ بدون اندازه‌ی صریح،
/// platform view کمی کوچک‌تر می‌شود و لبه‌های دکمه بریده می‌شوند.
Widget googleWebSignInButton() => const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 260,
        height: 44,
        child: _GisButton(),
      ),
    );

class _GisButton extends StatelessWidget {
  const _GisButton();

  @override
  Widget build(BuildContext context) => web_only.renderButton(
        configuration: web_only.GSIButtonConfiguration(
          theme: web_only.GSIButtonTheme.filledBlue,
          size: web_only.GSIButtonSize.large,
          text: web_only.GSIButtonText.signinWith,
          shape: web_only.GSIButtonShape.pill,
          logoAlignment: web_only.GSIButtonLogoAlignment.left,
        ),
      );
}
