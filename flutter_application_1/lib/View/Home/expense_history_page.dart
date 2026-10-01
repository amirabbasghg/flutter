// lib/view/expense_history_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_persian_calendar/flutter_persian_calendar.dart'; // اضافه شد

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/User.dart';
import '../../ViewModel/AppStateVM.dart';

// enum برای انواع فیلتر کاربر
enum UserParticipationFilter {
  all, // همه پرداخت‌ها
  paidByUser, // کاربر پرداخت کننده بوده
  paidForUser, // کاربر دریافت کننده بوده
  involvedUser // کاربر در هزینه شریک بوده (پرداخت کننده یا دریافت کننده)
}

// enum برای انواع فیلتر تاریخ
enum DateFilterType {
  all, // همه تاریخ‌ها
  today, // امروز
  yesterday, // دیروز
  thisWeek, // این هفته
  thisMonth, // این ماه
  lastMonth, // ماه قبل
  custom // بازه زمانی دلخواه
}

class ExpenseHistoryPage extends StatefulWidget {
  @override
  _ExpenseHistoryPageState createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  late pw.Font _vazirFont;
  final List<String> _selectedGroupIds = [];
  UserParticipationFilter _userFilter = UserParticipationFilter.all;

  // متغیرهای جدید برای فیلتر تاریخ
  DateFilterType _dateFilter = DateFilterType.all;
  Jalali? _startDate;
  Jalali? _endDate;

  @override
  void initState() {
    super.initState();
    _loadFont();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStateVM = Provider.of<AppStateVM>(context, listen: false);
      final currentUser = appStateVM.currentUser;
      if (currentUser != null) {
        final userGroups = appStateVM.groups.where((group) =>
            group.memberIds.contains(currentUser.id)).toList();

        setState(() {
          _selectedGroupIds.addAll(userGroups.map((g) => g.id));
        });
      }
    });
  }

  Future<void> _loadFont() async {
    final fontData = await rootBundle.load('fonts/Vazirmatn-Bold.ttf');
    _vazirFont = pw.Font.ttf(fontData);
  }

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final currentUser = appStateVM.currentUser;
    final allGroups = appStateVM.groups.where((group) =>
        group.memberIds.contains(currentUser!.id)).toList();

    final allExpenses = _getFilteredExpenses(appStateVM);
    final allUsers = appStateVM.members;

    allExpenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    double totalAmount = allExpenses.fold(0, (sum, expense) => sum + expense.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تاریخچه هزینه‌ها',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade300,
                Colors.deepPurple,

              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 3,
        actions: [
          ElevatedButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.deepPurple),
              elevation: WidgetStatePropertyAll(10),
              iconSize: WidgetStatePropertyAll(10),
            ),
            icon: Icon(Icons.filter_list_outlined, color: Colors.white),
            onPressed: () => _showFilterDialog(context, allGroups),
            label: Text('فیتر گروه', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
          ElevatedButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.deepPurple),
              elevation: WidgetStatePropertyAll(10),
              iconSize: WidgetStatePropertyAll(10),
            ),
            icon: Icon(Iconsax.filter, color: Colors.white),
            onPressed: () => _showDateFilterDialog(context, allGroups),
            label: Text('فیتر تاریخ', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ],
      ),
      body: Column(
        children: [
          // فیلترهای انتخاب شده
          if (_selectedGroupIds.isNotEmpty ||
              _userFilter != UserParticipationFilter.all ||
              _dateFilter != DateFilterType.all)
            _buildActiveFiltersChips(allGroups),

          // آمار کلی
          if (allExpenses.isNotEmpty)
            Card(
              margin: EdgeInsets.all(16),
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '💰 مجموع هزینه‌ها',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${NumberFormat('#,###').format(totalAmount).toPersianDigit()} تومان',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '📝 تعداد هزینه ها',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          allExpenses.length.toString().toPersianDigit(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: allExpenses.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    _getEmptyStateMessage(),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'فیلترهای خود را تغییر دهید',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: allExpenses.length,
              itemBuilder: (context, index) {
                final expense = allExpenses[index];
                final jalaliDate = Jalali.fromDateTime(expense.dateTime);
                final paidByUser = expense.getPaidBy(allUsers);
                final paidForUsers = expense.getPaidFor(allUsers);
                final group = allGroups.firstWhere(
                      (g) => g.id == expense.groupId,
                  orElse: () => Group.create(name: 'نامشخص', memberIds: [], createdBy: appStateVM.currentUser!.id),
                );

                return _buildExpenseCard(
                    expense,
                    jalaliDate,
                    paidByUser,
                    paidForUsers,
                    group,
                    appStateVM,
                    currentUser!
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: allExpenses.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () => _showExportOptions(context, allExpenses, allUsers, allGroups),
        icon: Icon(Icons.share),
        label: Text('اشتراک‌گذاری'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      )
          : null,
    );
  }

  // فیلتر هزینه‌ها بر اساس گروه‌ها، فیلتر کاربر و تاریخ
  List<Expense> _getFilteredExpenses(AppStateVM appStateVM) {
    final currentUser = appStateVM.currentUser;
    if (currentUser == null) return [];

    List<Expense> filteredExpenses = appStateVM.allExpenses;

    // فیلتر بر اساس گروه‌ها
      filteredExpenses = filteredExpenses.where((expense) =>
          _selectedGroupIds.contains(expense.groupId)).toList();


    // فیلتر بر اساس مشارکت کاربر
    filteredExpenses = filteredExpenses.where((expense) {
      switch (_userFilter) {
        case UserParticipationFilter.all:
          return true;
        case UserParticipationFilter.paidByUser:
          return expense.paidById == currentUser.id;
        case UserParticipationFilter.paidForUser:
          return expense.paidForIds.contains(currentUser.id);
        case UserParticipationFilter.involvedUser:
          return expense.paidById == currentUser.id ||
              expense.paidForIds.contains(currentUser.id);
      }
    }).toList();

    // فیلتر بر اساس تاریخ
    filteredExpenses = filteredExpenses.where((expense) {
      return _isExpenseInDateRange(expense);
    }).toList();

    return filteredExpenses;
  }

  // بررسی آیا هزینه در بازه تاریخی انتخاب شده قرار دارد
  bool _isExpenseInDateRange(Expense expense) {
    if (_dateFilter == DateFilterType.all) return true;

    final expenseJalali = Jalali.fromDateTime(expense.dateTime);
    final now = Jalali.now();

    switch (_dateFilter) {
      case DateFilterType.today:
        return expenseJalali.year == now.year &&
            expenseJalali.month == now.month &&
            expenseJalali.day == now.day;

      case DateFilterType.yesterday:
        final yesterday = now - (1);
        return expenseJalali.year == yesterday.year &&
            expenseJalali.month == yesterday.month &&
            expenseJalali.day == yesterday.day;

      case DateFilterType.thisWeek:
        final startOfWeek = now - (now.weekDay - 1);
        return  (expenseJalali.isAfter(startOfWeek) || expenseJalali.isAtSameMomentAs(startOfWeek)) && expenseJalali.isBefore(now) ;

      case DateFilterType.thisMonth:
        return expenseJalali.year == now.year && expenseJalali.month == now.month;

      case DateFilterType.lastMonth:
        final lastMonth = now.month == 1
            ? Jalali(now.year - 1, 12, 1)
            : Jalali(now.year, now.month - 1, 1);
        return expenseJalali.year == lastMonth.year && expenseJalali.month == lastMonth.month;

      case DateFilterType.custom:
        if (_startDate == null || _endDate == null) return true;
        return (expenseJalali.isAfter(_startDate!) || expenseJalali.isAtSameMomentAs(_startDate!)) &&
            (expenseJalali.isBefore(_endDate!) || expenseJalali.isAtSameMomentAs(_endDate!));

      case DateFilterType.all:
      default:
        return true;
    }
  }

  // پیام مناسب برای حالت خالی
  String _getEmptyStateMessage() {
    if (_selectedGroupIds.isEmpty &&
        _userFilter == UserParticipationFilter.all &&
        _dateFilter == DateFilterType.all) {
      return 'هزینه‌ای در گروه‌های شما یافت نشد';
    }

    String message = 'هزینه‌ای با فیلترهای انتخاب شده یافت نشد';

    if (_dateFilter != DateFilterType.all) {
      message += '\nبازه زمانی: ${_getDateFilterLabel().toPersianDigit()}';
    }

    return message;
  }

  // نمایش چیپ‌های فیلترهای فعال
  Widget _buildActiveFiltersChips(List<Group> allGroups) {
    final List<Widget> chips = [];

    // چیپ فیلتر تاریخ
    if (_dateFilter != DateFilterType.all) {
      chips.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Chip(
            label: Text(_getDateFilterLabel()),
            backgroundColor: Colors.orange.withOpacity(0.2),
            deleteIcon: Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _dateFilter = DateFilterType.all;
                _startDate = null;
                _endDate = null;
              });
            },
          ),
        ),
      );
    }

    // چیپ فیلتر کاربر
    if (_userFilter != UserParticipationFilter.all) {
      chips.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Chip(
            label: Text(_getUserFilterLabel()),
            backgroundColor: Colors.deepPurple.withOpacity(0.2),
            deleteIcon: Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _userFilter = UserParticipationFilter.all;
              });
            },
          ),
        ),
      );
    }

    // چیپ‌های گروه‌های انتخاب شده
    for (final groupId in _selectedGroupIds) {
      final group = allGroups.firstWhere((g) => g.id == groupId);
      chips.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Chip(
            label: Text(group.name),
            backgroundColor: Colors.deepPurple.withOpacity(0.2),
            deleteIcon: Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedGroupIds.remove(groupId);
              });
            },
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: chips.isNotEmpty ? 60 : 0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  // برچسب فیلتر تاریخ
  String _getDateFilterLabel() {
    switch (_dateFilter) {
      case DateFilterType.today:
        return 'امروز';
      case DateFilterType.yesterday:
        return 'دیروز';
      case DateFilterType.thisWeek:
        return 'این هفته';
      case DateFilterType.thisMonth:
        return 'این ماه';
      case DateFilterType.lastMonth:
        return 'ماه قبل';
      case DateFilterType.custom:
        if (_startDate != null && _endDate != null) {
          return '${_startDate!.formatCompactDate().toPersianDigit()} تا ${_endDate!.formatCompactDate().toPersianDigit()}';
        }
        return 'بازه دلخواه';
      case DateFilterType.all:
      default:
        return 'همه تاریخ‌ها';
    }
  }

  // برچسب فیلتر کاربر
  String _getUserFilterLabel() {
    switch (_userFilter) {
      case UserParticipationFilter.paidByUser:
        return 'پرداخت‌های من';
      case UserParticipationFilter.paidForUser:
        return 'دریافت‌های من';
      case UserParticipationFilter.involvedUser:
        return 'مشارکت‌های من';
      case UserParticipationFilter.all:
      default:
        return 'همه';
    }
  }

  // دیالوگ فیلترها
  void _showFilterDialog(BuildContext context, List<Group> allGroups) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('فیلترها'),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                
                      // بخش فیلتر کاربر
                      _buildUserFilterSection(setState),
                
                      Divider(),
                
                      // بخش فیلتر گروه‌ها
                      _buildGroupFilterSection(allGroups, setState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('لغو'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text('اعمال فیلتر'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showDateFilterDialog(BuildContext context, List<Group> allGroups) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('فیلترها'),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // بخش فیلتر تاریخ
                      _buildDateFilterSection(setState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('لغو'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text('اعمال فیلتر'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // بخش فیلتر تاریخ
  Widget _buildDateFilterSection(void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'بازه زمانی:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),

        // گزینه‌های فیلتر تاریخ
        Column(
          children: DateFilterType.values.map((filter) {
            return RadioListTile<DateFilterType>(
              title: Text(_getDateFilterTitle(filter)),
              value: filter,
              groupValue: _dateFilter,
              onChanged: (value) {
                setState(() {
                  _dateFilter = value!;
                  if (_dateFilter != DateFilterType.custom) {
                    _startDate = null;
                    _endDate = null;
                  }
                });
              },
            );
          }).toList(),
        ),

        // بخش انتخاب بازه دلخواه
        if (_dateFilter == DateFilterType.custom)
          Column(
            children: [
              SizedBox(height: 16),
              Text('انتخاب بازه دلخواه:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectStartDate(context),
                      child: Text(
                        _startDate == null
                            ? 'از تاریخ'
                            : _startDate!.formatCompactDate().toPersianDigit(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectEndDate(setState),
                      child: Text(
                        _endDate == null
                            ? 'تا تاریخ'
                            : _endDate!.formatCompactDate().toPersianDigit(),
                      ),
                    ),
                  ),
                ],
              ),

              if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'تاریخ شروع باید قبل از تاریخ پایان باشد',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // عنوان فیلتر تاریخ
  String _getDateFilterTitle(DateFilterType filter) {
    switch (filter) {
      case DateFilterType.all:
        return 'همه تاریخ‌ها';
      case DateFilterType.today:
        return 'امروز';
      case DateFilterType.yesterday:
        return 'دیروز';
      case DateFilterType.thisWeek:
        return 'این هفته';
      case DateFilterType.thisMonth:
        return 'این ماه';
      case DateFilterType.lastMonth:
        return 'ماه قبل';
      case DateFilterType.custom:
        return 'بازه دلخواه';
    }
  }

  // انتخاب تاریخ شروع
  Future<Jalali?> _selectStartDate(BuildContext context) async {
    Jalali? selectedDate ;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: PersianCalendar(
            height: 380.0,
            initialDate: selectedDate,
            startingDate: Jalali(1400, 1, 1),
            endingDate: Jalali(1450, 12, 29),
            onDateChanged: (Jalali newDate) {
              selectedDate = newDate;
            },
            primaryColor: Colors.deepPurple,
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
                        if (selectedDate != null) {
                          setState(() {
                            _startDate = selectedDate;
                            if (_endDate != null && _startDate!.isAfter(_endDate!)) {
                              _endDate = null;
                            }
                          });
                        }
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

  // انتخاب تاریخ پایان
  void _selectEndDate(void Function(void Function()) setState) async {
    final initialDate = _endDate ?? _startDate ?? Jalali.now();
    Jalali? selectedDate ;
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: PersianCalendar(
              height: 380.0,
              initialDate: initialDate,
              startingDate: Jalali(1400, 1, 1),
              endingDate: Jalali(1450, 12, 29),
              onDateChanged: (Jalali newDate) {
                selectedDate = newDate;
              },
              primaryColor: Colors.deepPurple,
              backgroundColor: Theme
                  .of(context)
                  .scaffoldBackgroundColor,
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
                          if (selectedDate != null) {
                            setState(() {
                              _endDate = selectedDate;
                            });
                          }
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
        }
    );
  }

  // بخش فیلتر کاربر (بدون تغییر)
  Widget _buildUserFilterSection(void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نقش شما در هزینه:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Column(
          children: UserParticipationFilter.values.map((filter) {
            return RadioListTile<UserParticipationFilter>(
              title: Text(_getUserFilterTitle(filter)),
              value: filter,
              groupValue: _userFilter,
              onChanged: (value) {
                setState(() {
                  _userFilter = value!;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // عنوان فیلتر کاربر
  String _getUserFilterTitle(UserParticipationFilter filter) {
    switch (filter) {
      case UserParticipationFilter.all:
        return 'همه پرداخت‌ها';
      case UserParticipationFilter.paidByUser:
        return 'من پرداخت کرده‌ام';
      case UserParticipationFilter.paidForUser:
        return 'برای من پرداخت شده';
      case UserParticipationFilter.involvedUser:
        return 'من شریک بودم (پرداخت یا دریافت)';
    }
  }

  // بخش فیلتر گروه‌ها (بدون تغییر)
  Widget _buildGroupFilterSection(List<Group> allGroups, void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'گروه‌ها:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),

        if (allGroups.isNotEmpty)
          ListTile(
            title: Text(_selectedGroupIds.length == allGroups.length ? 'لغو انتخاب همه' : 'انتخاب همه'),
            trailing: Icon(_selectedGroupIds.length == allGroups.length ? Icons.check_box : Icons.check_box_outline_blank),
            onTap: () {
              setState(() {
                if (_selectedGroupIds.length != allGroups.length) {
                  _selectedGroupIds.clear();
                  _selectedGroupIds.addAll(allGroups.map((g) => g.id));
                } else {
                  _selectedGroupIds.clear();
                }
              });
            },
          ),

        Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allGroups.length,
            itemBuilder: (context, index) {
              final group = allGroups[index];
              final isSelected = _selectedGroupIds.contains(group.id);

              return CheckboxListTile(
                title: Text(group.name),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedGroupIds.add(group.id);
                    } else {
                      _selectedGroupIds.remove(group.id);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

// ساخت کارت هزینه با قابلیت حذف
  Widget _buildExpenseCard(
      Expense expense,
      Jalali jalaliDate,
      User paidByUser,
      List<User> paidForUsers,
      Group group,
      AppStateVM appState,
      User currentUser // اضافه شده
      ) {
    final canDelete = expense.paidById == currentUser.id; // بررسی امکان حذف

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getAmountColor(expense.amount),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${NumberFormat('#,###').format(expense.amount).toPersianDigit()} تومان',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _getAmountColor(expense.amount),
                  ),
                ),
                SizedBox(height: 4),
                if (expense.description.isNotEmpty)
                  Text(
                    expense.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  '👤 پرداخت کننده: ${paidByUser.name}',
                  style: TextStyle(fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      '👥 دریافت کنندگان: ${paidForUsers.length.toString().toPersianDigit()} نفر',
                      style: TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      onPressed: (){_showGroupDetails(appState, paidForUsers , expense);},
                      icon: Stack(
                        children: [
                          Icon(Icons.groups, size: 25),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.info, size: 12 , color: _getAmountColor(expense.amount),),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${group.name}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _getAmountColor(expense.amount),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  jalaliDate.formatCompactDate().toPersianDigit(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            contentPadding: EdgeInsets.all(16),
          ),

          // دکمه حذف برای پرداخت کننده
          if (canDelete)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.delete, color: Colors.white, size: 18),
                  onPressed: () => _showDeleteConfirmationDialog(expense, appState),
                ),
              ),
            ),
        ],
      ),
    );
  }

// دیالوگ تأیید حذف هزینه
  void _showDeleteConfirmationDialog(Expense expense, AppStateVM appState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('حذف هزینه'),
          content: Text('آیا مطمئن هستید که می‌خواهید این هزینه را حذف کنید؟ این عمل قابل بازگشت نیست.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteExpense(expense, appState);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('حذف'),
            ),
          ],
        );
      },
    );
  }

// متد حذف هزینه
  Future<void> _deleteExpense(Expense expense, AppStateVM appState) async {
    try {
      // پیدا کردن گروه مربوطه
      final group = appState.groups.firstWhere(
            (g) => g.id == expense.groupId,
        orElse: () => Group.create(name: 'نامشخص', memberIds: [], createdBy: appState.currentUser!.id),
      );

      // حذف هزینه از گروه (روی سرور). بدون await، خطای سرور هرگز به این
      // try/catch نمی‌رسید و پیام موفقیت الکی نشان داده می‌شد.
      await appState.removeExpenseFromGroup(group, expense);

      if (!mounted) return;

      // نمایش پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ هزینه با موفقیت حذف شد'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // بروزرسانی UI
      setState(() {});

    } catch (e) {
      // نمایش پیام خطا
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا در حذف هزینه: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getAmountColor(double amount) {
    if (amount > 100000) return Colors.red;
    if (amount > 50000) return Colors.orange;
    if (amount > 20000) return Colors.blue;
    return Colors.green;
  }

  void _showExportOptions(BuildContext context, List<Expense> expenses, List<User> users, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('ذخیره به عنوان PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndSavePdf(expenses, users, groups);
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text('اشتراک‌گذاری به عنوان PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndSharePdf(expenses, users, groups);
                },
              ),
              ListTile(
                leading: Icon(Icons.print),
                title: Text('چاپ PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _printPdf(expenses, users, groups);
                },
              ),
            ],
          ),
        );
      },
    );
  }

// متدهای مربوط به PDF
  Future<void> _generateAndSavePdf(List<Expense> expenses, List<User> users, List<Group> groups) async {
    try {
      final pdf = await _createPdfDocument(expenses, users, groups);

      final directory = await getDownloadsDirectory();
      final fileName = 'تاریخچه_هزینه‌ها_${Jalali.now().year}${Jalali.now().month}${Jalali.now().day}.pdf';
      final file = File('${directory?.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF با موفقیت ذخیره شد'),
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تولید PDF: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _generateAndSharePdf(List<Expense> expenses, List<User> users, List<Group> groups) async {
    try {
      final pdf = await _createPdfDocument(expenses, users, groups);

      final directory = await getTemporaryDirectory();
      final fileName = 'تاریخچه_هزینه‌ها_${Jalali.now().year}${Jalali.now().month}${Jalali.now().day}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'تاریخچه هزینه‌ها');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اشتراک‌گذاری PDF: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _printPdf(List<Expense> expenses, List<User> users, List<Group> groups) async {
    try {
      final pdf = await _createPdfDocument(expenses, users, groups);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در چاپ PDF: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<pw.Document> _createPdfDocument(List<Expense> expenses, List<User> users, List<Group> groups) async {
    final pdf = pw.Document();
    final totalAmount = expenses.fold(0.0, (sum, expense) => sum + expense.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: _vazirFont),
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 20),
          _buildStatsCard(expenses.length, totalAmount),
          pw.SizedBox(height: 20),
          _buildTableTitle('لیست کامل هزینه ها'),
          pw.SizedBox(height: 10),
          _buildExpensesTable(expenses, users, groups),
          _buildFooter(),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.deepPurple,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      padding: pw.EdgeInsets.all(16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'گزارش کامل تاریخچه هزینه ها',
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.white,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatsCard(int count, double totalAmount) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.deepPurple.shade(0.1),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
      ),
      padding: pw.EdgeInsets.all(16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            title: 'مجموع هزینه ها',
            value: '${_formatNumber(totalAmount)} تومان',
            isPrimary: true,
          ),
          _buildStatItem(
            title: 'تعداد هزینه ها',
            value: _formatNumber(count),
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem({ required String title, required String value, required bool isPrimary}) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.deepPurple,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            color: isPrimary
                ? PdfColors.deepPurple
                : PdfColors.black,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  pw.Widget _buildTableTitle(String title) {
    return pw.Center(
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          color: PdfColors.deepPurple,
        ),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _buildExpensesTable(List<Expense> expenses, List<User> users, List<Group> groups) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.deepPurple,
        width: 0.8,
      ),
      columnWidths: {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(0.8),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.8),
      },
      children: [
        _buildTableHeader(),
        ..._buildTableRows(expenses, users, groups),
      ],
    );
  }

  pw.TableRow _buildTableHeader() {
    final headerColor = PdfColors.deepPurple;

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: headerColor,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      children: [
        _buildPdfCell('تاریخ', isHeader: true, textColor: PdfColors.white),
        _buildPdfCell('مبلغ', isHeader: true, textColor: PdfColors.white),
        _buildPdfCell('پرداخت کننده', isHeader: true, textColor: PdfColors.white),
        _buildPdfCell('گیرندگان', isHeader: true, textColor: PdfColors.white),
        _buildPdfCell('گروه', isHeader: true, textColor: PdfColors.white),
        _buildPdfCell('توضیحات', isHeader: true, textColor: PdfColors.white),
      ],
    );
  }

  List<pw.TableRow> _buildTableRows(List<Expense> expenses, List<User> users, List<Group> groups) {
    return expenses.asMap().entries.map((entry) {
      final index = entry.key;
      final expense = entry.value;

      final paidByUser = expense.getPaidBy(users);
      final paidForUsers = expense.getPaidFor(users);
      final group = groups.firstWhere(
            (g) => g.id == expense.groupId,
        orElse: () => Group.create(name: 'نامشخص', memberIds: [], createdBy:'' ),
      );
      final jalaliDate = Jalali.fromDateTime(expense.dateTime);

      final rowColor = index % 2 == 0
          ? PdfColors.grey50
          : PdfColors.white;

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: [
          _buildPdfCell(jalaliDate.formatCompactDate().toPersianDigit()),
          _buildPdfCell('${_formatNumber(expense.amount)}',
              amount: expense.amount),
          _buildPdfCell(paidByUser.name),
          _buildPdfCell('${paidForUsers.length.toString().toPersianDigit()} نفر'),
          _buildPdfCell(group.name),
          _buildPdfCell(expense.description.isNotEmpty ? expense.description : '-'),
        ],
      );
    }).toList();
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, PdfColor? textColor, double? amount}) {
    PdfColor cellColor = textColor ?? PdfColors.black;

    if (amount != null) {
      if (amount > 100000) {
        cellColor = PdfColors.red;
      } else if (amount > 50000) {
        cellColor = PdfColors.orange;
      } else if (amount > 20000) {
        cellColor = PdfColors.blue;
      } else {
        cellColor = PdfColors.green;
      }
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          color: cellColor,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 20),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          'تولید شده توسط اپلیکیشن مدیریت هزینه ها - ${Jalali.now().formatCompactDate().toPersianDigit()}',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number is int) return NumberFormat('#,###', 'fa_IR').format(number);
    if (number is double) return NumberFormat('#,###', 'fa_IR').format(number);
    return number.toString();
  }

  void _showGroupDetails(AppStateVM appStateVM, List members , Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),

            SizedBox(height: 16),

            // لیست اعضا با قابلیت حذف برای مالک
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'دریافت کنندگان:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'مبلغ دریافت شده:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),

            // لیست اعضا
            Container(
              constraints: BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final user = members[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    trailing: Text(
                      '${NumberFormat('#,###').format((expense.getCustomShare(user.id))).toPersianDigit()} تومان',
                      style: TextStyle( fontSize: 16),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),

            // دکمه‌های پایین
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('بستن'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}