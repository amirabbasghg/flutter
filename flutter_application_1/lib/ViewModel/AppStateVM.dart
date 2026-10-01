// lib/ViewModel/AppStateVM.dart
//
// لایه‌ی داده‌ی اپ. قبلاً مستقیماً روی Cloud Firestore بود؛ حالا کاملاً روی
// بک‌اند Cloudflare Workers + D1 است. انگیزه‌ی مهاجرت: دامنه‌های Firestore از
// ایران بدون فیلترشکن در دسترس نیستند، در حالی که workers.dev هست.
//
// تفاوت مفهومی مهم با نسخه‌ی Firestore:
//   قبلاً members یعنی «همه‌ی کاربران اپ» — هر کلاینت کل جدول users را
//   می‌خواند. حالا members یعنی «کاربرانِ قابل مشاهده برای من»: خودم،
//   دوستانم و هم‌گروهی‌هایم (GET /api/me/contacts). برای پیدا کردن دوست جدید
//   از searchUsers استفاده می‌شود که سمت سرور جست‌وجو می‌کند.
//
// real-time listener وجود ندارد (D1 چنین چیزی ندارد). به‌جایش هر تغییر، پاسخ
// سرور را در حالت محلی اعمال می‌کند و reload() برای تازه‌سازی دستی هست.

import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:uuid/uuid.dart';

import 'package:namer_app/model/Group.dart';
import 'package:namer_app/model/Expense.dart';
import 'package:namer_app/model/WordPairModel.dart';
import 'package:namer_app/model/User.dart';

import '../Services/Api.dart';
import '../Services/TokenStore.dart';

class AppStateVM extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  WordPairModel _current = WordPairModel(
    first: WordPair.random().first,
    second: WordPair.random().second,
  );

  final List<WordPairModel> _favorites = [];

  User? _currentUser;
  List<User> _members = [];
  List<Group> _groups = [];
  List<Expense> _allExpenses = [];

  bool _isLoading = false;
  String? _loadError;

  WordPairModel get current => _current;
  List<WordPairModel> get favorites => _favorites;

  User? get currentUser => _currentUser;

  /// کاربران قابل مشاهده: خودم + دوستان + هم‌گروهی‌ها.
  List<User> get members => _members;

  List<Group> get groups => _groups;
  List<Expense> get allExpenses => _allExpenses;

  /// در حال گرفتن داده از سرور.
  bool get isLoading => _isLoading;

  /// پیام خطای آخرین بارگذاری (null یعنی مشکلی نبود).
  String? get loadError => _loadError;

  bool get isLoggedIn => _currentUser != null;

  // ===========================================================================
  // ورود / خروج و بارگذاری
  // ===========================================================================

  /// کاربر فعلی را از نشست ذخیره‌شده می‌سازد. بعد از login/register همه‌ی این
  /// مقادیر پر هستند، پس حتی وقتی سرور در دسترس نیست currentUser تهی نمی‌ماند
  /// (وگرنه صفحه‌ها «لطفاً ابتدا وارد شوید» نشان می‌دهند).
  User? _userFromTokenStore() {
    final id = TokenStore.userId;
    if (id == null || id.isEmpty) return null;
    final photo = TokenStore.photoURL;
    final account = TokenStore.accountNumber;
    return User(
      id: id,
      name: (TokenStore.name?.isNotEmpty == true) ? TokenStore.name! : 'کاربر',
      email: TokenStore.email ?? '',
      photoURL: (photo?.isNotEmpty == true) ? photo : null,
      accountNumber: (account?.isNotEmpty == true) ? account : null,
      friendIds: _currentUser?.friendIds,
    );
  }

  /// بلافاصله بعد از ورود موفق (ایمیل/رمز، ثبت‌نام یا گوگل) و همچنین در
  /// Wrapper موقع باز شدن اپ با نشست ذخیره‌شده صدا زده می‌شود.
  Future<void> onSignedIn() async {
    _currentUser = _userFromTokenStore();
    notifyListeners();
    await reload();
  }

  /// سازگاری با فراخوان‌های قدیمی؛ همان reload است.
  Future<void> initialize() => reload();

  /// گرفتن همه‌ی داده‌ها در یک درخواست (GET /api/me/bootstrap).
  Future<void> reload() async {
    if (!TokenStore.hasSession) {
      _clearState();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.bootstrap();

      final user = data['user'];
      if (user is Map<String, dynamic>) {
        _currentUser = User.fromJson(user);
      } else {
        _currentUser ??= _userFromTokenStore();
      }

      _members = _parseList(data['contacts'], User.fromJson);
      _groups = _parseList(data['groups'], Group.fromJson);
      _allExpenses = _parseList(data['expenses'], Expense.fromJson);
      _ensureSelfInMembers();

      _loadError = null;
    } on SessionExpiredException {
      await _signOutLocally();
      return;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _signOutLocally();
        return;
      }
      _loadError = e.message;
      _currentUser ??= _userFromTokenStore();
    } catch (_) {
      // خطای شبکه: نشست و داده‌های قبلی را از دست نده
      _loadError = 'اتصال به سرور برقرار نشد';
      _currentUser ??= _userFromTokenStore();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// فقط پروفایل کاربر را تازه می‌کند (سبک‌تر از reload).
  Future<void> refreshCurrentUser() async {
    try {
      if (!TokenStore.hasSession) {
        _clearState();
        return;
      }
      final profile = await _api.getMyProfile();
      _currentUser = User.fromJson(profile);
      _upsertMember(_currentUser!);
      notifyListeners();
    } on SessionExpiredException {
      await _signOutLocally();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _signOutLocally();
        return;
      }
      _currentUser ??= _userFromTokenStore();
      notifyListeners();
    } catch (_) {
      _currentUser ??= _userFromTokenStore();
      notifyListeners();
    }
  }

  /// خروج: نشست سرور باطل و حالت محلی پاک می‌شود.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // حتی اگر سرور در دسترس نبود، نشست محلی باید پاک شود
      await TokenStore.clear();
    }
    _clearState();
  }

  Future<void> _signOutLocally() async {
    await TokenStore.clear();
    _clearState();
  }

  void _clearState() {
    _currentUser = null;
    _members = [];
    _groups = [];
    _allExpenses = [];
    _isLoading = false;
    _loadError = null;
    notifyListeners();
  }

  /// خودِ کاربر همیشه باید در members باشد تا نام و عکسش در صفحه‌ها پیدا شود.
  void _ensureSelfInMembers() {
    final me = _currentUser;
    if (me == null) return;
    if (!_members.any((u) => u.id == me.id)) {
      _members = [me, ..._members];
    }
  }

  // ===========================================================================
  // گروه‌ها
  // ===========================================================================

  Future<void> addGroup(String name, List<User> selectedMembers) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final memberIds = selectedMembers.map((u) => u.id).toSet();
    // سازنده همیشه عضو گروه است (سرور هم همین کار را می‌کند)
    if (_currentUser != null) memberIds.add(_currentUser!.id);

    final created = await _api.createGroup(
      id: const Uuid().v4(),
      name: trimmed,
      memberIds: memberIds.toList(),
    );

    _groups = [Group.fromJson(created), ..._groups];
    notifyListeners();
    // عضو جدید ممکن است هنوز در members نباشد
    await _refreshContacts();
  }

  /// نام و/یا اعضای گروه را ذخیره می‌کند. صفحه‌ها memberIds را درجا تغییر
  /// می‌دهند و بعد این متد را صدا می‌زنند، پس هر دو فرستاده می‌شود.
  Future<void> updateGroup(Group group) async {
    final updated = await _api.updateGroup(
      groupId: group.id,
      name: group.name,
      memberIds: group.memberIds,
    );
    _replaceGroup(Group.fromJson(updated));
    notifyListeners();
    await _refreshContacts();
  }

  Future<void> removeGroup(Group group) async {
    // سرور با ON DELETE CASCADE هزینه‌های گروه را هم پاک می‌کند
    await _api.deleteGroup(group.id);
    _groups = _groups.where((g) => g.id != group.id).toList();
    _allExpenses = _allExpenses.where((e) => e.groupId != group.id).toList();
    notifyListeners();
  }

  List<Group> getGroupsForUser(User user) =>
      _groups.where((g) => g.memberIds.contains(user.id)).toList();

  List<Group> getCurrentUserGroups() {
    if (_currentUser == null) return const [];
    return getGroupsForUser(_currentUser!);
  }

  // ===========================================================================
  // هزینه‌ها
  // ===========================================================================

  /// ساخت یک Expense با تقسیم مساوی (هنوز ذخیره نشده).
  /// برای ذخیره، addExpenseToGroup صدا زده می‌شود.
  Expense createExpense({
    required double amount,
    required User paidBy,
    required List<User> paidFor,
    required Group group,
    required DateTime dateTime,
    required String description,
  }) {
    return Expense(
      id: const Uuid().v4(),
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

  Future<void> addExpenseToGroup(Group group, Expense expense) async {
    final body = expense.toJson();
    // پرداخت‌کننده می‌تواند عضو دیگری از گروه باشد (مثل «علی شام را حساب کرد»)
    body['paidById'] = expense.paidById;

    final created = await _api.createExpense(body);
    final saved = Expense.fromJson(created);

    _allExpenses = [..._allExpenses, saved];
    // expenseIds گروه را هم به‌روز نگه داریم تا محاسبات گروه درست بماند
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1 && !_groups[index].expenseIds.contains(saved.id)) {
      _groups[index].expenseIds.add(saved.id);
    }
    notifyListeners();
  }

  Future<void> removeExpenseFromGroup(Group group, Expense expense) async {
    await _api.deleteExpense(expense.id);
    _allExpenses = _allExpenses.where((e) => e.id != expense.id).toList();
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index].expenseIds.remove(expense.id);
    }
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    final body = expense.toJson()..remove('id');
    body['paidById'] = expense.paidById;
    final updated = await _api.updateExpense(expense.id, body);
    final saved = Expense.fromJson(updated);
    _allExpenses = [
      for (final e in _allExpenses) if (e.id == saved.id) saved else e,
    ];
    notifyListeners();
  }

  List<Expense> getExpensesForGroup(Group group) =>
      _allExpenses.where((expense) => expense.groupId == group.id).toList();

  double getTotalExpensesForGroup(Group group) => getExpensesForGroup(group)
      .fold(0.0, (total, expense) => total + expense.amount);

  double getUserBalanceInGroup(User user, Group group) {
    double balance = 0;
    for (final expense in getExpensesForGroup(group)) {
      balance += expense.getDebtAmountForUser(user, _members);
    }
    return balance;
  }

  List<Map<String, dynamic>> getSettlementsForGroup(Group group) =>
      group.getSettlements(_allExpenses, _members);

  // ===========================================================================
  // دوستان و مخاطبین
  // ===========================================================================

  Future<void> addFriend(String friendId) async {
    if (_currentUser == null) return;
    if (_currentUser!.friendIds.contains(friendId)) return;

    await _api.addFriend(friendId);
    _currentUser = _currentUser!.copyWithAddedFriend(friendId);
    notifyListeners();
    // دوست جدید حالا مخاطب است → اطلاعات کاملش را بگیر
    await _refreshContacts();
  }

  Future<void> removeFriend(String friendId) async {
    if (_currentUser == null) return;
    if (!_currentUser!.friendIds.contains(friendId)) return;

    await _api.removeFriend(friendId);
    _currentUser = _currentUser!.copyWithRemovedFriend(friendId);
    notifyListeners();
    await _refreshContacts();
  }

  /// جست‌وجوی کاربران سمت سرور (حداقل ۲ نویسه).
  /// در نسخه‌ی Firestore این کار با فیلتر کردن «همه‌ی کاربران» در حافظه انجام
  /// می‌شد؛ حالا کل جدول users هیچ‌وقت به کلاینت نمی‌آید.
  Future<List<User>> searchUsers(String query) async {
    final results = await _api.searchUsers(query);
    return _parseList(results, User.fromJson);
  }

  Future<void> _refreshContacts() async {
    try {
      _members = _parseList(await _api.getContacts(), User.fromJson);
      _ensureSelfInMembers();
      notifyListeners();
    } catch (_) {
      // لیست قبلی را نگه دار؛ reload بعدی درستش می‌کند
    }
  }

  // ===========================================================================
  // پروفایل خودِ کاربر
  // ===========================================================================

  Future<void> updateCurrentUser({
    String? name,
    String? photoURL,
    String? accountNumber,
  }) async {
    if (_currentUser == null) return;
    final updated = await _api.updateMyProfile(
      name: name,
      photoURL: photoURL,
      accountNumber: accountNumber,
    );
    _currentUser = User.fromJson(updated);
    _upsertMember(_currentUser!);
    await TokenStore.save(
      accessToken: TokenStore.accessToken ?? '',
      refreshToken: TokenStore.refreshToken ?? '',
      userId: _currentUser!.id,
      name: _currentUser!.name,
      email: _currentUser!.email,
      photoURL: _currentUser!.photoURL,
      accountNumber: _currentUser!.accountNumber,
    );
    notifyListeners();
  }

  Future<void> updateCurrentUserAccountNumber(String accountNumber) =>
      updateCurrentUser(accountNumber: accountNumber);

  /// فقط شماره کارت خودِ کاربر قابل تغییر است؛ بک‌اند اجازه‌ی ویرایش پروفایل
  /// دیگران را نمی‌دهد.
  Future<void> updateUserAccountNumber(
    String userId,
    String accountNumber,
  ) async {
    if (_currentUser?.id != userId) {
      throw ApiException(403, 'فقط شماره کارت خودتان قابل تغییر است');
    }
    await updateCurrentUser(accountNumber: accountNumber);
  }

  bool hasAccountNumber(User user) =>
      user.accountNumber != null && user.accountNumber!.isNotEmpty;

  String? getUserAccountNumber(String userId) =>
      findUserById(userId)?.accountNumber;

  // ===========================================================================
  // جست‌وجو در حالت محلی
  // ===========================================================================

  bool hasEmail(String email) =>
      _members.any((user) => user.email == email.trim());

  bool hasName(String name) => _members
      .any((user) => user.name.toLowerCase() == name.toLowerCase().trim());

  User? findUserByEmail(String email) {
    final target = email.toLowerCase().trim();
    for (final user in _members) {
      if (user.email.toLowerCase() == target) return user;
    }
    return null;
  }

  User? findUserByName(String name) {
    final target = name.toLowerCase().trim();
    for (final user in _members) {
      if (user.name.toLowerCase() == target) return user;
    }
    return null;
  }

  User? findUserById(String userId) {
    for (final user in _members) {
      if (user.id == userId) return user;
    }
    if (_currentUser?.id == userId) return _currentUser;
    return null;
  }

  // ===========================================================================
  // کمکی‌ها
  // ===========================================================================

  void _replaceGroup(Group group) {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index == -1) {
      _groups = [group, ..._groups];
    } else {
      _groups[index] = group;
    }
  }

  void _upsertMember(User user) {
    final index = _members.indexWhere((u) => u.id == user.id);
    if (index == -1) {
      _members = [..._members, user];
    } else {
      _members[index] = user;
    }
  }

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) out.add(fromJson(item));
    }
    return out;
  }

  Future<void> setAmount(double value) async {
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    notifyListeners();
  }

  // ===========================================================================
  // WordPair (نمونه‌ی اولیه‌ی پروژه — بی‌ارتباط با داده‌ی هزینه‌ها)
  // ===========================================================================

  void toggleFavorite() {
    if (_favorites.contains(_current)) {
      _favorites.remove(_current);
    } else {
      _favorites.add(_current);
    }
    notifyListeners();
  }

  bool isFavorite(WordPairModel pair) => _favorites.contains(pair);

  void getNext() {
    final newPair = WordPair.random();
    _current = WordPairModel(first: newPair.first, second: newPair.second);
    notifyListeners();
  }
}
