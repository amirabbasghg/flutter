import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

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

  /// تبدیل از Firebase User به مدل شما
  factory User.fromFirebaseUser(fb.User user) {
    return User(
      id: user.uid,
      name: user.displayName ?? 'کاربر',
      email: user.email ?? '',
      photoURL: user.photoURL,
      accountNumber: null,
      friendIds: [],

    );
  }

  /// تبدیل از Firestore Document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: data['uid'],
      name:  data['displayName'] ?? 'کاربر',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      accountNumber: data['accountNumber'],
      friendIds: List<String>.from(data['friendIds'] ?? []),
    );
  }

  /// تبدیل به Map برای Firestore
   Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'displayName': name,
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
      id: id ?? FirebaseFirestore.instance.collection('users').doc().id,
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