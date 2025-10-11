import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // اگر متن جدید خالی است، بازگشت
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // فقط اعداد را نگه دار
    String digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // محدود کردن به 16 رقم
    if (digits.length > 16) {
      digits = digits.substring(0, 16);
    }

    // اضافه کردن خط تیره بعد از هر 4 رقم
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += '-';
      }
      formatted += digits[i];
    }

    // حفظ موقعیت کرسر
    int offset = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
