// lib/view/financial_reports_page.dart
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';

import '../../ViewModel/AppStateVM.dart';

class FinancialReportsPage extends StatefulWidget {
  @override
  _FinancialReportsPageState createState() => _FinancialReportsPageState();
}

class _FinancialReportsPageState extends State<FinancialReportsPage> {
  Group? _selectedGroup;
  String _selectedChartType = 'هزینه‌ها';
  final List<String> _chartTypes = ['هزینه‌ها', 'بدهی‌ها', 'کاربران', 'دسته‌بندی'];
  DateTimeRange? _selectedDateRange;
  Jalali? _selectedStartJalali;
  Jalali? _selectedEndJalali;

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final groups = appStateVM.groups;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '📊 گزارشات مالی',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: groups.isEmpty ? _buildEmptyState() : _buildContent(appStateVM, groups),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.teal[300]),
          SizedBox(height: 20),
          Text(
            'هنوز گروهی وجود ندارد',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'برای مشاهده گزارشات، ابتدا یک گروه ایجاد کنید',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppStateVM appStateVM, List<Group> groups) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // هدر با گرادیانت
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.teal[700]!, Colors.teal[300]!],
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'تحلیل مالی هوشمند',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'گزارشات دقیق و بصری از وضعیت مالی',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // فیلترها
                _buildFilters(appStateVM, groups),
                SizedBox(height: 16),

                // آمار کلی
                if (_selectedGroup != null) _buildSummaryCards(appStateVM),
                SizedBox(height: 16),

                // نمودارها
                if (_selectedGroup != null)
                  _buildChartsSection(appStateVM)
                else
                  Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics, size: 48, color: Colors.teal),
                          SizedBox(height: 16),
                          Text(
                            'گروهی انتخاب نشده',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AppStateVM appStateVM, List<Group> groups) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'فیلترها',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 16),
            // انتخاب گروه
            _buildDropdown(
              label: '🏢 گروه',
              value: _selectedGroup,
              items: groups,
              itemBuilder: (Group group) => Text(group.name, style: TextStyle(color: Colors.teal)),
              onChanged: (Group? newValue) => setState(() => _selectedGroup = newValue),
            ),
            SizedBox(height: 12),
            // انتخاب نوع نمودار
            _buildDropdown(
              label: '📈 نوع گزارش',
              value: _selectedChartType,
              items: _chartTypes,
              itemBuilder: (String type) => Text(type, style: TextStyle(color: Colors.teal)),
              onChanged: (String? newValue) => setState(() => _selectedChartType = newValue!),
            ),
            SizedBox(height: 12),
            // بازه زمانی
            _buildDateRangeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.teal[50],
      ),
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: itemBuilder(item),
        );
      }).toList(),
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal),
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_month, color: Colors.teal),
        title: Text(
          '📅 بازه زمانی',
          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _selectedDateRange == null
              ? 'همه زمان‌ها'
              : '${_selectedStartJalali?.formatCompactDate()} - ${_selectedEndJalali?.formatCompactDate()}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectDateRange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSummaryCards(AppStateVM appStateVM) {
    final groupExpenses = _getFilteredExpenses(appStateVM);
    final totalAmount = groupExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final averageExpense = groupExpenses.isEmpty ? 0 : totalAmount / groupExpenses.length;
    final maxExpense = groupExpenses.isEmpty ? 0 : groupExpenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            '💰 کل هزینه‌ها',
            '${NumberFormat("#,###").format(totalAmount)} تومان',
            Colors.teal,
            Icons.attach_money,
          ),
          SizedBox(width: 12),
          _buildSummaryCard(
            '📝 تعداد',
            '${groupExpenses.length}',
            Colors.blue,
            Icons.receipt,
          ),
          SizedBox(width: 12),
          _buildSummaryCard(
            '📊 میانگین',
            '${NumberFormat("#,###").format(averageExpense)} تومان',
            Colors.green,
            Icons.trending_up,
          ),
          SizedBox(width: 12),
          _buildSummaryCard(
            '🚀 بیشترین',
            '${NumberFormat("#,###").format(maxExpense)} تومان',
            Colors.orange,
            Icons.arrow_upward,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 150,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection(AppStateVM appStateVM) {
    return Column(
      children: [
        Text(
          '📈 نمودار تحلیل مالی',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold , color: Colors.teal),
        ),
        SizedBox(height: 16),
        Card(
          color: Colors.teal[50],
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            width: double.infinity,
            child: _buildCharts(appStateVM),
          ),
        ),
      ],
    );
  }

  Widget _buildCharts(AppStateVM appStateVM) {
    switch (_selectedChartType) {
      case 'هزینه‌ها':
        return _buildExpensesChart(appStateVM);
      case 'بدهی‌ها':
        return _buildDebtsChart(appStateVM);
      case 'کاربران':
        return _buildUsersChart(appStateVM);
      case 'دسته‌بندی':
        return _buildCategoryChart(appStateVM);
      default:
        return _buildExpensesChart(appStateVM);
    }
  }

  Widget _buildExpensesChart(AppStateVM appStateVM) {
    final expenses = _getFilteredExpenses(appStateVM);
    final dailyData = _groupExpensesByDay(expenses);

    return Container(
      height: 400,
      child: SfCartesianChart(
        title: ChartTitle(
          text: '📈 روند روزانه هزینه‌ها',
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        palette: [Colors.teal, Colors.blue, Colors.green],
        tooltipBehavior: TooltipBehavior(enable: true),
        primaryXAxis: CategoryAxis(
          title: AxisTitle(text: 'تاریخ', textStyle: TextStyle(fontSize: 14)),
          labelRotation: -45,
          labelStyle: TextStyle(fontSize: 12),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'مبلغ (تومان)', textStyle: TextStyle(fontSize: 14)),
          numberFormat: NumberFormat("#,###"),
          labelStyle: TextStyle(fontSize: 12),
        ),
        series: <CartesianSeries>[
          LineSeries<Map<String, dynamic>, String>(
            dataSource: dailyData,
            xValueMapper: (data, _) => data['date'],
            yValueMapper: (data, _) => data['amount'],
            markerSettings: MarkerSettings(isVisible: true, height: 8, width: 8),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsChart(AppStateVM appStateVM) {
    final members = _selectedGroup!.getMembers(appStateVM.members);
    final debtsData = members.map((user) {
      final balance = _selectedGroup!.getUserBalance(user, appStateVM.allExpenses, appStateVM.members);
      return {'user': user.name, 'balance': balance};
    }).toList();

    return Container(
      height: 400,
      child: SfCartesianChart(
        title: ChartTitle(
          text: '💸 وضعیت بدهی کاربران',
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        palette: [Colors.teal, Colors.red, Colors.purple],
        tooltipBehavior: TooltipBehavior(enable: true),
        primaryXAxis: CategoryAxis(
          title: AxisTitle(text: 'کاربران', textStyle: TextStyle(fontSize: 14)),
          labelRotation: -45,
          labelStyle: TextStyle(fontSize: 12),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'مبلغ (تومان)', textStyle: TextStyle(fontSize: 14)),
          numberFormat: NumberFormat("#,###"),
          labelStyle: TextStyle(fontSize: 12),
        ),
        series: <CartesianSeries>[
          ColumnSeries<Map<String, dynamic>, String>(
            dataSource: debtsData,
            xValueMapper: (data, _) => data['user'],
            yValueMapper: (data, _) => data['balance'],
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersChart(AppStateVM appStateVM) {
    final expenses = _getFilteredExpenses(appStateVM);
    final userExpenses = _groupExpensesByUser(appStateVM, expenses);

    return Container(
      height: 400,
      child: SfCircularChart(
        title: ChartTitle(
          text: '👥 سهم هر کاربر از هزینه‌ها',
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        palette: [Colors.teal, Colors.blue, Colors.green, Colors.orange, Colors.purple],
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CircularSeries>[
          DoughnutSeries<Map<String, dynamic>, String>(
            dataSource: userExpenses,
            xValueMapper: (data, _) => data['user'],
            yValueMapper: (data, _) => data['amount'],
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10),
            ),
            explode: true,
            explodeIndex: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(AppStateVM appStateVM) {
    final expenses = _getFilteredExpenses(appStateVM);
    final categoryData = _groupExpensesByCategory(expenses);

    return Container(
      height: 400,
      child: SfCircularChart(
        title: ChartTitle(
          text: '🏷️ دسته‌بندی هزینه‌ها',
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        palette: [Colors.teal, Colors.green, Colors.orange, Colors.purple, Colors.red],
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CircularSeries>[
          PieSeries<Map<String, dynamic>, String>(
            dataSource: categoryData,
            xValueMapper: (data, _) => data['category'],
            yValueMapper: (data, _) => data['amount'],
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  List<Expense> _getFilteredExpenses(AppStateVM appStateVM) {
    var expenses = appStateVM.getExpensesForGroup(_selectedGroup!);

    if (_selectedDateRange != null) {
      expenses = expenses.where((expense) =>
      expense.dateTime.isAfter(_selectedDateRange!.start) &&
          expense.dateTime.isBefore(_selectedDateRange!.end)).toList();
    }

    return expenses;
  }

  List<Map<String, dynamic>> _groupExpensesByDay(List<Expense> expenses) {
    final Map<String, double> dailyTotals = {};

    for (final expense in expenses) {
      final date = Jalali.fromDateTime(expense.dateTime).formatCompactDate();
      dailyTotals.update(date, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }

    return dailyTotals.entries.map((entry) => {
      'date': entry.key,
      'amount': entry.value,
    }).toList();
  }

  List<Map<String, dynamic>> _groupExpensesByUser(AppStateVM appStateVM, List<Expense> expenses) {
    final Map<String, double> userTotals = {};
    final members = _selectedGroup!.getMembers(appStateVM.members);

    for (final member in members) {
      final userExpenses = expenses.where((expense) => expense.paidById == member.id);
      final total = userExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
      userTotals[member.name] = total;
    }

    return userTotals.entries.map((entry) => {
      'user': entry.key,
      'amount': entry.value,
    }).toList();
  }

  List<Map<String, dynamic>> _groupExpensesByCategory(List<Expense> expenses) {
    final Map<String, double> categoryTotals = {};

    for (final expense in expenses) {
      final category = expense.description.isNotEmpty ? expense.description : 'بدون دسته';
      categoryTotals.update(
        category,
            (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return categoryTotals.entries.map((entry) => {
      'category': entry.key,
      'amount': entry.value,
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final Jalali? startDate = await showPersianDatePicker(
      context: context,
      initialDate: _selectedStartJalali ?? Jalali.now(),
      firstDate: Jalali(1400, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      locale: const Locale("fa"),
    );

    if (startDate != null) {
      final Jalali? endDate = await showPersianDatePicker(
        context: context,
        initialDate: _selectedEndJalali ?? Jalali.now(),
        firstDate: Jalali(1400, 1, 1),
        lastDate: Jalali(1450, 12, 29),
        locale: const Locale("fa"),
      );

      if (endDate != null) {
        setState(() {
          _selectedStartJalali = startDate;
          _selectedEndJalali = endDate;
          _selectedDateRange = DateTimeRange(
            start: startDate.toDateTime(),
            end: endDate.toDateTime(),
          );
        });
      }
    }
  }
}