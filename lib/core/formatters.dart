import 'package:intl/intl.dart';

final _currency = NumberFormat.decimalPattern('vi_VN');
String formatVnd(int value) => '${_currency.format(value)} ₫';
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
