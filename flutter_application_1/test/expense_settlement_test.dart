// تست رگرسیون برای باگ گرد کردن در تسویه حساب.
//
// گزارش شده بود: «تسویه حسابی هنوز هست که میگه فلانی به فلانی صفر تومان
// بدهکاره» و «وقتی تسویه میکنی هنوز مینویسه ۱ تومن باید امیرعباس پرداخت
// کنه». علتش این بود که تقسیم مساوی با تقسیم اعشاری حساب می‌شد
// (sharePerPerson = amount / n)، پس مجموع سهم‌ها هیچ‌وقت دقیقاً برابر مبلغ
// کل نمی‌شد و بعد از تسویه‌ی کامل یک باقیمانده‌ی کوچک (مثلاً ۰ یا ۱ تومان)
// می‌ماند. Expense.shares() حالا با تقسیم صحیح + پخش باقیمانده کار می‌کند.

import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/User.dart';

User _user(String id, String name) =>
    User(id: id, name: name, email: '$id@example.com');

void main() {
  final amir = _user('u1', 'امیرعباس');
  final sara = _user('u2', 'سارا');
  final reza = _user('u3', 'رضا');
  final users = [amir, sara, reza];

  group('Expense.shares — تقسیم مساوی', () {
    test('۱۰۰٬۰۰۰ بین ۳ نفر دقیقاً جمع می‌شود (نه اعشاری)', () {
      final expense = Expense(
        id: 'e1',
        amount: 100000,
        paidById: amir.id,
        paidForIds: [amir.id, sara.id, reza.id],
        groupId: 'g1',
        dateTime: DateTime.now(),
        description: 'شام',
      );

      final shares = expense.shares();
      final total = shares.values.fold(0.0, (sum, v) => sum + v);

      expect(total, 100000);
      // هر سهم باید عدد صحیح باشد، نه چیزی مثل ۳۳۳۳۳٫۳۳
      for (final share in shares.values) {
        expect(share, share.roundToDouble());
      }
    });

    test('مجموع بدهی همه‌ی افراد یک هزینه دقیقاً صفر است', () {
      final expense = Expense(
        id: 'e1',
        amount: 100000,
        paidById: amir.id,
        paidForIds: [amir.id, sara.id, reza.id],
        groupId: 'g1',
        dateTime: DateTime.now(),
        description: 'شام',
      );

      final totalDebt = users.fold(
        0.0,
        (sum, u) => sum + expense.getDebtAmountForUser(u, users),
      );

      expect(totalDebt, 0.0);
    });
  });

  group('تسویه‌ی کامل — گروه شریفیون (سناریوی گزارش‌شده)', () {
    test('بعد از ثبت پرداختِ دقیقِ بدهی، مانده صفر می‌شود، نه ۱ تومان', () {
      final group = Group(
        id: 'g1',
        name: 'شریفیون',
        memberIds: [amir.id, sara.id],
        expenseIds: ['e1', 'e2'],
        createdBy: amir.id,
        createdAt: DateTime.now(),
      );

      // امیرعباس ۱۰۰٬۰۰۱ تومان برای هر دو نفر خرج کرده (عمداً عدد فرد، تا
      // باقیمانده‌ی تقسیم را هم تست کند).
      final dinner = Expense(
        id: 'e1',
        amount: 100001,
        paidById: amir.id,
        paidForIds: [amir.id, sara.id],
        groupId: group.id,
        dateTime: DateTime.now(),
        description: 'شام',
      );

      // سارا الان دقیقاً همان سهمی را که بدهکار است به امیرعباس برمی‌گرداند.
      final saraDebtBefore = dinner.getDebtAmountForUser(sara, [amir, sara]);
      expect(saraDebtBefore, lessThan(0)); // سارا بدهکار است

      final settlement = Expense(
        id: 'e2',
        amount: -saraDebtBefore, // دقیقاً همان مبلغِ بدهی، نه یک عدد گرد‌شده
        paidById: sara.id,
        paidForIds: [amir.id],
        groupId: group.id,
        dateTime: DateTime.now(),
        description: 'تسویه',
      );

      final allExpenses = [dinner, settlement];
      final saraBalance = group.getUserBalance(sara, allExpenses, [amir, sara]);
      final amirBalance = group.getUserBalance(amir, allExpenses, [amir, sara]);

      // ⚠️ قبل از این فیکس، اینجا همیشه یک باقیمانده‌ی کوچک (۰٫XX یا حتی ۱
      // تومان کامل) می‌ماند چون sharePerPerson اعشاری بود.
      expect(saraBalance, 0.0, reason: 'بدهی سارا باید کاملاً صفر شود');
      expect(amirBalance, 0.0, reason: 'طلب امیرعباس باید کاملاً صفر شود');
    });
  });
}
