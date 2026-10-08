import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications_service.dart';

/// مسؤول: إشعارات انخفاض الرصيد حسب عتبات ثابتة.
/// كل عتبة تُرسل مرة واحدة فقط لكل كرت (تُحفظ الحالة لكل كرت في SharedPreferences)،
/// ويعمل الإرسال من أي سلسلة (الواجهة أو المهمة الخلفية حتى لو كان التطبيق مغلقاً).
class BalanceNotifier {
  BalanceNotifier._();

  static const List<int> thresholdsMB = [100, 70, 50, 30, 5];
  static bool _initialized = false;

  static String _key(String voucher, int mb) =>
      'balance_notified_${voucher}_${mb}mb';

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    try {
      await flutterLocalNotificationsPlugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {}
  }

  /// يفحص الرصيد المتبقي (بالبايت) مقابل العتبات من الأعلى للأسفل، ويرسل
  /// إشعاراً واحداً لأعلى عتبة مقطوعة لم يُرسل إشعارها بعد.
  /// يعيد قيمة العتبة (بالميجا) التي أُرسل لها إشعار، أو null.
  static Future<int?> checkAndNotify({
    required String voucher,
    required int remainingBytes,
  }) async {
    if (voucher.isEmpty || remainingBytes <= 0) return null;

    final remainingMB = remainingBytes ~/ (1024 * 1024);
    final prefs = await SharedPreferences.getInstance();

    int? fired;
    for (final mb in thresholdsMB) {
      if (remainingMB >= mb) break;
      final already = prefs.getBool(_key(voucher, mb)) ?? false;
      if (already) continue;
      await prefs.setBool(_key(voucher, mb), true);
      fired = mb;
      break;
    }

    if (fired != null) {
      await _ensureInitialized();
      await flutterLocalNotificationsPlugin.show(
        id: 2000 + fired,
        title: 'تنبيه انخفاض الرصيد',
        body: _message(fired),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'low_balance_channel',
            'تنبيهات الرصيد',
            channelDescription: 'إشعارات عند انخفاض رصيد الإنترنت',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
    return fired;
  }

  static String _message(int mb) => switch (mb) {
        100 => '⚠️ رصيدك أقل من 100 ميجا - اقترب نفاد كرت الإنترنت',
        70 => '⚠️ رصيدك أقل من 70 ميجا - الكرت يقترب من النفاد',
        50 => '⚠️ رصيدك أقل من 50 ميجا - راقب استهلاكك',
        30 => '⚠️ رصيدك أقل من 30 ميجا - الكرت على وشك الانتهاء',
        5 => '⚠️ رصيدك أقل من 5 ميجا - الكرت سينتهي خلال لحظات',
        _ => 'رصيدك أقل من $mb ميجا',
      };
}