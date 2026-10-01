import 'dart:typed_data';

import 'package:printing/printing.dart';

/// وب: مرورگر سیستم فایل ندارد. printing روی وب از bytes یک Blob می‌سازد و
/// دانلود را شروع می‌کند — یعنی فایل در پوشه‌ی دانلودِ خود مرورگر می‌نشیند.
Future<String> savePdfBytes(Uint8List bytes, String fileName) async {
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return 'فایل دانلود شد: $fileName';
}
