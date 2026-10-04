import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'Group.dart';
import 'User.dart';

class Expense {
  final String id;
  final double amount;
  final String paidById;
  final List<String> paidForIds;
  final String groupId;
  final DateTime dateTime;
  final String description;
  final bool isEqualSplit;
  final Map<String, double> customSplits;

  Expense({
    required this.id,
    required this.amount,
    required this.paidById,
    required this.paidForIds,
    required this.groupId,
    required this.dateTime,
    required this.description,
    this.isEqualSplit = true,
    this.customSplits = const {},
  });
  // در Expense.dart
  Expense.createCustom({
    required this.amount,
    required User paidBy,
    required List<User> paidFor,
    required Group group,
    required this.dateTime,
    required this.description,
    required Map<User, double> customSplits, // تغییر به Map<User, double>
  })  : id = Uuid().v4(),
        paidById = paidBy.id,
        paidForIds = paidFor.map((user) => user.id).toList(),
        groupId = group.id,
        isEqualSplit = false,
        customSplits = _convertUserMapToStringMap(customSplits) // تبدیل به Map<String, double>
  {
    _validateCustomSplits();
  }
  // Factory constructor برای ایجاد expense با تقسیم غیرمساوی
  // factory Expense.createCustom({
  //   required double amount,
  //   required User paidBy,
  //   required List<User> paidFor,
  //   required String groupId,
  //   required DateTime dateTime,
  //   required String description,
  //   required Map<User, double> customSplits,
  //   required DateTime createdAt,
  // }) {
  //   // تبدیل Map<User, double> به Map<String, double>
  //   final stringCustomSplits = <String, double>{};
  //   for (final entry in customSplits.entries) {
  //     stringCustomSplits[entry.key.id] = entry.value;
  //   }
  //
  //   // تبدیل لیست User به لیست String (آیدی‌ها)
  //   final paidForIds = paidFor.map((user) => user.id).toList();
  //
  //   return Expense(
  //     id: id,
  //     amount: amount,
  //     paidById: paidBy.id,
  //     paidForIds: paidForIds,
  //     groupId: groupId,
  //     dateTime: dateTime,
  //     description: description,
  //     isEqualSplit: false, // برای تقسیم غیرمساوی false می‌شود
  //     customSplits: stringCustomSplits,
  //     createdAt: createdAt,
  //   );
  // }

  /// ساخت از JSON بک‌اند. customSplits به شکل { userId: amount } می‌آید.
  factory Expense.fromJson(Map<String, dynamic> json) {
    final rawSplits = json['customSplits'];
    final splits = <String, double>{};
    if (rawSplits is Map) {
      rawSplits.forEach((key, value) {
        if (key is String && value is num) splits[key] = value.toDouble();
      });
    } else if (rawSplits is List) {
      // سرور در پاسخ POST/PUT آرایه‌ی [{userId, amount}] برمی‌گرداند
      for (final item in rawSplits) {
        if (item is Map &&
            item['userId'] is String &&
            item['amount'] is num) {
          splits[item['userId'] as String] = (item['amount'] as num).toDouble();
        }
      }
    }

    return Expense(
      id: (json['id'] ?? '') as String,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      paidById: (json['paidById'] ?? '') as String,
      paidForIds: (json['paidForIds'] as List?)?.cast<String>().toList() ?? [],
      groupId: (json['groupId'] ?? '') as String,
      dateTime:
          DateTime.tryParse((json['dateTime'] ?? '') as String)?.toLocal() ??
              DateTime.now(),
      description: (json['description'] ?? '') as String,
      isEqualSplit: json['isEqualSplit'] as bool? ?? true,
      customSplits: splits,
    );
  }

  /// بدنه‌ی POST /api/expenses و PUT /api/expenses/:id.
  /// سرور paidById را از توکن می‌گیرد، پس فرستادنش لازم نیست.
  /// customSplits در ورودیِ سرور آرایه است، نه map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'paidForIds': paidForIds,
      'groupId': groupId,
      'dateTime': dateTime.toUtc().toIso8601String(),
      'description': description,
      'isEqualSplit': isEqualSplit,
      'customSplits': isEqualSplit
          ? const []
          : customSplits.entries
              .map((e) => {'userId': e.key, 'amount': e.value})
              .toList(),
    };
  }

  static Map<String, double> _convertUserMapToStringMap(Map<User, double> userMap) {
    final result = <String, double>{};
    for (final entry in userMap.entries) {
      result[entry.key.id] = entry.value;
    }
    return result;
  }

  void _validateCustomSplits() {
    if (!isEqualSplit) {
      final totalCustomAmount = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
      if (totalCustomAmount != amount) {
        throw Exception('مجموع مبالغ تقسیم شده باید برابر با مبلغ کل باشد');
      }
    }
  }

  /// میانگین خامِ سهم هر نفر — ممکن است اعشاری باشد.
  /// برای محاسبه‌ی بدهی از [shareOf] استفاده کنید، نه از این.
  double get sharePerPerson {
    if (paidForIds.isEmpty) return 0;
    return amount / paidForIds.length;
  }

  /// سهم هر شرکت‌کننده، به تومانِ صحیح، طوری که **مجموع سهم‌ها دقیقاً برابر
  /// مبلغ کل شود**.
  ///
  /// ⚠️ چرا لازم است: تقسیم مساویِ ۱۰۰٬۰۰۰ بین ۳ نفر یعنی ۳۳۳۳۳٫۳۳… برای هر
  /// نفر. با اعشار، مانده‌ها هیچ‌وقت دقیقاً صفر نمی‌شوند و بعد از تسویه‌ی کامل
  /// باز چیزی مثل «۰ تومان بدهکار» یا «۱ تومان» باقی می‌ماند — همان چیزی که
  /// در گروه شریفیون دیده شد. اینجا باقیمانده‌ی تقسیم (۰ تا n-۱ تومان) بین
  /// نفرات اول پخش می‌شود تا جمع سهم‌ها مو به مو برابر کل باشد.
  ///
  /// ترتیب پخشِ باقیمانده بر اساس شناسه‌ی مرتب‌شده است تا برای یک هزینه‌ی ثابت
  /// همیشه یک نتیجه بدهد (نه وابسته به ترتیب لیست در حافظه).
  Map<String, double> shares() {
    if (!isEqualSplit) {
      return Map<String, double>.from(customSplits);
    }
    final n = paidForIds.length;
    if (n == 0) return const {};

    final total = amount.round();
    final base = total ~/ n;
    var remainder = total - base * n;

    final ids = [...paidForIds]..sort();
    final out = <String, double>{};
    for (final id in ids) {
      var share = base;
      if (remainder > 0) {
        share += 1;
        remainder -= 1;
      }
      out[id] = share.toDouble();
    }
    return out;
  }

  /// سهم یک کاربر از این هزینه (۰ اگر شرکت‌کننده نباشد).
  double shareOf(String userId) => shares()[userId] ?? 0;

  double getCustomShare(String userId) => shareOf(userId);

  bool isUserInvolved(User user, List<User> allUsers) {
    return paidById == user.id || paidForIds.contains(user.id);
  }

  String getUserRole(User user, List<User> allUsers) {
    if (paidById == user.id) return 'payer';
    if (paidForIds.contains(user.id)) return 'receiver';
    return 'not_involved';
  }

  /// مانده‌ی این کاربر از این هزینه. مثبت = طلبکار، منفی = بدهکار.
  ///
  /// جمعِ این مقدار روی همه‌ی افراد درگیر **دقیقاً صفر** است، چون هم از
  /// [shares] استفاده می‌کند و هم کل را از روی همان سهم‌ها می‌گیرد.
  double getDebtAmountForUser(User user, List<User> allUsers) {
    final split = shares();
    final userShare = split[user.id] ?? 0;

    if (paidById == user.id) {
      // آنچه پرداخت کرده منهای سهم خودش
      final total = split.values.fold(0.0, (sum, value) => sum + value);
      return total - userShare;
    }
    if (split.containsKey(user.id)) {
      return -userShare;
    }
    return 0;
  }

  User getPaidBy(List<User> allUsers) {
    return allUsers.firstWhere((user) => user.id == paidById);
  }

  List<User> getPaidFor(List<User> allUsers) {
    return allUsers.where((user) => paidForIds.contains(user.id)).toList();
  }

  List<User> getAllInvolvedUsers(List<User> allUsers) {
    final paidBy = getPaidBy(allUsers);
    final paidFor = getPaidFor(allUsers);
    return [paidBy, ...paidFor];
  }

  String getSummary(List<User> allUsers) {
    final paidBy = getPaidBy(allUsers);
    final paidFor = getPaidFor(allUsers);
    final formatter = NumberFormat("#,###");

    return '💰 مبلغ: ${formatter.format(amount)} تومان\n'
        '💳 پرداخت کننده: ${paidBy.name}\n'
        '👥 دریافت کنندگان: ${paidFor.map((u) => u.name).join(", ")}\n'
        '📝 توضیحات: $description';
  }

  @override
  String toString() {
    return 'Expense(amount: $amount, paidById: $paidById, paidFor: ${paidForIds.length} users, '
        'isEqualSplit: $isEqualSplit, description: $description)';
  }
}