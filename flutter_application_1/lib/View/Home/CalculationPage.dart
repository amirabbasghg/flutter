// lib/view/calculation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_linear_datepicker/flutter_datepicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:flutter_persian_calendar/flutter_persian_calendar.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/User.dart';
import 'package:namer_app/model/Expense.dart';
import '../../ViewModel/AppStateVM.dart';

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

class CalculationPage extends StatefulWidget {
  @override
  _CalculationPageState createState() => _CalculationPageState();
}

class _CalculationPageState extends State<CalculationPage> {
  Group? _selectedGroup;
  final Color _primaryColor = Colors.orange;
  final Color _primaryDarkColor = Colors.orange.shade800;
  final Color _primaryLightColor = Colors.orange.shade100;

  // متغیرهای جدید برای فیلتر تاریخ
  DateFilterType _dateFilter = DateFilterType.all;
  Jalali? _startDate;
  Jalali? _endDate;
  final List<String> _selectedGroupIds = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStateVM = Provider.of<AppStateVM>(context, listen: false);
      final currentUser = appStateVM.currentUser;
      if (currentUser != null) {
        final userGroups = appStateVM.groups.where((group) =>
            group.memberIds.contains(currentUser.id)).toList();

        setState(() {
          _selectedGroupIds.addAll(userGroups.map((g) => g.id));
          // انتخاب اولین گروه به صورت پیش‌فرض
          if (userGroups.isNotEmpty) {
            _selectedGroup = userGroups.first;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final allUsers = appStateVM.members;
    final currentUser = appStateVM.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'لطفاً ابتدا وارد شوید',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final groups = appStateVM.groups.where((group) =>
        group.memberIds.contains(currentUser.id)).toList();

    // فیلتر کردن گروه‌ها بر اساس انتخاب کاربر
    final filteredGroups = groups.where((group) =>
        _selectedGroupIds.contains(group.id)).toList();

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: _primaryColor,
        colorScheme: ColorScheme.light(primary: _primaryColor),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          toolbarHeight: 100,
          title: Row(
            // mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(FontAwesomeIcons.calculator, color: Colors.white, size: 20),
              SizedBox(height: 2,),
              Text(
                'محاسبه بدهی دو به دو',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(_primaryColor),
                elevation: WidgetStatePropertyAll(10),
                iconSize: WidgetStatePropertyAll(10),
              ),
              icon: Icon(Iconsax.filter, color: Colors.white),
              onPressed: () => _showDateFilterDialog(context),
              label: Text('فیتر تاریخ', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [


              // کارت انتخاب گروه
              _buildGroupSelectionCard(filteredGroups),
              SizedBox(height: 20),

              // نمایش نتایج
              if (_selectedGroup != null)
                Expanded(
                  child: _buildDebtMatrix(appStateVM, _selectedGroup!),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_work,
                          size: 80,
                          color: _primaryColor.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          filteredGroups.isEmpty ? '❌ گروهی با فیلترهای انتخاب شده یافت نشد' : '👈 یک گروه انتخاب کنید',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          filteredGroups.isEmpty ? 'فیلترهای خود را تغییر دهید' : 'برای مشاهده بدهی‌های دو به دو',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

    // چیپ‌های گروه‌های انتخاب شده
    for (final groupId in _selectedGroupIds) {
      final group = allGroups.firstWhere((g) => g.id == groupId);
      chips.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Chip(
            label: Text(group.name),
            backgroundColor: _primaryColor.withOpacity(0.2),
            deleteIcon: Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedGroupIds.remove(groupId);
                // اگر گروه انتخاب شده حذف شد، آن را از _selectedGroup نیز حذف کنیم
                if (_selectedGroup != null && _selectedGroup!.id == groupId) {
                  _selectedGroup = null;
                }
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
          return '${_startDate!.formatCompactDate()} تا ${_endDate!.formatCompactDate()}';
        }
        return 'بازه دلخواه';
      case DateFilterType.all:
      default:
        return 'همه تاریخ‌ها';
    }
  }

  // دیالوگ فیلتر گروه‌ها
  void _showGroupFilterDialog(BuildContext context, List<Group> allGroups) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('فیلتر گروه‌ها'),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

  // دیالوگ فیلتر تاریخ
  void _showDateFilterDialog(BuildContext context) {
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
  // void _selectStartDate(void Function(void Function()) setState) async {
  //   final selectedDate = await showPersianDatePicker(
  //     context: context,
  //     initialDate: _startDate ?? Jalali.now(),
  //     firstDate: Jalali(1400, 1, 1),
  //     lastDate: Jalali.now(),
  //   );
  //
  //   if (selectedDate != null) {
  //     setState(() {
  //       _startDate = selectedDate;
  //       if (_endDate != null && _startDate!.isAfter(_endDate!)) {
  //         _endDate = null;
  //       }
  //     });
  //   }
  // }
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
            primaryColor: _primaryColor,
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
              primaryColor: _primaryColor,
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

  // بخش فیلتر گروه‌ها
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
                  _selectedGroup = null;
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
                      // اگر گروه انتخاب شده حذف شد، آن را از _selectedGroup نیز حذف کنیم
                      if (_selectedGroup != null && _selectedGroup!.id == group.id) {
                        _selectedGroup = null;
                      }
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

  Widget _buildGroupSelectionCard(List<Group> groups) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.9),
            _primaryDarkColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'انتخاب گروه',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<Group>(
                value: _selectedGroup,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Color(0xFFFF9B00),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 28,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  labelText: groups.isEmpty ? 'هیچ گروهی یافت نشد' : 'گروه مورد نظر را انتخاب کنید',
                  labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                items: groups.map((Group group) {
                  return DropdownMenuItem<Group>(
                    value: group,
                    child: Text(
                      group.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: groups.isEmpty ? null : (Group? newValue) {
                  setState(() {
                    _selectedGroup = newValue;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtMatrix(AppStateVM appStateVM, Group group) {
    // فیلتر کردن هزینه‌ها بر اساس تاریخ
    final groupExpenses = appStateVM.getExpensesForGroup(group).where((expense) =>
        _isExpenseInDateRange(expense)).toList();

    final groupMembers = group.getMembers(appStateVM.members);
    final formatter = NumberFormat("#,###");

    return Column(
      children: [
        // هدر اطلاعات گروه
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGroupInfoItem(
                Icons.people,
                'تعداد اعضا',
                groupMembers.length.toString().toPersianDigit(),
              ),
              _buildGroupInfoItem(
                Icons.receipt,
                'تعداد هزینه‌ها',
                groupExpenses.length.toString().toPersianDigit(),
              ),
              _buildGroupInfoItem(
                Icons.account_balance_wallet,
                'کل هزینه‌ها',
                formatter.format(_getTotalExpensesForGroup(groupExpenses)).toPersianDigit(),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // نمایش فیلتر تاریخ فعال
        if (_dateFilter != DateFilterType.all)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  'فیلتر تاریخ: ${_getDateFilterLabel()}',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 16),

        // عنوان ماتریس
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '💰 ماتریس بدهی‌های گروه ${group.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // لیست بدهی‌ها
        Expanded(
          child: groupExpenses.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text(
                  'هزینه‌ای در بازه زمانی انتخاب شده یافت نشد',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: groupMembers.length,
            itemBuilder: (context, index) {
              final user1 = groupMembers[index];
              return _buildUserDebtCard(appStateVM, group, user1, groupMembers, groupExpenses);
            },
          ),
        ),
      ],
    );
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

  // محاسبه مجموع هزینه‌های فیلتر شده
  double _getTotalExpensesForGroup(List<Expense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Widget _buildGroupInfoItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: _primaryColor),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _primaryDarkColor,
          ),
        ),
      ],
    );
  }

  Widget _buildUserDebtCard(AppStateVM appStateVM, Group group, User user, List<User> groupMembers, List<Expense> groupExpenses) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر کاربر
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryColor,
                        _primaryDarkColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'بدهی‌های دو به دو',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_getUserDebtCount(group, user, groupMembers, groupExpenses)} مورد',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // لیست بدهی‌های کاربر
            ...groupMembers.map((user2) {
              if (user == user2) return SizedBox();

              final debt = _getDebtBetweenUsers(user, user2, groupExpenses, appStateVM.members);
              if (debt == 0) return SizedBox();

              return _buildDebtRow(user, user2, debt);
            }).toList(),

            if (_getUserDebtCount(group, user, groupMembers, groupExpenses) == 0)
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 40, color: Colors.green),
                      SizedBox(height: 8),
                      Text(
                        '✅ هیچ بدهی‌ای ندارد',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // محاسبه بدهی بین دو کاربر با در نظر گرفتن فیلتر تاریخ
  double _getDebtBetweenUsers(User user1, User user2, List<Expense> expenses, List<User> allUsers) {
    double debt = 0.0;

    for (final expense in expenses) {
      if (expense.paidById == user1.id && expense.paidForIds.contains(user2.id)) {
        // user1 برای user2 پرداخت کرده
        final share = expense.getCustomShare(user2.id);
        debt -= share; // user2 به user1 بدهکار است
      } else if (expense.paidById == user2.id && expense.paidForIds.contains(user1.id)) {
        // user2 برای user1 پرداخت کرده
        final share = expense.getCustomShare(user1.id);
        debt += share; // user1 به user2 بدهکار است
      }
    }

    return debt;
  }

  int _getUserDebtCount(Group group, User user, List<User> groupMembers, List<Expense> groupExpenses) {
    int count = 0;
    for (final user2 in groupMembers) {
      if (user != user2) {
        final debt = _getDebtBetweenUsers(user, user2, groupExpenses, Provider.of<AppStateVM>(context, listen: false).members);
        if (debt != 0) count++;
      }
    }
    return count;
  }

  Widget _buildDebtRow(User user1, User user2, double debt) {
    final isDebtPositive = debt > 0;
    final amount = debt.abs();
    final formatter = NumberFormat("#,###");

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDebtPositive
            ? Colors.green.withOpacity(0.05)
            : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDebtPositive
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDebtPositive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDebtPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.white,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user2.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isDebtPositive ? 'دریافت کننده' : 'پرداخت کننده',
                  style: TextStyle(
                    color: isDebtPositive ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDebtPositive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDebtPositive
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${formatter.format(amount).toPersianDigit()} تومان',
              style: TextStyle(
                color: isDebtPositive ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}