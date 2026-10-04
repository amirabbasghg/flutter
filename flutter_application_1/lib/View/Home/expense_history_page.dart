// lib/view/expense_history_page.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/User.dart';
import '../../Services/PdfSaver.dart';
import '../../Services/Api.dart';
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

  // متغیرهای فیلتر تاریخ
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
    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text('لطفاً ابتدا وارد شوید')),
      );
    }

    final allGroups = appStateVM.groups.where((group) =>
        group.memberIds.contains(currentUser.id)).toList();

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
            fontSize: 18,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(Icons.filter_list_outlined, color: Colors.white, size: 16),
            onPressed: () => _showFilterDialog(context, allGroups),
            label: Text('فیلتر گروه', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
          SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(Iconsax.filter, color: Colors.white, size: 16),
            onPressed: () => _showDateFilterDialog(context, allGroups),
            label: Text('فیلتر تاریخ', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
          SizedBox(width: 8),
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
              color: Colors.deepPurple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.deepPurple.shade200, width: 1),
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
                            color: Colors.deepPurple.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${NumberFormat('#,###').format(totalAmount).toPersianDigit()} تومان',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 36, width: 1, color: Colors.deepPurple.shade200),
                    Column(
                      children: [
                        Text(
                          '📝 تعداد هزینه‌ها',
                          style: TextStyle(
                            color: Colors.deepPurple.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          allExpenses.length.toString().toPersianDigit(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
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
                          color: Colors.deepPurple.shade200,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _getEmptyStateMessage(),
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        orElse: () => Group.create(name: 'نامشخص', memberIds: [], createdBy: currentUser.id),
                      );

                      return _buildExpenseCard(
                          expense,
                          jalaliDate,
                          paidByUser,
                          paidForUsers,
                          group,
                          appStateVM,
                          currentUser
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: allExpenses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showExportOptions(context, allExpenses, allUsers, allGroups),
              icon: Icon(Icons.share, color: Colors.white),
              label: Text('اشتراک‌گذاری', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.deepPurple,
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
        return (expenseJalali.isAfter(startOfWeek) || expenseJalali.isAtSameMomentAs(startOfWeek)) && expenseJalali.isBefore(now);

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
            backgroundColor: Colors.deepPurple.withOpacity(0.15),
            labelStyle: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            deleteIcon: Icon(Icons.close, size: 16, color: Colors.deepPurple),
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
            backgroundColor: Colors.deepPurple.withOpacity(0.15),
            labelStyle: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            deleteIcon: Icon(Icons.close, size: 16, color: Colors.deepPurple),
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
      final group = allGroups.firstWhere((g) => g.id == groupId, orElse: () => Group.create(name: '', memberIds: [], createdBy: ''));
      if (group.name.isNotEmpty) {
        chips.add(
          Container(
            margin: EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(group.name),
              backgroundColor: Colors.deepPurple.withOpacity(0.15),
              labelStyle: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
              deleteIcon: Icon(Icons.close, size: 16, color: Colors.deepPurple),
              onDeleted: () {
                setState(() {
                  _selectedGroupIds.remove(groupId);
                });
              },
            ),
          ),
        );
      }
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
                      _buildUserFilterSection(setState),
                      Divider(),
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
                    this.setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
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
              title: Text('فیلتر تاریخ'),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                    this.setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
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

        Column(
          children: DateFilterType.values.map((filter) {
            return RadioListTile<DateFilterType>(
              title: Text(_getDateFilterTitle(filter)),
              value: filter,
              groupValue: _dateFilter,
              activeColor: Colors.deepPurple,
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple),
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

  Future<Jalali?> _selectStartDate(BuildContext context) async {
    final selectedDate = await showPersianDatePicker(
      context: context,
      initialDate: _startDate ?? Jalali.now(),
      firstDate: Jalali(1400, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      locale: const Locale('fa'),
    );

    if (selectedDate != null) {
      setState(() {
        _startDate = selectedDate;
        if (_endDate != null && _startDate!.isAfter(_endDate!)) {
          _endDate = null;
        }
      });
    }

    return selectedDate;
  }

  void _selectEndDate(void Function(void Function()) setState) async {
    final selectedDate = await showPersianDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? Jalali.now(),
      firstDate: Jalali(1400, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      locale: const Locale('fa'),
    );

    if (selectedDate != null) {
      setState(() {
        _endDate = selectedDate;
      });
    }
  }

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
              activeColor: Colors.deepPurple,
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
            trailing: Icon(_selectedGroupIds.length == allGroups.length ? Icons.check_box : Icons.check_box_outline_blank, color: Colors.deepPurple),
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
                activeColor: Colors.deepPurple,
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

  // ساخت کارت هزینه با قابلیت‌های ویرایش و حذف
  Widget _buildExpenseCard(
      Expense expense,
      Jalali jalaliDate,
      User paidByUser,
      List<User> paidForUsers,
      Group group,
      AppStateVM appState,
      User currentUser
      ) {
    // طبق قانون حذف: فقط پرداخت کننده اصلی می‌تواند حذف کند
    final canDelete = expense.paidById == currentUser.id;
    // طبق دسترسی ویرایش: پرداخت‌کننده یا ادمین اصلی mhsyny293
    final canEdit = expense.paidById == currentUser.id || currentUser.isSuperAdmin;

    final cardThemeColor = Colors.deepPurple;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cardThemeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: cardThemeColor,
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
                    color: cardThemeColor,
                  ),
                ),
                SizedBox(height: 4),
                if (expense.description.isNotEmpty)
                  Text(
                    expense.description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () { _showGroupDetails(appState, paidForUsers, expense); },
                      icon: Icon(Icons.info_outline, size: 18, color: cardThemeColor),
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
                  group.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: cardThemeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  jalaliDate.formatCompactDate().toPersianDigit(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          ),

          // دکمه‌های اقدام عملیاتی (ویرایش و حذف)
          Positioned(
            top: 6,
            left: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canEdit)
                  Container(
                    margin: EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.all(4),
                      icon: Icon(Icons.edit_rounded, color: Colors.deepPurple.shade800, size: 16),
                      onPressed: () => _showEditExpenseDialog(context, expense, appState),
                      tooltip: 'ویرایش هزینه',
                    ),
                  ),
                if (canDelete)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.all(4),
                      icon: Icon(Icons.delete_rounded, color: Colors.red.shade800, size: 16),
                      onPressed: () => _showDeleteConfirmationDialog(expense, appState),
                      tooltip: 'حذف هزینه',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // باز کردن فرم شیک ویرایش هزینه
  void _showEditExpenseDialog(BuildContext context, Expense expense, AppStateVM appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditExpenseSheet(expense: expense, appStateVM: appState),
    ).then((updated) {
      if (updated == true) {
        setState(() {});
      }
    });
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
                foregroundColor: Colors.white,
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
      final group = appState.groups.firstWhere(
        (g) => g.id == expense.groupId,
        orElse: () => Group.create(name: 'نامشخص', memberIds: [], createdBy: appState.currentUser!.id),
      );

      await appState.removeExpenseFromGroup(group, expense);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ هزینه با موفقیت حذف شد'),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {});

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا در حذف هزینه: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showExportOptions(BuildContext context, List<Expense> expenses, List<User> users, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.deepPurple),
                title: Text('ذخیره به عنوان PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndSavePdf(expenses, users, groups);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: Colors.deepPurple),
                title: Text('اشتراک‌گذاری به عنوان PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndSharePdf(expenses, users, groups);
                },
              ),
              ListTile(
                leading: Icon(Icons.print, color: Colors.deepPurple),
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

  String get _pdfFileName {
    final now = Jalali.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'expenses-${now.year}-$m-$d.pdf';
  }

  Future<void> _generateAndSavePdf(List<Expense> expenses, List<User> users, List<Group> groups) async {
    try {
      final pdf = await _createPdfDocument(expenses, users, groups);
      final message = await savePdfBytes(await pdf.save(), _pdfFileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تولید PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _generateAndSharePdf(List<Expense> expenses, List<User> users, List<Group> groups) async {
    try {
      final pdf = await _createPdfDocument(expenses, users, groups);
      await Printing.sharePdf(bytes: await pdf.save(), filename: _pdfFileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اشتراک‌گذاری PDF: $e'),
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
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
          _buildPdfCell(_formatNumber(expense.amount)),
          _buildPdfCell(paidByUser.name),
          _buildPdfCell('${paidForUsers.length.toString().toPersianDigit()} نفر'),
          _buildPdfCell(group.name),
          _buildPdfCell(expense.description.isNotEmpty ? expense.description : '-'),
        ],
      );
    }).toList();
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, PdfColor? textColor}) {
    PdfColor cellColor = textColor ?? PdfColors.deepPurple;

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'دریافت کنندگان:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                Text(
                  'مبلغ دریافت شده:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ],
            ),
            SizedBox(height: 8),

            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final user = members[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: Colors.deepPurple.shade800,
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
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

/// فرم مدرن و بنفش ویرایش هزینه
class _EditExpenseSheet extends StatefulWidget {
  final Expense expense;
  final AppStateVM appStateVM;

  const _EditExpenseSheet({
    Key? key,
    required this.expense,
    required this.appStateVM,
  }) : super(key: key);

  @override
  __EditExpenseSheetState createState() => __EditExpenseSheetState();
}

class __EditExpenseSheetState extends State<_EditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  Group? _selectedGroup;
  User? _selectedPayer;
  final List<User> _selectedReceivers = [];
  late Jalali _selectedJalali;

  bool _isEqualSplit = true;
  final Map<User, TextEditingController> _customAmountControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    final appState = widget.appStateVM;

    _amountController = TextEditingController(
      text: NumberFormat("#,###").format(expense.amount.toInt()),
    );
    _descriptionController = TextEditingController(text: expense.description);
    _selectedJalali = Jalali.fromDateTime(expense.dateTime);
    _isEqualSplit = expense.isEqualSplit;

    // پیدا کردن گروه
    final matchingGroupList = appState.groups.where((g) => g.id == expense.groupId).toList();
    if (matchingGroupList.isNotEmpty) {
      _selectedGroup = matchingGroupList.first;
    }

    if (_selectedGroup != null) {
      final groupMembers = _selectedGroup!.getMembers(appState.members);

      // پیدا کردن پرداخت‌کننده
      final matchingPayer = groupMembers.where((u) => u.id == expense.paidById).toList();
      if (matchingPayer.isNotEmpty) {
        _selectedPayer = matchingPayer.first;
      }

      // پیدا کردن دریافت‌کنندگان
      for (final userId in expense.paidForIds) {
        final matchingUser = groupMembers.where((u) => u.id == userId).toList();
        if (matchingUser.isNotEmpty) {
          _selectedReceivers.add(matchingUser.first);
        }
      }

      // مقادیر custom split
      for (final user in _selectedReceivers) {
        final amount = expense.customSplits[user.id] ?? (expense.amount / (_selectedReceivers.isEmpty ? 1 : _selectedReceivers.length));
        _customAmountControllers[user] = TextEditingController(
          text: NumberFormat("#,###").format(amount.toInt()),
        );
      }
    }

    _amountController.addListener(_updateCustomAmounts);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCustomAmounts);
    _amountController.dispose();
    _descriptionController.dispose();
    _customAmountControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _updateCustomAmounts() {
    if (_amountController.text.isNotEmpty && _selectedReceivers.isNotEmpty && _isEqualSplit) {
      try {
        final totalAmount = Decimal.parse(_amountController.text.replaceAll(',', ''));
        final share = totalAmount / Decimal.fromInt(_selectedReceivers.length);

        setState(() {
          for (final user in _selectedReceivers) {
            if (!_customAmountControllers.containsKey(user)) {
              _customAmountControllers[user] = TextEditingController();
            }
            _customAmountControllers[user]!.text = NumberFormat("#,###").format(share.toBigInt().toInt());
          }
        });
      } catch (_) {}
    }
  }

  void _updateCustomControllers() {
    _customAmountControllers.keys
        .where((user) => !_selectedReceivers.contains(user))
        .toList()
        .forEach((user) {
      _customAmountControllers[user]?.dispose();
      _customAmountControllers.remove(user);
    });

    for (final user in _selectedReceivers) {
      if (!_customAmountControllers.containsKey(user)) {
        _customAmountControllers[user] = TextEditingController();
      }
    }

    if (!_isEqualSplit && _amountController.text.isNotEmpty) {
      final totalText = _amountController.text.replaceAll(',', '');
      final formatter = NumberFormat("#,###");
      if (totalText.isNotEmpty) {
        try {
          final total = Decimal.parse(totalText);
          final share = total / Decimal.fromInt(_selectedReceivers.length);

          final roundedShare = share.toBigInt().toInt();
          final totalInt = total.toBigInt().toInt();
          final remainder = totalInt - (roundedShare * _selectedReceivers.length);

          for (int i = 0; i < _selectedReceivers.length; i++) {
            final user = _selectedReceivers[i];
            final amount = i < remainder ? roundedShare + 1 : roundedShare;
            _customAmountControllers[user]?.text = formatter.format(amount);
          }
        } catch (_) {}
      }
    }

    setState(() {});
  }

  InputDecoration _purpleInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.deepPurple.shade700),
      filled: true,
      fillColor: Colors.deepPurple.shade50.withOpacity(0.5),
      prefixIcon: Icon(icon, color: Colors.deepPurple),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.deepPurple, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appStateVM;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // هدر ویرایش هزینه
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_rounded, color: Colors.deepPurple, size: 24),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'ویرایش هزینه',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ],
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
                  decoration: _purpleInputDecoration('مبلغ (تومان)', Icons.attach_money_rounded),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'لطفا مبلغ را وارد کنید';
                    final cleanValue = value.replaceAll(',', '');
                    if (double.tryParse(cleanValue) == null) return 'عدد معتبر وارد کنید';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // فیلد توضیحات
                TextFormField(
                  controller: _descriptionController,
                  decoration: _purpleInputDecoration('توضیحات', Icons.description_outlined),
                  maxLines: 2,
                ),
                SizedBox(height: 16),

                // انتخاب گروه
                DropdownButtonFormField<Group>(
                  value: _selectedGroup,
                  decoration: _purpleInputDecoration('گروه', Icons.groups_outlined),
                  items: appState.getCurrentUserGroups().map((Group group) {
                    return DropdownMenuItem<Group>(
                      value: group,
                      child: Text(group.name, style: TextStyle(fontSize: 15)),
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
                  validator: (value) => value == null ? 'لطفا گروه را انتخاب کنید' : null,
                ),
                SizedBox(height: 16),

                // انتخاب پرداخت‌کننده
                if (_selectedGroup != null)
                  DropdownButtonFormField<User>(
                    value: _selectedPayer,
                    decoration: _purpleInputDecoration('پرداخت کننده', Icons.person_outlined),
                    items: _selectedGroup!.getMembers(appState.members).map((User user) {
                      return DropdownMenuItem<User>(
                        value: user,
                        child: Text(user.name, style: TextStyle(fontSize: 15)),
                      );
                    }).toList(),
                    onChanged: (User? newValue) {
                      setState(() {
                        _selectedPayer = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'لطفا پرداخت‌کننده را انتخاب کنید' : null,
                  ),
                SizedBox(height: 16),

                // انتخاب دریافت کنندگان
                if (_selectedGroup != null) ...[
                  Text(
                    '👥 دریافت کنندگان:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple.shade900),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _selectedGroup!.getMembers(appState.members).map((user) {
                      final isSelected = _selectedReceivers.contains(user);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(user.name),
                        selectedColor: Colors.deepPurple.shade100,
                        checkmarkColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.deepPurple.shade900 : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedReceivers.add(user);
                            } else {
                              _selectedReceivers.remove(user);
                            }
                            _updateCustomControllers();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                ],

                // نوع تقسیم
                if (_selectedReceivers.isNotEmpty) ...[
                  Card(
                    color: Colors.deepPurple.shade50.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.deepPurple.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نوع تقسیم هزینه:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade900),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: Text('تقسیم مساوی', style: TextStyle(fontSize: 14)),
                                  activeColor: Colors.deepPurple,
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
                                  title: Text('تقسیم غیرمساوی', style: TextStyle(fontSize: 14)),
                                  activeColor: Colors.deepPurple,
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
                  SizedBox(height: 16),
                ],

                // مبالغ اختصاصی
                if (_selectedReceivers.isNotEmpty && !_isEqualSplit) ...[
                  Text(
                    '💰 مبلغ هر نفر:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple.shade900),
                  ),
                  SizedBox(height: 8),
                  ..._selectedReceivers.map((user) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _customAmountControllers[user],
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
                              decoration: _purpleInputDecoration('تومان', Icons.attach_money).copyWith(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'وارد کنید';
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 12),
                ],

                // انتخاب تاریخ
                Card(
                  color: Colors.deepPurple.shade50.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.calendar_today_rounded, color: Colors.deepPurple),
                    title: Text('تاریخ ثبت هزینه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      _formatJalaliDate(_selectedJalali),
                      style: TextStyle(fontSize: 14, color: Colors.deepPurple.shade800),
                    ),
                    trailing: Icon(Icons.edit_rounded, color: Colors.deepPurple, size: 20),
                    onTap: () async {
                      final picked = await showPersianDatePicker(
                        context: context,
                        initialDate: _selectedJalali,
                        firstDate: Jalali(1400, 1, 1),
                        lastDate: Jalali(1450, 12, 29),
                        locale: const Locale('fa'),
                      );
                      if (picked != null) {
                        setState(() => _selectedJalali = picked);
                      }
                    },
                  ),
                ),
                SizedBox(height: 24),

                // دکمه ذخیره تغییرات
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveChanges(),
                  icon: _isSaving
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'در حال ذخیره...' : 'ذخیره تغییرات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatJalaliDate(Jalali date) {
    final monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return '${date.day.toString().toPersianDigit()} ${monthNames[date.month - 1]} ${date.year.toString().toPersianDigit()}';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroup == null || _selectedPayer == null || _selectedReceivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لطفا تمام فیلدها را کامل کنید'), backgroundColor: Colors.red),
      );
      return;
    }

    final totalAmount = double.parse(_amountController.text.replaceAll(',', ''));

    Map<String, double> customSplitsMap = {};
    if (!_isEqualSplit) {
      var customTotal = 0.0;
      for (final user in _selectedReceivers) {
        final amountText = _customAmountControllers[user]?.text.replaceAll(',', '') ?? '0';
        final val = double.tryParse(amountText) ?? 0;
        customTotal += val;
        customSplitsMap[user.id] = val;
      }

      if ((customTotal - totalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مجموع مبالغ فردی باید برابر با مبلغ کل ($totalAmount) باشد'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final updatedExpense = Expense(
        id: widget.expense.id,
        amount: totalAmount,
        paidById: _selectedPayer!.id,
        paidForIds: _selectedReceivers.map((u) => u.id).toList(),
        groupId: _selectedGroup!.id,
        dateTime: _selectedJalali.toDateTime(),
        description: _descriptionController.text,
        isEqualSplit: _isEqualSplit,
        customSplits: _isEqualSplit ? const {} : customSplitsMap,
      );

      await widget.appStateVM.updateExpense(updatedExpense);

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ هزینه با موفقیت ویرایش شد'),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'خطا در ویرایش هزینه: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
