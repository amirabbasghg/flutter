import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:iranian_banks/iranian_banks.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../ViewModel/AppStateVM.dart';

// enum برای مدیریت وضعیت اعتبارسنجی بدون تغییر باقی می‌ماند
enum VerificationState { neutral, valid, invalid }

class ChooseCard extends StatelessWidget {
  const ChooseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fa')],
      locale: const Locale('fa'),
      home: const BankInfoPage(),
    );
  }
}

class BankInfoPage extends StatelessWidget {
  const BankInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شناسایی و اعتبارسنجی کارت بانکی'),
          bottom: const TabBar(
            tabs: [Tab(text: 'شماره کارت'), Tab(text: 'شماره شبا')],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              child: BankLookupTab(
                lookupFunction: IranianBanks.getBankFromCard,
                verificationFunction: IranianBanks.verifyCardNumber,
                labelText: 'شماره کارت',
                hintText: 'شماره ۱۶ رقمی کارت را وارد کنید',
                maxLength: 19, // 16 رقم + 3 خط تیره
                minLengthForLookup: 6, // شناسایی بانک از ۶ رقم
                keyboardType: TextInputType.number,
                isCard: true, // اضافه کردن پرچم برای تشخیص نوع ورودی
              ),
            ),
            SingleChildScrollView(
              child: BankLookupTab(
                lookupFunction: IranianBanks.getBankFromIban,
                verificationFunction: IranianBanks.verifyIBAN,
                labelText: 'شماره شبا (IBAN)',
                hintText: 'شماره شبا را با IR شروع کنید',
                maxLength: 26,
                minLengthForLookup: 7, // شناسایی بانک از ۷ کاراکتر (IR + 5)
                keyboardType: TextInputType.text,
                isCard: false, // اضافه کردن پرچم برای تشخیص نوع ورودی
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BankLookupTab extends StatefulWidget {
  final BankInfoView? Function(String) lookupFunction;
  final bool Function(String) verificationFunction;
  final String labelText;
  final String hintText;
  final int maxLength;
  final int minLengthForLookup;
  final TextInputType keyboardType;
  final bool isCard; // پرچم جدید برای تشخیص نوع ورودی

  const BankLookupTab({
    super.key,
    required this.lookupFunction,
    required this.verificationFunction,
    required this.labelText,
    required this.hintText,
    required this.maxLength,
    required this.minLengthForLookup,
    required this.keyboardType,
    required this.isCard,
  });

  @override
  State<BankLookupTab> createState() => _BankLookupTabState();
}

class _BankLookupTabState extends State<BankLookupTab> {
  final TextEditingController _controller = TextEditingController();
  BankInfoView? _bankInfo;
  VerificationState _verificationState = VerificationState.neutral;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    // برای شماره کارت، خط تیره‌ها را حذف می‌کنیم
    // برای شبا، فقط فاصله‌ها را حذف می‌کنیم
    final inputText = widget.isCard
        ? _controller.text.replaceAll(RegExp(r'[\s-]'), '')
        : _controller.text.replaceAll(RegExp(r'\s'), '');

    setState(() {
      // --- بخش اول: شناسایی بانک (بر اساس حداقل طول) ---
      if (inputText.length >= widget.minLengthForLookup) {
        _bankInfo = widget.lookupFunction(inputText);
      } else {
        _bankInfo = null;
      }

      // --- بخش دوم: اعتبارسنجی (فقط در طول کامل) ---
      final int expectedLength = widget.isCard ? 16 : 26;
      if (inputText.length == expectedLength) {
        final bool isValid = widget.verificationFunction(inputText);
        _verificationState =
        isValid ? VerificationState.valid : VerificationState.invalid;
      } else {
        // تا زمانی که طول کامل نشده، وضعیت خنثی است
        _verificationState = VerificationState.neutral;
      }
    });
  }

  Widget? _getVerificationIcon() {
    switch (_verificationState) {
      case VerificationState.valid:
        return const Icon(Icons.check_circle, color: Colors.green);
      case VerificationState.invalid:
        return const Icon(Icons.cancel, color: Colors.red);
      case VerificationState.neutral:
        return null;
    }
  }

  // فورمتر مخصوص شماره کارت
  List<TextInputFormatter> _getCardInputFormatters() {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(19), // 16 رقم + 3 خط تیره
      TextInputFormatter.withFunction((oldValue, newValue) {
        // اگر متن جدید خالی است
        if (newValue.text.isEmpty) return newValue;

        // حذف همه کاراکترهای غیرعددی به جز خط تیره
        final cleanedText = newValue.text.replaceAll(RegExp(r'[^\d-]'), '');

        // اگر بعد از حذف کاراکترهای غیرمجاز متن خالی شد
        if (cleanedText.isEmpty) return newValue.copyWith(text: '');

        // جدا کردن اعداد از خط تیره‌ها
        final digitsOnly = cleanedText.replaceAll('-', '');

        // اگر طول اعداد بیش از ۱۶ شد، مقدار قبلی را برگردان
        if (digitsOnly.length > 16) return oldValue;

        // فرمت کردن: XXXX-XXXX-XXXX-XXXX
        final buffer = StringBuffer();
        for (int i = 0; i < digitsOnly.length; i++) {
          if (i > 0 && i % 4 == 0) {
            buffer.write('-');
          }
          buffer.write(digitsOnly[i]);
        }

        final formatted = buffer.toString();
        return newValue.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }),
    ];
  }

  // فورمتر مخصوص شماره شبا
  List<TextInputFormatter> _getIbanInputFormatters() {
    return [
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')),
      LengthLimitingTextInputFormatter(26),
      TextInputFormatter.withFunction((oldValue, newValue) {
        // تبدیل به حروف بزرگ و حذف فاصله‌های اضافی
        final text = newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

        return newValue.copyWith(
          text: text,
          selection: newValue.selection,
        );
      }),
    ];
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            inputFormatters: widget.isCard
                ? _getCardInputFormatters()
                : _getIbanInputFormatters(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              suffixIcon: _getVerificationIcon(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 24),
          BankCardWidget(bankInfo: _bankInfo),
          ?_verificationState == VerificationState.valid ?
          Column(
            children: [
              const SizedBox(height: 8),
              ElevatedButton.icon(onPressed: ()async {
              var appStateVM = Provider.of<AppStateVM>(context, listen: false);
              Navigator.pop(context);
              await appStateVM.updateCurrentUserAccountNumber(_controller.text);
    }, label: Text('ذخیره'))
            ],
          ) : null,
        ],
      ),
    );
  }
}

// ویجت کارت بانکی بدون تغییر
class BankCardWidget extends StatelessWidget {
  final BankInfoView? bankInfo;

  const BankCardWidget({super.key, this.bankInfo});

  @override
  Widget build(BuildContext context) {
    if (bankInfo == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'برای نمایش اطلاعات، شماره را وارد کنید.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bankInfo!.primaryColor, bankInfo!.darkerColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: bankInfo!.logoBuilder(height: 40),
              ),
              const Spacer(),
              Text(
                bankInfo!.title,
                style: TextStyle(
                  color: bankInfo!.onPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      blurRadius: 2,
                      color: Colors.black26,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bankInfo!.name,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}