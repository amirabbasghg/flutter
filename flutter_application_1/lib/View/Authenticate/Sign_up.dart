import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gradient_icon/gradient_icon.dart';
import 'package:provider/provider.dart';

import '../../Services/Auth.dart';
import '../../Services/GoogleSignInService.dart';
import '../../ViewModel/AppStateVM.dart';
import 'ChooseUsername.dart';

class SignUp extends StatefulWidget {
  SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool isVisible = true;
  String _email = '';
  String _password = '';

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
                    prefixIcon: Icon(Icons.lock,),
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
                    if (value.length < 6) {
                      return 'رمز عبور باید حداقل 6 کاراکتر باشد';
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
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     InkWell(
                //       onTap: () {
                //         // افزودن عملکرد فراموشی رمز عبور
                //       },
                //       child: const Text(
                //         'فراموشی رمز عبور',
                //         style: TextStyle(
                //           color: AppColors.primary,
                //           fontSize: 12,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //     InkWell(
                //       onTap: () {
                //         // افزودن عملکرد ثبت نام با موبایل
                //       },
                //       child: const Text(
                //         'ثبت نام با موبایل',
                //         style: TextStyle(
                //           color: AppColors.primary,
                //           fontSize: 12,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
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
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // ثبت نام با Firebase
                          dynamic result = await _authService.signUpEmailAndPassword(_email, _password);

                          if (result is User) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ثبت نام با موفقیت انجام شد'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // هدایت به صفحه انتخاب نام کاربری
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChooseUsername(user: result),
                              ),
                            );
                          } else if (result is String) {
                            // خطا
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.triangleExclamation, color: AppColors.warning),
                                    const SizedBox(width: 10),
                                    Text('ثبت نام انجام نشد'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
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
                      child: const Text(
                        'ثبت نام',
                        style: TextStyle(
                          color: Colors.black,
                          // fontWeight: FontWeight.bold ,
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
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      _handleGoogleSignIn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.text,
                      foregroundColor: AppColors.background,
                      elevation: 100,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    icon: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                          ],
                          stops: [0.0, 0.4, 0.7, 0.9],
                        ).createShader(bounds);
                      },
                      child: FaIcon(
                        FontAwesomeIcons.google,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    label: Text(
                      'ثبت نام با گوگل',
                      style: TextStyle(
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
  void _handleGoogleSignIn() async {
    try {
      User? user = await GoogleSignInService.signInWithGoogle();
      final appState = Provider.of<AppStateVM>(context, listen: false);

      if (user == null) {
        _showErrorSnackbar('ثبت نام انجام نشد');
      } else if (appState.hasEmail(user.email!)){
        _showErrorSnackbar('ایمیل تکراری است');
        await GoogleSignInService.signOut();
      } else {
        _showSuccessSnackbar('ثبت نام با موفقیت انجام شد ');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChooseUsername(user: user),
          ),
        );

        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
      }
    } catch (e) {
      _showErrorSnackbar('ثبت نام انجام نشد');
    }
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