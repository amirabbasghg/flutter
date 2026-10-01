import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../Services/Api.dart';
import '../../ViewModel/AppStateVM.dart';
import 'GoogleAuthButton.dart';
import 'Sign_up.dart';
import '../Home/HomePage.dart';

class SignIn extends StatefulWidget {
  SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final ApiService _api = ApiService.instance;
  final _formKey = GlobalKey<FormState>();
  bool isVisible = true;
  bool _loading = false;
  String _email = '';
  String _password = '';

  /// ورود با بک‌اند D1/Workers. موفقیت یعنی true.
  Future<bool> _apiLogin(String email, String password) async {
    setState(() => _loading = true);
    try {
      await _api.login(email: email, password: password);
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        _showErrorSnackbar(e.statusCode == 401
            ? 'ایمیل یا رمز عبور اشتباه است'
            : e.message);
      }
      return false;
    } catch (_) {
      if (mounted) _showErrorSnackbar('اتصال به سرور برقرار نشد');
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// بعد از هر ورود موفق باید AppStateVM هم خبردار شود، وگرنه currentUser
  /// تهی می‌ماند و صفحه‌های داخلی «لطفاً ابتدا وارد شوید» نشان می‌دهند.
  Future<void> _enterApp() async {
    await context.read<AppStateVM>().onSignedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  Future<void> _handleGoogleIdToken(String idToken) async {
    setState(() => _loading = true);
    try {
      await _api.loginWithGoogle(idToken);
      if (mounted) {
        _showSuccessSnackbar('ورود با گوگل انجام شد');
        await _enterApp();
      }
    } on ApiException catch (e) {
      if (mounted) _showErrorSnackbar(e.message);
    } catch (_) {
      if (mounted) _showErrorSnackbar('ورود با گوگل انجام نشد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    'ورود',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const SizedBox(height: 5),
                TextFormField(
                  decoration: InputDecoration(
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
                    hintText: 'ایمیل خود را وارد کنید',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    labelText: 'ایمیل',
                    labelStyle: TextStyle(
                      color: AppColors.primary,
                    ),
                    prefixIcon: Icon(Icons.email),
                    prefixIconColor: AppColors.primary,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  style: const TextStyle(
                    color: AppColors.text,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا ایمیل خود را وارد کنید';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _email = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 5),
                TextFormField(
                  decoration: InputDecoration(
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
                    hintText: 'رمز عبور خود را وارد کنید',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    labelText: 'رمز عبور',
                    labelStyle: TextStyle(
                      color: AppColors.primary,
                    ),
                    prefixIcon: Icon(Icons.lock),
                    prefixIconColor: AppColors.primary,
                    suffixIcon: IconButton(
                      icon: isVisible
                          ? const Icon(Icons.visibility_off)
                          : const Icon(Icons.visibility),
                      onPressed: () {
                        setState(() {
                          isVisible = !isVisible;
                        });
                      },
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  obscureText: isVisible,
                  style: const TextStyle(
                    color: AppColors.text,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا رمز عبور خود را وارد کنید';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () async {
                        if (_email.isEmpty) {
                          _showErrorSnackbar('لطفا ایمیل خود را وارد کنید');
                          return;
                        }

                        // بازیابی رمز با بک‌اند جدید (توکن یک‌بارمصرف در D1).
                        // سرویس ایمیل هنوز وصل نشده: در حالت dev سرور خودِ توکن
                        // را برمی‌گرداند (devResetToken) تا همین‌جا تست شود.
                        try {
                          final result =
                              await _api.forgotPassword(_email.trim());
                          if (result.success) {
                            if (result.devResetToken != null) {
                              _showSuccessSnackbar(
                                  'کد بازیابی (فقط dev): ${result.devResetToken}');
                            } else {
                              _showSuccessSnackbar(
                                  'لینک بازنشانی رمز عبور به ایمیل شما ارسال شد');
                            }
                          } else {
                            _showErrorSnackbar('خطا در ارسال ایمیل. لطفا مجدداً تلاش کنید');
                          }
                        } on ApiException catch (e) {
                          _showErrorSnackbar(e.message);
                        } catch (_) {
                          _showErrorSnackbar('اتصال به سرور برقرار نشد');
                        }
                      },
                      child: const Text(
                        'فراموشی رمز عبور',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
                                // ورود با بک‌اند جدید (D1 + JWT)
                                final ok = await _apiLogin(_email, _password);
                                if (ok && mounted) {
                                  _showSuccessSnackbar('ورود با موفقیت انجام شد');
                                  await _enterApp();
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
                              'ورود',
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
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: GoogleAuthButton(
                    label: 'ورود با گوگل',
                    enabled: !_loading,
                    onIdToken: _handleGoogleIdToken,
                    onError: _showErrorSnackbar,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUp()),
                      );
                    },
                    child: const Text(
                      'حساب کاربری ندارید؟ ثبت نام کنید',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.triangleExclamation, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
              ),
            ),
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
        duration: Duration(seconds: 3),
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