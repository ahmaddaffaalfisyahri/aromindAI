// lib/formatters/thousand_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _f = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // hanya digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // hindari overflow; parse int
    final intValue = int.tryParse(digitsOnly) ?? 0;
    final newText = _f.format(intValue);

    // tempatkan cursor di akhir (sederhana)
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
