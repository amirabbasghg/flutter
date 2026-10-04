import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../Services/GoogleSignInService.dart';

/// دکمه‌ی «ورود با گوگل» که هر دو پلتفرم را پوشش می‌دهد و در نهایت فقط یک
/// چیز به صفحه می‌دهد: `idToken`.
///
/// موبایل → دکمه‌ی خودمان + `authenticate()` که اکانت را مستقیم برمی‌گرداند.
/// وب    → دکمه‌ی رسمی گوگل (GIS) که خودِ گوگل رندرش می‌کند؛ نتیجه مستقیم
///          برنمی‌گردد و باید از استریم `authenticationEvents` گرفته شود.
class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.onIdToken,
    required this.onError,
    this.enabled = true,
  });

  /// متن دکمه روی موبایل. روی وب متن را خودِ گوگل تعیین می‌کند.
  final String label;

  /// با توکن معتبر گوگل صدا زده می‌شود.
  final Future<void> Function(String idToken) onIdToken;

  final void Function(String message) onError;

  final bool enabled;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  bool _webReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _initWeb();
  }

  Future<void> _initWeb() async {
    try {
      await GoogleSignInService.initSignIn();
      _authSub = GoogleSignInService.authenticationEvents.listen(
        _onAuthEvent,
        onError: (_) => widget.onError('ورود با گوگل انجام نشد'),
      );
      if (mounted) setState(() => _webReady = true);
    } catch (_) {
      if (mounted) widget.onError('راه‌اندازی ورود با گوگل انجام نشد');
    }
  }

  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    if (!mounted) return;

    // صفحه‌ی ورود و ثبت‌نام هر دو می‌توانند هم‌زمان در استک باشند و هر دو به
    // این استریم گوش می‌دهند. فقط صفحه‌ای که الان جلوی چشم کاربر است باید
    // واکنش نشان دهد، وگرنه یک توکن دو بار به بک‌اند فرستاده می‌شود.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

    final idToken = event.user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      widget.onError('توکن گوگل دریافت نشد');
      return;
    }
    widget.onIdToken(idToken);
  }

  Future<void> _handleMobilePress() async {
    final account = await GoogleSignInService.authenticateAndGetAccount();
    if (!mounted) return;
    if (account == null) {
      widget.onError('ورود انجام نشد');
      return;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      widget.onError('توکن گوگل دریافت نشد');
      return;
    }
    await widget.onIdToken(idToken);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // تا وقتی GIS آماده نشده جای دکمه را نگه می‌داریم تا صفحه نپرد.
      if (!_webReady) {
        return const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return GoogleSignInService.webButton();
    }

    return ElevatedButton.icon(
      onPressed: widget.enabled ? _handleMobilePress : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 100,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
      icon: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
            stops: [0.0, 0.4, 0.7, 0.9],
          ).createShader(bounds);
        },
        child: const FaIcon(
          FontAwesomeIcons.google,
          size: 28,
          color: Colors.white,
        ),
      ),
      label: Text(widget.label, style: const TextStyle(fontSize: 14)),
    );
  }
}
