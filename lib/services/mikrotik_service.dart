import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MikrotikService {
  static final MikrotikService _instance = MikrotikService._internal();
  factory MikrotikService() => _instance;
  MikrotikService._internal();

  String? _gatewayIp;

  String? get gatewayIp => _gatewayIp;
  static const String _defaultGateway = '172.16.0.1';

  void setGatewayIp(String ip) {
    _gatewayIp = ip;
  }

  String get _gateway => _gatewayIp ?? _defaultGateway;

  Future<MikrotikLoginResult> login(String voucher) async {
    try {
      try {
        final response = await http
            .post(
              Uri.parse('http://$_gateway/login'),
              body: {'username': voucher, 'password': voucher},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          if (response.body.contains('error') ||
              response.body.contains('failed')) {
            return MikrotikLoginResult(
              success: false,
              message: 'رمز الكرت غير صحيح',
            );
          }
          return MikrotikLoginResult(
            success: true,
            message: 'تم تسجيل الدخول بنجاح',
          );
        }
      } catch (_) {}

      final getUri = Uri.parse(
          'http://$_gateway/login?username=$voucher&password=$voucher');
      final response =
          await http.get(getUri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.contains('error') ||
            response.body.contains('failed')) {
          return MikrotikLoginResult(
            success: false,
            message: 'رمز الكرت غير صحيح',
          );
        }
        return MikrotikLoginResult(
          success: true,
          message: 'تم تسجيل الدخول بنجاح',
        );
      }

      return MikrotikLoginResult(
        success: false,
        message: 'فشل الاتصال بالشبكة',
      );
    } catch (e) {
      return MikrotikLoginResult(
        success: false,
        message: 'خطأ في الاتصال بتأكد من اتصالك بشبكة WiFi',
      );
    }
  }

  Future<int> getRemainingBytes() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_gateway/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = response.body;

        // 1) محاولة تحليل بصيغة JSON (صالح أو بعلامات اقتباس مفردة)
        Map<String, dynamic>? data;
        try {
          final d = jsonDecode(body);
          if (d is Map) data = d.map((k, v) => MapEntry('$k', v));
        } catch (_) {
          var s = body;
          final bs = s.indexOf('{');
          final be = s.lastIndexOf('}');
          if (bs >= 0 && be > bs) s = s.substring(bs, be + 1);
          try {
            final d = jsonDecode(s.replaceAll("'", '"'));
            if (d is Map) data = d.map((k, v) => MapEntry('$k', v));
          } catch (_) {}
        }

        if (data != null) {
          int? asInt(dynamic v) {
            final n = num.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
            return (n != null && n > 0) ? n.round() : null;
          }

          // حقول الرصيد المتبقي المباشر
          for (final k in [
            'bytesLeft', 'bytesleft', 'bytes_left', 'remainingBytes', 'remainBytes',
            'bytesRemain', 'remaining_byte', 'bytes_remaining', 'quota', 'bytesLimit'
          ]) {
            final v = data[k];
            if (v != null) {
              final n = asInt(v);
              if (n != null) return n;
            }
          }

          // حساب المتبقي = الحد - المستخدم
          final inLimit = asInt(data['bytes_in_limit'] ?? data['bytesInLimit'] ?? data['bytesLimitIn']);
          final outLimit = asInt(data['bytes_out_limit'] ?? data['bytesOutLimit'] ?? data['bytesLimitOut']);
          final totalLimit = asInt(data['bytes_limit'] ?? data['bytesLimit'] ?? data['limitBytes']);
          final bytesIn = asInt(data['bytes_in'] ?? data['bytesIn']);
          final bytesOut = asInt(data['bytes_out'] ?? data['bytesOut']);

          final limit = inLimit != null && outLimit != null
              ? inLimit + outLimit
              : totalLimit;
          final used = (bytesIn ?? 0) + (bytesOut ?? 0);
          if (limit != null && limit > 0 && used >= 0) {
            final remaining = limit - used;
            if (remaining >= 0) return remaining;
          }
        }

        // 2) الأنماط النصية القديمة
        final patterns = [
          RegExp(r'remainingBytes\s*=\s*(\d+)'),
          RegExp(r'remainBytes\s*=\s*(\d+)'),
          RegExp(r'bytes-left[^>]*>(\d+)'),
          RegExp(r'(?:بايت|bytes).*?(\d+)'),
        ];
        for (final p in patterns) {
          final match = p.firstMatch(body);
          if (match != null) {
            final val = int.tryParse(match.group(1)!);
            if (val != null && val >= 0) return val;
          }
        }
      }
    } catch (_) {}
    return -1;
  }

  /// يستخرج الرصيد المتبقي (بالبايت) من نص استجابة البوابة/الحالة.
  /// يقبل JSON (صالحاً أو بعلامات اقتباس مفردة) و query string.
  /// يُستخدم في المهمة الخلفية حتى يعمل الإشعار والتطبيق مغلق.
  static int parseRemainingBytes(String body) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      final n = num.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      return (n != null && n > 0) ? n.round() : null;
    }

    Map<String, dynamic>? data;
    try {
      final d = jsonDecode(body);
      if (d is Map) data = d.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      var s = body;
      final bs = s.indexOf('{');
      final be = s.lastIndexOf('}');
      if (bs >= 0 && be > bs) s = s.substring(bs, be + 1);
      try {
        final d = jsonDecode(s.replaceAll("'", '"'));
        if (d is Map) data = d.map((k, v) => MapEntry('$k', v));
      } catch (_) {}
    }

    const remainKeys = [
      'remain_bytes_total', 'remainBytesTotal', 'remainbyt', 'remain_bytes',
      'bytesLeft', 'bytes_remaining', 'remainingBytes', 'remaining_byte',
      'bytesRemain', 'remaining',
    ];

    if (data != null) {
      for (final k in remainKeys) {
        final n = asInt(data[k]);
        if (n != null) return n;
      }

      // الحساب من الحد - المستخدم
      final inLimit = asInt(data['bytes_in_limit'] ?? data['bytesInLimit'] ?? data['bytesLimitIn']);
      final outLimit = asInt(data['bytes_out_limit'] ?? data['bytesOutLimit'] ?? data['bytesLimitOut']);
      final totalLimit = asInt(data['bytes_limit'] ?? data['bytesLimit'] ?? data['limitBytes'] ?? data['limitbytes']);
      final bytesIn = asInt(data['bytes_in'] ?? data['bytesIn']);
      final bytesOut = asInt(data['bytes_out'] ?? data['bytesOut']);
      final limit = inLimit != null && outLimit != null ? inLimit + outLimit : totalLimit;
      final used = (bytesIn ?? 0) + (bytesOut ?? 0);
      if (limit != null && limit > 0 && used >= 0) {
        final remaining = limit - used;
        if (remaining >= 0) return remaining;
      }
    }

    // Query string
    try {
      final qs = Uri.splitQueryString(body);
      int? fromQs(String key) {
        final v = qs[key];
        if (v == null) return null;
        final n = int.tryParse(v);
        return (n != null && n > 0) ? n : null;
      }
      for (final k in remainKeys) {
        final n = fromQs(k);
        if (n != null) return n;
      }
    } catch (_) {}

    return -1;
  }

  /// محاولة قراءة عنوان MAC الخاص بالعميل من صفحة حالة الميكروتيك
  /// (بعض إصدارات الـ Hotspot تُرجع حقل mac في الاستجابة).
  Future<String?> getClientMac() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$_gateway/status?var=callBack'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      // محاولة كـ JSON
      try {
        final d = jsonDecode(response.body);
        if (d is Map) {
          final mac = d['mac'] ?? d['Mac'] ?? d['MAC'];
          if (mac is String && mac.isNotEmpty) return mac;
        }
      } catch (_) {}

      // محاولة كـ query string / HTML
      final macMatch =
          RegExp(r'[?&]mac=([0-9A-Fa-f]{2}[:.-][0-9A-Fa-f:.-]+)').firstMatch(response.body);
      if (macMatch != null) return macMatch.group(1);
    } catch (_) {}
    return null;
  }

  /// قراءة إجمالي حجم الكرت الفعلي (بالبايت) من بوابة تسجيل الدخول/الحالة.
  /// يُستخدم لتحديد فئة الكرت بدقة: أكبر من 1 جيجا = كبيرة، 1 جيجا أو أقل = صغيرة.
  Future<int> getVoucherLimitBytes() async {
    try {
      final uri = Uri.parse('http://$_gateway/status?var=callBack');
      String body = '';
      try {
        final resp = await http
            .get(uri, headers: {'Cache-Control': 'no-cache'})
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) body = resp.body;
      } catch (_) {}
      if (body.isEmpty) {
        try {
          final resp = await http
              .get(Uri.parse('http://$_gateway/status'))
              .timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) body = resp.body;
        } catch (_) {}
      }

      if (body.isEmpty) return -1;

      // تشخيص: طباعة استجابة الرادار الخام لمعرفة الحقول الفعلية للكرت
      debugPrint('[MKT][DIAG] callBack body (first 600): ${body.length > 600 ? body.substring(0, 600) : body}');

      // محاولة قراءة JSON
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          int? tryGet(List<String> keys) {
            for (final k in keys) {
              final v = data[k];
              if (v != null) {
                final n = num.tryParse(v.toString());
                if (n != null && n > 0) return n.toInt();
              }
            }
            return null;
          }
          final limitBytes = tryGet([
            'limitBytes', 'byteslimitdown', 'bytes_limit', 'limitbytes',
            'bytesLimitDown', 'bytes_limit_down', 'quota', 'bytesLeft'
          ]);
          if (limitBytes != null) return limitBytes;

          // الميكروتيك الكلاسيكي: remain_bytes_total (الباقي) + bytes_in + bytes_out = الحجم الأصلي للكرت
          final remainTotal = tryGet(['remain_bytes_total', 'remainBytesTotal', 'remainbyt', 'remain_bytes']);
          if (remainTotal != null) {
            final usedIn = tryGet(['bytes_in', 'bytesIn']);
            final usedOut = tryGet(['bytes_out', 'bytesOut']);
            final originalLimit = remainTotal + (usedIn ?? 0) + (usedOut ?? 0);
            debugPrint('[MKT][DIAG] remain=$remainTotal usedIn=${usedIn ?? 0} usedOut=${usedOut ?? 0} original=$originalLimit');
            if (originalLimit > 0) return originalLimit;
          }

          // بعض الأنظمة تُرجع القيمة بالميجابايت
          final limitMB = tryGet([
            'limitMB', 'limit_mb', 'mbLimit', 'limitMb', 'maxMB', 'quotamb'
          ]);
          if (limitMB != null) return limitMB * 1024 * 1024;

          // حقول الميكروتيك الفعلية: الحد الصافي + الحد السفلي (المجموع = الحد الكلي)
          final inLimit = tryGet(['bytes_in_limit', 'bytesInLimit', 'limit_up']);
          final outLimit = tryGet(['bytes_out_limit', 'bytesOutLimit', 'limit_down']);
          if (inLimit != null && outLimit != null) return inLimit + outLimit;
          if (inLimit != null) return inLimit;
          if (outLimit != null) return outLimit;
        } catch (_) {}

        // محاولة قراءة من HTML/query string
        final qs = Uri.splitQueryString(body);
        if (qs.isNotEmpty) {
          int? fromQs(String key) {
            final v = qs[key];
            if (v != null) {
              final n = int.tryParse(v);
              if (n != null && n > 0) return n;
            }
            return null;
          }
          final lb = fromQs('limitBytes') ?? fromQs('byteslimitdown') ??
              fromQs('maxBytes') ?? fromQs('quota');
          if (lb != null) return lb;

          // حقول الميكروتيك الفعلية من query string
          final inLim = fromQs('bytes_in_limit') ?? fromQs('limit_up');
          final outLim = fromQs('bytes_out_limit') ?? fromQs('limit_down');
          if (inLim != null && outLim != null) return inLim + outLim;
          if (inLim != null) return inLim;
          if (outLim != null) return outLim;
        }
    } catch (_) {}
    return -1;
  }

  /// تحديد فئة الكرت بناءً على إجمالي الميجا الفعلية.
  /// - 300 ميجا أو أقل → 'none' (لا يُحتسب في عجلة الحظ)
  /// - 600 ميجا / 1 جيجا → 'small'
  /// - 1500 ميجا / 3ج / 7ج / 10ج → 'large'
  Future<String?> determineVoucherCategory({String? fallbackSpeed}) async {
    final limitBytes = await getVoucherLimitBytes();
    if (limitBytes > 0) {
      final totalMB = limitBytes / (1024 * 1024);
      debugPrint('[MKT][DIAG] limitBytes=$limitBytes (${totalMB.toStringAsFixed(2)} MB)');
      if (totalMB < 450) return 'none';
      if (totalMB <= 1150) return 'small';
      return 'large';
    }
    // الاحتياط: التصنيف من حقل السرعة إن توفر
    if (fallbackSpeed != null) {
      debugPrint('[MKT][DIAG] fallback to speed: "$fallbackSpeed"');
      if (fallbackSpeed.contains('economic') || fallbackSpeed.contains('normal')) {
        return 'small';
      } else if (fallbackSpeed.contains('middle') || fallbackSpeed.contains('high') ||
          fallbackSpeed.contains('very')) {
        return 'large';
      }
    }
    return null;
  }

  Future<double> measureSpeed() async {
    double best = 0;
    for (int i = 0; i < 3; i++) {
      try {
        final sw = Stopwatch()..start();
        final response = await http
            .get(Uri.parse('http://$_gateway/'))
            .timeout(const Duration(seconds: 4));
        sw.stop();
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        final bytes = response.bodyBytes.length;
        if (elapsed > 0 && bytes > 0) {
          final mbps = (bytes * 8) / (elapsed * 1_000_000);
          if (mbps > best) best = mbps;
        }
      } catch (_) {}
    }
    return best;
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      await http
          .get(Uri.parse('http://$_gateway/logout'))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// فحص حالة تسجيل الدخول من الميكروتيك
  /// يرجع (isLoggedIn, username, speed) أو (false, '', '')
  /// فحص حالة تسجيل الدخول من الميكروتيك
  /// يرجع (isLoggedIn, username, speed) أو (false, '', '')
  Future<(bool, String, String)> checkLoginStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$_gateway/status?var=callBack'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final loggedIn = _loggedInValue(data['logged_in']);
          final username = data['username']?.toString() ?? '';
          final speed = data['sps']?.toString() ?? '';
          if (loggedIn) {
            return (true, username, speed);
          }
        } catch (_) {
          // بعض الإصدارات ترجع بصيغة JSON بعلامات اقتباس مفردة
          var jsonStr = response.body;
          final bs = jsonStr.indexOf('{');
          final be = jsonStr.lastIndexOf('}');
          if (bs >= 0 && be > bs) {
            jsonStr = jsonStr.substring(bs, be + 1);
          }
          try {
            final fixed = jsonStr.replaceAll("'", '"');
            final data = jsonDecode(fixed) as Map<String, dynamic>;
            final loggedIn = _loggedInValue(data['logged_in']);
            final username = data['username']?.toString() ?? '';
            final speed = data['sps']?.toString() ?? '';
            if (loggedIn) {
              return (true, username, speed);
            }
          } catch (_) {
            // بعض الإصدارات ترجع بصيغة query string
            final params = Uri.splitQueryString(response.body);
            if (params['logged_in'] == '1' ||
                params['logged_in'] == 'yes') {
              return (true, params['username'] ?? '', params['sps'] ?? '');
            }
          }
        }
      }
    } catch (_) {}
    return (false, '', '');
  }

  /// يعود true إذا كانت قيمة logged_in تدل على نجاح تسجيل الدخول
  bool _loggedInValue(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    return s == 'yes' || s == '1' || s == 'true' || s == 'on';
  }
}

class MikrotikLoginResult {
  final bool success;
  final String message;

  MikrotikLoginResult({required this.success, required this.message});
}
