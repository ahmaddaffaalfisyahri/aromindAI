// lib/price_input_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // jika kosong, kembalikan
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // ambil hanya angka (hilangkan titik/koma/spasi/dsb)
    final numericOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // hindari leading zeros yang panjang: biarkan '0' tapi trim banyak 0 di depan
    final trimmed = numericOnly.replaceFirst(RegExp(r'^0+(?=.)'), '');

    // format angka
    try {
      final parsed = int.tryParse(trimmed.isEmpty ? '0' : trimmed) ?? 0;
      final newText = _fmt.format(parsed);

      // letakkan cursor di akhir (sederhana & stabil)
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } catch (e) {
      // kalau ada error parsing fallback ke numericOnly
      return TextEditingValue(
        text: numericOnly,
        selection: TextSelection.collapsed(offset: numericOnly.length),
      );
    }
  }
}
