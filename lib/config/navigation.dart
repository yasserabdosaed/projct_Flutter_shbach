import 'package:flutter/material.dart';

/// مفتاح الملاحّة العام للتطبيق - يُستخدم لفتح شاشة الرسائل
/// عند الضغط على إشعار نظام (Push Notification).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();