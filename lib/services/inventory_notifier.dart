import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spin_prize.dart';
import 'notifications_service.dart';

/// مسؤول: إشعار عند توفر كروت جديدة في مخزون عجلة الحظ.
/// يُرسل إشعاراً واحداً فقط لكل جهاز في كل مرة يتحول فيها المخزون من
/// «فارغ» إلى «متوفر» (الحالة الانتقالية محفوظة محلياً في SharedPreferences)،
/// ولا يُرسل إلا إذا كان لدى المستخدم دوّارة محفوظة وجاهزة للدوران.
class InventoryNotifier {
  InventoryNotifier._();

  static const String _key = 'spin_inventory_empty_seen_v2';
  static bool _initialized = false;

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

  /// يُستدعى عند وصول قائمة الجوائز المهيأة (من Stream Firestore).
  /// المخزون الفارغ = جميع الجوائز بلا أي كرت متبقي.
  static Future<void> checkAndNotify({
    required List<SpinPrize> prizes,
    bool onlyIfAvailableWheel = false,
  }) async {
    if (prizes.isEmpty) return;

    final hasCards = prizes.any((p) => p.cardCount > 0);
    final prefs = await SharedPreferences.getInstance();
    final prevEmpty = prefs.getBool(_key);

    if (!hasCards) {
      // المخزون فارغ حالياً: سجّل الحالة ولا حاجة لإشعار الآن
      await prefs.setBool(_key, true);
      return;
    }

    // المخزون متوفر: هل كانت فارغة قبل هذا التحديث بالذات؟
    final transitioned = prevEmpty == true;
    await prefs.setBool(_key, false);

    // لا إشعار عند أول ملاحظة للجهاز (prevEmpty == null) حتى لا يصل
    // إشعار زائف مع كل فتح للتطبيق، ولا إشعار لمن ليس له دوّارة جاهزة.
    if (!transitioned || !onlyIfAvailableWheel) return;

    await _ensureInitialized();
    await flutterLocalNotificationsPlugin.show(
      id: 1500,
      title: 'عجلة الحظ جاهزة',
      body: 'تتوفر الآن كروت جديدة في عجلة الحظ! ادخل وجرّب حظك 🎡',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'inventory_channel',
          'توفر المخزون',
          channelDescription: 'إشعارات عند توفر كروت جديدة في عجلة الحظ',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}