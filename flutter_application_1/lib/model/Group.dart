// lib/model/Group.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'Expense.dart';
import 'User.dart';

class Group {
  final String id;
  final String name;
  final List<String> memberIds;
  final List<String> expenseIds;
  final String createdBy;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.expenseIds,
    required this.createdBy,
    required this.createdAt,
  });

  Group.create({
    required this.name,
    required List<String> memberIds,
    required this.createdBy,
  })  : id = Uuid().v4(),
        memberIds = memberIds,
        expenseIds = [],
        createdAt = DateTime.now();

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      expenseIds: List<String>.from(data['expenseIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'memberIds': memberIds,
      'expenseIds': expenseIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }


  // Helper methods
  void addMember(String userId) {
    if (!memberIds.contains(userId)) {
      memberIds.add(userId);
    }
  }

  void removeMember(String userId) {
    memberIds.remove(userId);
  }

  bool hasMember(String userId) {
    return memberIds.contains(userId);
  }

  void addExpense(String expenseId) {
    if (!expenseIds.contains(expenseId)) {
      expenseIds.add(expenseId);
    }
  }
  double getDebtBetweenUsers(User user1, User user2, List<Expense> allExpenses, List<User> allUsers) {
    double debt = 0;
    final groupExpenses = allExpenses.where((expense) => expenseIds.contains(expense.id));

    for (final expense in groupExpenses) {
      final paidBy = expense.getPaidBy(allUsers);
      final paidForUsers = expense.getPaidFor(allUsers);

      if (paidBy.id == user1.id && paidForUsers.any((user) => user.id == user2.id)) {
        debt += expense.sharePerPerson;
      } else if (paidBy.id == user2.id && paidForUsers.any((user) => user.id == user1.id)) {
        debt -= expense.sharePerPerson;
      }
    }
    return debt;
  }

  void removeExpense(String expenseId) {
    expenseIds.remove(expenseId);
  }
  List<User> getMembers(List<User> allUsers) {
    return allUsers.where((user) => memberIds.contains(user.id)).toList();
  }
  // سایر متدهای محاسباتی بدون تغییر باقی می‌مانند...
  double getTotalExpenses(List<Expense> allExpenses) {
    final groupExpenses = allExpenses.where((expense) => expenseIds.contains(expense.id));
    return groupExpenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  List<Expense> getExpensesForUser(User user, List<Expense> allExpenses, List<User> allUsers) {
    final groupExpenses = allExpenses.where((expense) => expenseIds.contains(expense.id));
    return groupExpenses.where((expense) => expense.isUserInvolved(user, allUsers)).toList();
  }

  double getUserBalance(User user, List<Expense> allExpenses, List<User> allUsers) {
    double balance = 0;
    final groupExpenses = allExpenses.where((expense) => expenseIds.contains(expense.id));

    for (final expense in groupExpenses) {
      balance += expense.getDebtAmountForUser(user, allUsers);
    }
    return balance;
  }

  Map<String, double> getBalances(List<Expense> allExpenses, List<User> allUsers) {
    final balances = <String, double>{};
    for (final user in allUsers.where((user) => memberIds.contains(user.id))) {
      balances[user.id] = getUserBalance(user, allExpenses, allUsers);
    }
    return balances;
  }

  List<Map<String, dynamic>> getSettlements(List<Expense> allExpenses, List<User> allUsers) {
    final balances = getBalances(allExpenses, allUsers);
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    balances.forEach((userId, balance) {
      if (balance > 0) {
        creditors[userId] = balance;
      } else if (balance < 0) {
        debtors[userId] = -balance;
      }
    });

    final settlements = <Map<String, dynamic>>[];
    for (final creditorId in creditors.keys) {
      var creditAmount = creditors[creditorId]!;
      for (final debtorId in debtors.keys) {
        if (creditAmount <= 0) break;
        if (debtors[debtorId]! <= 0) continue;

        final settlementAmount = min(creditAmount, debtors[debtorId]!);
        settlements.add({
          'from': allUsers.firstWhere((user) => user.id == debtorId),
          'to': allUsers.firstWhere((user) => user.id == creditorId),
          'amount': settlementAmount,
        });

        creditAmount -= settlementAmount;
        debtors[debtorId] = debtors[debtorId]! - settlementAmount;
      }
    }
    return settlements;
  }

  int get memberCount => memberIds.length;
  int get expenseCount => expenseIds.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Group &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Group(name: $name, members: $memberCount, expenses: $expenseCount)';
}