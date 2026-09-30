import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Google Sign-In Service Class
class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool isInitialize = false;
  static Future<void> initSignIn() async {
    if (!isInitialize) {
      await _googleSignIn.initialize(
        serverClientId:
        '277889096548-56031v6p9lomnmifk7brqhm09733mpai.apps.googleusercontent.com',
      );
    }
    isInitialize = true;
  }
  // Sign in with Google
  /// فقط احراز هویت گوگل و برگرداندن اکانت (برای ارسال idToken به بک‌اند).
  /// بدون Firebase. اگر کاربر لغو کرد null برمی‌گرداند.
  static Future<GoogleSignInAccount?> authenticateAndGetAccount() async {
    await initSignIn();
    try {
      return await _googleSignIn.authenticate();
    } catch (_) {
      return null;
    }
  }

  static Future<User?> signInWithGoogle() async {
    try {
      initSignIn();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      final authorizationClient = googleUser.authorizationClient;
      GoogleSignInClientAuthorization? authorization = await authorizationClient
          .authorizationForScopes(['email', 'profile']);
      final accessToken = authorization?.accessToken;
      if (accessToken == null) {
        final authorization2 = await authorizationClient.authorizationForScopes(
          ['email', 'profile'],
        );
        if (authorization2?.accessToken == null) {
          throw FirebaseAuthException(code: "error", message: "error");
        }
        authorization = authorization2;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;
      // if (user != null) {
      //   final userDoc = FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(user.uid);
      //   final docSnapshot = await userDoc.get();
      //   if (!docSnapshot.exists) {
      //     await userDoc.set({
      //       'uid': user.uid,
      //       'name': user.displayName ?? '',
      //       'email': user.email ?? '',
      //       'photoURL': user.photoURL ?? '',
      //       'provider': 'google',
      //       'createdAt': FieldValue.serverTimestamp(),
      //     });
      //   }
      // }
      return user;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
  // Sign out
  static Future<void> signOut() async {
    try {
      // فقط sign-out محلی گوگل — بک‌اند جدید Firebase لازم ندارد.
      // (_auth.signOut() قدیمی عمداً حذف شد تا با حالت مهمان Firebase تداخل نکند.)
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }
  // Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }
}
