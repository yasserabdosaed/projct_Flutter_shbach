import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';
import '../models/admin_message.dart';
import '../models/suggestion.dart';
import '../models/review.dart';
import '../models/spin_prize.dart';
import '../services/firebase_service.dart';
import '../services/mikrotik_service.dart';
import '../services/storage_service.dart';
import '../main.dart';

class AppProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final StorageService _storage = StorageService();
  final MikrotikService _mikrotik = MikrotikService();

  bool _firebaseReady = false;
  bool _localReady = false;
  bool _isConnected = false;
  String? _voucher;
  String _loginUrl = '';
  String _liveUrl = '';
  String _restUrl = '';

  List<AdminMessage> _messages = [];
  List<Suggestion> _suggestions = [];
  List<Review> _reviews = [];

  bool _isSuperAdmin = false;
  String? _logoPath;

  // Balance monitoring
  int _remainingBalance = -1;
  bool _lowBalanceShown = false;
  DateTime? _lastLowBalanceNotificationTime;
  static const int _lowBalanceThreshold = 100 * 1024 * 1024; // 100 MB
  static const Duration _notificationCooldown = Duration(hours: 2);

  Timer? _monitorTimer;
  double _currentSpeed = 0;
  int _pingMs = 0;

  // ===== عجلة الحظ (دوّارتان منفصلتان) =====
  int _spinSmallCounter = 0;
  int _spinLargeCounter = 0;
  bool _spinSmallAvailable = false;
  bool _spinLargeAvailable = false;
  String _spinCategory = 'small';
  List<SpinPrize> _spinPrizes = [];
  final Set<String> _processingVouchers = {}; // لمنازعة التزامن

  // Getters
  bool get isReady => _localReady;
  bool get isConnected => _isConnected;
  String? get voucher => _voucher;
  String get loginUrl => _loginUrl;
  String get liveUrl => _liveUrl;
  String get restUrl => _restUrl;
  List<AdminMessage> get messages => _messages;
  List<Suggestion> get suggestions => _suggestions;
  List<Review> get reviews => _reviews;
  int get unreadCount => _messages.where((m) => !m.read).length;
  bool get isSuperAdmin => _isSuperAdmin;
  void setSuperAdmin(bool v) { _isSuperAdmin = v; notifyListeners(); }

  int get remainingBalance => _remainingBalance;
  bool get isLowBalance => _remainingBalance > 0 && _remainingBalance < _lowBalanceThreshold;
  bool get lowBalanceShown => _lowBalanceShown;
  double get currentSpeed => _currentSpeed;
  int get pingMs => _pingMs;
  bool get isMonitoring => _monitorTimer != null;
  int get remainingMB => _remainingBalance > 0 ? _remainingBalance ~/ (1024 * 1024) : 0;

  // Spin Wheel getters (دوّارتان)
  int get spinSmallCounter => _spinSmallCounter;
  int get spinLargeCounter => _spinLargeCounter;
  bool get spinSmallAvailable => _spinSmallAvailable;
  bool get spinLargeAvailable => _spinLargeAvailable;
  String get spinCategory => _spinCategory;
  List<SpinPrize> get spinPrizes => _spinPrizes;
  // التوافق مع الكود القديم
  int get spinCounter => _spinSmallCounter;
  bool get spinAvailable => _spinSmallAvailable;

  void resetLowBalanceWarning() => _lowBalanceShown = true;

  // Contact info
  String get whatsapp => _storage.whatsapp;
  String get telegram => _storage.telegram;
  String get phone => _storage.phone;
  String get whatsappGroup => _storage.whatsappGroup;
  String? get logoPath => _logoPath;
  String? get gatewayIp => _mikrotik.gatewayIp;

  // ===== دوال عجلة الحظ =====
  Future<void> loadSpinData() async {
    _spinSmallCounter = await _storage.getSmallSpinCounter();
    _spinLargeCounter = await _storage.getLargeSpinCounter();
    _spinSmallAvailable = await _storage.getSmallSpinAvailable();
    _spinLargeAvailable = await _storage.getLargeSpinAvailable();
    _spinCategory = await _storage.getSpinCategory() ?? 'small';
    _spinPrizes = await _storage.getSpinPrizes();
    notifyListeners();

    // مزامنة من Firebase (كل مستخدم له عداده الخاص)
    if (_voucher != null && _voucher!.isNotEmpty) {
      await _loadSpinDataFromFirebase(_voucher!);
      // بعد المزج، نرفع البيانات المحلية إلى Firebase
      // (لضمان أن النقاط من المهمة الخلفية لا تضيع)
      if (_firebaseReady) {
        await _syncSpinDataToFirebase(_voucher!);
      }
    }
  }

  // ===== دوال تتبع الكروت =====
  Future<String?> getLastCheckedVoucher() async {
    return await _storage.getLastCheckedVoucher();
  }

  Future<void> saveLastCheckedVoucher(String voucher) async {
    await _storage.saveLastCheckedVoucher(voucher);
  }

  Future<bool> isVoucherProcessed(String voucher) async {
    return await _storage.isVoucherProcessed(voucher);
  }

  Future<void> handleSpinWheel(String voucher, {String? category}) async {
    if (_processingVouchers.contains(voucher)) return;

    // فحص محلي أولاً
    if (await _storage.isVoucherProcessed(voucher)) return;

    // فحص Firebase أيضاً (لمنع التلاعب حتى لو أعاد التثبيت)
    if (_firebaseReady) {
      try {
        final remote = await _firebase.getUserSpinData(voucher);
        if (remote != null) {
          final processed = (remote['processedVouchers'] as List<dynamic>?)
              ?.map((e) => e.toString()).toSet() ?? {};
          if (processed.contains(voucher)) return;
        }
      } catch (_) {}
    }

    _processingVouchers.add(voucher);

    try {
      final cat = category ?? _spinCategory;

      if (cat == 'small') {
        _spinCategory = 'small';
        await _storage.saveSpinCategory('small');
        await _storage.addSmallVoucher(voucher);

        _spinSmallCounter = await _storage.getSmallSpinCounter();
        _spinSmallCounter++;
        await _storage.saveSmallSpinCounter(_spinSmallCounter);

        if (_spinSmallCounter >= 5 && !_spinSmallAvailable) {
          _spinSmallAvailable = true;
          await _storage.saveSmallSpinAvailable(true);
        }
      } else {
        _spinCategory = 'large';
        await _storage.saveSpinCategory('large');
        await _storage.addLargeVoucher(voucher);

        _spinLargeCounter = await _storage.getLargeSpinCounter();
        _spinLargeCounter++;
        await _storage.saveLargeSpinCounter(_spinLargeCounter);

        if (_spinLargeCounter >= 5 && !_spinLargeAvailable) {
          _spinLargeAvailable = true;
          await _storage.saveLargeSpinAvailable(true);
        }
      }

      await _storage.saveProcessedVoucher(voucher);

      if (_firebaseReady) {
        await _syncSpinDataToFirebase(voucher);
      }

      notifyListeners();
    } finally {
      _processingVouchers.remove(voucher);
    }
  }

  Future<void> _syncSpinDataToFirebase(String voucher) async {
    if (!_firebaseReady) return;
    final smallVouchers = await _storage.getSmallVouchers();
    final largeVouchers = await _storage.getLargeVouchers();
    final processed = await _storage.getProcessedVouchers();
    await _firebase.saveUserSpinData(voucher, {
      'smallCounter': _spinSmallCounter,
      'largeCounter': _spinLargeCounter,
      'smallAvailable': _spinSmallAvailable,
      'largeAvailable': _spinLargeAvailable,
      'smallVouchers': smallVouchers,
      'largeVouchers': largeVouchers,
      'processedVouchers': processed.toList(),
    });
  }

  Future<void> _loadSpinDataFromFirebase(String voucher) async {
    if (!_firebaseReady) return;
    final remote = await _firebase.getUserSpinData(voucher);
    if (remote == null) return;

    final remoteSmall = remote['smallCounter'] as int? ?? 0;
    final remoteLarge = remote['largeCounter'] as int? ?? 0;
    final remoteSmallAvail = remote['smallAvailable'] as bool? ?? false;
    final remoteLargeAvail = remote['largeAvailable'] as bool? ?? false;
    final remoteSmallVouchers = (remote['smallVouchers'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final remoteLargeVouchers = (remote['largeVouchers'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final remoteProcessed = (remote['processedVouchers'] as List<dynamic>?)
            ?.map((e) => e.toString()).toSet() ?? {};

    // نأخذ القيمة الأعلى (إذا المستخدم استخدم نفس الكرت على جهاز آخر)
    bool changed = false;
    if (remoteSmall > _spinSmallCounter) {
      _spinSmallCounter = remoteSmall;
      await _storage.saveSmallSpinCounter(remoteSmall);
      changed = true;
    }
    if (remoteLarge > _spinLargeCounter) {
      _spinLargeCounter = remoteLarge;
      await _storage.saveLargeSpinCounter(remoteLarge);
      changed = true;
    }
    if (remoteSmallAvail && !_spinSmallAvailable) {
      _spinSmallAvailable = true;
      await _storage.saveSmallSpinAvailable(true);
      changed = true;
    }
    if (remoteLargeAvail && !_spinLargeAvailable) {
      _spinLargeAvailable = true;
      await _storage.saveLargeSpinAvailable(true);
      changed = true;
    }
    // دمج قوائم الكروت
    for (final v in remoteSmallVouchers) {
      await _storage.addSmallVoucher(v);
    }
    for (final v in remoteLargeVouchers) {
      await _storage.addLargeVoucher(v);
    }
    for (final v in remoteProcessed) {
      await _storage.saveProcessedVoucher(v);
    }

    if (changed) notifyListeners();
  }

  void setSpinCategory(String category) {
    _spinCategory = category;
    notifyListeners();
  }

  Future<void> resetSpinWheel({String? category}) async {
    final cat = category ?? _spinCategory;
    if (cat == 'small') {
      _spinSmallCounter = 0;
      _spinSmallAvailable = false;
      await _storage.saveSmallSpinCounter(0);
      await _storage.saveSmallSpinAvailable(false);
      await _storage.saveSmallVouchers([]);
    } else {
      _spinLargeCounter = 0;
      _spinLargeAvailable = false;
      await _storage.saveLargeSpinCounter(0);
      await _storage.saveLargeSpinAvailable(false);
      await _storage.saveLargeVouchers([]);
    }
    notifyListeners();

    // مزامنة Firebase
    if (_firebaseReady && _voucher != null) {
      await _syncSpinDataToFirebase(_voucher!);
    }
  }

  // ===== إدارة الجوائز (باستخدام المعاملات المسماة) =====
  Future<void> addSpinPrize(String name, String value, String type) async {
    final prize = SpinPrize(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      value: value,
      type: type,
    );
    _spinPrizes.add(prize);
    await _storage.saveSpinPrizes(_spinPrizes);
    if (_firebaseReady) {
      await _firebase.addSpinPrize(prize);
    }
    notifyListeners();
  }

  Future<void> updateSpinPrize(String id, String name, String value, String type) async {
    final index = _spinPrizes.indexWhere((p) => p.id == id);
    if (index != -1) {
      _spinPrizes[index] = SpinPrize(
        id: id,
        name: name,
        value: value,
        type: type,
      );
      await _storage.saveSpinPrizes(_spinPrizes);
      if (_firebaseReady) {
        await _firebase.updateSpinPrize(_spinPrizes[index]);
      }
      notifyListeners();
    }
  }

  Future<void> deleteSpinPrize(String id) async {
    _spinPrizes.removeWhere((p) => p.id == id);
    await _storage.saveSpinPrizes(_spinPrizes);
    if (_firebaseReady) {
      await _firebase.deleteSpinPrize(id);
    }
    notifyListeners();
  }

  // ===== دوال مساعدة للكروت =====
  Future<List<String>> getSmallVouchers() async {
    return await _storage.getSmallVouchers();
  }

  Future<List<String>> getLargeVouchers() async {
    return await _storage.getLargeVouchers();
  }

  Future<int> smallVoucherCount() async {
    return await _storage.smallVoucherCount();
  }

  Future<int> largeVoucherCount() async {
    return await _storage.largeVoucherCount();
  }

  Future<void> claimVoucher(String type, String voucher) async {
    await _storage.claimVoucher(type, voucher);
    if (type == 'small') {
      _spinSmallCounter = await _storage.getSmallSpinCounter();
      final list = await _storage.getSmallVouchers();
      if (list.isEmpty) {
        _spinSmallAvailable = false;
        await _storage.saveSmallSpinAvailable(false);
      }
    } else {
      _spinLargeCounter = await _storage.getLargeSpinCounter();
      final list = await _storage.getLargeVouchers();
      if (list.isEmpty) {
        _spinLargeAvailable = false;
        await _storage.saveLargeSpinAvailable(false);
      }
    }
    notifyListeners();

    if (_firebaseReady && _voucher != null) {
      await _syncSpinDataToFirebase(_voucher!);
    }
  }

  // ===== دالة updateAdminMessage =====
  Future<void> updateAdminMessage(String docId, String title, String body) async {
    if (!_firebaseReady) return;
    await _firebase.updateAdminMessage(docId, title, body);
  }

  // ===== باقي الدوال =====
  Future<void> init() async {
    await _storage.init();
    _loginUrl = _storage.loginUrl;
    _liveUrl = _storage.liveUrl;
    _restUrl = _storage.restUrl;
    _voucher = _storage.voucher;
    _isConnected = _voucher != null;
    _logoPath = _storage.logoPath;
    _localReady = true;

    await loadSpinData();
    notifyListeners();

    _firebase.init().then((_) {
      _firebaseReady = _firebase.isAvailable;
      if (_firebaseReady) {
        _listenToMessages();
        _listenToSuggestions();
        _listenToReviews();
        _listenToSpinPrizes();
        if (_firebase.fcmToken != null) {
          _storage.saveFcmToken(_firebase.fcmToken!);
          if (_voucher != null) {
            _firebase.saveUserToken(_voucher!);
          }
        }
      }
      notifyListeners();
    });

    Future.delayed(const Duration(seconds: 5), _runMonitorCycle);
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) => _runMonitorCycle());
  }

  void _listenToMessages() {
    _firebase.getMessagesStream().listen((msgs) {
      final oldMessages = Map.fromEntries(_messages.map((m) => MapEntry(m.id, m.read)));
      _messages = msgs.map((msg) {
        if (oldMessages.containsKey(msg.id)) {
          return msg.copyWith(read: oldMessages[msg.id]);
        }
        return msg;
      }).toList();
      notifyListeners();
    });
  }

  void _listenToSuggestions() {
    _firebase.getSuggestionsStream().listen((sugs) {
      _suggestions = sugs;
      notifyListeners();
    });
  }

  void _listenToReviews() {
    _firebase.getReviewsStream().listen((revs) {
      _reviews = revs;
      notifyListeners();
    });
  }

  void _listenToSpinPrizes() {
    _firebase.getSpinPrizesStream().listen((prizes) {
      _spinPrizes = prizes;
      _storage.saveSpinPrizes(_spinPrizes);
      notifyListeners();
    });
  }

  Future<void> _runMonitorCycle() async {
    final cycle = _runMonitorCycleInner().timeout(const Duration(seconds: 20));
    try {
      await cycle;
    } catch (_) {}
  }

  /// تحديد فئة الكرت بناءً على حقل السرعة من الميكروتيك
  String _speedToCategory(String speed) {
    if (speed.contains('economic') || speed.contains('normal')) {
      return 'small';
    } else if (speed.contains('middle') || speed.contains('high') || speed.contains('very')) {
      return 'large';
    }
    return 'small';
  }

  Future<void> _runMonitorCycleInner() async {
    // فحص حالة تسجيل الدخول من الميكروتيك (يعمل حتى لو _isConnected = false)
    try {
      final (isLoggedIn, username, speed) = await _mikrotik.checkLoginStatus();
      if (isLoggedIn && username.isNotEmpty) {
        // المستخدم مسجّل الدخول حالياً
        final alreadyProcessed = await _storage.isVoucherProcessed(username);
        if (!alreadyProcessed) {
          // كرت جديد (تسجيل دخول من متصفح أو التطبيق)
          final category = _speedToCategory(speed);
          await _storage.saveSession(username, _mikrotik.gatewayIp ?? '192.168.88.1');
          if (_firebaseReady && _firebase.fcmToken != null) {
            await _firebase.saveUserToken(username);
          }
          await handleSpinWheel(username, category: category);
        }
        // تحديث حالة الاتصال
        if (!_isConnected || _voucher != username) {
          _voucher = username;
          _isConnected = true;
          notifyListeners();
        }
      } else if (_isConnected) {
        // جلسة المستخدم انتهت
        _isConnected = false;
        _voucher = null;
        _remainingBalance = -1;
        _lowBalanceShown = false;
        await _storage.clearSession();
        notifyListeners();
      }
    } catch (_) {
      // إذا فشل الاتصال بالبوابة، لا بأس
    }

    if (_isConnected) {
      _remainingBalance = await _mikrotik.getRemainingBytes();
      if (_remainingBalance > 0 && _remainingBalance < _lowBalanceThreshold) {
        final remainingMB = _remainingBalance ~/ (1024 * 1024);
        _lowBalanceShown = false;
        await _sendLowBalanceNotification(remainingMB);
      } else {
        _lowBalanceShown = false;
      }
    }
    _currentSpeed = await _mikrotik.measureSpeed();

    try {
      final sw = Stopwatch()..start();
      await http.get(Uri.parse('http://172.16.0.1/')).timeout(const Duration(seconds: 3));
      sw.stop();
      _pingMs = sw.elapsedMilliseconds;
    } catch (_) {
      _pingMs = -1;
    }

    notifyListeners();
  }

  // ===== إرسال إشعار انخفاض الرصيد (تم تصحيح الاستدعاء) =====
  Future<void> _sendLowBalanceNotification(int remainingMB) async {
    if (_lastLowBalanceNotificationTime != null) {
      final diff = DateTime.now().difference(_lastLowBalanceNotificationTime!);
      if (diff < _notificationCooldown) return;
    }

    const androidDetails = AndroidNotificationDetails(
      'low_balance_channel',
      'تنبيهات الرصيد',
      channelDescription: 'إشعارات عند انخفاض رصيد الإنترنت',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: '⚠️ رصيد منخفض',
      body: 'الرصيد المتبقي: $remainingMB ميجابايت. يرجى تجديد الاشتراك.',
      notificationDetails: details,
    );
    _lastLowBalanceNotificationTime = DateTime.now();
  }

  Future<String> login(String voucher, {String? category}) async {
    final result = await _mikrotik.login(voucher);
    if (result.success) {
      _voucher = voucher;
      _isConnected = true;
      await _storage.saveSession(voucher, _mikrotik.gatewayIp ?? '192.168.88.1');
      if (_firebaseReady && _firebase.fcmToken != null) {
        await _firebase.saveUserToken(voucher);
      }
      // تُحتسب النقطة مرة واحدة فقط لكل كرت (حتى لو دُعي login() مراراً)
      await handleSpinWheel(voucher, category: category);
      notifyListeners();
      return 'success';
    }
    notifyListeners();
    return result.message;
  }

  Future<void> logout() async {
    await _mikrotik.logout();
    await _storage.clearSession();
    _voucher = null;
    _isConnected = false;
    _remainingBalance = -1;
    _lowBalanceShown = false;
    notifyListeners();
  }

  Future<void> addSuggestion(String title, String body) async {
    if (_firebaseReady) {
      await _firebase.addSuggestion(title, body);
    }
  }

  Future<void> addReview(String userName, String comment, double rating) async {
    if (_firebaseReady) {
      await _firebase.addReview(userName, comment, rating);
    }
  }

  Future<void> sendAdminMessage(String title, String body) async {
    if (!_firebaseReady) return;
    await _firebase.sendMessage(title, body);
  }

  Future<void> updateLoginUrl(String url) async {
    _loginUrl = url;
    await _storage.saveLoginUrl(url);
    notifyListeners();
  }

  Future<void> updateLiveUrl(String url) async {
    _liveUrl = url;
    await _storage.saveLiveUrl(url);
    notifyListeners();
  }

  Future<void> updateRestUrl(String url) async {
    _restUrl = url;
    await _storage.saveRestUrl(url);
    notifyListeners();
  }

  void markMessageRead(String id) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1 && !_messages[idx].read) {
      _messages[idx] = _messages[idx].copyWith(read: true);
      notifyListeners();
    }
  }

  Future<bool> verifyAdminPassword(String password) async {
    if (!_firebaseReady) return password == AppConstants.adminSecretKey;
    return await _firebase.verifyAdminPassword(password);
  }

  Future<bool> updateAdminPassword(String current, String newPassword) async {
    if (!_firebaseReady) return false;
    return await _firebase.updateAdminPassword(current, newPassword);
  }

  Future<void> toggleUserBlock(String fcmToken, bool blocked) async {
    if (!_firebaseReady) return;
    await _firebase.toggleUserBlock(fcmToken, blocked);
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firebase.getUsersStream();
  }

  Future<int> getActiveUserCount() => _firebase.getActiveUserCount();
  Future<int> getTotalUserCount() => _firebase.getTotalUserCount();

  Future<bool> verifySuperAdminPassword(String password) async {
    if (!_firebaseReady) return password == AppConstants.superAdminSecretKey;
    return await _firebase.verifySuperAdminPassword(password);
  }

  Future<bool> updateSuperAdminPassword(String current, String newPassword) async {
    if (!_firebaseReady) return false;
    return await _firebase.updateSuperAdminPassword(current, newPassword);
  }

  Future<String?> getNetworkAdminPassword() async {
    if (!_firebaseReady) return null;
    return await _firebase.getNetworkAdminPassword();
  }

  Future<bool> setNetworkAdminPassword(String newPassword) async {
    if (!_firebaseReady) return false;
    return await _firebase.setNetworkAdminPassword(newPassword);
  }

  Future<String?> pickAndSaveLogo() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return _logoPath;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(picked.path);
      final saved = await file.copy('${dir.path}/app_logo.${picked.path.split('.').lastOrNull ?? 'jpg'}');
      _logoPath = saved.path;
      await _storage.saveLogoPath(_logoPath!);
      notifyListeners();
      return _logoPath;
    } catch (_) {
      return _logoPath;
    }
  }

  Future<void> saveWhatsapp(String v) async {
    await _storage.saveWhatsapp(v);
    notifyListeners();
  }

  Future<void> saveTelegram(String v) async {
    await _storage.saveTelegram(v);
    notifyListeners();
  }

  Future<void> savePhone(String v) async {
    await _storage.savePhone(v);
    notifyListeners();
  }

  Future<void> saveWhatsappGroup(String v) async {
    await _storage.saveWhatsappGroup(v);
    notifyListeners();
  }

  void startMonitoring() {
    _monitorTimer?.cancel();
    Future.delayed(const Duration(seconds: 5), _runMonitorCycle);
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) => _runMonitorCycle());
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }
}