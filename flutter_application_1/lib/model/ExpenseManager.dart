// lib/utils/expense_manager.dart
import 'package:intl/intl.dart';

import 'Expense.dart';
import 'Group.dart';
import 'User.dart';


class ExpenseManager {
  // ایجاد expense با تقسیم غیرمساوی
  // در ExpenseManager.dart
  static Expense createCustomSplitExpense({
    required User payer,
    required double amount,
    required List<User> participants,
    required Map<User, double> customSplits,
    required Group group,
    required DateTime dateTime,
    required String description,
  }) {
    // بررسی صحت مبالغ
    final totalCustomAmount = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
    if (totalCustomAmount != amount) {
      throw Exception('مجموع مبالغ تقسیم شده باید برابر با مبلغ کل باشد');
    }

    // بررسی اینکه همه participants (به جز payer) در customSplits وجود دارند
    for (final participant in participants) {
      if (participant != payer && !customSplits.containsKey(participant)) {
        throw Exception('همه participants باید در customSplits وجود داشته باشند');
      }
    }

    return Expense.createCustom(
      amount: amount,
      paidBy: payer,
      paidFor: participants.toList(),
      dateTime: dateTime,
      description: description,
      customSplits: customSplits, group: group, // حالا درست شده
    );
  }

  // ایجاد expense با تقسیم غیرمساوی (نسخه جایگزین)
  static Expense createCustomExpense({
    required double amount,
    required User paidBy,
    required List<User> participants,
    required Map<User, double> customSplits,
    required Group group,
    required DateTime dateTime,
    required String description,
  }) {
    return createCustomSplitExpense(
      payer: paidBy,
      amount: amount,
      participants: participants,
      customSplits: customSplits,
      group: group,
      dateTime: dateTime,
      description: description,
    );
  }

  // گرفتن خلاصه زیبا برای نمایش
  static String getExpenseBreakdown({
    required Expense expense,
    required List<User> allUsers,
    required Map<User, double> customSplits,
  }) {
    final paidBy = expense.getPaidBy(allUsers);
    final breakdown = StringBuffer();

    final formatter = NumberFormat("#,###");

    breakdown.writeln('💰 مبلغ کل: ${formatter.format(expense.amount)} تومان');
    breakdown.writeln('💳 پرداخت کننده: ${paidBy.name}');
    breakdown.writeln('📊 تقسیم بندی:');

    for (final entry in customSplits.entries) {
      breakdown.writeln('   • ${entry.key.name}: ${formatter.format(entry.value)} تومان');
    }

    // محاسبه و نمایش سهم پرداخت کننده
    final totalPaidForOthers = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
    final payerShare = expense.amount - totalPaidForOthers;
    breakdown.writeln('   • ${paidBy.name} (پرداخت کننده): ${formatter.format(payerShare)} تومان');

    return breakdown.toString();
  }

  // محاسبه سهم هر نفر برای تقسیم غیرمساوی
  static Map<User, double> calculateCustomShares({
    required double amount,
    required List<User> participants,
    required Map<User, double> customSplits,
  }) {
    final shares = <User, double>{};

    for (final participant in participants) {
      if (participant == customSplits.keys.first) {
        // پرداخت کننده
        shares[participant] = amount - customSplits.values.fold(0.0, (sum, amount) => sum + amount);
      } else {
        // سایر participants
        shares[participant] = -customSplits[participant]!;
      }
    }

    return shares;
  }

  // گرفتن خلاصه بدهی‌ها برای یک expense با تقسیم غیرمساوی
  static Map<User, double> getExpenseSummary({
    required Expense expense,
    required List<User> allUsers,
    required Map<User, double> customSplits,
  }) {
    final summary = <User, double>{};
    final paidBy = expense.getPaidBy(allUsers);
    final participants = expense.getPaidFor(allUsers)..add(paidBy);

    for (final participant in participants) {
      if (participant == paidBy) {
        // پرداخت کننده - مبلغی که باید بگیرد
        final totalPaidForOthers = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
        summary[participant] = expense.amount - totalPaidForOthers;
      } else {
        // سایر participants - مبلغی که باید بپردازند
        summary[participant] = -customSplits[participant]!;
      }
    }

    return summary;
  }

  // بررسی صحت تقسیم‌بندی
  static bool validateCustomSplit({
    required double amount,
    required Map<User, double> customSplits,
  }) {
    final total = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
    return total == amount;
  }

  // تبدیل تقسیم مساوی به غیرمساوی
  static Map<User, double> convertEqualToCustom({
    required double amount,
    required List<User> participants,
    required User payer,
    Map<User, double>? baseSplits,
  }) {
    final equalShare = amount / participants.length;
    final customSplits = <User, double>{};

    for (final participant in participants) {
      if (participant == payer) {
        continue; // پرداخت کننده سهم نمی‌پردازد
      }

      if (baseSplits != null && baseSplits.containsKey(participant)) {
        customSplits[participant] = baseSplits[participant]!;
      } else {
        customSplits[participant] = equalShare;
      }
    }

    return customSplits;
  }

  // تبدیل Map<User, double> به Map<String, double>
  static Map<String, double> convertUserMapToStringMap(Map<User, double> userMap) {
    final result = <String, double>{};
    for (final entry in userMap.entries) {
      result[entry.key.id] = entry.value;
    }
    return result;
  }

  // تبدیل Map<String, double> به Map<User, double>
  static Map<User, double> convertStringMapToUserMap(Map<String, double> stringMap, List<User> allUsers) {
    final result = <User, double>{};
    for (final entry in stringMap.entries) {
      final user = allUsers.firstWhere(
            (u) => u.id == entry.key,
        // orElse: () => User(name: 'کاربر حذف شده'),
      );
      result[user] = entry.value;
    }
    return result;
  }

  // محاسبه کل بدهی‌ها از multiple expenses
  static Map<User, double> calculateTotalDebts({
    required List<Expense> expenses,
    required List<User> allUsers,
    required Map<Expense, Map<User, double>> allCustomSplits,
  }) {
    final totalDebts = <User, double>{};

    for (final user in allUsers) {
      totalDebts[user] = 0.0;
    }

    for (final expense in expenses) {
      if (allCustomSplits.containsKey(expense)) {
        final summary = getExpenseSummary(
          expense: expense,
          allUsers: allUsers,
          customSplits: allCustomSplits[expense]!,
        );

        for (final entry in summary.entries) {
          totalDebts[entry.key] = (totalDebts[entry.key] ?? 0.0) + entry.value;
        }
      }
    }

    return totalDebts;
  }

  // گرفتن خلاصه فرمت شده
  static String getFormattedSummary(Expense expense, List<User> allUsers) {
    final paidBy = expense.getPaidBy(allUsers);
    final paidFor = expense.getPaidFor(allUsers);
    final formatter = NumberFormat("#,###");

    return '💰 مبلغ: ${formatter.format(expense.amount)} تومان\n'
        '💳 پرداخت کننده: ${paidBy.name}\n'
        '👥 تعداد: ${paidFor.length + 1} نفر\n'
        '📝 توضیحات: ${expense.description}';
  }
}