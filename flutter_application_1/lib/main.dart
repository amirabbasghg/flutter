// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // این import را اضافه کنید
import 'package:namer_app/Model/Expense.dart';
import 'package:namer_app/Model/Group.dart';
import 'package:namer_app/View/Authenticate/Authenticate.dart';
import 'package:namer_app/View/Wrapper.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as pdp;
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'Model/User.dart';
import 'View/Home/HomePage.dart';
import 'ViewModel/AppStateVM.dart';
import 'ViewModel/HomeVM.dart';

void main() async {
  // Initialize Hive
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register Hive adapters

  // await Hive.deleteBoxFromDisk('usersBox');
  // await Hive.deleteBoxFromDisk('groupsBox');
  // await Hive.deleteBoxFromDisk('expensesBox');


  // Open the boxes


  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppStateVM()),
        ChangeNotifierProvider(create: (context) => HomeVM()),
      ],
      child: Consumer<AppStateVM>(
        builder: (context, appState, _) {
          return FutureBuilder(
            future: appState.initialize(), // منتظر initialize بمون
            builder: (context, snapshot) {
              // if (appState.members.isEmpty) {
              //   return MaterialApp(
              //     home: Scaffold(
              //       body: Center(child: CircularProgressIndicator()),
              //     ),
              //   );
              // }

              return MaterialApp(
                title: 'Namer App',
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple ),
                ),
                locale: const Locale("fa"),
                localizationsDelegates: [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  pdp.PersianMaterialLocalizations.delegate,
                  pdp.PersianCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale("fa", 'IR'),
                  Locale("en"),
                ],
                home: const Wrapper(), // اینجا دیگه امنه
              );
            },
          );
        },
      ),
    );
  }
}