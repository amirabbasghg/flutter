import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      paidById: data['paidById'] ?? '',
      paidForIds: List<String>.from(data['paidForIds'] ?? []),
      groupId: data['groupId'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      isEqualSplit: data['isEqualSplit'] ?? true,
      customSplits: Map<String, double>.from(data['customSplits'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'paidById': paidById,
      'paidForIds': paidForIds,
      'groupId': groupId,
      'dateTime': Timestamp.fromDate(dateTime),
      'description': description,
      'isEqualSplit': isEqualSplit,
      'customSplits': customSplits,
      'updatedAt': FieldValue.serverTimestamp(),
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

  // سایر متدهای utility بدون تغییر باقی می‌مانند...
  double get sharePerPerson {
    if (paidForIds.isEmpty) return 0;
    return amount / paidForIds.length;
  }

  double getCustomShare(String userId) {
    if (isEqualSplit) {
      return sharePerPerson;
    }
    return customSplits[userId] ?? 0;
  }

  bool isUserInvolved(User user, List<User> allUsers) {
    return paidById == user.id || paidForIds.contains(user.id);
  }

  String getUserRole(User user, List<User> allUsers) {
    if (paidById == user.id) return 'payer';
    if (paidForIds.contains(user.id)) return 'receiver';
    return 'not_involved';
  }

  double getDebtAmountForUser(User user, List<User> allUsers) {
    if (paidById == user.id) {
      if (isEqualSplit) {
        return amount - (paidForIds.contains(user.id) ? sharePerPerson : 0);
      } else {
        final totalPaidForOthers = customSplits.values.fold(0.0, (sum, amount) => sum + amount);
        if (customSplits.containsKey(user.id)) {
          return totalPaidForOthers - customSplits[user.id]!;
        } else {
          return totalPaidForOthers;
        }
      }
    } else if (paidForIds.contains(user.id)) {
      if (isEqualSplit) {
        return -sharePerPerson;
      } else {
        return -customSplits[user.id]!;
      }
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