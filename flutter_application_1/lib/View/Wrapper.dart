import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Services/TokenStore.dart';
import '../ViewModel/AppStateVM.dart';
import 'Home/HomePage.dart';
import 'Authenticate/Authenticate.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  late final Future<bool> _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = _resolveSession();
  }

  /// تعیین وضعیت ورود بر اساس TokenStore (بدون Firebase).
  ///
  /// کل کار به AppStateVM.onSignedIn سپرده می‌شود تا دقیقاً همان مسیری طی شود
  /// که بعد از ورود دستی طی می‌شود: اول currentUser از TokenStore ساخته
  /// می‌شود، بعد پروفایل از سرور تازه می‌گردد و فقط در صورت ۴۰۱/۴۰۳ نشست
  /// پاک می‌شود.
  ///
  /// قبلاً اینجا در خطای شبکه/۵xx مقدار true برگردانده می‌شد ولی currentUser
  /// پر نمی‌شد، و نتیجه‌اش صفحه‌ی اصلی با پیام «لطفاً ابتدا وارد شوید» بود.
  Future<bool> _resolveSession() async {
    if (!TokenStore.hasSession) return false;
    final appState = Provider.of<AppStateVM>(context, listen: false);
    await appState.onSignedIn();
    // onSignedIn در صورت ۴۰۱/۴۰۳ نشست را پاک کرده است.
    return TokenStore.hasSession && appState.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _readyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return HomePage();
        }
        return Authenticate();
      },
    );
  }
}
