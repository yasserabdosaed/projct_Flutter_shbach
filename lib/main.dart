import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'providers/app_provider.dart';
import 'services/background_service.dart';
import 'services/notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // الخط مضمّن محلياً في الأصول - منع أي تحميل من الإنترنت عند التشغيل
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Google Fonts'], license);
  });

  final appProvider = AppProvider();

  // منع أي خطأ غير متوقع من إغلاق التطبيق نهائياً
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  // ===== تشغيل الواجهة فوراً (لا شيء يمنع ظهور أول شاشة) =====
  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const ShabakatApp(),
    ),
  );

  // ===== كل التهيئة تجري في الخلفية بمهلة قصوى - لا تُعيق إقلاع التطبيق =====
  unawaited(_initBackgroundServices());
  unawaited(_initAppData(appProvider));
}

Future<void> _initBackgroundServices() async {
  try {
    await Workmanager()
        .initialize(spinWheelBackgroundCallback)
        .timeout(const Duration(seconds: 5));
    registerBackgroundTask();
  } catch (_) {
    // المهمة الخلفية غير متوفرة على هذا الجهاز/البيئة
  }

  try {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await flutterLocalNotificationsPlugin
        .initialize(settings: initSettings)
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // الإشعارات غير متوفرة على هذا الجهاز
  }

  // طلب صلاحية إشعارات النظام على أندرويد 13+ (ضروري لعرض الـ Push)
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (_) {}
}

Future<void> _initAppData(AppProvider appProvider) async {
  // تهيئة البيانات - أخطاء التهيئة لن تمنع فتح التطبيق
  try {
    await appProvider.init();
  } catch (_) {}
}
