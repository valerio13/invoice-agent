import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '€', decimalDigits: 0);
final _month = DateFormat('MMM', 'en_US');
final _monthLong = DateFormat('MMMM', 'en_US');

/// €18,420
String money(double value) => _money.format(value);

/// €18.4K, for chart labels.
String moneyShort(double value) {
  if (value >= 1000) return '€${(value / 1000).toStringAsFixed(1)}K';
  return money(value);
}

/// JUN
String monthShort(DateTime month) => _month.format(month).toUpperCase();

/// November
String monthName(DateTime month) => _monthLong.format(month);

/// +23%, or null when there is nothing to compare with.
String? change(double now, double before) {
  if (before == 0) return null;
  final percent = ((now - before) / before * 100).round();
  return '${percent >= 0 ? '+' : ''}$percent%';
}
