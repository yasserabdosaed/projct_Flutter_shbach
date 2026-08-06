import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/admin_message.dart';
import '../models/spin_prize.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ===== الجلسة =====
  Future<void> saveSession(String voucher, String gatewayIp) async {
    await _prefs!.setString(AppConstants.keyUserVoucher, voucher);
    await _prefs!.setString(AppConstants.keySessionStart,
        DateTime.now().toIso8601String());
    await _prefs!.setString(AppConstants.keyGatewayIp, gatewayIp);
  }

  String? get voucher => _prefs!.getString(AppConstants.keyUserVoucher);
  DateTime? get sessionStart {
    final s = _prefs!.getString(AppConstants.keySessionStart);
    return s != null ? DateTime.parse(s) : null;
  }

  bool get hasActiveSession {
    final v = voucher;
    final start = sessionStart;
    if (v == null || start == null) return false;
    return true;
  }

  Future<void> clearSession() async {
    await _prefs!.remove(AppConstants.keyUserVoucher);
    await _prefs!.remove(AppConstants.keySessionStart);
    await _prefs!.remove(AppConstants.keyGatewayIp);
  }

  // ===== الروابط =====
  String get loginUrl =>
      _prefs!.getString(AppConstants.keyLoginUrl) ?? AppConstants.defaultLoginUrl;
  Future<void> saveLoginUrl(String url) async {
    await _prefs!.setString(AppConstants.keyLoginUrl, url);
  }

  String get liveUrl =>
      _prefs!.getString(AppConstants.keyLiveUrl) ?? AppConstants.defaultLiveUrl;
  Future<void> saveLiveUrl(String url) async {
    await _prefs!.setString(AppConstants.keyLiveUrl, url);
  }

  String get restUrl =>
      _prefs!.getString(AppConstants.keyRestUrl) ?? AppConstants.defaultRestUrl;
  Future<void> saveRestUrl(String url) async {
    await _prefs!.setString(AppConstants.keyRestUrl, url);
  }

  // ===== FCM =====
  Future<void> saveFcmToken(String token) async {
    await _prefs!.setString(AppConstants.keyFcmToken, token);
  }
  String? get fcmToken => _prefs!.getString(AppConstants.keyFcmToken);

  // ===== الرسائل المخزنة محلياً =====
  Future<void> saveLocalMessages(List<AdminMessage> messages) async {
    final json = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs!.setString('cached_messages', json);
  }

  List<AdminMessage> getLocalMessages() {
    final json = _prefs!.getString('cached_messages');
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => AdminMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ===== حالة تسجيل الدخول الإداري =====
  Future<void> setAdminLoggedIn(bool value) async {
    await _prefs!.setBool(AppConstants.keyAdminLoggedIn, value);
  }
  bool get isAdminLoggedIn =>
      _prefs!.getBool(AppConstants.keyAdminLoggedIn) ?? false;

  Future<void> setSuperAdminLoggedIn(bool value) async {
    await _prefs!.setBool(AppConstants.keySuperAdminLoggedIn, value);
  }
  bool get isSuperAdminLoggedIn =>
      _prefs!.getBool(AppConstants.keySuperAdminLoggedIn) ?? false;

  // ===== كلمات المرور الإدارية =====
  String get adminPassword =>
      _prefs!.getString(AppConstants.keyAdminPassword) ?? AppConstants.adminSecretKey;
  Future<void> saveAdminPassword(String value) async {
    await _prefs!.setString(AppConstants.keyAdminPassword, value);
  }

  String get superAdminPassword =>
      _prefs!.getString(AppConstants.keySuperAdminPassword) ?? AppConstants.superAdminSecretKey;
  Future<void> saveSuperAdminPassword(String value) async {
    await _prefs!.setString(AppConstants.keySuperAdminPassword, value);
  }

  // ===== الشعار =====
  String? get logoPath => _prefs!.getString(AppConstants.keyLogoPath);
  Future<void> saveLogoPath(String path) async {
    await _prefs!.setString(AppConstants.keyLogoPath, path);
  }

  // ===== معلومات التواصل =====
  String get whatsapp =>
      _prefs!.getString(AppConstants.keyWhatsapp) ?? AppConstants.whatsappNumber;
  Future<void> saveWhatsapp(String value) async {
    await _prefs!.setString(AppConstants.keyWhatsapp, value);
  }

  String get telegram =>
      _prefs!.getString(AppConstants.keyTelegram) ?? AppConstants.telegramGroupUrl;
  Future<void> saveTelegram(String value) async {
    await _prefs!.setString(AppConstants.keyTelegram, value);
  }

  String get phone =>
      _prefs!.getString(AppConstants.keyPhone) ?? AppConstants.whatsappNumber;
  Future<void> savePhone(String value) async {
    await _prefs!.setString(AppConstants.keyPhone, value);
  }

  String get whatsappGroup =>
      _prefs!.getString(AppConstants.keyWhatsappGroup) ?? AppConstants.whatsappGroupUrl;
  Future<void> saveWhatsappGroup(String value) async {
    await _prefs!.setString(AppConstants.keyWhatsappGroup, value);
  }

  // ===== مفتاح FCM =====
  String get fcmServerKey =>
      _prefs!.getString(AppConstants.keyFcmServerKey) ?? AppConstants.defaultFcmServerKey;
  Future<void> saveFcmServerKey(String value) async {
    await _prefs!.setString(AppConstants.keyFcmServerKey, value);
  }

  // =============================================================
  // ===== دوال عجلة الحظ =====
  // =============================================================

  // عدّاد الدوارة الصغيرة
  Future<int> getSmallSpinCounter() async {
    return _prefs?.getInt(AppConstants.keySpinSmallCounter) ?? 0;
  }
  Future<void> saveSmallSpinCounter(int value) async {
    await _prefs?.setInt(AppConstants.keySpinSmallCounter, value);
  }

  // عدّاد الدوارة الكبيرة
  Future<int> getLargeSpinCounter() async {
    return _prefs?.getInt(AppConstants.keySpinLargeCounter) ?? 0;
  }
  Future<void> saveLargeSpinCounter(int value) async {
    await _prefs?.setInt(AppConstants.keySpinLargeCounter, value);
  }

  // حالة الدوارة الصغيرة
  Future<bool> getSmallSpinAvailable() async {
    return _prefs?.getBool(AppConstants.keySpinSmallAvailable) ?? false;
  }
  Future<void> saveSmallSpinAvailable(bool value) async {
    await _prefs?.setBool(AppConstants.keySpinSmallAvailable, value);
  }

  // حالة الدوارة الكبيرة
  Future<bool> getLargeSpinAvailable() async {
    return _prefs?.getBool(AppConstants.keySpinLargeAvailable) ?? false;
  }
  Future<void> saveLargeSpinAvailable(bool value) async {
    await _prefs?.setBool(AppConstants.keySpinLargeAvailable, value);
  }

  Future<String?> getSpinCategory() async {
    return _prefs?.getString(AppConstants.keySpinCategory);
  }
  Future<void> saveSpinCategory(String value) async {
    await _prefs?.setString(AppConstants.keySpinCategory, value);
  }

  Future<List<SpinPrize>> getSpinPrizes() async {
    final json = _prefs?.getString(AppConstants.keySpinPrizes);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => SpinPrize.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<void> saveSpinPrizes(List<SpinPrize> prizes) async {
    final json = jsonEncode(prizes.map((p) => p.toJson()).toList());
    await _prefs?.setString(AppConstants.keySpinPrizes, json);
  }

  // ===== دوال تتبع الكروت المُعالَجة (لمنع التكرار) =====
  Future<Set<String>> getProcessedVouchers() async {
    final json = _prefs?.getString(AppConstants.keyProcessedVouchers);
    if (json == null) return {};
    return Set<String>.from(jsonDecode(json));
  }
  Future<void> saveProcessedVoucher(String voucher) async {
    final set = await getProcessedVouchers();
    set.add(voucher);
    await _prefs?.setString(AppConstants.keyProcessedVouchers, jsonEncode(set.toList()));
  }
  Future<bool> isVoucherProcessed(String voucher) async {
    final set = await getProcessedVouchers();
    return set.contains(voucher);
  }

  // ===== دوال تتبع الكروت =====
  Future<String?> getLastCheckedVoucher() async {
    return _prefs?.getString('last_checked_voucher');
  }
  Future<void> saveLastCheckedVoucher(String voucher) async {
    await _prefs?.setString('last_checked_voucher', voucher);
  }

  // دوال الكروت الصغيرة
  Future<List<String>> getSmallVouchers() async {
    final json = _prefs?.getString(AppConstants.keySpinSmallVouchers);
    if (json == null) return [];
    return List<String>.from(jsonDecode(json));
  }
  Future<void> saveSmallVouchers(List<String> vouchers) async {
    final json = jsonEncode(vouchers);
    await _prefs?.setString(AppConstants.keySpinSmallVouchers, json);
  }
  Future<void> addSmallVoucher(String voucher) async {
    final list = await getSmallVouchers();
    if (!list.contains(voucher)) {
      list.add(voucher);
      await saveSmallVouchers(list);
    }
  }
  Future<int> smallVoucherCount() async {
    return (await getSmallVouchers()).length;
  }

  // دوال الكروت الكبيرة
  Future<List<String>> getLargeVouchers() async {
    final json = _prefs?.getString(AppConstants.keySpinLargeVouchers);
    if (json == null) return [];
    return List<String>.from(jsonDecode(json));
  }
  Future<void> saveLargeVouchers(List<String> vouchers) async {
    final json = jsonEncode(vouchers);
    await _prefs?.setString(AppConstants.keySpinLargeVouchers, json);
  }
  Future<void> addLargeVoucher(String voucher) async {
    final list = await getLargeVouchers();
    if (!list.contains(voucher)) {
      list.add(voucher);
      await saveLargeVouchers(list);
    }
  }
  Future<int> largeVoucherCount() async {
    return (await getLargeVouchers()).length;
  }

  // إعادة تعيين بيانات العجلة
  Future<void> resetSpinData(String type) async {
    if (type == 'small') {
      await _prefs?.remove(AppConstants.keySpinSmallVouchers);
      await _prefs?.remove(AppConstants.keySpinSmallCounter);
      await _prefs?.setBool(AppConstants.keySpinSmallAvailable, false);
    } else if (type == 'large') {
      await _prefs?.remove(AppConstants.keySpinLargeVouchers);
      await _prefs?.remove(AppConstants.keySpinLargeCounter);
      await _prefs?.setBool(AppConstants.keySpinLargeAvailable, false);
    }
  }

  // صرف جائزة
  Future<void> claimVoucher(String type, String voucher) async {
    if (type == 'small') {
      final list = await getSmallVouchers();
      list.remove(voucher);
      await saveSmallVouchers(list);
      final count = await getSmallSpinCounter();
      await saveSmallSpinCounter((count - 1).clamp(0, 999));
    } else if (type == 'large') {
      final list = await getLargeVouchers();
      list.remove(voucher);
      await saveLargeVouchers(list);
      final count = await getLargeSpinCounter();
      await saveLargeSpinCounter((count - 1).clamp(0, 999));
    }
  }
}