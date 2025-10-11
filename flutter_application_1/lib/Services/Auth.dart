import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:namer_app/Services/Database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<User?> signInAnon() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      return user;
    } catch (e) {
      print("Error in signInAnon: $e");
      return null;
    }
  }
  Future<dynamic> signUpEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      // await DatabaseService(uid: user!.uid).updateUserData('');
      return user;
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'email-already-in-use') {
        errorMessage = 'این ایمیل قبلا استفاده شده';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'فرمت ایمیل اشتباه است';
      } else if (e.code == 'weak-password') {
        errorMessage = 'رمز عبور خیلی ضعیفه';
      } else {
        errorMessage = 'خطای ناشناخته: ${e.message}';
      }

      return errorMessage;
    } catch (e) {
      print("Unexpected error: $e");
      return 'خطای غیرمنتظره رخ داده است';
    }
  }
  Future<dynamic> signInEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'فرمت ایمیل اشتباه است';
          break;
        case 'user-disabled':
          errorMessage = 'این حساب کاربری غیرفعال شده است';
          break;
        case 'user-not-found':
          errorMessage = 'کاربری با این ایمیل پیدا نشد';
          break;
        case 'wrong-password':
          errorMessage = 'رمز عبور اشتباه است';
          break;
        case 'invalid-credential':
          errorMessage = 'اعتبارنامه وارد شده نامعتبر است';
          break;
        case 'too-many-requests':
          errorMessage = 'تلاش‌های زیادی انجام شده. لطفاً稍后 مجدداً尝试 کنید';
          break;
        case 'network-request-failed':
          errorMessage = 'اتصال اینترنت برقرار نیست';
          break;
        case 'operation-not-allowed':
          errorMessage = 'ورود با ایمیل و رمز غیرفعال است';
          break;
        default:
          errorMessage = 'خطا در ورود: ${e.message}';
      }

      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return errorMessage;
    }
  }
  Future<bool> forgetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true; // موفقیت آمیز
    } catch (e) {
      print('Error sending password reset email: $e');
      return false; // خطا
    }
  }
  Future<void> signOutAnon() async {
    try {
       await _auth.signOut();
    } catch (e) {
      print("Error in signInAnon: $e");
    }
    return;
  }
}