// lib/viewmodel/app_state_vm.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/WordPairModel.dart';
import 'package:namer_app/model/User.dart';

import '../Services/Database.dart';

class AppStateVM extends ChangeNotifier {
  WordPairModel _current = WordPairModel(
    first: WordPair
        .random()
        .first,
    second: WordPair
        .random()
        .second,
  );

  final List<WordPairModel> _favorites = [];
  User? _currentUser;

  // لیست‌های کش شده
  List<User> _members = [];
  List<Group> _groups = [];
  List<Expense> _allExpenses = [];

  // سرویس Firestore
  final FirestoreService _firestoreService = FirestoreService();

  WordPairModel get current => _current;

  List<WordPairModel> get favorites => _favorites;

  User? get currentUser => _currentUser;

  List<User> get members => _members;

  List<Group> get groups => _groups;

  List<Expense> get allExpenses => _allExpenses;

  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

  AppStateVM() {
    initialize();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    _authStateSubscription =
        firebase_auth.FirebaseAuth.instance.authStateChanges().listen((
            firebaseUser) {
          if (firebaseUser != null) {
            // کاربر لاگین کرده
            _handleUserAuthState(firebaseUser);
          } else {
            // کاربر لاگ اوت کرده
            _currentUser = null;
            notifyListeners();
          }
        });
  }

  Future<void> _handleUserAuthState(firebase_auth.User firebaseUser) async {
    try {
      await _loadMembers();
      await _loadGroups();
      await _loadExpenses();
      // اول بررسی می‌کنیم که کاربر در لیست members وجود دارد یا نه
      User? existingUser = findUserById(firebaseUser.uid);

      if (existingUser != null) {
        // کاربر در دیتابیس وجود دارد
        _currentUser = existingUser;
      } else {
        // کاربر جدید - باید به دیتابیس اضافه شود
        final newUser = User(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email
              ?.split('@')
              .first ?? 'User',
          email: firebaseUser.email ?? '',
          photoURL: firebaseUser.photoURL,
        );

        await _firestoreService.usersCollection.doc(firebaseUser.uid).set(
            newUser.toFirestore());
        _members.add(newUser);
        _currentUser = newUser;
      }

      notifyListeners();
    } catch (e) {
      print('Error handling auth state: $e');
    }
  }

  Future<void> refreshCurrentUser() async {
    final currentFirebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (currentFirebaseUser != null) {
      await _handleUserAuthState(currentFirebaseUser);
    } else {
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    // بارگذاری اولیه داده‌ها
    await _loadMembers();
    await _loadGroups();
    await _loadExpenses();

    // راه‌اندازی listeners برای تغییرات real-time
    _setupRealTimeListeners();
  }

  void _setupRealTimeListeners() {
    // Listener برای کاربران
    _firestoreService.usersCollection.snapshots().listen((snapshot) {
      _members = snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
      notifyListeners();
    });

    // Listener برای گروه‌ها
    _firestoreService.groupsCollection.snapshots().listen((snapshot) {
      _groups = snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
      notifyListeners();
    });

    // Listener برای expenses
    _firestoreService.expensesCollection.snapshots().listen((snapshot) {
      _allExpenses =
          snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  Future<void> _loadMembers() async {
    try {
      final snapshot = await _firestoreService.usersCollection.get();
      _members = snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _loadGroups() async {
    try {
      final snapshot = await _firestoreService.groupsCollection.get();
      _groups = snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final snapshot = await _firestoreService.expensesCollection.get();
      _allExpenses =
          snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error loading expenses: $e');
    }
  }

  Future<void> setAmount(double value) async {
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  // اضافه کردن کاربر جدید
  Future<void> addUser({
    required String name,
    required String email,
    String? photoURL,
    String? id,
  }) async {
    if (name
        .trim()
        .isNotEmpty && !hasEmail(email)) {
      final userId = id ?? _firestoreService.usersCollection
          .doc()
          .id;
      final newUser = User(
        id: userId,
        name: name.trim(),
        email: email,
        photoURL: photoURL,
      );

      await _firestoreService.usersCollection.doc(userId).set(
          newUser.toFirestore());
    }
  }

  // اضافه کردن کاربر از Firebase User
  Future<void> addUserFromFirebase(firebase.User firebaseUser,
      String name) async {
    if (!hasEmail(firebaseUser.email ?? '')) {
      final newUser = User(
        id: firebaseUser.uid,
        name: name,
        email: firebaseUser.email ?? '',
        photoURL: firebaseUser.photoURL,
      );

      await _firestoreService.usersCollection.doc(firebaseUser.uid).set(
          newUser.toFirestore());
      _members.add(newUser);
    }
  }

  Future<void> addGroup(String name, List<User> selectedMembers) async {
    if (name
        .trim()
        .isNotEmpty) {
      final memberIds = selectedMembers.map((user) => user.id).toList();
      final currentUserId = _currentUser?.id ?? 'unknown';

      final newGroup = Group.create(
        name: name.trim(),
        memberIds: memberIds,
        createdBy: currentUserId,
      );

      await _firestoreService.saveGroup(newGroup);
    }
  }

  Future<void> removeGroup(Group group) async {
    try {
      // حذف expenseهای گروه
      final groupExpenses = _allExpenses.where((expense) =>
      expense.groupId == group.id);
      for (final expense in groupExpenses) {
        await _firestoreService.deleteExpense(expense.id);
      }

      // حذف گروه
      await _firestoreService.deleteGroup(group.id);
    } catch (e) {
      print('Error removing group: $e');
    }
  }

  // بررسی وجود ایمیل
  bool hasEmail(String email) {
    return _members.any((user) =>
    user.email == email.trim());
  }

  // بررسی وجود نام
  bool hasName(String name) {
    return _members.any((user) =>
    user.name.toLowerCase() == name.toLowerCase().trim());
  }

  // پیدا کردن کاربر با ایمیل
  User? findUserByEmail(String email) {
    try {
      return _members.firstWhere((user) =>
      user.email.toLowerCase() == email.toLowerCase().trim());
    } catch (e) {
      return null;
    }
  }

  // پیدا کردن کاربر با نام
  User? findUserByName(String name) {
    try {
      return _members.firstWhere((user) =>
      user.name.toLowerCase() == name.toLowerCase().trim());
    } catch (e) {
      return null;
    }
  }

  // پیدا کردن کاربر با ID
  User? findUserById(String userId) {
    try {
      return _members.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  Future<void> removeMember(User user) async {
    try {
      // حذف کاربر از گروه‌ها
      for (final group in _groups) {
        if (group.memberIds.contains(user.id)) {
          group.memberIds.remove(user.id);
          await _firestoreService.updateGroup(group);
        }
      }

      // مدیریت expenseهای کاربر
      final userExpenses = _allExpenses.where((expense) =>
      expense.paidById == user.id || expense.paidForIds.contains(user.id));

      for (final expense in userExpenses) {
        if (expense.paidById == user.id) {
          await _firestoreService.deleteExpense(expense.id);
        } else {
          expense.paidForIds.remove(user.id);
          await _firestoreService.updateExpense(expense);
        }
      }

      // حذف کاربر
      await _firestoreService.usersCollection.doc(user.id).delete();
    } catch (e) {
      print('Error removing member: $e');
    }
  }

  Future<void> addExpenseToGroup(Group group, Expense expense) async {
    await _firestoreService.addExpenseToGroup(expense, group);
  }

  Future<void> removeExpenseFromGroup(Group group, Expense expense) async {
    await _firestoreService.removeExpenseFromGroup(expense.id, group);
  }

  List<Expense> getExpensesForGroup(Group group) {
    return _allExpenses
        .where((expense) => expense.groupId == group.id)
        .toList();
  }

  double getTotalExpensesForGroup(Group group) {
    final groupExpenses = getExpensesForGroup(group);
    return groupExpenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  double getUserBalanceInGroup(User user, Group group) {
    final groupExpenses = getExpensesForGroup(group);
    double balance = 0;

    for (final expense in groupExpenses) {
      balance += expense.getDebtAmountForUser(user, _members);
    }

    return balance;
  }

  List<Map<String, dynamic>> getSettlementsForGroup(Group group) {
    return group.getSettlements(_allExpenses, _members);
  }

  void toggleFavorite() {
    if (_favorites.contains(_current)) {
      _favorites.remove(_current);
    } else {
      _favorites.add(_current);
    }
    notifyListeners();
  }

  bool isFavorite(WordPairModel pair) {
    return _favorites.contains(pair);
  }

  void getNext() {
    final newPair = WordPair.random();
    _current = WordPairModel(
      first: newPair.first,
      second: newPair.second,
    );
    notifyListeners();
  }

  Expense createExpense({
    required double amount,
    required User paidBy,
    required List<User> paidFor,
    required Group group,
    required DateTime dateTime,
    required String description,
  }) {
    return Expense(
      id: _firestoreService.expensesCollection
          .doc()
          .id,
      amount: amount,
      paidById: paidBy.id,
      paidForIds: paidFor.map((user) => user.id).toList(),
      groupId: group.id,
      dateTime: dateTime,
      description: description,
      isEqualSplit: true,
      customSplits: const {},
    );
  }

  Future<void> updateGroup(Group group) async {
    await _firestoreService.updateGroup(group);
  }

  Future<void> updateUser(User user) async {
    await _firestoreService.usersCollection.doc(user.id).update(
        user.toFirestore());
  }

  Future<void> updateExpense(Expense expense) async {
    await _firestoreService.updateExpense(expense);
  }

  Future<void> updateUserName(String userId, String name) async {
    final user = findUserById(userId);
    if (user != null) {
      final updatedUser = User(
        id: user.id,
        name: name,
        email: user.email,
        photoURL: user.photoURL,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> updateUserPhotoURL(String userId, String photoURL) async {
    final user = findUserById(userId);
    if (user != null) {
      final updatedUser = User(
        id: user.id,
        name: user.name,
        email: user.email,
        photoURL: photoURL,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> updateUserEmail(String userId, String email) async {
    final user = findUserById(userId);
    if (user != null) {
      final updatedUser = User(
        id: user.id,
        name: user.name,
        email: email,
        photoURL: user.photoURL,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> startSetCurrentUserFromFirebase(firebase.User firebaseUser,
      String name) async {
    User? existingUser = findUserById(firebaseUser.uid);

    if (existingUser != null) {
      _currentUser = existingUser;
    } else {
      await addUserFromFirebase(firebaseUser, name);
      _currentUser = findUserById(firebaseUser.uid);
    }

    notifyListeners();
  }

  Future<void> setCurrentUserFromFirebase(firebase.User firebaseUser) async {
    User? existingUser = findUserById(firebaseUser.uid);
    if (existingUser != null) {
      _currentUser = existingUser;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;

  Future<void> updateCurrentUser({
    String? name,
    String? email,
    String? photoURL,
  }) async {
    if (_currentUser != null) {
      final updatedUser = User(
        id: _currentUser!.id,
        name: name ?? _currentUser!.name,
        email: email ?? _currentUser!.email,
        photoURL: photoURL ?? _currentUser!.photoURL,
      );

      await updateUser(updatedUser);
      _currentUser = updatedUser;
    }
  }

  // متدهای کمکی برای کار با Firestore
  Stream<List<User>> getUsersStream() {
    return _firestoreService.usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Group>> getGroupsStream() {
    return _firestoreService.groupsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Expense>> getExpensesStream() {
    return _firestoreService.expensesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    });
  }

  // در AppStateVM
  Future<void> addFriend(String friendId) async {
    if (_currentUser != null && !_currentUser!.friendIds.contains(friendId)) {
      try {
        // گرفتن اطلاعات کاربر مقابل
        final friendUser = await _getUserById(friendId);
        if (friendUser == null) {
          throw Exception('User not found');
        }

        final batch = _firestoreService.batch;

        // آپدیت کاربر فعلی - اضافه کردن دوست به لیست
        final updatedCurrentUser = _currentUser!.copyWithAddedFriend(friendId);
        final currentUserDoc = _firestoreService.usersCollection.doc(
            _currentUser!.id);
        batch.update(
            currentUserDoc, {'friendIds': updatedCurrentUser.friendIds});

        // آپدیت کاربر مقابل - اضافه کردن کاربر فعلی به لیست دوستانش
        final updatedFriendUser = friendUser.copyWithAddedFriend(
            _currentUser!.id);
        final friendUserDoc = _firestoreService.usersCollection.doc(friendId);
        batch.update(friendUserDoc, {'friendIds': updatedFriendUser.friendIds});

        // اجرای batch
        await batch.commit();

        // آپدیت کاربر فعلی در حافظه
        _currentUser = updatedCurrentUser;

        // آپدیت لیست members اگر کاربر مقابل در آن وجود دارد
        final friendIndex = _members.indexWhere((user) => user.id == friendId);
        if (friendIndex != -1) {
          _members[friendIndex] = updatedFriendUser;
        }

        notifyListeners();
      } catch (e) {
        print('Error adding friend: $e');
        throw e;
      }
    }
  }

  Future<void> removeFriend(String friendId) async {
    if (_currentUser != null && _currentUser!.friendIds.contains(friendId)) {
      try {
        // گرفتن اطلاعات کاربر مقابل
        final friendUser = await _getUserById(friendId);
        if (friendUser == null) {
          throw Exception('User not found');
        }

        final batch = _firestoreService.batch;

        // آپدیت کاربر فعلی - حذف دوست از لیست
        final updatedCurrentUser = _currentUser!.copyWithRemovedFriend(
            friendId);
        final currentUserDoc = _firestoreService.usersCollection.doc(
            _currentUser!.id);
        batch.update(
            currentUserDoc, {'friendIds': updatedCurrentUser.friendIds});

        // آپدیت کاربر مقابل - حذف کاربر فعلی از لیست دوستانش
        final updatedFriendUser = friendUser.copyWithRemovedFriend(
            _currentUser!.id);
        final friendUserDoc = _firestoreService.usersCollection.doc(friendId);
        batch.update(friendUserDoc, {'friendIds': updatedFriendUser.friendIds});

        // اجرای batch
        await batch.commit();

        // آپدیت کاربر فعلی در حافظه
        _currentUser = updatedCurrentUser;

        // آپدیت لیست members اگر کاربر مقابل در آن وجود دارد
        final friendIndex = _members.indexWhere((user) => user.id == friendId);
        if (friendIndex != -1) {
          _members[friendIndex] = updatedFriendUser;
        }

        notifyListeners();
      } catch (e) {
        print('Error removing friend: $e');
        throw e;
      }
    }
  }

// متد کمکی برای گرفتن کاربر از Firestore
  Future<User?> _getUserById(String userId) async {
    try {
      final doc = await _firestoreService.usersCollection.doc(userId).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  List<Group> getGroupsForUser(User user) {
    return _groups.where((group) => group.memberIds.contains(user.id)).toList();
  }

// یا اگر می‌خواهید گروه‌های کاربر فعلی را برگرداند:
  List<Group> getCurrentUserGroups() {
    if (_currentUser == null) return [];
    return _groups
        .where((group) => group.memberIds.contains(_currentUser!.id))
        .toList();
  }

  Future<void> updateUserAccountNumber(String userId,
      String accountNumber) async {
    try {
      // پیدا کردن کاربر
      final user = findUserById(userId);
      if (user != null) {
        // ایجاد کاربر آپدیت شده
        final updatedUser = user.copyWith(accountNumber: accountNumber);

        // آپدیت در Firestore
        await _firestoreService.usersCollection.doc(userId).update({
          'accountNumber': accountNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // آپدیت در حافظه
        final userIndex = _members.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          _members[userIndex] = updatedUser;
        }

        // اگر کاربر فعلی است، آپدیت شود
        if (_currentUser?.id == userId) {
          _currentUser = updatedUser;
        }
        refreshCurrentUser();

        notifyListeners();
      }
    } catch (e) {
      print('Error updating account number: $e');
      throw e;
    }
  }

// متد برای آپدیت شماره کارت کاربر فعلی
  Future<void> updateCurrentUserAccountNumber(String accountNumber) async {
    if (_currentUser != null) {
      await updateUserAccountNumber(_currentUser!.id, accountNumber);
    }
  }



// متد برای بررسی وجود شماره کارت
  bool hasAccountNumber(User user) {
    return user.accountNumber != null && user.accountNumber!.isNotEmpty;
  }

// متد برای گرفتن شماره کارت کاربر
  String? getUserAccountNumber(String userId) {
    final user = findUserById(userId);
    return user?.accountNumber;
  }
}
