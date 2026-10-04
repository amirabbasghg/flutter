// ذخیره‌ی فایل PDF روی دیسک — پیاده‌سازی‌اش بین وب و موبایل فرق دارد.
//
// موبایل: نوشتن در فایل موقت و بعد کپی در پوشه‌ی Downloads دستگاه.
// وب:    مرورگر فایلی ندارد؛ باید Blob ساخته و دانلود را شروع کرد.
//
// نسخه‌ی موبایل dart:io و path_provider لازم دارد که روی وب در دسترس نیستند،
// پس با conditional import جدا نگه داشته می‌شوند.
export 'PdfSaverIo.dart' if (dart.library.js_interop) 'PdfSaverWeb.dart';
