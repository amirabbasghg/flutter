import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Services/Api.dart';
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

  /// تعیین وضعیت ورود بر اساس TokenStore (بدون Firebase):
  /// - نشست ذخیره‌شده باشد → یک بار getMyProfile زده می‌شود؛ اگر access token
  ///   منقضی باشد، Api به‌صورت خودکار refresh می‌کند. موفق → کاربر وارد است.
  /// - خطای ۴۰۱ قطعی یا SessionExpired → نشست پاک و صفحه ورود نشان داده می‌شود.
  /// - خطای شبکه (سرور روشن نیست) → وضعیت نشست حفظ می‌شود تا کاربر مجبور به
  ///   ورود مجدد نشود؛ درخواست‌های بعدی دوباره تلاش خواهند کرد.
  Future<bool> _resolveSession() async {
    if (!TokenStore.hasSession) return false;
    try {
      await ApiService.instance.getMyProfile();
      final appState = Provider.of<AppStateVM>(context, listen: false);
      await appState.refreshCurrentUser();
      return true;
    } on SessionExpiredException {
      await TokenStore.clear();
      return false;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await TokenStore.clear();
        return false;
      }
      // 5xx یا خطای دیگر: نشست را از دست نده
      return true;
    } catch (_) {
      // خطای شبکه یا هر چیز دیگر: نشست حفظ شود
      return true;
    }
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
          return const HomePage();
        }
        return Authenticate();
      },
    );
  }
}
