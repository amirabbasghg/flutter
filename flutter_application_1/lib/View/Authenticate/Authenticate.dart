import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/Services/Auth.dart';
import 'package:toggle_switch/toggle_switch.dart';

import 'Sign_in.dart';
import 'Sign_up.dart';

class Authenticate extends StatefulWidget {
  const Authenticate({super.key});

  @override
  State<Authenticate> createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  int _toggleIndex = 0; // لتتبع حالة التبديل الحالية

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff373737),
      appBar: AppBar(
        backgroundColor: const Color(0xff373737),
        title: Center(
          child: ToggleSwitch(
            minWidth: 240.0,
            initialLabelIndex: _toggleIndex,
            activeBgColor: const [Color(0xff00ffaf)],
            inactiveBgColor: const Color(0xff292929),
            totalSwitches: 2,
            labels: const ['ورود', 'ثبت نام'],
            fontSize: 20,
            radiusStyle: true,
            cornerRadius: 10,
            borderColor: const [Color(0xff292929)],
            activeFgColor: Colors.white,
            inactiveFgColor: Colors.white54,
            onToggle: (index) {
              setState(() {
                _toggleIndex = index ?? 0;
              });
            },
            borderWidth: 6,
          ),
        ),
      ),
      body: _toggleIndex == 0 ? SignIn() : SignUp(), // ستحتاج لإنشاء واجهة SignUp
    );
  }
}
