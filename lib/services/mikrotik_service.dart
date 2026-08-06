import 'dart:convert';
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
          final loggedIn = data['logged_in'];
          final username = data['username']?.toString() ?? '';
          final speed = data['sps']?.toString() ?? '';
          if (loggedIn == '1' || loggedIn == true) {
            return (true, username, speed);
          }
        } catch (_) {
          // بعض الإصدارات ترجع بصيغة query string
          final params = Uri.splitQueryString(response.body);
          if (params['logged_in'] == '1') {
            return (true, params['username'] ?? '', params['sps'] ?? '');
          }
        }
      }
    } catch (_) {}
    return (false, '', '');
  }
}

class MikrotikLoginResult {
  final bool success;
  final String message;

  MikrotikLoginResult({required this.success, required this.message});
}
