import 'package:intl/intl.dart';

const Map<String, double> exchangeRates = {
  'IDR': 1.0,
  'USD': 1.0 / 15500.0,
  'EUR': 1.0 / 17000.0,
  'JPY': 1.0 / 105.0,
  'CNY': 1.0 / 2150.0,
  'THB': 1.0 / 450.0,
  'INR': 1.0 / 185.0,
  'GBP': 1.0 / 20000.0,
};

const Map<String, String> currencySymbolMap = {
  'IDR': 'Rp ',
  'USD': '\$ ',
  'EUR': '€ ',
  'JPY': '¥ ',
  'CNY': '¥ ',
  'THB': '฿ ',
  'INR': '₹ ',
  'GBP': '£ ',
};

double toBaseIDR(num amountInActiveCurrency, [String currency = 'IDR']) {
  final rate = exchangeRates[currency] ?? 1.0;
  return (amountInActiveCurrency / rate);
}

double fromBaseIDR(num baseAmountIDR, [String currency = 'IDR']) {
  final rate = exchangeRates[currency] ?? 1.0;
  return (baseAmountIDR * rate);
}

String formatCurrency(num amount, [String currency = 'IDR']) {
  final rate = exchangeRates[currency] ?? 1.0;
  final converted = amount * rate;

  final localeMap = {
    'IDR': 'id_ID',
    'USD': 'en_US',
    'EUR': 'de_DE',
    'JPY': 'ja_JP',
    'CNY': 'zh_CN',
    'THB': 'th_TH',
    'INR': 'hi_IN',
    'GBP': 'en_GB',
  };

  final digits = (currency == 'IDR' || currency == 'JPY') ? 0 : 2;

  final formatter = NumberFormat.currency(
    locale: localeMap[currency] ?? 'id_ID',
    symbol: currencySymbolMap[currency] ?? 'Rp ',
    decimalDigits: digits,
  );
  return formatter.format(converted);
}

String formatRupiah(num amount, [String currency = 'IDR']) {
  return formatCurrency(amount, currency);
}

String formatDateIndo(DateTime date) {
  return DateFormat('d MMM yyyy', 'id_ID').format(date);
}

String formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mtk lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 30) return '${diff.inDays} hr lalu';
  return DateFormat('d MMM', 'id_ID').format(dateTime);
}
