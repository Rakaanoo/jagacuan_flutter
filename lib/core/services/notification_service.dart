import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );

    _isInitialized = true;
  }

  NotificationDetails _getNotificationDetails({
    String channelId = 'jagacuan_reminders',
    String channelName = 'Pengingat Tabungan JagaCuan',
    String channelDescription = 'Notifikasi pengingat & motivasi tabungan JagaCuan',
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // 1. Pengingat Jam Terjadwal & Motivasi Progress
  Future<void> showInstantReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _getNotificationDetails(),
    );
  }

  // 2. Schedule Target Reminder Notification
  Future<void> scheduleTargetReminder({
    required int targetIdHash,
    required String targetTitle,
    required int hour,
    required int minute,
    required double remainingAmount,
  }) async {
    await init();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final remainingStr = fmt.format(remainingAmount);

    final title = '⏰ Waktunya Nabung! ($targetTitle)';
    final body = remainingAmount > 0
        ? 'Ayo sisihkan tabunganmu hari ini! Target "$targetTitle" kurang $remainingStr lagi. Kejar impianmu sekarang! 💪'
        : 'Hebat! Target "$targetTitle" kamu sudah tercapai. Pertahankan kebiasaan baik ini! 🎉';

    await _notificationsPlugin.show(
      targetIdHash.abs() % 100000,
      title,
      body,
      _getNotificationDetails(),
    );
  }

  // 3. Notifikasi Aktivitas Room Nabar (Social)
  Future<void> showNabarActivityNotification({
    required String roomName,
    required String memberName,
    required double amount,
  }) async {
    await init();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final amountStr = fmt.format(amount);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      '👥 Update Room Nabar: $roomName',
      '$memberName baru saja menabung $amountStr! Yuk ikut menyetor biar tidak ketinggalan! 🚀',
      _getNotificationDetails(
        channelId: 'jagacuan_nabar',
        channelName: 'Aktivitas Room Nabar',
        channelDescription: 'Notifikasi setoran & anggota di Room Nabar',
      ),
    );
  }

  // 4. Rekap Mingguan Tabungan (Weekly Recap)
  Future<void> showWeeklySummaryNotification({
    required double weeklyTotal,
    required int activeTargetsCount,
  }) async {
    await init();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalStr = fmt.format(weeklyTotal);

    await _notificationsPlugin.show(
      99901,
      '📊 Rekap Mingguan Tabungan JagaCuan',
      'Luar biasa! Minggu ini kamu telah mengumpulkan $totalStr untuk $activeTargetsCount target tabungan. Terus tingkatkan! 🔥',
      _getNotificationDetails(
        channelId: 'jagacuan_summary',
        channelName: 'Rekap & Ringkasan Tabungan',
        channelDescription: 'Ringkasan performa tabungan mingguan',
      ),
    );
  }

  // 5. Warning Deadline (Peringatan H-7 / H-3 Tenggat Waktu)
  Future<void> showDeadlineWarningNotification({
    required String targetTitle,
    required int daysLeft,
    required double remainingAmount,
  }) async {
    await init();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final remainingStr = fmt.format(remainingAmount);

    await _notificationsPlugin.show(
      (targetTitle.hashCode + daysLeft).abs() % 100000,
      '⚠️ Target "$targetTitle" Tinggal $daysLeft Hari Lagi!',
      'Kekurangan tabungan masih $remainingStr. Yuk kencangkan sabuk dan capai targetmu tepat waktu! 🎯',
      _getNotificationDetails(
        channelId: 'jagacuan_deadlines',
        channelName: 'Peringatan Tenggat Waktu',
        channelDescription: 'Notifikasi peringatan target mendekati tenggat',
      ),
    );
  }

  Future<void> cancelReminder(int targetIdHash) async {
    await _notificationsPlugin.cancel(targetIdHash.abs() % 100000);
  }
}
