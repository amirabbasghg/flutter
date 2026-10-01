// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // این import را اضافه کنید
import 'package:namer_app/View/Wrapper.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as pdp;
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'Services/TokenStore.dart';
import 'ViewModel/AppStateVM.dart';
import 'ViewModel/HomeVM.dart';

void main() async {
  // Initialize Hive
  WidgetsFlutterBinding.ensureInitialized();

  // باز کردن باکس احراز هویت (TokenStore) — قبل از runApp لازم است
  await Hive.initFlutter();
  await TokenStore.init();

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
      // ⚠️ اینجا قبلاً Consumer<AppStateVM> + FutureBuilder(appState.initialize())
      // بود. چون initialize() داخل build صدا زده می‌شد، هر notifyListeners یک
      // بار دیگر آن را اجرا می‌کرد: ۳ کوئری تازه + ۳ لیسنر تازه، و هر لیسنر
      // خودش notifyListeners می‌زد → حلقه‌ی بی‌پایان و چند برابر شدن لیسنرها.
      // MaterialApp به appState وابسته نیست، پس مستقیم ساخته می‌شود و
      // مقداردهی اولیه در سازنده‌ی AppStateVM انجام می‌گیرد.
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        locale: const Locale("fa"),
        localizationsDelegates: const [
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
        home: const Wrapper(),
      ),
    );
  }
}