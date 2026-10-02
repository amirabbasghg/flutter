import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:iranian_banks/iranian_banks.dart';
import 'package:namer_app/View/Home/BankInfoPage.dart';
import 'package:provider/provider.dart';

import '../../Services/Api.dart';
import '../../ViewModel/AppStateVM.dart';
import 'AdminPanelPage.dart';
import 'CardNumberInputFormatter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    var currentUser = appStateVM.currentUser;

    // استخراج اطلاعات بانک بر اساس شماره حساب
    BankInfoView? bankInfo;
    if (currentUser?.accountNumber != null &&
        currentUser!.accountNumber!.length >= 6) {
      bankInfo = IranianBanks.getBankFromCard(currentUser.accountNumber!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'پروفایل کاربری',
          style: TextStyle(
            fontSize: 20,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // بخش عکس پروفایل
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: appStateVM.currentUser?.photoURL != null
                    ? NetworkImage(appStateVM.currentUser!.photoURL!)
                    : null,
                child: appStateVM.currentUser?.photoURL == null
                    ? Icon(Icons.person_outline, size: 80, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 30),

            // کارت شماره حساب با بک‌گراند بانک
            if (bankInfo != null && currentUser!.accountNumber != null)
              _buildBankThemedCardNumber(context, bankInfo, currentUser.accountNumber!)
            else
              _buildDefaultCardNumber(context, currentUser!),

            SizedBox(height: 16),

            // کارت اطلاعات دیگر (نام و ایمیل)
            _buildUserInfoCard(context, currentUser!),

            if (currentUser != null && currentUser.isSuperAdmin) ...[
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.security, size: 20),
                  label: Text(
                    '🛡️ ورود به پنل مدیریت کل (Super Admin)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPanelPage(),
                      ),
                    );
                  },
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  // کارت شماره حساب با تم بانکی
  Widget _buildBankThemedCardNumber(BuildContext context, BankInfoView bankInfo, String accountNumber) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bankInfo.primaryColor, bankInfo.darkerColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // هدر کارت با لوگوی بانک
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // لوگوی بانک
                  bankInfo.logoBuilder(height: 40),

                  // نام بانک
                  Text(
                    bankInfo.title,
                    style: TextStyle(
                      color: bankInfo.onPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // شماره حساب
              _buildCardNumberItem(
                context,
                accountNumber: accountNumber,
                textColor: bankInfo.onPrimaryColor,
                iconColor: bankInfo.onPrimaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // کارت شماره حساب پیش فرض (وقتی بانک شناسایی نشد)
  Widget _buildDefaultCardNumber(BuildContext context, dynamic currentUser) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: _buildCardNumberItem(
          context,
          accountNumber: currentUser.accountNumber,
        ),
      ),
    );
  }

  // آیتم شماره حساب
  Widget _buildCardNumberItem(BuildContext context, {
    required String? accountNumber,
    Color? textColor,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(
            Iconsax.card,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
            size: 24
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شماره حساب',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor != null
                      ? Colors.white.withOpacity(0.2)
                      : null,
                  foregroundColor: textColor ?? Colors.black,
                  elevation: 0,
                ),
                label: Text(
                  accountNumber == null
                      ? 'شماره حسابی وارد نشده'
                      : _formatCardNumber(accountNumber),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: accountNumber != null ? Icon(Iconsax.copy, size: 18) : null,
                onPressed: accountNumber == null ? null : () {
                  Clipboard.setData(ClipboardData(
                      text: accountNumber.replaceAll('-', '')
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('شماره حساب کپی شد'))
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.edit,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BankInfoPage())
            );
          },
        ),
      ],
    );
  }

  // کارت اطلاعات کاربر (نام و ایمیل)
  Widget _buildUserInfoCard(BuildContext context, dynamic currentUser) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoItem(
              context,
              icon: Icons.person,
              title: 'نام',
              value: currentUser.name ?? ' ',
              onEdit: () => _showEditNameDialog(context, currentUser.name ?? ''),
            ),
            Divider(
              indent: 5,
              endIndent: 5,
              thickness: 1,
              color: Colors.grey[300],
            ),
            _buildInfoItem(
              context,
              icon: Icons.email,
              title: 'ایمیل',
              value: currentUser.email,
            ),
          ],
        ),
      ),
    );
  }

  // تابع برای فرمت کردن شماره کارت
  String _formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 16) return cardNumber;

    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  // تابع کمکی برای ایجاد آیتم‌های اطلاعات
  Widget _buildInfoItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: currentName);
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تغییر نام نمایش'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'نام جدید',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'لطفاً نام خود را وارد کنید';
                }
                if (value.trim().length > 50) {
                  return 'نام نمی‌تواند بیش از 50 کاراکتر باشد';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => loading = true);
                        final newName = nameController.text.trim();
                        final appStateVM =
                            Provider.of<AppStateVM>(context, listen: false);
                        try {
                          await appStateVM.updateCurrentUser(name: newName);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('نام با موفقیت تغییر یافت'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on ApiException catch (e) {
                          setDialogState(() => loading = false);
                          String errorMsg;
                          if (e.message == 'display-name-taken' || e.statusCode == 409) {
                            errorMsg = 'این نام‌کاربری قبلاً استفاده شده است';
                          } else {
                            errorMsg = e.message;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } catch (_) {
                          setDialogState(() => loading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تغییر نام انجام نشد'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCard(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    TextEditingController cardController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغییر شماره حساب'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: cardController,
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    decoration: InputDecoration(
                      labelText: 'شماره حساب',
                      hintText: '1234-5678-9012-3456',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardNumberInputFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'لطفاً شماره حساب را وارد کنید';
                      }
                      String digits = value.replaceAll('-', '');
                      if (digits.length != 16) {
                        return 'شماره حساب باید 16 رقمی باشد';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (_formKey.currentState != null) {
                        _formKey.currentState!.validate();
                      }
                    },
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  cardController.text.replaceAll('-', '').isNotEmpty &&
                      cardController.text.replaceAll('-', '').length < 16
                      ? 'شماره حساب باید 16 رقمی باشد'
                      : '',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                String cardNumber = cardController.text.replaceAll('-', '');
                var appStateVM = Provider.of<AppStateVM>(context, listen: false);
                Navigator.pop(context);
                await appStateVM.updateCurrentUserAccountNumber(cardNumber);
              }
            },
            child: Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}