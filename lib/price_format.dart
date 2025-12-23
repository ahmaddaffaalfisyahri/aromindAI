// lib/price_format.dart
import 'package:intl/intl.dart';

class PriceFormat {
  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(double? price) {
    if (price == null) return '-';
    return _idr.format(price);
  }
}
