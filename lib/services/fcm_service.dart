import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// إرسال إشعارات Firebase Cloud Messaging عبر HTTP v1
///
/// بديل OneSignal: يوقّع الـ JWT بحساب الخدمة (fcm-sender.json) للحصول على
/// OAuth2 access token ثم يرسل عبر معرّف المشروع مباشرة (بدون سيرفر خارجي).
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String _assetPath = 'assets/firebase/fcm-sender.json';
  static const String _scope = 'https://www.googleapis.com/auth/firebase.messaging';
  static const String _tokenUri = 'https://oauth2.googleapis.com/token';
  static const String _fcmSendUri = 'https://fcm.googleapis.com/v1/projects/shabakat-app/messages:send';

  Map<String, dynamic>? _creds;
  String? _token;
  DateTime? _tokenExpiry;

  /// قراءة ملف حساب الخدمة من الأصول (مرة واحدة).
  Future<void> _ensureCreds() async {
    if (_creds != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    _creds = jsonDecode(raw) as Map<String, dynamic>;
  }

  /// الحصول على access token جديد أو استخدام المخزّن غير منتهي الصلاحية.
  Future<String> _getAccessToken() async {
    await _ensureCreds();
    if (_token != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 2)))) {
      return _token!;
    }

    final now = DateTime.now().toUtc();
    final jwt = JWT({
      'iss': _creds!['client_email'],
      'scope': _scope,
      'aud': _tokenUri,
    });

    final privateKey = RSAPrivateKey(_creds!['private_key'] as String);
    final signed = jwt.sign(
      privateKey,
      algorithm: JWTAlgorithm.RS256,
      expiresIn: const Duration(hours: 1),
    );

    final response = await http.post(
      Uri.parse(_tokenUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': signed,
      },
    );

    if (response.statusCode >= 400) {
      final body = response.body;
      debugPrint('[FCM/v1] OAuth failed ${response.statusCode}: $body');
      throw Exception('OAuth failed ${response.statusCode}: $body');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    _tokenExpiry = now.add(Duration(seconds: expiresIn));
    debugPrint('[FCM/v1] token OK (expires in ${expiresIn}s)');
    return _token!;
  }

  /// إرسال إشعار إلى موضوع (topic). الافتراضي 'all' لجميع المستخدمين.
  Future<void> send({
    required String title,
    required String body,
    String topic = 'all',
    String dataType = 'admin_message',
  }) async {
    try {
      final token = await _getAccessToken();
      final response = await http.post(
        Uri.parse(_fcmSendUri),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'message': {
            'topic': topic,
            'notification': {'title': title, 'body': body},
            'data': {
              'type': dataType,
              'title': title,
              'body': body,
            },
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 400) {
        debugPrint('[FCM/v1] send failed: ${response.statusCode} ${response.body}');
      } else {
        debugPrint('[FCM/v1] send OK (${response.statusCode}, topic=$topic)');
      }
    } catch (e) {
      debugPrint('[FCM/v1] send error: $e');
    }
  }
}