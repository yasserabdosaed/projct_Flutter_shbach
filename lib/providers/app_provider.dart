import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';
import '../models/admin_message.dart';
import '../models/suggestion.dart';
import '../models/spin_prize.dart';
import '../services/balance_notifier.dart';
import '../services/firebase_service.dart';
import '../services/device_info_service.dart';
import '../services/inventory_notifier.dart';
import '../services/mikrotik_service.dart';
import '../services/storage_service.dart';

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

  bool _isSuperAdmin = false;
  String? _logoPath;

  // Balance monitoring
  int _remainingBalance = -1;
  bool _lowBalanceShown = false;
  static const int _lowBalanceThreshold = 100 * 1024 * 1024; // 100 MB

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

  /// يُحدَّث الرصيد المتبقي (بالبايت) من شاشة تسجيل الدخول بناءً على
  /// القيمة المعروضة في الصفحة الفعلية (#remain_bytes_total)
  void setRemainingBalanceFromBytes(int bytes) {
    if (bytes <= 0) return;
    _remainingBalance = bytes;
    _storage.saveRemainingBytes(bytes);
    notifyListeners();
  }

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
  // معرّف الجهاز الدائم = معرّف المستخدم (كل جهاز = مستخدم = عجلة خاصة)
  String get deviceId => _storage.deviceId;

  // ===== دوال عجلة الحظ =====
  Future<void> loadSpinData() async {
    _spinSmallCounter = await _storage.getSmallSpinCounter();
    _spinLargeCounter = await _storage.getLargeSpinCounter();
    _spinSmallAvailable = await _storage.getSmallSpinAvailable();
    _spinLargeAvailable = await _storage.getLargeSpinAvailable();
    _spinCategory = await _storage.getSpinCategory() ?? 'small';
    _spinPrizes = await _storage.getSpinPrizes();
    notifyListeners();

    // مزامنة من Firebase (كل جهاز=مستخدم له عداده الخاص، مرتبط بمعرّف الجهاز الدائم)
    final deviceId = _storage.deviceId;
    if (deviceId != 'unknown-device') {
      await _loadSpinDataFromFirebase(deviceId);
      // بعد المزج، نرفع البيانات المحلية إلى Firebase
      if (_firebaseReady) {
        await _syncSpinDataToFirebase(deviceId);
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

  Future<String?> handleSpinWheel(String voucher, {String? category}) async {
    // القفل الحصري فوراً (قبل أي await) لمنع المسارات المتوازية
    // (الشاشة + دورة المراقبة + الخلفية) من احتساب نفس الكرت مرتين.
    if (_processingVouchers.contains(voucher)) {
      debugPrint('[SPIN][DEBUG] handleSpinWheel called but already processing: $voucher');
      return null;
    }
    _processingVouchers.add(voucher);

    try {
      final cat = category ?? _spinCategory;

      // الكرت صغير جداً (300 ميجا أو أقل): لا يُحتسب أي نقطة في عجلة الحظ
      // ولا يُسجَّل كبطاقة محتسبة — فقط تظهر رسالة للمستخدم.
      if (cat == 'none') {
        debugPrint('[SPIN][DEBUG] card too small for spin wheel: $voucher');
        // نُعلّم الكرت محلياً كأنه معالج حتى لا يعيده نظام المراقبة فحصه كل دورة،
        // لكن لا يُسجَّل في السحابة ولا تُحتسب له أي نقطة.
        await _storage.saveProcessedVoucher(voucher);
        notifyListeners();
        return 'none';
      }

      // الفئة غير معروفة (فشل قراءة الحجم): لا نحتسب أي شيء حتى نتحقق منها
      if (cat != 'small' && cat != 'large') {
        debugPrint('[SPIN][DEBUG] unknown category, skipped to avoid wrong count: $voucher cat=$cat');
        return null;
      }

      // الحماية محلية على الجهاز: الكرت يُخزَّن على الجهاز نفسه فور احتسابه،
      // بحيث لو سجّل المستخدم خروجاً ثم أدخل نفس الكرت مجدداً لا تُحتسب له
      // نقطة أخرى. هذا يجعل الكرت الجديد يُحتسب فوراً (بدون انتظار أو أخطاء).
      final already = await _storage.isVoucherProcessed(voucher);
      if (already) {
        debugPrint('[SPIN][DEBUG] blocked: card already processed locally: $voucher');
        return null;
      }

      // الحماية العالمية عبر السحابة: منع تكرار نفس الكرت على أي جهاز آخر.
      // spin_claims هو السجل المرجعي (global) — المعاملة الذرية تضمن أن
      // أول جهاز يحتسب الكرت هو الوحيد. إن كان Firebase متاحاً والكرت
      // محتسباً مسبقاً من جهاز آخر → لا نقطة.
      if (_firebaseReady) {
        try {
          final claim = await _firebase.claimVoucherOnce(voucher);
          if (claim == 'already') {
            debugPrint('[SPIN][DEBUG] blocked: card already claimed on another device: $voucher');
            return null;
          }
          if (claim == null) {
            debugPrint('[SPIN][DEBUG] cloud claim unavailable - falling back to local-only: $voucher');
          }
        } catch (e) {
          debugPrint('[SPIN][DEBUG] cloud claim error (ignored), local-only: $e');
        }
      }

      // فحص نهائي قبل الاحتساب: قد يكون كرتاً احتسبه مسار آخر أثناء انتظاراتنا
      if (await _storage.isVoucherProcessed(voucher)) {
        debugPrint('[SPIN][DEBUG] blocked: card processed during await: $voucher');
        return null;
      }

      debugPrint('[SPIN][DEBUG] handleSpinWheel received card: $voucher category: $cat');

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

      // حفظ الكرت على الجهاز لمنع تكرار نقطته
      await _storage.saveProcessedVoucher(voucher);

      debugPrint('[SPIN][DEBUG] card counted. small=$_spinSmallCounter large=$_spinLargeCounter');

      // إعلام الواجهة فوراً حتى لا يتأخر تحديث العداد مهما حدث
      notifyListeners();

      // مزامنة اختيارية مع Firebase (لا تمنع الكرت الجديد أبداً)
      if (_firebaseReady) {
        try {
          await _syncSpinDataToFirebase(_storage.deviceId);
        } catch (e) {
          debugPrint('[SPIN][DEBUG] firebase sync failed (ignored): $e');
        }
      }
      return 'counted';
    } finally {
      _processingVouchers.remove(voucher);
    }
  }

  Future<void> _syncSpinDataToFirebase(String key) async {
    if (!_firebaseReady) return;
    final smallVouchers = await _storage.getSmallVouchers();
    final largeVouchers = await _storage.getLargeVouchers();
    final processed = await _storage.getProcessedVouchers();
    await _firebase.saveUserSpinData(key, {
      'smallCounter': _spinSmallCounter,
      'largeCounter': _spinLargeCounter,
      'smallAvailable': _spinSmallAvailable,
      'largeAvailable': _spinLargeAvailable,
      'smallVouchers': smallVouchers,
      'largeVouchers': largeVouchers,
      'processedVouchers': processed.toList(),
    });
  }

  Future<void> _loadSpinDataFromFirebase(String key) async {
    if (!_firebaseReady) return;
    final remote = await _firebase.getUserSpinData(key);
    if (remote == null) return;

    final remoteSmall = remote['smallCounter'] as int? ?? 0;
    final remoteLarge = remote['largeCounter'] as int? ?? 0;
    final remoteSmallAvail = remote['smallAvailable'] as bool? ?? false;
    final remoteLargeAvail = remote['largeAvailable'] as bool? ?? false;
    final remoteSmallVouchers = (remote['smallVouchers'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final remoteLargeVouchers = (remote['largeVouchers'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];

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
    if (_firebaseReady) {
      await _syncSpinDataToFirebase(_storage.deviceId);
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

  // ===== سحب كرت حقيقي من مخزون صنف (ذري في Firebase) =====
  // يُستدعى عند فوز المستخدم. يسحب كرتاً عشوائياً ويحذفه من المخزون.
  // يرجع رقم الكرت، أو null إذا المخزون فارغ.
  Future<String?> drawPrizeCard(String prizeId) async {
    String? card;
    if (_firebaseReady) {
      card = await _firebase.drawCard(prizeId);
    } else {
      // بدون Firebase نرجع null (لا يمكن السحب بأمان)
      return null;
    }
    if (card != null) {
      // تحديث المخزون محلياً بعد السحب
      final idx = _spinPrizes.indexWhere((p) => p.id == prizeId);
      if (idx != -1) {
        final updatedCards = List<String>.from(_spinPrizes[idx].cards)
          ..remove(card);
        _spinPrizes[idx] =
            _spinPrizes[idx].copyWith(cards: updatedCards);
        await _storage.saveSpinPrizes(_spinPrizes);
        _checkLowCardsNotification(_spinPrizes[idx]);
        notifyListeners();
      }
    }
    return card;
  }

  Future<void> _checkLowCardsNotification(SpinPrize prize) async {
    // عندما ينخفض المخزون إلى أقل من 5، أُرسل إشعاراً للأدمن/السوبر إدمن.
    // نرسل مرة واحدة فقط عند كل مستوى (مثلاً عند 4، ثم عند 3، ...) لتجنّب
    // إغراق الإشعارات في كل عملية سحب.
    final remaining = prize.cardCount;
    if (remaining >= 5) return;
    final lastNotified = _storage.getLastLowCardsNotified(prize.id);
    if (lastNotified != null && lastNotified == remaining) return;

    if (_firebaseReady) {
      await _firebase.sendLowCardsNotification(
          prize.name, prize.type, remaining);
      await _storage.setLastLowCardsNotified(prize.id, remaining);
    }
  }

  // ===== إضافة مخزون الكروت لصنف (من لوحة الإدمن) =====
  Future<void> addPrizeCards(String prizeId, List<String> cards) async {
    final idx = _spinPrizes.indexWhere((p) => p.id == prizeId);
    if (idx == -1) return;
    final current = List<String>.from(_spinPrizes[idx].cards);
    for (final c in cards) {
      if (!current.contains(c)) current.add(c);
    }
    _spinPrizes[idx] = _spinPrizes[idx].copyWith(cards: current);
    await _storage.saveSpinPrizes(_spinPrizes);
    if (_firebaseReady) {
      await _firebase.replacePrizeCards(prizeId, current);
    }
    notifyListeners();
  }

  // ===== تحديث المخزون بعد التعديل من لوحة الإدمن =====
  Future<void> replaceAllPrizeCards(
      String prizeId, List<String> cards) async {
    final idx = _spinPrizes.indexWhere((p) => p.id == prizeId);
    if (idx == -1) return;
    _spinPrizes[idx] = _spinPrizes[idx].copyWith(cards: cards);
    await _storage.saveSpinPrizes(_spinPrizes);
    if (_firebaseReady) {
      await _firebase.replacePrizeCards(prizeId, cards);
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

    if (_firebaseReady) {
      await _syncSpinDataToFirebase(_storage.deviceId);
    }
  }

  // ===== دالة updateAdminMessage =====
  Future<void> updateAdminMessage(String docId, String title, String body) async {
    if (!_firebaseReady) return;
    await _firebase.updateAdminMessage(docId, title, body);
  }

  // ===== حذف رسالة من رسائل الإدارة =====
  Future<void> deleteAdminMessage(String docId) async {
    if (!_firebaseReady || docId.isEmpty) return;
    try {
      await _firebase.deleteAdminMessage(docId);
      _messages.removeWhere((m) => m.id == docId);
      _storage.removeReadMessageId(docId);
      notifyListeners();
    } catch (_) {}
  }

  // ===== حذف اقتراح =====
  Future<void> deleteSuggestion(String docId) async {
    if (!_firebaseReady || docId.isEmpty) return;
    try {
      await _firebase.deleteSuggestion(docId);
      _suggestions.removeWhere((s) => s.id == docId);
      notifyListeners();
    } catch (_) {}
  }

  // ===== رد على اقتراح (user أو admin) كأنها محادثة خاصة =====
  Future<void> replyToSuggestion(String docId, String text, String sender) async {
    if (!_firebaseReady || docId.isEmpty || text.trim().isEmpty) return;
    try {
      await _firebase.replyToSuggestion(docId, text, sender);
      // تحديث محلي فوري دون انتظار البث
      final idx = _suggestions.indexWhere((s) => s.id == docId);
      if (idx >= 0) {
        final s = _suggestions[idx];
        _suggestions[idx] = s.copyWith(
          replies: [
            ...s.replies,
            SuggestionReply(
              sender: sender,
              text: text.trim(),
              createdAt: DateTime.now(),
            ),
          ],
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  // اقتراحات المستخدم الحالي (كل مستخدم يرى دردشته الخاصة فقط)
  List<Suggestion> mySuggestions(String username) => _suggestions
      .where((s) => s.userName == username)
      .toList(growable: false);

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

    await _storage.weeklyCleanupIfDue();
    await loadSpinData();
    _remainingBalance = _storage.remainingBytes;
    notifyListeners();

    _firebase.init().then((_) {
      _firebaseReady = _firebase.isAvailable;
      if (_firebaseReady) {
        _listenToAppSettings();
        _listenToMessages();
        _listenToSuggestions();
        _listenToSpinPrizes();
        // قراءة فورية (مرة واحدة) لأحدث الإعدادات من السحاب لضمان وصول التغييرات
        // حتى قبل أن يبثّ stream التحديثات، وعند كل فتح للتطبيق.
        _firebase.getAppSettings().then((settings) {
          if (settings.isNotEmpty) _applyAppSettings(settings);
        }).catchError((_) {});
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
      final persistedRead = _storage.getReadMessageIds();
      final oldMessages = Map.fromEntries(_messages.map((m) => MapEntry(m.id, m.read)));
      _messages = msgs.map((msg) {
        // تُعتبر الرسالة مقروءة إذا كانت مقروءة مسبقاً في هذه الجلسة
        // أو كانت في قائمة القراءة المحفوظة (تبقى مقروءة بعد إعادة الفتح)
        final read = oldMessages[msg.id] ?? persistedRead.contains(msg.id);
        if (read) {
          return msg.copyWith(read: true);
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

  void _listenToSpinPrizes() {
    _firebase.getSpinPrizesStream().listen((prizes) {
      _spinPrizes = prizes;
      _storage.saveSpinPrizes(_spinPrizes);
      // إشعار عند توفر كروت جديدة بعد أن كانت فارغة — فقط لمن عنده
      // دوّارة محفوظة وجاهزة (بلغ 5 نقاط ولم يدوّر بعد).
      final wheelWaiting = _spinSmallAvailable || _spinLargeAvailable;
      InventoryNotifier.checkAndNotify(
        prizes: prizes,
        onlyIfAvailableWheel: wheelWaiting,
      );
      notifyListeners();
    });
  }

  // ===== الإعدادات المشتركة (تتحدث لكل المستخدمين عند تغيير الأدمن) =====
  void _listenToAppSettings() {
    _firebase.getAppSettingsStream().listen((settings) {
      _applyAppSettings(settings);
    });
  }

  void _applyAppSettings(Map<String, dynamic> settings) {
    var changed = false;

    final login = settings['loginUrl'];
    if (login is String && login.isNotEmpty && login != _loginUrl) {
      _loginUrl = login;
      _storage.saveLoginUrl(login);
      changed = true;
    }
    final live = settings['liveUrl'];
    if (live is String && live.isNotEmpty && live != _liveUrl) {
      _liveUrl = live;
      _storage.saveLiveUrl(live);
      changed = true;
    }
    final rest = settings['restUrl'];
    if (rest is String && rest.isNotEmpty && rest != _restUrl) {
      _restUrl = rest;
      _storage.saveRestUrl(rest);
      changed = true;
    }
    final wa = settings['whatsapp'];
    if (wa is String && wa.isNotEmpty && wa != _storage.whatsapp) {
      _storage.saveWhatsapp(wa);
      changed = true;
    }
    final ph = settings['phone'];
    if (ph is String && ph.isNotEmpty && ph != _storage.phone) {
      _storage.savePhone(ph);
      changed = true;
    }
    final wg = settings['whatsappGroup'];
    if (wg is String && wg.isNotEmpty && wg != _storage.whatsappGroup) {
      _storage.saveWhatsappGroup(wg);
      changed = true;
    }
    final tg = settings['telegram'];
    if (tg is String && tg.isNotEmpty && tg != _storage.telegram) {
      _storage.saveTelegram(tg);
      changed = true;
    }

    // كلمات المرور - تُخزَّن محلياً لمنع الالتباس (1234 / yasser)
    final ap = settings['adminPassword'];
    if (ap is String && ap.isNotEmpty) {
      _storage.saveAdminPassword(ap);
      changed = true;
    }
    final sap = settings['superAdminPassword'];
    if (sap is String && sap.isNotEmpty) {
      _storage.saveSuperAdminPassword(sap);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> _runMonitorCycle() async {
    final cycle = _runMonitorCycleInner().timeout(const Duration(seconds: 20));
    try {
      await cycle;
    } catch (_) {}
  }

  /// تحديد فئة الكرت بناءً على حقل السرعة من الميكروتيك
  Future<void> _runMonitorCycleInner() async {
    // فحص حالة تسجيل الدخول من الميكروتيك (يعمل حتى لو _isConnected = false)
    try {
      final (isLoggedIn, username, speed) = await _mikrotik.checkLoginStatus();
      if (isLoggedIn && username.isNotEmpty) {
        // المستخدم مسجّل الدخول حالياً
        final alreadyProcessed = await _storage.isVoucherProcessed(username);
        if (!alreadyProcessed) {
          // كرت جديد (تسجيل دخول من متصفح أو التطبيق)
          // التحديد الدقيق: 300 ميجا='none'، 600/1ج='small'، 1.5ج فأكثر='large'
          // إن تعذّر التحديد (null) نُؤجل ولا نحتسب — يُعاد الفحص في الدورة التالية
          final category =
              await _mikrotik.determineVoucherCategory(fallbackSpeed: speed);
          if (category == null) {
            debugPrint('[SPIN][DEBUG] monitor: category undetermined for $username, deferring');
            this.notifyListeners();
            return;
          }
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
        await _storage.clearRemainingBytes();
        notifyListeners();
      }
    } catch (_) {
      // إذا فشل الاتصال بالبوابة، لا بأس
    }

    if (_isConnected) {
      // لا تكسر قيمة رصيد معروفة جيدة بقيمة -1 عند فشل التحليل المؤقت
      final bal = await _mikrotik.getRemainingBytes();
      if (bal >= 0) {
        _remainingBalance = bal;
        await _storage.saveRemainingBytes(bal);
      }
      if (_remainingBalance > 0 && _remainingBalance < _lowBalanceThreshold) {
        _lowBalanceShown = false;
      } else {
        _lowBalanceShown = false;
      }
      // إشعارات انخفاض الرصيد حسب العتبات (100/70/50/30/5 ميجا)،
      // كل عتبة تُرسل مرة واحدة لكل كرت (محفوظة محلياً لكل كرت)
      if (_remainingBalance > 0 && _voucher != null) {
        await BalanceNotifier.checkAndNotify(
          voucher: _voucher!,
          remainingBytes: _remainingBalance,
        );
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

  Future<String> login(String voucher, {String? category}) async {
    final result = await _mikrotik.login(voucher);
    if (result.success) {
      _voucher = voucher;
      _isConnected = true;
      await _storage.saveSession(voucher, _mikrotik.gatewayIp ?? '192.168.88.1');
      if (_firebaseReady && _firebase.fcmToken != null) {
        final mac = await _mikrotik.getClientMac();
        final deviceName = await DeviceInfoService.instance.getDeviceName();
        await _firebase.saveUserToken(voucher, mac, deviceName);
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
    await _storage.clearRemainingBytes();
    _voucher = null;
    _isConnected = false;
    _remainingBalance = -1;
    _lowBalanceShown = false;
    notifyListeners();
  }

  Future<void> addSuggestion(String title, String body, String userName) async {
    if (_firebaseReady) {
      await _firebase.addSuggestion(title, body, userName);
    }
  }

  Future<void> sendAdminMessage(String title, String body) async {
    if (!_firebaseReady) return;
    await _firebase.sendMessage(title, body);
  }

  Future<void> updateLoginUrl(String url) async {
    _loginUrl = url;
    await _storage.saveLoginUrl(url);
    await _firebase.saveAppSetting('loginUrl', url);
    notifyListeners();
  }

  Future<void> updateLiveUrl(String url) async {
    _liveUrl = url;
    await _storage.saveLiveUrl(url);
    await _firebase.saveAppSetting('liveUrl', url);
    notifyListeners();
  }

  Future<void> updateRestUrl(String url) async {
    _restUrl = url;
    await _storage.saveRestUrl(url);
    await _firebase.saveAppSetting('restUrl', url);
    notifyListeners();
  }

  void markMessageRead(String id) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1 && !_messages[idx].read) {
      _messages[idx] = _messages[idx].copyWith(read: true);
      _storage.addReadMessageId(id);
      notifyListeners();
    }
  }

  Future<bool> verifyAdminPassword(String password) async {
    final ok = _firebaseReady
        ? await _firebase.verifyAdminPassword(password)
        : password == AppConstants.adminSecretKey;
    if (ok) await subscribeAdminToTopic();
    return ok;
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
    final ok = _firebaseReady
        ? await _firebase.verifySuperAdminPassword(password)
        : password == AppConstants.superAdminSecretKey;
    if (ok) await subscribeAdminToTopic();
    return ok;
  }

  // ===== اشتراك جهاز الإدمن/السوبر في موضوع «الأدمن» لاستقبال إشعار النقص =====
  Future<void> subscribeAdminToTopic() async {
    if (_firebaseReady) {
      await _firebase.subscribeToAdminTopic();
    }
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
    await _firebase.saveAppSetting('whatsapp', v);
    notifyListeners();
  }

  Future<void> saveTelegram(String v) async {
    await _storage.saveTelegram(v);
    await _firebase.saveAppSetting('telegram', v);
    notifyListeners();
  }

  Future<void> savePhone(String v) async {
    await _storage.savePhone(v);
    await _firebase.saveAppSetting('phone', v);
    notifyListeners();
  }

  Future<void> saveWhatsappGroup(String v) async {
    await _storage.saveWhatsappGroup(v);
    await _firebase.saveAppSetting('whatsappGroup', v);
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