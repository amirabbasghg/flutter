// دکمه‌ی رسمی «ورود با گوگل» مخصوص وب.
//
// چرا این فایل وجود دارد: روی وب پکیج google_sign_in متد authenticate() را
// پشتیبانی نمی‌کند (`supportsAuthenticate() => false` و خودِ متد
// UnimplementedError پرتاب می‌کند). تنها راه، رندر کردن دکمه‌ی خود گوگل با
// google_sign_in_web/web_only.dart است.
//
// آن فایل dart:js_interop را import می‌کند و روی اندروید اصلاً کامپایل نمی‌شود،
// پس با conditional import جدا نگه داشته می‌شود: روی اندروید نسخه‌ی stub
// (یک ویجت خالی) و روی وب نسخه‌ی واقعی بار می‌شود.
export 'GoogleWebButtonStub.dart'
    if (dart.library.js_interop) 'GoogleWebButtonWeb.dart';
