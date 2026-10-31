import 'package:intl/intl.dart';

String formatCurrency(num amount, [String? _]) {
  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

String formatRupiah(num amount, [String? _]) {
  return formatCurrency(amount);
}

String formatAmountOnly(num amount, [String? _]) {
  final formatter = NumberFormat.decimalPattern('id_ID');
  return formatter.format(amount);
}

String formatDateIndo(DateTime date, [String lang = 'id']) {
  final localeMap = {
    'id': 'id_ID',
    'en': 'en_US',
    'de': 'de_DE',
    'fr': 'fr_FR',
    'it': 'it_IT',
    'es': 'es_ES',
    'ja': 'ja_JP',
    'zh': 'zh_CN',
    'th': 'th_TH',
    'hi': 'hi_IN',
  };
  return DateFormat('d MMM yyyy', localeMap[lang] ?? 'id_ID').format(date);
}

String formatTimeAgo(DateTime dateTime, [String lang = 'id']) {
  final diff = DateTime.now().difference(dateTime);
  final m = diff.inMinutes;
  final h = diff.inHours;
  final d = diff.inDays;

  switch (lang) {
    case 'en':
      if (m < 1) return 'Just now';
      if (m < 60) return '$m min ago';
      if (h < 24) return '$h hr ago';
      if (d < 30) return '$d d ago';
      return DateFormat('d MMM', 'en_US').format(dateTime);
    case 'it':
      if (m < 1) return 'Proprio ora';
      if (m < 60) return '$m min fa';
      if (h < 24) return '$h ore fa';
      if (d < 30) return '$d giorni fa';
      return DateFormat('d MMM', 'it_IT').format(dateTime);
    case 'de':
      if (m < 1) return 'Gerade eben';
      if (m < 60) return 'vor $m Min.';
      if (h < 24) return 'vor $h Std.';
      if (d < 30) return 'vor $d Tg.';
      return DateFormat('d MMM', 'de_DE').format(dateTime);
    case 'fr':
      if (m < 1) return 'À l’instant';
      if (m < 60) return 'il y a $m min';
      if (h < 24) return 'il y a $h h';
      if (d < 30) return 'il y a $d j';
      return DateFormat('d MMM', 'fr_FR').format(dateTime);
    case 'es':
      if (m < 1) return 'Ahora mismo';
      if (m < 60) return 'hace $m min';
      if (h < 24) return 'hace $h h';
      if (d < 30) return 'hace $d d';
      return DateFormat('d MMM', 'es_ES').format(dateTime);
    case 'ja':
      if (m < 1) return 'たった今';
      if (m < 60) return '$m分前';
      if (h < 24) return '$h時間前';
      if (d < 30) return '$d日前';
      return DateFormat('M月d日', 'ja_JP').format(dateTime);
    case 'zh':
      if (m < 1) return '刚刚';
      if (m < 60) return '$m分钟前';
      if (h < 24) return '$h小时前';
      if (d < 30) return '$d天前';
      return DateFormat('M月d日', 'zh_CN').format(dateTime);
    case 'th':
      if (m < 1) return 'เมื่อสักครู่';
      if (m < 60) return '$m นาทีที่แล้ว';
      if (h < 24) return '$h ชม. ที่แล้ว';
      if (d < 30) return '$d วันที่แล้ว';
      return DateFormat('d MMM', 'th_TH').format(dateTime);
    case 'hi':
      if (m < 1) return 'अभी-अभी';
      if (m < 60) return '$m मिनट पहले';
      if (h < 24) return '$h घंटे पहले';
      if (d < 30) return '$d दिन पहले';
      return DateFormat('d MMM', 'hi_IN').format(dateTime);
    case 'id':
    default:
      if (m < 1) return 'Baru saja';
      if (m < 60) return '$m mnt lalu';
      if (h < 24) return '$h jam lalu';
      if (d < 30) return '$d hari lalu';
      return DateFormat('d MMM', 'id_ID').format(dateTime);
  }
}
