import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../config/constants.dart';
import 'balance_notifier.dart';
import 'mikrotik_service.dart';

const String periodicTaskName = 'checkLoginTask';
const String periodicTaskTag = 'spinWheelCheck';

@pragma('vm:entry-point')
void spinWheelBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final gatewayIp = prefs.getString(AppConstants.keyGatewayIp) ?? '172.16.0.1';

      final response = await http
          .get(
            Uri.parse('http://$gatewayIp/status?var=callBack'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return true;

      // التنظيف الأسبوعي للكروت المخزّنة على الجهاز حتى لا تكبر ذاكرة الهاتف
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastClean = prefs.getInt('weekly_cleanup_time');
      if (lastClean != null &&
          nowMs - lastClean >= 7 * 24 * 60 * 60 * 1000) {
        await prefs.remove(AppConstants.keyProcessedVouchers);
        await prefs.remove(AppConstants.keySpinSmallVouchers);
        await prefs.remove(AppConstants.keySpinLargeVouchers);
        await prefs.remove(AppConstants.keySpinSmallCounter);
        await prefs.remove(AppConstants.keySpinLargeCounter);
        await prefs.setBool(AppConstants.keySpinSmallAvailable, false);
        await prefs.setBool(AppConstants.keySpinLargeAvailable, false);
      } else if (lastClean == null) {
        await prefs.setInt('weekly_cleanup_time', nowMs);
      }

      String username = '';
      String speed = '';
      bool isLoggedIn = false;

      // محلّل مرن يدعم: JSON صالح / JSON بعلامات اقتباس مفردة / query string
      // ويكشف تسجيل الدخول بأي قيمة: 'yes' / '1' / true
      bool checkIn(dynamic v) {
        if (v == null) return false;
        if (v is bool) return v;
        final s = v.toString().toLowerCase().trim();
        return s == 'yes' || s == '1' || s == 'true' || s == 'on';
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        isLoggedIn = checkIn(data['logged_in']);
        username = data['username']?.toString() ?? '';
        speed = data['sps']?.toString() ?? '';
      } catch (_) {
        String jsonStr = response.body;
        final bs = jsonStr.indexOf('{');
        final be = jsonStr.lastIndexOf('}');
        if (bs >= 0 && be > bs) {
          jsonStr = jsonStr.substring(bs, be + 1);
        }
        try {
          final fixed = jsonStr.replaceAll("'", '"');
          final data = jsonDecode(fixed) as Map<String, dynamic>;
          isLoggedIn = checkIn(data['logged_in']);
          username = data['username']?.toString() ?? '';
          speed = data['sps']?.toString() ?? '';
        } catch (_) {
          final params = Uri.splitQueryString(response.body);
          isLoggedIn = checkIn(params['logged_in']);
          username = params['username'] ?? '';
          speed = params['sps'] ?? '';
        }
      }

      if (!isLoggedIn || username.isEmpty) return true;

      // إشعارات انخفاض الرصيد حسب العتبات (100/70/50/30/5 ميجا)
      // تعمل حتى لو كان التطبيق مغلقاً أو في الخلفية
      try {
        final remain = MikrotikService.parseRemainingBytes(response.body);
        if (remain > 0) {
          await BalanceNotifier.checkAndNotify(
            voucher: username,
            remainingBytes: remain,
          );
        }
      } catch (_) {}

      final processedRaw = prefs.getString(AppConstants.keyProcessedVouchers);
      final processed = processedRaw != null
          ? Set<String>.from(jsonDecode(processedRaw) as List)
          : <String>{};

      if (processed.contains(username)) return true;

      String category;
      // تحديد دقيق من إجمالي ميجا الكرت الفعلي (300='none'، 600/1ج='small'، 1.5ج فأكثر='large')
      try {
        final mikrotik = MikrotikService()..setGatewayIp(gatewayIp);
        final cat = await mikrotik.determineVoucherCategory(fallbackSpeed: speed);
        // إن لم نستطع تحديد الفئة (null) أو كانت 'none' لا نحتسب أي نقطة إطلاقاً
        if (cat == 'none' || cat == null) {
          debugPrint('[SPIN][DEBUG] background: not counted (none/undetermined): $username cat=$cat');
          return true;
        }
        category = cat;
      } catch (_) {
        debugPrint('[SPIN][DEBUG] background: detection failed, not counting: $username');
        return true;
      }

      processed.add(username);
      await prefs.setString(AppConstants.keyProcessedVouchers, jsonEncode(processed.toList()));

      if (category == 'small') {
        final raw = prefs.getString(AppConstants.keySpinSmallVouchers);
        final list = raw != null
            ? List<String>.from(jsonDecode(raw) as List)
            : <String>[];
        list.add(username);
        await prefs.setString(AppConstants.keySpinSmallVouchers, jsonEncode(list));

        final counter = prefs.getInt(AppConstants.keySpinSmallCounter) ?? 0;
        await prefs.setInt(AppConstants.keySpinSmallCounter, counter + 1);
        if (counter + 1 >= 5) {
          await prefs.setBool(AppConstants.keySpinSmallAvailable, true);
        }
      } else {
        final raw = prefs.getString(AppConstants.keySpinLargeVouchers);
        final list = raw != null
            ? List<String>.from(jsonDecode(raw) as List)
            : <String>[];
        list.add(username);
        await prefs.setString(AppConstants.keySpinLargeVouchers, jsonEncode(list));

        final counter = prefs.getInt(AppConstants.keySpinLargeCounter) ?? 0;
        await prefs.setInt(AppConstants.keySpinLargeCounter, counter + 1);
        if (counter + 1 >= 5) {
          await prefs.setBool(AppConstants.keySpinLargeAvailable, true);
        }
      }

      await prefs.setString(AppConstants.keyUserVoucher, username);
      await prefs.setString(AppConstants.keySessionStart,
          DateTime.now().toIso8601String());
      await prefs.setString(AppConstants.keyGatewayIp, gatewayIp);
    } catch (_) {}

    return true;
  });
}

void registerBackgroundTask() {
  Workmanager().registerPeriodicTask(
    periodicTaskTag,
    periodicTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
