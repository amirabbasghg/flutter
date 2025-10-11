import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../Services/Database.dart';
import '../../ViewModel/AppStateVM.dart';

import '../Home/HomePage.dart';

class ChooseUsername extends StatefulWidget {
  final User user;

  const ChooseUsername({super.key, required this.user});

  @override
  State<ChooseUsername> createState() => _ChooseUsernameState();
}

class _ChooseUsernameState extends State<ChooseUsername> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
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
                const SizedBox(height: 60),
                const Text(
                  'انتخاب نام کاربری',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'یک نام کاربری منحصر به فرد انتخاب کنید',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _usernameController,
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
                    hintText: 'نام کاربری خود را وارد کنید',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    labelText: 'نام کاربری',
                    labelStyle: TextStyle(
                      color: AppColors.primary,
                    ),
                    prefixIcon: Icon(Icons.person),
                    prefixIconColor: AppColors.primary,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  style: const TextStyle(
                    color: AppColors.text,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام کاربری را وارد کنید';
                    }
                    if (value.length < 3) {
                      return 'نام کاربری باید حداقل 3 کاراکتر باشد';
                    }
                    return null;
                  },
                ),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ),

                const SizedBox(height: 30),
                const Text(
                  'نکات انتخاب نام کاربری:',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildTipItem('• حداقل 3 کاراکتر باشد'),
                _buildTipItem('• نام کاربری باید منحصر به فرد باشد'),

                const SizedBox(height: 50),
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
                      onPressed: _isLoading ? null : _submitUsername,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'ادامه',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),

                // دکمه برای استفاده از نام گوگل
                if (widget.user.displayName != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLight.withOpacity(0.3),
                            blurRadius: 5,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitUsernameWithGoogle,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: AppColors.cardBackground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: AppColors.cardBackground.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                          'استفاده از "${widget.user.displayName}"',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUsername() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final username = _usernameController.text.trim();

        // بررسی تکراری نبودن نام کاربری
        final isAvailable = await _firestoreService.isDisplayNameAvailable(username);

        if (!isAvailable) {
          setState(() {
            _errorMessage = 'این نام کاربری قبلاً انتخاب شده است';
            _isLoading = false;
          });
          return;
        }

        // ذخیره نام کاربری
        await _firestoreService.saveDisplayName(username, widget.user.email ?? '');

        final appState = Provider.of<AppStateVM>(context, listen: false);

        // ایجاد کاربر جدید در Firestore
        // final userData = {
        //   'uid': widget.user.uid,
        //   'displayName': username,
        //   'email': widget.user.email,
        //   'photoURL': widget.user.photoURL,
        // };

        // await _firestoreService.saveUser(userData);

        // اضافه کردن کاربر به AppState
        await appState.addUserFromFirebase(widget.user, username);
        await appState.startSetCurrentUserFromFirebase(widget.user, username);

        _navigateToHome();

      } catch (e) {
        setState(() {
          _errorMessage = 'خطا در ذخیره نام کاربری';
          _isLoading = false;
        });
        print('Error: $e');
      }
    }
  }

  Future<void> _submitUsernameWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final displayName = widget.user.displayName;
      if (displayName == null || displayName.isEmpty) {
        setState(() {
          _errorMessage = 'نام کاربری گوگل موجود نیست';
          _isLoading = false;
        });
        return;
      }

      // بررسی تکراری نبودن نام کاربری
      final isAvailable = await _firestoreService.isDisplayNameAvailable(displayName);

      if (!isAvailable) {
        setState(() {
          _errorMessage = 'این نام کاربری قبلاً انتخاب شده است';
          _isLoading = false;
        });
        return;
      }

      // ذخیره نام کاربری
      await _firestoreService.saveDisplayName(displayName, widget.user.email ?? '');

      final appState = Provider.of<AppStateVM>(context, listen: false);

      // ایجاد کاربر جدید در Firestore
      final userData = {
        'uid': widget.user.uid,
        'displayName': displayName,
        'email': widget.user.email,
        'photoURL': widget.user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.saveUser(userData);

      await appState.addUserFromFirebase(widget.user, displayName);
      await appState.startSetCurrentUserFromFirebase(widget.user, displayName);

      _navigateToHome();

    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در ذخیره نام کاربری';
        _isLoading = false;
      });
      print('Error: $e');
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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