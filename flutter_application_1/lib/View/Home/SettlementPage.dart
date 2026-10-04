import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/User.dart';
import '../../Services/Api.dart';
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

class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  final List<String> _selectedGroupIds = [];
  final Color _primaryColor = Colors.blue;
  final Color _primaryDarkColor = Colors.blue.shade800;
  final Color _primaryLightColor = Colors.blue.shade100;

  // متغیرهای جدید برای فیلتر تاریخ
  DateFilterType _dateFilter = DateFilterType.all;
  Jalali? _startDate;
  Jalali? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStateVM = Provider.of<AppStateVM>(context, listen: false);
      final currentUser = appStateVM.currentUser;
      if (currentUser == null) return;

      final userGroups = appStateVM.groups
          .where((group) => group.memberIds.contains(currentUser.id))
          .toList();
      if (userGroups.isEmpty) return;

      // ⚠️ قبلاً همه‌ی گروه‌ها یک‌جا انتخاب می‌شدند و بدهی‌ها بین گروه‌ها با هم
      // جمع/خنثی می‌شد — یعنی «مبلغ همه‌ی گروه‌ها» در یک عدد نشان داده می‌شد.
      // تسویه ذاتاً درون‌گروهی است، پس پیش‌فرض فقط تازه‌ترین گروه انتخاب می‌شود
      // و کاربر در صورت نیاز از دکمه‌ی «فیلتر» بقیه را اضافه می‌کند.
      setState(() {
        _selectedGroupIds.add(userGroups.first.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final allUsers = appStateVM.members;
    final allExpenses = appStateVM.allExpenses;
    final currentUser = appStateVM.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

    final allGroups = appStateVM.groups.where((group) =>
        group.memberIds.contains(currentUser.id)).toList();

    // فیلتر کردن expenseها بر اساس گروه‌های انتخاب شده و تاریخ
    final filteredExpenses = _getFilteredExpenses(allExpenses);

    // محاسبه بدهی‌ها با expenseهای فیلتر شده
    final debtSummary = _calculateDebts(filteredExpenses, allUsers);

    return Theme(
      // ⚠️ قبلاً اینجا ColorScheme.light بود که صفحه را حتی در حالت تیره هم
      // روشن نگه می‌داشت. فقط رنگ اصلی override می‌شود، نه کل طرح‌رنگ.
      data: Theme.of(context).copyWith(
        primaryColor: _primaryColor,
        colorScheme:
            Theme.of(context).colorScheme.copyWith(primary: _primaryColor),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            '💰 تسویه حساب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
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
            Container(
              margin: EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: Icon(Icons.filter_list, size: 18),
                onPressed: () => _showFilterDialog(context, allGroups),
                label: Text(
                  'فیلتر',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نمایش وضعیت فیلتر
              _buildFilterStatus(allGroups, context),
              const SizedBox(height: 16),

              // خلاصه وضعیت
              _selectedGroupIds.isEmpty ? Container() : _buildSummaryCard(debtSummary, filteredExpenses.length, context),
              const SizedBox(height: 20),

              // عنوان لیست بدهی‌ها
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.list, color: _primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'لیست بدهی‌ها',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Spacer(),
                    Text(
                      _selectedGroupIds.isEmpty ? '${_selectedGroupIds.length.toString().toPersianDigit()} مورد ' : '${debtSummary.values.where((debt) => !_isSettled(debt)).length.toString().toPersianDigit()} مورد',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              // لیست بدهی‌ها
              Expanded(
                child: _buildDebtsList(debtSummary, allUsers, context),
              ),

              // دکمه تسویه
              _selectedGroupIds.isEmpty ? Container() : _buildSettlementButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // فیلتر کردن expenseها بر اساس گروه‌های انتخاب شده و تاریخ
  List<Expense> _getFilteredExpenses(List<Expense> allExpenses) {
    List<Expense> filteredExpenses = allExpenses;

    // فیلتر بر اساس گروه‌ها
    if (_selectedGroupIds.isNotEmpty) {
      filteredExpenses = filteredExpenses.where((expense) =>
          _selectedGroupIds.contains(expense.groupId)).toList();
    }

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

  // نمایش وضعیت فیلتر
  Widget _buildFilterStatus(List<Group> allGroups, BuildContext context) {
    final selectedGroupCount = _selectedGroupIds.length;
    final totalGroupCount = allGroups.length;
    final hasDateFilter = _dateFilter != DateFilterType.all;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.1),
            _primaryLightColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 18, color: _primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'فیلتر فعال:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              if (selectedGroupCount > 0 || hasDateFilter)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.clear, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'پاک کردن',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),

          // نمایش وضعیت فیلتر گروه‌ها
          Row(
            children: [
              Icon(Icons.group, size: 14, color: _primaryColor),
              SizedBox(width: 4),
              Text(
                'گروه‌ها: ',
                style: TextStyle(fontSize: 12, color: _primaryColor),
              ),
              Text(
                '$selectedGroupCount از $totalGroupCount گروه'.toPersianDigit(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // نمایش وضعیت فیلتر تاریخ
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: _primaryColor),
              SizedBox(width: 4),
              Text(
                'تاریخ: ',
                style: TextStyle(fontSize: 12, color: _primaryColor),
              ),
              Text(
                _getDateFilterLabel().toPersianDigit(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
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

  void _clearFilters() {
    setState(() {
      _selectedGroupIds.clear();
      _dateFilter = DateFilterType.all;
      _startDate = null;
      _endDate = null;
    });
  }

  // محاسبه بدهی‌ها
  /// کمتر از نیم تومان یعنی تسویه‌شده.
  ///
  /// سهم‌ها حالا تومانِ صحیح‌اند و جمعشان دقیقاً صفر می‌شود، ولی هزینه‌های
  /// قدیمی با تقسیم سفارشیِ اعشاری هنوز می‌توانند ته‌مانده بسازند. بدون این
  /// آستانه، چنین ته‌مانده‌ای به شکل «۰ تومان بدهکار است» نمایش داده می‌شد.
  static const double _settledThreshold = 0.5;

  static bool _isSettled(double value) => value.abs() < _settledThreshold;

  Map<User, double> _calculateDebts(List<Expense> expenses, List<User> users) {
    final debts = <User, double>{};

    // مقدار اولیه صفر برای همه کاربران
    for (final user in users) {
      debts[user] = 0.0;
    }

    // محاسبه بدهی از هر expense
    for (final expense in expenses) {
      for (final user in users) {
        final debt = expense.getDebtAmountForUser(user, users);
        debts[user] = debts[user]! + debt;
      }
    }

    return debts;
  }

  // کارت خلاصه وضعیت
  Widget _buildSummaryCard(Map<User, double> debts, int expenseCount, BuildContext context) {
    // هر هزینه دو طرف دارد: طلبکار با +X و بدهکار با -X. جمعِ قدرمطلق‌ها دقیقاً
    // دو برابر پولی است که باید جابه‌جا شود، پس فقط طرف مثبت جمع می‌شود.
    final totalDebt = debts.values
        .where((debt) => debt > 0)
        .fold(0.0, (sum, debt) => sum + debt);
    final numberOfTransactions =
        debts.values.where((debt) => !_isSettled(debt)).length;
    final formatter = NumberFormat("#,###");

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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // ردیف اول آمار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '📊 کل مبادلات',
                  '${formatter.format(totalDebt).toPersianDigit()} تومان',
                  Colors.white,
                ),
                _buildSummaryItem(
                  '🔢 تراکنش‌ها',
                  numberOfTransactions.toString().toPersianDigit(),
                  Colors.white,
                ),
              ],
            ),
            SizedBox(height: 16),

            // ردیف دوم آمار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '🏢 هزینه‌ها',
                  expenseCount.toString().toPersianDigit(),
                  Colors.white,
                ),
                _buildSummaryItem(
                  '📅 بازه زمانی',
                  _getDateFilterShortLabel(),
                  Colors.white,
                ),
              ],
            ),
            SizedBox(height: 16),

            // پیام راهنما
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'برای ثبت پرداخت، دکمه پایین را بزنید',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // برچسب کوتاه برای فیلتر تاریخ
  String _getDateFilterShortLabel() {
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
        return 'دلخواه';
      case DateFilterType.all:
      default:
        return 'همه';
    }
  }

  Widget _buildSummaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'IranSans',
          ),
        ),
      ],
    );
  }

  // لیست بدهی‌ها
  Widget _buildDebtsList(Map<User, double> debts, List<User> users, BuildContext context) {
    final debtEntries =
        debts.entries.where((entry) => !_isSettled(entry.value)).toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    if (debtEntries.isEmpty || _selectedGroupIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 80,
              color: _primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              '🎉 همه حساب‌ها تسویه است!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _selectedGroupIds.isEmpty
                  ? 'هیچ بدهی یا طلبی در سیستم وجود ندارد'
                  : 'در گروه‌های انتخاب شده بدهی وجود ندارد',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _dateFilter != DateFilterType.all
                  ? '📅 فیلتر تاریخ: ${_getDateFilterLabel().toPersianDigit()}'
                  : '💎 وضعیت مالی شما کاملاً متعادل است',
              style: TextStyle(
                color: _dateFilter != DateFilterType.all ? _primaryColor : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: debtEntries.length,
      itemBuilder: (context, index) {
        final entry = debtEntries[index];
        final user = entry.key;
        final debt = entry.value;

        return _buildDebtItem(user, debt, context, index);
      },
    );
  }

  // بقیه متدها بدون تغییر...

  void _showFilterDialog(BuildContext context, List<Group> allGroups) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: _primaryColor,
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // هدر دیالوگ
                        Row(
                          children: [
                            Icon(Icons.filter_list_rounded,
                                color: _primaryColor, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'فیلترها',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // بخش فیلتر تاریخ
                        _buildDateFilterSection(setState),
                        SizedBox(height: 16),

                        // بخش فیلتر گروه‌ها
                        _buildGroupFilterSection(allGroups, setState),

                        SizedBox(height: 20),

                        // دکمه‌های پایین
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('انصراف'),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('اعمال فیلتر'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
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
          '📅 بازه زمانی:',
          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
        ),
        SizedBox(height: 8),

        // گزینه‌های فیلتر تاریخ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DateFilterType.values.map((filter) {
            final isSelected = _dateFilter == filter;
            return FilterChip(
              label: Text(_getDateFilterTitle(filter)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _dateFilter = filter;
                  if (_dateFilter != DateFilterType.custom) {
                    _startDate = null;
                    _endDate = null;
                  }
                });
              },
              selectedColor: _primaryColor.withOpacity(0.2),
              checkmarkColor: _primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? _primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        foregroundColor: _primaryColor,
                      ),
                      child: Text(
                        _startDate == null
                            ? '📅 از تاریخ'
                            : _startDate!.formatCompactDate().toPersianDigit(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectEndDate(setState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        foregroundColor: _primaryColor,
                      ),
                      child: Text(
                        _endDate == null
                            ? '📅 تا تاریخ'
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
        return 'همه';
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
        return 'دلخواه';
    }
  }

  // انتخاب تاریخ شروع
  // انتخاب تاریخ شروع
  //
  // ⚠️ قبلاً اینجا دیالوگ دست‌ساز روی ویجت PersianCalendar (پکیج
  // flutter_persian_calendar) بود که دو باگ داشت: ۱) دکمه‌ی «لغو» دقیقاً کار
  // «تأیید» را می‌کرد (هر دو فقط Navigator.pop می‌زدند)، ۲) خودِ پکیج روز
  // انتخاب‌شده را با شماره‌ی ماه مقایسه می‌کرد (`selectedDate.month ==
  // dayIndex + 1`)، پس رنگ‌آمیزی روز انتخابی اشتباه بود و کاربر فکر می‌کرد لمسش
  // اثر نکرده. showPersianDatePicker از پکیج persian_datetime_picker (که از
  // قبل در پروژه بود و FinancialReportsPage درست استفاده‌اش می‌کرد) هیچ‌کدام
  // از این مشکلات را ندارد.
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

  // انتخاب تاریخ پایان
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


  // بخش فیلتر گروه‌ها
  Widget _buildGroupFilterSection(List<Group> allGroups, void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏢 گروه‌ها:',
          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
        ),
        SizedBox(height: 8),

        if (allGroups.isNotEmpty)
          Card(
            color: _primaryColor.withOpacity(0.1),
            child: ListTile(
              leading: Icon(
                _selectedGroupIds.length == allGroups.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: _primaryColor,
              ),
              title: Text(
                _selectedGroupIds.length == allGroups.length
                    ? 'لغو انتخاب همه'
                    : 'انتخاب همه گروه‌ها',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              onTap: () {
                setState(() {
                  if (_selectedGroupIds.length == allGroups.length) {
                    _selectedGroupIds.clear();
                  } else {
                    _selectedGroupIds.clear();
                    _selectedGroupIds.addAll(allGroups.map((g) => g.id));
                  }
                });
              },
            ),
          ),

        SizedBox(height: 8),

        Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: allGroups.isEmpty
              ? Center(
            child: Column(
              children: [
                Icon(Icons.group_off,
                    size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'هیچ گروهی پیدا نشد',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: allGroups.length,
            itemBuilder: (context, index) {
              final group = allGroups[index];
              final isSelected = _selectedGroupIds.contains(group.id);
              final expensesCount = _getExpensesCountForGroup(group);

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? _primaryColor
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${group.memberIds.length} عضو • $expensesCount هزینه',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: Checkbox(
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
                      activeColor: _primaryColor,
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedGroupIds.remove(group.id);
                        } else {
                          _selectedGroupIds.add(group.id);
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

// ساخت آیتم بدهی
  Widget _buildDebtItem(User user, double debt, BuildContext context, int index) {
    final formatter = NumberFormat("#,###");
    final isDebt = debt > 0;
    final amount = debt.abs();
    final isEven = index % 2 == 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isDebt
                ? Colors.green.withOpacity(0.3)
                : Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        color: isEven
            ? Theme.of(context).cardColor
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDebt
                    ? [Colors.green.shade100, Colors.green.shade200]
                    : [Colors.red.shade100, Colors.red.shade200],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDebt
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isDebt ? Icons.arrow_downward : Icons.arrow_upward,
              color: isDebt ? Colors.green.shade700 : Colors.red.shade700,
              size: 20,
            ),
          ),
          title: Text(
            user.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(
                isDebt ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: isDebt ? Colors.green : Colors.red,
              ),
              SizedBox(width: 4),
              Text(
                isDebt ? 'دریافت کننده' : 'پرداخت کننده',
                style: TextStyle(
                  color: isDebt ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDebt
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDebt
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${formatter.format(amount).toPersianDigit()} تومان',
              style: TextStyle(
                color: isDebt ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'IranSans',
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

// دکمه تسویه حساب
  Widget _buildSettlementButton(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _showSettlementSuggestions(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 24),
              SizedBox(width: 12),
              Text(
                '💎 مشاهده پیشنهادات تسویه',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// تعداد expenseهای یک گروه
  int _getExpensesCountForGroup(Group group) {
    final appStateVM = Provider.of<AppStateVM>(context, listen: false);
    return appStateVM.allExpenses.where((expense) => expense.groupId == group.id).length;
  }

// نمایش پیشنهادات تسویه
  void _showSettlementSuggestions(BuildContext context) {
    final appStateVM = context.read<AppStateVM>();
    final allUsers = appStateVM.members;
    final filteredExpenses = _getFilteredExpenses(appStateVM.allExpenses);
    final debts = _calculateDebts(filteredExpenses, allUsers);

    final _descriptionController = TextEditingController();
    final _amountController = TextEditingController();

    Group? _selectedGroup;
    User? _selectedUserPaidBy;
    User? _selectedUserPaidFor;

    // محاسبه پیشنهادات تسویه
    final suggestions = _calculateSettlementSuggestions(debts);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                decoration: BoxDecoration(
                  // ⚠️ قبلاً Colors.white بود؛ در حالت تیره یک جعبه‌ی سفیدِ
                  // براق وسط صفحه‌ی تیره می‌نشست و متن‌های بدون رنگِ صریح
                  // داخلش (پیش‌فرضِ تم که در حالت تیره تقریباً سفید است) روی
                  // همین پس‌زمینه‌ی سفید نامرئی می‌شدند.
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // هدر
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: _primaryColor, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '💡 پیشنهادات تسویه',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // لیست پیشنهادات
                      if (suggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 48, color: Colors.green),
                              SizedBox(height: 12),
                              Text(
                                '✅ همه حساب‌ها تسویه است',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'هیچ پیشنهاد تسویه‌ای وجود ندارد',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            Text(
                              'پیشنهادات بهینه برای تسویه:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 12),

                            Container(
                              constraints: BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: suggestions.length,
                                itemBuilder: (context, index) {
                                  final suggestion = suggestions[index];
                                  final commonGroups = _findCommonGroups(
                                      suggestion.from,
                                      suggestion.to,
                                      appStateVM.groups,
                                      allUsers
                                  );
                                  final hasCommonGroups = commonGroups.isNotEmpty;

                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 4),
                                    color: hasCommonGroups
                                        ? _primaryColor.withOpacity(0.05)
                                        : Colors.orange.withOpacity(0.05),
                                    child: ListTile(
                                      leading: Icon(
                                        hasCommonGroups
                                            ? Icons.arrow_forward
                                            : Icons.warning,
                                        color: hasCommonGroups
                                            ? _primaryColor
                                            : Colors.orange,
                                      ),
                                      title: Text(
                                        '${suggestion.from.name} به ${suggestion.to.name}',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${NumberFormat("#,###").format(suggestion.amount).toPersianDigit()} تومان',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _primaryColor,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          hasCommonGroups
                                              ? Text(
                                            '🏢 ${commonGroups.first.name}',
                                            style: TextStyle(
                                                color: _primaryColor,
                                                fontSize: 11
                                            ),
                                          )
                                              : Text(
                                            '⚠️ گروه مشترک ندارند',
                                            style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 11
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: hasCommonGroups
                                          ? IconButton(
                                        icon: Icon(
                                          Icons.play_arrow,
                                          color: _primaryColor,
                                        ),
                                        onPressed: () {
                                          _amountController.text =
                                              suggestion.amount.toStringAsFixed(0);
                                          _selectedUserPaidBy = suggestion.from;
                                          _selectedUserPaidFor = suggestion.to;
                                          _selectedGroup = commonGroups.first;
                                          _descriptionController.text =
                                          'تسویه حساب پیشنهادی - ${suggestion.from.name} به ${suggestion.to.name}';

                                          // بستن دیالوگ فعلی و باز کردن دیالوگ ثبت پرداخت
                                          Navigator.pop(context);
                                          _showCustomSettlementDialog(
                                              context,
                                              preSelectedPayer: suggestion.from,
                                              preSelectedReceiver: suggestion.to,
                                              preSelectedGroup: commonGroups.first,
                                              preSelectedAmount: suggestion.amount
                                          );
                                        },
                                      )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: 20),

                      // دکمه‌های پایین
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('بستن'),
                            ),
                          ),
                          SizedBox(width: 12),
                          if (suggestions.isNotEmpty)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showCustomSettlementDialog(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('ثبت دستی'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// متد کمکی برای پیدا کردن گروه‌های مشترک
  List<Group> _findCommonGroups(User user1, User user2, List<Group> allGroups, List<User> allUsers) {
    return allGroups.where((group) {
      final members = group.getMembers(allUsers);
      return members.contains(user1) && members.contains(user2);
    }).toList();
  }

// متد اصلی ثبت پرداخت دستی (با پارامترهای اختیاری برای پیش‌پر کردن)
  void _showCustomSettlementDialog(
      BuildContext context, {
        User? preSelectedPayer,
        User? preSelectedReceiver,
        Group? preSelectedGroup,
        double? preSelectedAmount,
      }) {
    final appStateVM = context.read<AppStateVM>();
    final allUsers = appStateVM.members;

    final _descriptionController = TextEditingController();
    final _amountController = TextEditingController();

    Group? _selectedGroup = preSelectedGroup;
    User? _selectedUserPaidBy = preSelectedPayer;
    User? _selectedUserPaidFor = preSelectedReceiver;

    // پیش‌پر کردن فیلدها اگر مقادیر داده شده باشد
    if (preSelectedAmount != null) {
      _amountController.text = preSelectedAmount.toStringAsFixed(0);
    }
    if (preSelectedPayer != null && preSelectedReceiver != null) {
      _descriptionController.text =
      'تسویه حساب - ${preSelectedPayer.name} به ${preSelectedReceiver.name}';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                decoration: BoxDecoration(
                  // ⚠️ قبلاً Colors.white بود؛ در حالت تیره یک جعبه‌ی سفیدِ
                  // براق وسط صفحه‌ی تیره می‌نشست و متن‌های بدون رنگِ صریح
                  // داخلش (پیش‌فرضِ تم که در حالت تیره تقریباً سفید است) روی
                  // همین پس‌زمینه‌ی سفید نامرئی می‌شدند.
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // هدر
                      Row(
                        children: [
                          Icon(Icons.payment, color: _primaryColor, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '💳 ثبت پرداخت دستی',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // انتخاب گروه
                      DropdownButtonFormField<Group>(
                        value: _selectedGroup,
                        decoration: InputDecoration(
                          labelText: '🏢 گروه',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.group, color: _primaryColor),
                          filled: true,
                        ),
                        items: appStateVM.groups
                            .where((group) => _selectedGroupIds.isEmpty || _selectedGroupIds.contains(group.id))
                            .map((Group group) {
                          return DropdownMenuItem<Group>(
                            value: group,
                            child: Text(group.name, style: TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                        onChanged: (Group? newValue) {
                          setState(() {
                            _selectedGroup = newValue;
                            _selectedUserPaidBy = null;
                            _selectedUserPaidFor = null;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      if (_selectedGroup != null) ...[
                        // انتخاب پرداخت کننده
                        DropdownButtonFormField<User>(
                          value: _selectedUserPaidBy,
                          decoration: InputDecoration(
                            labelText: '💳 پرداخت کننده',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.person, color: _primaryColor),
                            filled: true,
                          ),
                          items: _selectedGroup!.getMembers(allUsers).map((User user) {
                            return DropdownMenuItem<User>(
                              value: user,
                              child: Text(user.name, style: TextStyle(fontSize: 16)),
                            );
                          }).toList(),
                          onChanged: (User? newValue) {
                            setState(() {
                              _selectedUserPaidBy = newValue;
                            });
                          },
                        ),
                        SizedBox(height: 16),

                        // انتخاب دریافت کننده
                        DropdownButtonFormField<User>(
                          value: _selectedUserPaidFor,
                          decoration: InputDecoration(
                            labelText: '👤 دریافت کننده',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.person_outline, color: _primaryColor),
                            filled: true,
                          ),
                          items: _selectedGroup!.getMembers(allUsers).map((User user) {
                            return DropdownMenuItem<User>(
                              value: user,
                              child: Text(user.name, style: TextStyle(fontSize: 16)),
                            );
                          }).toList(),
                          onChanged: (User? newValue) {
                            setState(() {
                              _selectedUserPaidFor = newValue;
                            });
                          },
                        ),
                        SizedBox(height: 16),

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
                            labelText: '💰 مبلغ (تومان)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.attach_money, color: _primaryColor),
                            filled: true,
                          ),
                        ),
                        SizedBox(height: 16),

                        // فیلد توضیحات
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: '📝 توضیحات (اختیاری)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.description, color: _primaryColor),
                            filled: true,
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 20),
                      ],

                      // دکمه‌های پایین
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('انصراف'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_validateForm(
                                    _selectedGroup,
                                    _selectedUserPaidBy,
                                    _selectedUserPaidFor,
                                    _amountController.text,
                                    context
                                )) {
                                  _addExpense(
                                      _selectedUserPaidBy!,
                                      _selectedUserPaidFor!,
                                      _selectedGroup!,
                                      _descriptionController.text,
                                      _amountController.text,
                                      context
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ پرداخت با موفقیت ثبت شد'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('ثبت پرداخت'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// متد اعتبارسنجی فرم
  bool _validateForm(Group? group, User? payer, User? receiver, String amount, BuildContext context) {
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لطفاً یک گروه انتخاب کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (payer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لطفاً پرداخت کننده را انتخاب کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (receiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لطفاً دریافت کننده را انتخاب کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لطفاً مبلغ را وارد کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (payer == receiver) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('پرداخت کننده و دریافت کننده نمی‌توانند یک نفر باشند'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

// متد اضافه کردن expense
  Future<void> _addExpense(
      User selectedUserPaidBy,
      User selectedUserPaidFor,
      Group selectedGroup,
      String description,
      String amount,
      BuildContext context
      ) async {
    final totalAmount = double.parse(amount.replaceAll(',', ''));
    final appStateVM = context.read<AppStateVM>();
    final messenger = ScaffoldMessenger.of(context);

    final expense = appStateVM.createExpense(
      amount: totalAmount,
      paidBy: selectedUserPaidBy,
      paidFor: [selectedUserPaidFor],
      group: selectedGroup,
      dateTime: DateTime.now(),
      description: description.isNotEmpty ? description : 'پرداخت دستی',
    );

    // ثبت روی سرور؛ اگر رد شد کاربر باید بفهمد (قبلاً با Firestore بی‌صدا بود)
    try {
      await appStateVM.addExpenseToGroup(selectedGroup, expense);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'ثبت تسویه انجام نشد'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// محاسبه پیشنهادات تسویه
  List<SettlementSuggestion> _calculateSettlementSuggestions(Map<User, double> debts) {
    final suggestions = <SettlementSuggestion>[];
    // ته‌مانده‌های زیر یک تومان نه بدهکارند نه طلبکار؛ وگرنه پیشنهادهایی مثل
    // «۰ تومان بپرداز» یا «۱ تومان بپرداز» تولید می‌شد.
    final debtors =
        debts.entries.where((e) => e.value < 0 && !_isSettled(e.value)).toList();
    final creditors =
        debts.entries.where((e) => e.value > 0 && !_isSettled(e.value)).toList();

    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((b, a) => a.value.compareTo(b.value));

    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor.value.abs();
      final creditAmount = creditor.value;

      final settleAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      if (!_isSettled(settleAmount)) {
        suggestions.add(SettlementSuggestion(
          from: debtor.key,
          to: creditor.key,
          amount: settleAmount.roundToDouble(),
        ));
      }

      if (debtAmount < creditAmount) {
        creditors[j] = MapEntry(creditor.key, creditAmount - debtAmount);
        i++;
      } else {
        debtors[i] = MapEntry(debtor.key, debtAmount - creditAmount);
        j++;
      }
    }

    return suggestions;
  }
}

class SettlementSuggestion {
  final User from;
  final User to;
  final double amount;

  SettlementSuggestion({
    required this.from,
    required this.to,
    required this.amount,
  });
}
