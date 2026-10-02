// lib/Services/Api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:namer_app/Services/ApiConfig.dart';
import 'package:namer_app/Services/TokenStore.dart';

/// خطای عمومی سرور API (هر کد غیر ۲xx که رفرش هم نتوانست درست کند).
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// بدنه‌ی کامل پاسخ خطای سرور (اگر JSON بوده) تا UI بتواند فیلدهای
  /// اضافی مثل `registeredViaGoogle` را بخواند.
  final Map<String, dynamic>? details;

  ApiException(this.statusCode, this.message, [this.details]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// نشست منقضی شده و رفرش هم جواب نداد → کاربر باید دوباره وارد شود.
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'نشست شما منقضی شده، دوباره وارد شوید']);
}

/// نتیجه‌ی درخواست forgot-password.
class ForgotPasswordResult {
  final bool success;
  final String? devResetToken; // فقط در محیط dev — بعد از وصل شدن سرویس ایمیل حذف می‌شود
  final String? devExpiresAt;
  ForgotPasswordResult({
    required this.success,
    this.devResetToken,
    this.devExpiresAt,
  });
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();
  bool _isRefreshing = false;

  // Only GETs to these paths may ever be served from cache. Auth endpoints
  // (register/login/refresh/google) are POSTs, but a browser/service-worker
  // or an intermediate cache could still replay a stale "email-already-in-use"
  // response after the account was deleted — so every auth request explicitly
  // asks for a fresh network response.
  static const _noStoreHeaders = {
    'Cache-Control': 'no-store',
    'Pragma': 'no-cache',
  };

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  Map<String, String> _authHeaders([bool withToken = true]) {
    final headers = {..._jsonHeaders};
    if (withToken && TokenStore.accessToken != null) {
      headers['Authorization'] = 'Bearer ${TokenStore.accessToken}';
    }
    return headers;
  }

  /// بدنه‌ی پاسخ را همان‌طور که هست برمی‌گرداند: Map، List یا null.
  ///
  /// ⚠️ این متد قبلاً فقط Map را قبول می‌کرد و برای هر پاسخ دیگری null
  /// برمی‌گرداند. چون مسیرهای لیستی سرور (/me/groups، /me/expenses،
  /// /me/contacts، /users/search، /users/:id/friends) آرایه‌ی JSON در سطح
  /// بالا برمی‌گردانند، همه‌ی آن‌ها بی‌صدا «لیست خالی» می‌شدند — بدون هیچ خطایی.
  @visibleForTesting
  static dynamic decodeBody(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// فقط برای خواندن فیلدهای خطا — پاسخ خطای سرور همیشه آبجکت است.
  static Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  String _errorMessage(dynamic data, http.Response res) {
    final map = _asMap(data);
    final msg = map?['error'] ?? map?['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    return 'خطای سرور (${res.statusCode})';
  }

  /// تلاش برای گرفتن جفت توکن جدید با refreshToken ذخیره‌شده.
  /// موفقیت یعنی true. اگر refresh هم ۴۰۱ داد، نشست پاک می‌شود.
  Future<bool> _tryRefresh() async {
    final refreshToken = TokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final res = await _client.post(
        ApiConfig.uri('/auth/refresh'),
        headers: {..._jsonHeaders, ..._noStoreHeaders},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final data = _asMap(decodeBody(res));
      if (res.statusCode == 200 &&
          data != null &&
          data['accessToken'] is String) {
        await TokenStore.updateTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String?,
        );
        return true;
      }
      // توکن رفرش نامعتبر/منقضی → نشست تمام شده
      if (res.statusCode == 401) {
        await TokenStore.clear();
      }
      return false;
    } catch (_) {
      return false; // خطای شبکه: وضعیت نشست را حفظ کن
    }
  }

  /// GET با توکن + یک بار تلاش مجدد بعد از refresh خودکار.
  Future<dynamic> get(String path) async {
    final res = await _client.get(
      ApiConfig.uri(path),
      headers: _authHeaders(),
    );
    if (res.statusCode == 401) {
      final refreshed = _isRefreshing ? false : await _guardedRefresh();
      if (!refreshed) throw SessionExpiredException();
      final retry = await _client.get(
        ApiConfig.uri(path),
        headers: _authHeaders(),
      );
      return _handle(retry);
    }
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) async {
    final res = await _client.post(
      ApiConfig.uri(path),
      headers: {..._authHeaders(authenticated), ..._noStoreHeaders},
      body: jsonEncode(body),
    );
    if (authenticated && res.statusCode == 401) {
      final refreshed = _isRefreshing ? false : await _guardedRefresh();
      if (!refreshed) throw SessionExpiredException();
      final retry = await _client.post(
        ApiConfig.uri(path),
        headers: {..._authHeaders(), ..._noStoreHeaders},
        body: jsonEncode(body),
      );
      return _handle(retry);
    }
    return _handle(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await _client.put(
      ApiConfig.uri(path),
      headers: _authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) {
      final refreshed = _isRefreshing ? false : await _guardedRefresh();
      if (!refreshed) throw SessionExpiredException();
      final retry = await _client.put(
        ApiConfig.uri(path),
        headers: _authHeaders(),
        body: jsonEncode(body),
      );
      return _handle(retry);
    }
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _client.delete(
      ApiConfig.uri(path),
      headers: _authHeaders(),
    );
    if (res.statusCode == 401) {
      final refreshed = _isRefreshing ? false : await _guardedRefresh();
      if (!refreshed) throw SessionExpiredException();
      final retry = await _client.delete(
        ApiConfig.uri(path),
        headers: _authHeaders(),
      );
      return _handle(retry);
    }
    return _handle(res);
  }

  // همزمان‌سازی: اگر چند درخواست هم‌زمان ۴۰۱ گرفتند، فقط یک refresh زده شود
  // و بقیه منتظر همان نتیجه بمانند (refresh token یک‌بارمصرف است!).
  CompleterSlot? _pending;

  Future<bool> _guardedRefresh() async {
    if (_pending != null) return _pending!.future;
    _pending = CompleterSlot();
    _isRefreshing = true;
    final ok = await _tryRefresh();
    _isRefreshing = false;
    final slot = _pending!;
    slot.complete(ok);
    _pending = null;
    return ok;
  }

  dynamic _handle(http.Response res) {
    final data = decodeBody(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    throw ApiException(
      res.statusCode,
      _errorMessage(data, res),
      _asMap(data),
    );
  }

  // ===== Auth =====

  /// ثبت‌نام با API جدید. body سرور: { email, password, name } — همان نامی که
  /// کاربر وارد می‌کند هم به‌عنوان display_name ذخیره می‌شود (یکتا در سطح کل).
  /// بعد از موفقیت، توکن‌ها ذخیره و کاربر وارد شده است.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await post(
      '/auth/register',
      {'name': name, 'email': email, 'password': password},
      authenticated: false,
    ) as Map<String, dynamic>;
    // سرور در پاسخ ۲۰۱ جفت توکن برمی‌گرداند → کاربر بلافاصله وارد می‌شود
    await _saveSession(data);
  }

  /// بررسی آزاد بودن نام نمایشی (برای صفحه ChooseUsername).
  Future<bool> isDisplayNameAvailable(String name) async {
    final res = await _client.get(
      ApiConfig.uri('/display-names/check?name=${Uri.encodeQueryComponent(name)}'),
    );
    final data = _asMap(decodeBody(res));
    if (res.statusCode == 200 && data != null) {
      return data['available'] == true;
    }
    throw ApiException(res.statusCode, _errorMessage(data, res));
  }

  /// ورود با رمز. بعد از موفقیت توکن‌ها در TokenStore ذخیره می‌شوند.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await post(
      '/auth/login',
      {'email': email, 'password': password},
      authenticated: false,
    ) as Map<String, dynamic>;
    await _saveSession(data);
  }

  /// ورود با گوگل. [idToken] از GoogleSignInAccount.authentication.idToken می‌آید.
  Future<void> loginWithGoogle(String idToken) async {
    final data = await post(
      '/auth/google',
      {'idToken': idToken},
      authenticated: false,
    ) as Map<String, dynamic>;
    await _saveSession(data);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw ApiException(500, 'پاسخ سرور بدون توکن است');
    }
    await TokenStore.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: (data['id'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      photoURL: data['photoURL'] as String?,
      accountNumber: data['accountNumber'] as String?,
    );
  }

  /// فراموشی رمز. در محیط dev توکن ریست در نتیجه برمی‌گردد (devResetToken).
  Future<ForgotPasswordResult> forgotPassword(String email) async {
    final data = await post(
      '/auth/password/forgot',
      {'email': email},
      authenticated: false,
    ) as Map<String, dynamic>;
    return ForgotPasswordResult(
      success: data['success'] == true,
      devResetToken: data['devResetToken'] as String?,
      devExpiresAt: data['devExpiresAt'] as String?,
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await post(
      '/auth/password/reset',
      {'token': token, 'newPassword': newPassword},
      authenticated: false,
    );
  }

  /// خروج: توکن سرور باطل و نشست محلی پاک می‌شود.
  Future<void> logout() async {
    final refreshToken = TokenStore.refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await post('/auth/logout', {'refreshToken': refreshToken},
            authenticated: false);
      }
    } finally {
      await TokenStore.clear();
    }
  }

  // ===== Profile =====

  Future<Map<String, dynamic>> getMyProfile() async {
    final id = TokenStore.userId;
    if (id == null) throw SessionExpiredException('کاربر وارد نشده است');
    return await get('/users/$id') as Map<String, dynamic>;
  }

  /// ویرایش پروفایل خودِ کاربر. فقط فیلدهای غیر null فرستاده می‌شوند.
  /// برای پاک کردن شماره کارت، رشته‌ی خالی بفرستید.
  Future<Map<String, dynamic>> updateMyProfile({
    String? name,
    String? photoURL,
    String? accountNumber,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (photoURL != null) body['photoURL'] = photoURL;
    if (accountNumber != null) body['accountNumber'] = accountNumber;
    if (body.isEmpty) return await getMyProfile();
    return await put('/me', body) as Map<String, dynamic>;
  }

  // ===== Bootstrap =====

  /// همه‌ی داده‌های اولیه در یک درخواست:
  /// { user, contacts[], groups[], expenses[] }
  Future<Map<String, dynamic>> bootstrap() async {
    return await get('/me/bootstrap') as Map<String, dynamic>;
  }

  // ===== Users / Contacts =====

  /// کاربرانی که برای این حساب قابل مشاهده‌اند: خودش، دوستان و هم‌گروهی‌ها.
  Future<List<dynamic>> getContacts() async => _asList(await get('/me/contacts'));

  /// همه‌ی کاربران اپ (برای تب «پیدا کردن»؛ فیلتر کردن محلی روی همین لیست
  /// انجام می‌شود، نه با یک درخواست به ازای هر حرف تایپ‌شده).
  /// نتیجه فقط id/name/photoURL دارد — ایمیل و شماره کارت برنمی‌گردند.
  Future<List<dynamic>> listAllUsers() async =>
      _asList(await get('/users/search'));

  /// جست‌وجوی کاربران روی سرور. معمولاً لازم نیست — [listAllUsers] +
  /// فیلتر محلی برای تعداد کاربرانِ یک اپ دوستانه کافی است؛ این فقط برای
  /// سازگاری/حالت‌های خاص نگه داشته شده.
  Future<List<dynamic>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return listAllUsers();
    return _asList(await get('/users/search?q=${Uri.encodeQueryComponent(q)}'));
  }

  // ===== Friends =====

  Future<List<dynamic>> getFriends() async {
    final id = TokenStore.userId;
    if (id == null) throw SessionExpiredException('کاربر وارد نشده است');
    return _asList(await get('/users/$id/friends'));
  }

  Future<void> addFriend(String friendId) async {
    final id = TokenStore.userId;
    if (id == null) throw SessionExpiredException('کاربر وارد نشده است');
    await post('/users/$id/friends', {'friendId': friendId});
  }

  Future<void> removeFriend(String friendId) async {
    final id = TokenStore.userId;
    if (id == null) throw SessionExpiredException('کاربر وارد نشده است');
    await delete('/users/$id/friends/$friendId');
  }

  // ===== Groups =====

  Future<List<dynamic>> getMyGroups() async => _asList(await get('/me/groups'));

  Future<Map<String, dynamic>> createGroup({
    required String id,
    required String name,
    required List<String> memberIds,
  }) async {
    return await post('/groups', {
      'id': id,
      'name': name,
      'memberIds': memberIds,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    List<String>? memberIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (memberIds != null) body['memberIds'] = memberIds;
    return await put('/groups/$groupId', body) as Map<String, dynamic>;
  }

  Future<void> deleteGroup(String groupId) async {
    await delete('/groups/$groupId');
  }

  // ===== Expenses =====

  Future<List<dynamic>> getMyExpenses() async =>
      _asList(await get('/me/expenses'));

  Future<List<dynamic>> getGroupExpenses(String groupId) async =>
      _asList(await get('/groups/$groupId/expenses'));

  /// ثبت هزینه. سرور paidById را از توکن می‌گیرد، پس پرداخت‌کننده همیشه
  /// خودِ کاربر واردشده است.
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> body) async {
    return await post('/expenses', body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateExpense(
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    return await put('/expenses/$expenseId', body) as Map<String, dynamic>;
  }

  Future<void> deleteExpense(String expenseId) async {
    await delete('/expenses/$expenseId');
  }

  /// سرور هم آرایه‌ی خالی برمی‌گرداند و هم (در بعضی مسیرها) آبجکت با کلید.
  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const ['groups', 'expenses', 'users', 'friends', 'contacts']) {
        if (data[key] is List) return data[key] as List<dynamic>;
      }
    }
    return const [];
  }
}

/// یک Completer ساده برای همزمان‌سازی refresh.
class CompleterSlot {
  final _completer = Completer<bool>();
  Future<bool> get future => _completer.future;
  void complete(bool value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }
}
