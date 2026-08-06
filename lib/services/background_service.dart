import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../config/constants.dart';

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

      String username = '';
      String speed = '';
      bool isLoggedIn = false;

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        isLoggedIn = data['logged_in'] == '1' || data['logged_in'] == true;
        username = data['username']?.toString() ?? '';
        speed = data['sps']?.toString() ?? '';
      } catch (_) {
        final params = Uri.splitQueryString(response.body);
        isLoggedIn = params['logged_in'] == '1';
        username = params['username'] ?? '';
        speed = params['sps'] ?? '';
      }

      if (!isLoggedIn || username.isEmpty) return true;

      final processedRaw = prefs.getString(AppConstants.keyProcessedVouchers);
      final processed = processedRaw != null
          ? Set<String>.from(jsonDecode(processedRaw) as List)
          : <String>{};

      if (processed.contains(username)) return true;

      String category;
      if (speed.contains('economic') || speed.contains('normal')) {
        category = 'small';
      } else if (speed.contains('middle') || speed.contains('high') ||
          speed.contains('very')) {
        category = 'large';
      } else {
        category = 'small';
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
