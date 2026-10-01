import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:intl/intl.dart';
import 'package:toggle_switch/toggle_switch.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/WordPairModel.dart';
import 'package:namer_app/model/User.dart';
import '../../Services/Api.dart';
import '../../ViewModel/AppStateVM.dart';
import '../../model/ExpenseManager.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:flutter_persian_calendar/flutter_persian_calendar.dart';

import 'ServicesScreen.dart';

class AddExpensePage extends StatefulWidget {
  @override
  _AddExpensePageState createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  Group? _selectedGroup;
  User? _selectedPayer;
  final List<User> _selectedReceivers = [];
  Jalali _selectedJalali = Jalali.now();

  // متغیرهای جدید برای تقسیم غیرمساوی
  bool _isEqualSplit = true;
  final Map<User, TextEditingController> _customAmountControllers = {};

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCustomAmounts);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCustomAmounts);
    _amountController.dispose();
    _descriptionController.dispose();
    _customAmountControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _updateCustomAmounts() {
    if (_amountController.text.isNotEmpty && _selectedReceivers.isNotEmpty) {
      final totalAmount = Decimal.parse(_amountController.text.replaceAll(',', ''));

      setState(() {
        if (_isEqualSplit) {
          // تقسیم مساوی دقیق
          final share = totalAmount / Decimal.fromInt(_selectedReceivers.length);

          for (final user in _selectedReceivers) {
            if (!_customAmountControllers.containsKey(user)) {
              _customAmountControllers[user] = TextEditingController();
            }
            _customAmountControllers[user]!.text = share.toString();
          }
        }
      });
    }
  }

  void _updateCustomControllers() {
    // حذف کاربرانی که دیگه نیستن
    _customAmountControllers.keys
        .where((user) => !_selectedReceivers.contains(user))
        .toList()
        .forEach((user) {
      _customAmountControllers[user]?.dispose();
      _customAmountControllers.remove(user);
    });

    // اضافه کردن کاربرانی که تازه اضافه شدن
    for (final user in _selectedReceivers) {
      if (!_customAmountControllers.containsKey(user)) {
        _customAmountControllers[user] = TextEditingController();
      }
    }

    // اگر تقسیم مساوی است، مقادیرشون رو به صورت مساوی پر کن
    if (!_isEqualSplit && _amountController.text.isNotEmpty) {
      final totalText = _amountController.text.replaceAll(',', '');
      final formatter = NumberFormat("#,###");
      if (totalText.isNotEmpty) {
        try {
          final total = Decimal.parse(totalText);
          final share = total / Decimal.fromInt(_selectedReceivers.length);

          // تقسیم مساوی با مدیریت باقیمانده
          final roundedShare = share.toBigInt().toInt(); // قسمت صحیح
          final totalInt = total.toBigInt().toInt();
          final remainder = totalInt - (roundedShare * _selectedReceivers.length);

          for (int i = 0; i < _selectedReceivers.length; i++) {
            final user = _selectedReceivers[i];
            // به اولین کاربران باقیمانده را اضافه کنید
            final amount = i < remainder ? roundedShare + 1 : roundedShare;
            _customAmountControllers[user]?.text = formatter.format(amount);
          }
        } catch (e) {
          // در صورت خطا در parsing
          print('Error parsing amount: $e');
        }
      }
    }

    setState(() {}); // UI بروزرسانی می‌شود
  }

  // گرادیانت سبز برای چک باکس‌ها
  final LinearGradient _greenGradient = LinearGradient(
    colors: [Colors.green.shade600, Colors.green.shade400, Colors.green.shade300],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'اضافه کردن هزینه',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // کارت اطلاعات
              Card(
                elevation: 3,
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Icon(Icons.receipt, size: 40, color: Colors.green),
                      SizedBox(height: 8),
                      Text(
                        'ثبت هزینه جدید',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // فیلد مبلغ
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    final number = int.parse(newValue.text.replaceAll(',', ''));
                    final formatted = NumberFormat("#,###").format(number);
                    return newValue.copyWith(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }),
                ],
                decoration: InputDecoration(
                  labelText: 'مبلغ (تومان)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green, // حاشیه سبز پررنگ
                      width: 2.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green, // حاشیه سبز پررنگ
                      width: 2.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green.shade700, // حاشیه سبز تیره هنگام فوکوس
                      width: 2.5,
                    ),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'لطفا مبلغ را وارد کنید';
                  final cleanValue = value.replaceAll(',', '');
                  if (double.tryParse(cleanValue) == null) return 'لطفا یک عدد معتبر وارد کنید';
                  return null;
                },
                onChanged: (value) {
                  final cleanValue = value.replaceAll(',', '');
                  final parsed = double.tryParse(cleanValue);
                  if (parsed != null) {
                    appStateVM.setAmount(parsed);
                    _updateCustomControllers();
                  }
                },
              ),
              SizedBox(height: 16),

              // فیلد توضیحات
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'توضیحات',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green,
                      width: 2.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green,
                      width: 2.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green.shade700,
                      width: 2.5,
                    ),
                  ),
                  prefixIcon: Icon(Icons.description, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green[50],
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),

              // انتخاب گروه
              DropdownButtonFormField<Group>(
                value: _selectedGroup,
                decoration: InputDecoration(
                  labelText: 'گروه',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green,
                      width: 2.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green,
                      width: 2.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green.shade700,
                      width: 2.5,
                    ),
                  ),
                  prefixIcon: Icon(Icons.group, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green[50],
                ),
                items: appStateVM.getCurrentUserGroups().map((Group group) {
                  return DropdownMenuItem<Group>(
                    value: group,
                    child: Text(group.name, style: TextStyle(fontSize: 16)),
                  );
                }).toList(),
                onChanged: (Group? newValue) {
                  setState(() {
                    _selectedGroup = newValue;
                    _selectedPayer = null;
                    _selectedReceivers.clear();
                    _customAmountControllers.clear();
                  });
                },
                validator: (value) => value == null ? 'لطفا یک گروه انتخاب کنید' : null,
              ),
              SizedBox(height: 16),

              // انتخاب پرداخت کننده
              if (_selectedGroup != null)
                DropdownButtonFormField<User>(
                  value: _selectedPayer,
                  decoration: InputDecoration(
                    labelText: 'پرداخت کننده',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green,
                        width: 2.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green,
                        width: 2.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2.5,
                      ),
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.green),
                    filled: true,
                    fillColor: Colors.green[50],
                  ),
                  items: _selectedGroup!.getMembers(appStateVM.members).map((User user) {
                    return DropdownMenuItem<User>(
                      value: user,
                      child: Text(user.name, style: TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (User? newValue) {
                    setState(() {
                      _selectedPayer = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'لطفا پرداخت کننده را انتخاب کنید' : null,
                ),
              SizedBox(height: 16),

              // انتخاب دریافت کنندگان
              if (_selectedGroup != null && _selectedGroup!.memberIds.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👥 دریافت کنندگان:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_selectedReceivers.length.toString().toPersianDigit()} نفر انتخاب شده',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                ? _greenGradient
                                : null,
                            color: _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                ? null
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green,
                              width: 2.0,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              _toggleSelectAll(_selectedGroup!.getMembers(appStateVM.members));
                            },
                            child: Row(
                              children: [
                                SizedBox(width: 4),
                                AnimatedSize(
                                  duration: Duration(milliseconds: 300),
                                  child: Text(
                                    _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                        ? 'لغو انتخاب همه'
                                        : 'انتخاب همه',
                                    style: TextStyle(
                                      color: _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                          ? Colors.white
                                          : Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text('  '),
                                Icon(
                                  _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  size: 20,
                                  color: _selectedReceivers.length == _selectedGroup!.getMembers(appStateVM.members).length
                                      ? Colors.white
                                      : Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ..._selectedGroup!.getMembers(appStateVM.members).map((user) {
                      final isSelected = _selectedReceivers.contains(user);
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.green,
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isSelected ? _greenGradient : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            activeColor: Colors.white,
                            checkColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              user.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedReceivers.add(user);
                                  if (!_customAmountControllers.containsKey(user)) {
                                    _customAmountControllers[user] = TextEditingController();
                                  }
                                } else {
                                  _selectedReceivers.remove(user);
                                  _customAmountControllers[user]?.dispose();
                                  _customAmountControllers.remove(user);
                                }
                                _updateCustomAmounts();
                                _updateCustomControllers();
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              SizedBox(height: 16),

              // انتخاب نوع تقسیم
              if (_selectedReceivers.isNotEmpty)
                Card(
                  color: Colors.green[50],
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.green,
                      width: 2.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نوع تقسیم هزینه:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text('تقسیم مساوی'),
                                activeColor: Colors.green,
                                value: true,
                                groupValue: _isEqualSplit,
                                onChanged: (value) => setState(() {
                                  _isEqualSplit = value!;
                                  _updateCustomAmounts();
                                }),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text('تقسیم غیرمساوی'),
                                activeColor: Colors.green,
                                value: false,
                                groupValue: _isEqualSplit,
                                onChanged: (value) {
                                  setState(() => _isEqualSplit = value!);
                                  _updateCustomControllers();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // فیلدهای مبلغ اختصاصی برای تقسیم غیرمساوی
              if (_selectedReceivers.isNotEmpty && !_isEqualSplit)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Text(
                      '💰 مبلغ هر نفر:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    ..._selectedReceivers.map((user) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text('${user.name}:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _customAmountControllers[user],
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                                  TextInputFormatter.withFunction((oldValue, newValue) {
                                    if (newValue.text.isEmpty) return newValue;
                                    final number = int.parse(newValue.text.replaceAll(',', ''));
                                    final formatted = NumberFormat("#,###").format(number);
                                    return newValue.copyWith(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                  }),
                                ],
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.green[50],
                                  labelText: 'مبلغ (تومان)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.green,
                                      width: 2.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.green,
                                      width: 2.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.green.shade700,
                                      width: 2.5,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'لطفا مبلغ را وارد کنید';
                                  final cleanValue = value.replaceAll(',', '');
                                  if (double.tryParse(cleanValue) == null) return 'عدد معتبر وارد کنید';
                                  return null;
                                },
                                onChanged: (value) {
                                  final cleanValue = value.replaceAll(',', '');
                                  final parsed = double.tryParse(cleanValue);
                                  if (parsed != null) {
                                    appStateVM.setAmount(parsed);
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 8),
                    _buildTotalValidation(),
                  ],
                ),

              // انتخاب تاریخ
              Card(
                color: Colors.green[50],
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.green,
                    width: 2.0,
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.calendar_today, color: Colors.green),
                  title: Text('تاریخ', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _formatJalaliDate(_selectedJalali),
                    style: TextStyle(fontSize: 16),
                  ),
                  trailing: Icon(Icons.edit, color: Colors.green),
                  onTap: () async {
                    final Jalali? picked = await _showPersianCalendarPicker(context);
                    if (picked != null && picked != _selectedJalali) {
                      setState(() => _selectedJalali = picked);
                    }
                  },
                ),
              ),
              SizedBox(height: 24),

              // دکمه اضافه کردن هزینه
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade400],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _addExpense(appStateVM),
                  icon: Icon(Icons.add_circle, color: Colors.white, size: 25),
                  label: Text('اضافه کردن هزینه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalValidation() {
    if (!_isEqualSplit && _amountController.text.isNotEmpty && _selectedReceivers.isNotEmpty) {
      final totalAmount = double.parse(_amountController.text.replaceAll(',', ''));
      var customTotal = 0.0;

      for (final user in _selectedReceivers) {
        final amountText = _customAmountControllers[user]?.text.replaceAll(',', '');
        customTotal += double.tryParse(amountText!) ?? 0;
      }

      final isValid = customTotal == totalAmount;

      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isValid ? Colors.green[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isValid ? Colors.green : Colors.red,
            width: 2.0,
          ),
        ),
        child: Row(
          children: [
            Icon(isValid ? Icons.check_circle : Icons.error, color: isValid ? Colors.green : Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                isValid
                    ? '✅ مجموع مبالغ صحیح است (${NumberFormat('#,###').format(customTotal).toPersianDigit()} تومان)'
                    : '❌ مجموع مبالغ باید ${NumberFormat('#,###').format(totalAmount).toPersianDigit()} تومان باشد (حالا: ${NumberFormat('#,###').format(customTotal).toPersianDigit()} تومان)',
                style: TextStyle(color: isValid ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox();
  }

  Future<void> _addExpense(AppStateVM appStateVM) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGroup == null || _selectedPayer == null || _selectedReceivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لطفا تمام فیلدهای ضروری را پر کنید'), backgroundColor: Colors.red),
        );
        return;
      }

      final totalAmount = double.parse(_amountController.text.replaceAll(',', ''));

      // بررسی تقسیم غیرمساوی
      if (!_isEqualSplit) {
        var customTotal = 0.0;

        for (final user in _selectedReceivers) {
          final amountText = _customAmountControllers[user]?.text?.replaceAll(',', '') ?? '0';
          customTotal += double.tryParse(amountText) ?? 0;
        }

        // کمی tolerance برای خطای گرد کردن در نظر بگیرید
        final isValid = (customTotal - totalAmount).abs() < 0.01;

        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('مجموع مبالغ فردی باید برابر با مبلغ کل باشد\n'
                  'مبلغ کل: $totalAmount\n'
                  'مجموع مقادیر: $customTotal'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final expense = _isEqualSplit
          ? appStateVM.createExpense(
        amount: totalAmount,
        paidBy: _selectedPayer!,
        paidFor: _selectedReceivers,
        group: _selectedGroup!,
        dateTime: _selectedJalali.toDateTime(),
        description: _descriptionController.text,
      )
          : ExpenseManager.createCustomSplitExpense(
        payer: _selectedPayer!,
        amount: totalAmount,
        participants: _selectedReceivers,
        customSplits: _getCustomSplits(),
        group: _selectedGroup!,
        dateTime: _selectedJalali.toDateTime(),
        description: _descriptionController.text,
      );

      // ثبت روی سرور (Cloudflare D1). قبلاً Firestore بود و خطا را قورت می‌داد؛
      // حالا اگر سرور قبول نکند باید به کاربر گفته شود و فرم پاک نشود.
      try {
        await appStateVM.addExpenseToGroup(_selectedGroup!, expense);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'ثبت هزینه انجام نشد'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      // نمایش خلاصه
      _showExpenseSummary(expense, appStateVM.members);

      // پاک کردن فیلدها
      _resetForm();
    }
  }

  Map<User, double> _getCustomSplits() {
    final splits = <User, double>{};
    for (final user in _selectedReceivers) {
      final amountText = _customAmountControllers[user]?.text.replaceAll(',', '') ?? '0';
      splits[user] = double.tryParse(amountText) ?? 0;
    }
    return splits;
  }

  void _showExpenseSummary(Expense expense, List<User> allUsers) {
    String summary;

    if (_isEqualSplit) {
      final share = expense.amount / _selectedReceivers.length;
      summary = '💰 مبلغ کل: ${expense.amount.toStringAsFixed(0)} تومان\n'
          '💳 پرداخت کننده: ${_selectedPayer!.name}\n'
          '📊 تقسیم مساوی: هر نفر ${share.toStringAsFixed(0)} تومان\n'
          '👥 تعداد افراد: ${_selectedReceivers.length} نفر';
    } else {
      final customSplits = _getCustomSplits();
      summary = ExpenseManager.getExpenseBreakdown(
        expense: expense,
        allUsers: allUsers,
        customSplits: customSplits,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ هزینه اضافه شد\n$summary'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _toggleSelectAll(List<User> allMembers) {
    setState(() {
      if (_selectedReceivers.length == allMembers.length) {
        // اگر همه انتخاب شده‌اند، همه را deselect کن
        _selectedReceivers.clear();
      } else {
        // اگر نه، همه را select کن
        _selectedReceivers.clear();
        _selectedReceivers.addAll(allMembers);
      }
    });
  }

  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedGroup = null;
      _selectedPayer = null;
      _selectedReceivers.clear();
      _customAmountControllers.forEach((_, controller) => controller.dispose());
      _customAmountControllers.clear();
      _selectedJalali = Jalali.now();
      _isEqualSplit = true;
    });
  }

  String _formatJalaliDate(Jalali date) {
    final monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];

    return '${date.day.toString().toPersianDigit()} ${monthNames[date.month - 1]} ${date.year.toString().toPersianDigit()}';
  }

  // متد اصلاح شده برای نمایش تقویم
  Future<Jalali?> _showPersianCalendarPicker(BuildContext context) async {
    Jalali? selectedDate = _selectedJalali;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: PersianCalendar(
            height: 380.0,
            initialDate: _selectedJalali,
            startingDate: Jalali(1400, 1, 1),
            endingDate: Jalali(1450, 12, 29),
            onDateChanged: (Jalali newDate) {
              selectedDate = newDate;
            },
            primaryColor: Colors.green,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            textStyle: TextStyle(
              fontFamily: 'Vazir',
            ),
            confirmButton: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('لغو'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('تأیید'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return selectedDate;
  }
}