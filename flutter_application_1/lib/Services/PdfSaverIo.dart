import 'dart:io';
import 'dart:typed_data';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path_provider/path_provider.dart';

/// اندروید/iOS/دسکتاپ: فایل در پوشه‌ی Downloads دستگاه ذخیره می‌شود.
///
/// مستقیم در Downloads نمی‌نویسیم چون روی اندروید دسترسی مستقیم به آن پوشه
/// محدود است؛ اول در فضای خصوصی اپ نوشته و بعد کپی می‌شود.
Future<String> savePdfBytes(Uint8List bytes, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes);

  final copied = await copyFileIntoDownloadFolder(tempFile.path, fileName);
  if (copied == true) {
    return 'در پوشه‌ی Downloads ذخیره شد: $fileName';
  }
  // اگر کپی نشد، دست‌کم مسیر فایل موقت را برگردان تا کاربر دستش خالی نماند.
  return 'ذخیره شد: ${tempFile.path}';
}
