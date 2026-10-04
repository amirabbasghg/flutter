import 'package:uuid/uuid.dart';

class User {
  final String name;
  final String id;
  final String email;
  final String? photoURL;
  final String? accountNumber;
  final List<String> friendIds;


  User({
    required this.name,
    required this.email,
    required this.id,
    this.photoURL,
    this.accountNumber,
    List<String>? friendIds,
  }) : friendIds = friendIds ?? [];

  /// ساخت از JSON بک‌اند Cloudflare.
  /// شکل پاسخ: { id, name, email, photoURL, accountNumber, friendIds? }
  /// friendIds فقط برای خودِ کاربر برمی‌گردد؛ برای مخاطبین خالی است.
  factory User.fromJson(Map<String, dynamic> json) {
    String? nullIfEmpty(Object? value) {
      final s = value as String?;
      return (s == null || s.isEmpty) ? null : s;
    }

    return User(
      id: (json['id'] ?? '') as String,
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name'] as String
          : 'کاربر',
      email: (json['email'] ?? '') as String,
      photoURL: nullIfEmpty(json['photoURL']),
      accountNumber: nullIfEmpty(json['accountNumber']),
      friendIds: (json['friendIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoURL': photoURL,
      'accountNumber': accountNumber,
      'friendIds': friendIds,
    };
  }

  /// ایجاد کاربر جدید
  factory User.create({
    required String name,
    required String email,
    String? id,
    String? photoURL,
    String? accountNumber,
  }) {
    return User(
      id: id ?? const Uuid().v4(),
      name: name,
      email: email,
      photoURL: photoURL,
      accountNumber: accountNumber,
      friendIds: [],
    );
  }

  /// اضافه کردن دوست جدید
  User copyWithAddedFriend(String friendId) {
    if (friendIds.contains(friendId)) {
      return this;
    }

    final updatedFriendIds = List<String>.from(friendIds)..add(friendId);

    return User(
      id: id,
      name: name,
      email: email,
      photoURL: photoURL,
      accountNumber: accountNumber,
      friendIds: updatedFriendIds,
    );
  }

  /// حذف دوست
  User copyWithRemovedFriend(String friendId) {
    if (!friendIds.contains(friendId)) {
      return this;
    }

    final updatedFriendIds = List<String>.from(friendIds)..remove(friendId);

    return User(
      id: id,
      name: name,
      email: email,
      photoURL: photoURL,
      accountNumber: accountNumber,
      friendIds: updatedFriendIds,
    );
  }

  /// بررسی اینکه آیا کاربر دوست است یا نه
  bool isFriend(String userId) {
    return friendIds.contains(userId);
  }

  /// گرفتن تعداد دوستان
  int get friendsCount => friendIds.length;

  /// کپی کردن کاربر با مقادیر جدید
  User copyWith({
    String? name,
    String? email,
    String? photoURL,
    String? accountNumber,
    List<String>? friendIds,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      accountNumber: accountNumber ?? this.accountNumber,
      friendIds: friendIds ?? this.friendIds,
    );
  }

  /// تبدیل به لیست دوستان (برای نمایش)
  List<String> getFriendsList() {
    return List<String>.from(friendIds);
  }

  /// آیا کاربر ادمین کل است؟
  bool get isSuperAdmin => email.trim().toLowerCase() == 'mhsyny293@gmail.com';

  /// بررسی اینکه کاربر معتبر است
  bool get isValid => name.isNotEmpty && email.isNotEmpty && id.isNotEmpty;

  /// گرفتن اطلاعات اولیه کاربر
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'U';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User(name: $name, id: $id, email: $email, '
      'accountNumber: $accountNumber, friends: ${friendIds.length})';
}