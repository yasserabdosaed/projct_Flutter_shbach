import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'providers/app_provider.dart';
import 'services/background_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة المهمة الخلفية - إذا فشلت (مثلاً في بيئة التطوير) يكمل التطبيق بشكل طبيعي
  try {
    await Workmanager().initialize(spinWheelBackgroundCallback);
    registerBackgroundTask();
  } catch (_) {
    // المهمة الخلفية غير متوفرة على هذا الجهاز/البيئة
  }

  // تهيئة الإشعارات المحلية
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

  final appProvider = AppProvider();

  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const ShabakatApp(),
    ),
  );

  appProvider.init();
}