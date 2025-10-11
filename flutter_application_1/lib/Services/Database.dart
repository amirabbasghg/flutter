// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/Group.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get usersCollection => _firestore.collection('users');
  CollectionReference get groupsCollection => _firestore.collection('groups');
  CollectionReference get expensesCollection => _firestore.collection('expenses');
  CollectionReference get displayNamesCollection => _firestore.collection('displayNames');

  // Constructor با uid اختیاری
  FirestoreService({String? uid});

  // بررسی اینکه displayName تکراری نباشد
  Future<bool> isDisplayNameAvailable(String displayName) async {
    try {
      final snapshot = await displayNamesCollection
          .doc(displayName.toLowerCase())
          .get();
      return !snapshot.exists;
    } catch (e) {
      print('Error checking display name availability: $e');
      return false;
    }
  }

  // ذخیره displayName
  Future<void> saveDisplayName(String displayName, String email) async {
    final batch = _firestore.batch();

    // ذخیره displayName برای بررسی تکراری نبودن
    final displayNameDoc = displayNamesCollection.doc(displayName.toLowerCase());
    batch.set(displayNameDoc, {
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Group Operations
  Future<void> saveGroup(Group group) async {
    await groupsCollection.doc(group.id).set(group.toFirestore());
  }

  Future<void> updateGroup(Group group) async {
    await groupsCollection.doc(group.id).update(group.toFirestore());
  }

  Future<void> deleteGroup(String groupId) async {
    await groupsCollection.doc(groupId).delete();
  }

  Future<Group?> getGroup(String groupId) async {
    final snapshot = await groupsCollection.doc(groupId).get();
    return snapshot.exists ? Group.fromFirestore(snapshot) : null;
  }

  // Expense Operations
  Future<void> saveExpense(Expense expense) async {
    await expensesCollection.doc(expense.id).set(expense.toFirestore());
  }

  Future<void> updateExpense(Expense expense) async {
    await expensesCollection.doc(expense.id).update(expense.toFirestore());
  }

  Future<void> deleteExpense(String expenseId) async {
    await expensesCollection.doc(expenseId).delete();
  }

  Future<Expense?> getExpense(String expenseId) async {
    final snapshot = await expensesCollection.doc(expenseId).get();
    return snapshot.exists ? Expense.fromFirestore(snapshot) : null;
  }

  // Batch operations
  Future<void> addExpenseToGroup(Expense expense, Group group) async {
    final batch = _firestore.batch();

    // Save expense
    final expenseDoc = expensesCollection.doc(expense.id);
    batch.set(expenseDoc, expense.toFirestore());

    // Update group's expense list
    final groupDoc = groupsCollection.doc(group.id);
    final updatedExpenseIds = List<String>.from(group.expenseIds)..add(expense.id);
    batch.update(groupDoc, {
      'expenseIds': updatedExpenseIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> removeExpenseFromGroup(String expenseId, Group group) async {
    final batch = _firestore.batch();

    // Delete expense
    final expenseDoc = expensesCollection.doc(expenseId);
    batch.delete(expenseDoc);

    // Update group's expense list
    final groupDoc = groupsCollection.doc(group.id);
    final updatedExpenseIds = List<String>.from(group.expenseIds)..remove(expenseId);
    batch.update(groupDoc, {
      'expenseIds': updatedExpenseIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // User Operations
  Future<void> saveUser(Map<String, dynamic> userData) async {
    await usersCollection.doc(userData['uid']).set(userData);
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final snapshot = await usersCollection.doc(uid).get();
      return snapshot.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // در FirestoreService
  WriteBatch get batch => _firestore.batch();
}