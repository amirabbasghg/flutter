// تست رگرسیون برای ApiService.decodeBody.
//
// باگی که این تست جلوی برگشتنش را می‌گیرد: نسخه‌ی قبلی decode فقط Map را قبول
// می‌کرد و برای هر چیز دیگری null برمی‌گرداند. مسیرهای لیستی بک‌اند
// (/me/groups، /me/expenses، /me/contacts، /users/search، /users/:id/friends)
// آرایه‌ی JSON در سطح بالا برمی‌گردانند، پس همه‌ی آن‌ها بی‌صدا «لیست خالی»
// می‌شدند: نه خطایی، نه لاگی — فقط صفحه‌های خالی.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:namer_app/Services/Api.dart';

http.Response jsonResponse(String body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(body), status);

void main() {
  group('ApiService.decodeBody', () {
    test('آرایه‌ی JSON در سطح بالا حفظ می‌شود', () {
      final decoded = ApiService.decodeBody(jsonResponse(
        '[{"id":"u1","name":"Amir"},{"id":"u2","name":"Soltan"}]',
      ));

      expect(decoded, isA<List>());
      expect((decoded as List).length, 2);
      expect((decoded.first as Map)['name'], 'Amir');
    });

    test('آرایه‌ی خالی، خالی می‌ماند و null نمی‌شود', () {
      expect(ApiService.decodeBody(jsonResponse('[]')), isA<List>());
      expect(ApiService.decodeBody(jsonResponse('[]')), isEmpty);
    });

    test('آبجکت JSON هم مثل قبل کار می‌کند', () {
      final decoded = ApiService.decodeBody(jsonResponse(
        '{"id":"u1","name":"Amir","friendIds":["u2"]}',
      ));

      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map)['friendIds'], ['u2']);
    });

    test('بدنه‌ی خالی و JSON نامعتبر به null تبدیل می‌شوند', () {
      expect(ApiService.decodeBody(jsonResponse('')), isNull);
      expect(ApiService.decodeBody(jsonResponse('not json')), isNull);
    });

    test('UTF-8 فارسی درست decode می‌شود', () {
      final decoded = ApiService.decodeBody(
        jsonResponse('[{"id":"u1","name":"امیرعباس"}]'),
      );

      expect(((decoded as List).first as Map)['name'], 'امیرعباس');
    });
  });
}
