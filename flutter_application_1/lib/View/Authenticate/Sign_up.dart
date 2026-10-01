import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../Services/Api.dart';
import '../../ViewModel/AppStateVM.dart';
import 'GoogleAuthButton.dart';
import '../Home/HomePage.dart';

class SignUp extends StatefulWidget {
  SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final ApiService _api = ApiService.instance;
  final _formKey = GlobalKey<FormState>();
  bool isVisible = true;
  bool _loading = false;
  String _name = '';
  String _email = '';
  String _password = '';

  /// ثبت‌نام با بک‌اند جدید (D1 + JWT). موفقیت یعنی true.
  /// سرور بعد از ثبت‌نام جفت توکن برمی‌گرداند و کاربر بلافاصله وارد می‌شود؛
  /// همان نامی که اینجا وارد می‌شود به‌عنوان display_name ذخیره می‌گردد،
  /// پس دیگر نیازی به صفحه ChooseUsername نیست.
  Future<bool> _apiRegister(String name, String email, String password) async {
    setState(() => _loading = true);
    try {
      await _api.register(name: name, email: email, password: password);
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        _showErrorSnackbar(
          e.statusCode == 409 ? 'این ایمیل قبلاً ثبت شده است' : e.message,
        );
      }
      return false;
    } catch (_) {
      if (mounted) _showErrorSnackbar('اتصال به سرور برقرار نشد');
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// بعد از ورود/ثبت‌نام موفق باید AppStateVM هم خبردار شود، وگرنه
  /// currentUser تهی می‌ماند و صفحه‌های داخلی «لطفاً ابتدا وارد شوید»
  /// نشان می‌دهند.
  Future<void> _goHome() async {
    await context.read<AppStateVM>().onSignedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required String label,
    required Icon prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 3),
      ),
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.primary),
      prefixIcon: prefix,
      prefixIconColor: AppColors.primary,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.cardBackground,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 30),
                Center(
                  child: const Text(
                    'ثبت نام',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  decoration: _inputDecoration(
                    hint: 'نام خود را وارد کنید',
                    label: 'نام',
                    prefix: const Icon(Icons.person),
                  ),
                  style: const TextStyle(color: AppColors.text),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفا نام خود را وارد کنید';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _name = value),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: _inputDecoration(
                    hint: 'ایمیل خود را وارد کنید',
                    label: 'ایمیل',
                    prefix: const Icon(Icons.email),
                  ),
                  style: const TextStyle(color: AppColors.text),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا ایمیل خود را وارد کنید';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _email = value),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: _inputDecoration(
                    hint: 'رمز عبور خود را وارد کنید',
                    label: 'رمز عبور',
                    prefix: const Icon(Icons.lock),
                    suffix: IconButton(
                      icon: isVisible
                          ? const Icon(Icons.visibility_off)
                          : const Icon(Icons.visibility),
                      onPressed: () => setState(() => isVisible = !isVisible),
                      color: AppColors.primary,
                    ),
                  ),
                  obscureText: isVisible,
                  style: const TextStyle(color: AppColors.text),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا رمز عبور خود را وارد کنید';
                    }
                    // بک‌اند حداقل ۸ کاراکتر می‌خواهد — اینجا هم همان‌قدر چک شود
                    if (value.length < 8) {
                      return 'رمز عبور باید حداقل 8 کاراکتر باشد';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _password = value),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                final ok = await _apiRegister(
                                    _name.trim(), _email.trim(), _password);
                                if (ok && mounted) {
                                  _showSuccessSnackbar('ثبت نام با موفقیت انجام شد');
                                  await _goHome();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'ثبت نام',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                const Center(
                  child: Text(
                    'یا ادامه با',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: GoogleAuthButton(
                    label: 'ثبت نام با گوگل',
                    enabled: !_loading,
                    onIdToken: _loginWithGoogleIdToken,
                    onError: _showErrorSnackbar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ثبت‌نام/ورود با گوگل بدون Firebase: توکن گوگل (از دکمه‌ی موبایل یا از
  /// دکمه‌ی رسمی وب) به POST /api/auth/google فرستاده می‌شود. اگر اکانتی با آن
  /// ایمیل وجود داشته باشد لاگین می‌شود، وگرنه کاربر جدید ساخته می‌شود.
  Future<void> _loginWithGoogleIdToken(String idToken) async {
    setState(() => _loading = true);
    try {
      await _api.loginWithGoogle(idToken);
      if (mounted) {
        _showSuccessSnackbar('ثبت نام با موفقیت انجام شد');
        await _goHome();
      }
    } on ApiException catch (e) {
      if (mounted) _showErrorSnackbar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackbar('ثبت نام انجام نشد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.triangleExclamation,
                color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class AppColors {
  static const Color primary = Color(0xff00dd94);
  static const Color primaryLight = Color(0xff75ecc9);
  static const Color background = Color(0xff373737);
  static const Color cardBackground = Color(0xff292929);
  static const Color text = Colors.white;
  static const Color textSecondary = Colors.white54;
  static const Color warning = Color(0xffffff00);
  static const Color error = Color(0xffff0000);
}
