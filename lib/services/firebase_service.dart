import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/constants.dart';
import 'fcm_service.dart';
import 'notifications_service.dart';
import 'storage_service.dart';
import '../models/admin_message.dart';
import '../models/suggestion.dart';
import '../models/spin_prize.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _available = false;

  bool get isAvailable => _available;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      _firestore = FirebaseFirestore.instance;
      _messaging = FirebaseMessaging.instance;
      _fcmToken = await _messaging!.getToken().timeout(const Duration(seconds: 5));
      if (_fcmToken != null) {
        _messaging!.subscribeToTopic('all');
      }
      _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        _showLocalNotification(message);
      });

      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  // ===== إظهار إشعار النظام عندما يكون التطبيق مفتوحاً في المقدمة =====
  void _showLocalNotification(RemoteMessage message) {
    try {
      final n = message.notification;
      if (n == null) return;
      flutterLocalNotificationsPlugin.show(
        id: message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000).toInt(),
        title: n.title ?? 'شبكة الحارث',
        body: n.body ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'admin_messages',
            'رسائل الإدارة',
            channelDescription: 'إشعارات رسائل الإدارة',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> saveUserToken([String? voucher, String? mac, String? deviceName]) async {
    if (!_available || _fcmToken == null) return;
    final data = <String, dynamic>{
      'fcmToken': _fcmToken,
      'lastActive': FieldValue.serverTimestamp(),
    };
    if (voucher != null && voucher.isNotEmpty) {
      data['voucher'] = voucher;
    }
    if (mac != null && mac.isNotEmpty) {
      data['mac'] = mac;
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      data['deviceName'] = deviceName;
    }
    await _firestore!
        .collection(AppConstants.collectionUsers)
        .doc(_fcmToken)
        .set(data, SetOptions(merge: true));
  }

  // ===== الرسائل =====
  Stream<List<AdminMessage>> getMessagesStream() {
    if (!_available) return Stream.value([]);
    return _firestore!
        .collection(AppConstants.collectionMessages)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(String title, String body) async {
    if (!_available) return;
    await _firestore!.collection(AppConstants.collectionMessages).add({
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
    await _sendFcmNotification(title, body);
  }

  Future<void> updateAdminMessage(String docId, String title, String body) async {
    if (!_available) return;
    await _firestore!
        .collection(AppConstants.collectionMessages)
        .doc(docId)
        .update({
      'title': title,
      'body': body,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  Future<void> deleteAdminMessage(String docId) async {
    if (!_available || docId.isEmpty) return;
    await _firestore!
        .collection(AppConstants.collectionMessages)
        .doc(docId)
        .delete()
        .timeout(const Duration(seconds: 10));
  }

  Future<void> _sendFcmNotification(String title, String body) async {
    // إرسال عبر FCM HTTP v1 (بديل Legacy fcm/send)
    await FcmService.instance.send(title: title, body: body, topic: 'all');
  }

  // ===== الاقتراحات (دردشة خاصة بين المستخدم والإدارة) =====
  Stream<List<Suggestion>> getSuggestionsStream() {
    if (!_available) return Stream.value([]);
    return _firestore!
        .collection(AppConstants.collectionSuggestions)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Suggestion.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> addSuggestion(String title, String body, String userName) async {
    if (!_available) return;
    await _firestore!.collection(AppConstants.collectionSuggestions).add({
      'title': title,
      'body': body,
      'userName': userName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSuggestion(String docId) async {
    if (!_available || docId.isEmpty) return;
    await _firestore!
        .collection(AppConstants.collectionSuggestions)
        .doc(docId)
        .delete()
        .timeout(const Duration(seconds: 10));
  }

  /// إلحاق رد (user أو admin) بمحادثة اقتراح قائمة (كأنها دردشة).
  /// ملاحظة: لا يمكن استخدام FieldValue.serverTimestamp() داخل العناصر
  /// المخزّنة في مصفوفة (arrayUnion) - Firestore يرفضها، لذا نستخدم
  /// وقتاً من جهة العميل للرد وتوقيعاً من الخادم لحقل آخر.
  Future<void> replyToSuggestion(String docId, String text, String sender) async {
    if (!_available || docId.isEmpty || text.trim().isEmpty) return;
    await _firestore!
        .collection(AppConstants.collectionSuggestions)
        .doc(docId)
        .update({
      'replies': FieldValue.arrayUnion([
        {
          'sender': sender,
          'text': text.trim(),
          'createdAt': DateTime.now().toIso8601String(),
        }
      ]),
      'lastReplyAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  // =============================================================
  // ===== دوال عجلة الحظ (إدارة الجوائز) =====
  // =============================================================

  Stream<List<SpinPrize>> getSpinPrizesStream() {
    if (!_available) return Stream.value([]);
    return _firestore!
        .collection(AppConstants.collectionSpinPrizes)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SpinPrize.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> addSpinPrize(SpinPrize prize) async {
    if (!_available) return;
    await _firestore!
        .collection(AppConstants.collectionSpinPrizes)
        .doc(prize.id)
        .set(prize.toFirestore())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> updateSpinPrize(SpinPrize prize) async {
    if (!_available) return;
    await _firestore!
        .collection(AppConstants.collectionSpinPrizes)
        .doc(prize.id)
        .update(prize.toFirestore())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> deleteSpinPrize(String id) async {
    if (!_available) return;
    await _firestore!
        .collection(AppConstants.collectionSpinPrizes)
        .doc(id)
        .delete()
        .timeout(const Duration(seconds: 10));
  }

  // ===== سحب كرت حقيقي ذريّاً من مخزون صنف =====
  // يُسحب كرت عشوائياً ويُحذف من المخزون في معاملة واحدة، فلا يمكن
  // لمستخدمين أخذ نفس الكرت. يرجع رقم الكرت، أو null إذا المخزون فارغ.
  Future<String?> drawCard(String prizeId) async {
    if (!_available || prizeId.isEmpty) return null;
    try {
      final ref =
          _firestore!.collection(AppConstants.collectionSpinPrizes).doc(prizeId);
      final drawnCard = await _firestore!.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return null;
        final data = snap.data()!;
        final cards = (data['cards'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (cards.isEmpty) return null;
        final idx = DateTime.now().millisecondsSinceEpoch % cards.length;
        final card = cards.removeAt(idx);
        txn.update(ref, {'cards': cards});
        return card;
      }).timeout(const Duration(seconds: 10));
      return drawnCard;
    } catch (_) {
      return null;
    }
  }

  // ===== إضافة/تحديث مخزون الكروت لصنف =====
  Future<void> replacePrizeCards(String prizeId, List<String> cards) async {
    if (!_available || prizeId.isEmpty) return;
    try {
      await _firestore!
          .collection(AppConstants.collectionSpinPrizes)
          .doc(prizeId)
          .update({'cards': cards}).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ===== إشعار نقص الكروت (للإدمن والسوبر إدمن فقط) =====
  // يُرسل إشعار عبر الموضوع المخصص للأدمن، ولا يصل للمستخدمين العاديين.
  Future<void> sendLowCardsNotification(
      String prizeName, String category, int remaining) async {
    final title = 'انخفاض كروت: $prizeName';
    final body = 'عدد الكروت المتبقية في صنف '
        '${category == 'large' ? 'الكبيرة' : 'الصغيرة'} ($prizeName) '
        'أقل من 5 (المتبقي: $remaining). يرجى تعبئتها.';
    await _sendAdminOnlyNotification(title, body);
  }

  Future<void> _sendAdminOnlyNotification(String title, String body) async {
    // موضوع «الأدمن» فقط عبر FCM HTTP v1 - لا يصل للمستخدمين العاديين
    await FcmService.instance.send(
      title: title,
      body: body,
      topic: 'admins',
      dataType: 'low_cards',
    );
  }

  // ===== اشتراك جهاز الإدمن في موضوع «الأدمن» =====
  // يُستدعى عند نجاح تسجيل الدخول كإدمن/سوبر إدمن، حتى يستقبل جهاز الإدمن
  // إشعارات نقص الكروت (المستخدمون العاديون لا يشتركون هنا وبالتالي لا
  // يستقبلون هذه الإشعارات).
  Future<void> subscribeToAdminTopic() async {
    if (!_available || _messaging == null) return;
    try {
      await _messaging!.subscribeToTopic('admins').timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ===== دوال عجلة الحظ لكل مستخدم (في Firebase) =====
  Future<Map<String, dynamic>?> getUserSpinData(String voucher) async {
    if (!_available || voucher.isEmpty) return null;
    try {
      final doc = await _firestore!
          .collection(AppConstants.collectionUserSpinData)
          .doc(voucher)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // ===== قفل الكرت ذرّياً (منع الاحتساب مرتين من أي جهة) =====
  // المفتاح هو الكرت نفسه فقط (دون معرّف الجهاز)، لذا المعاملة (transaction)
  // تضمن أن الكرت يُحتسب مرة واحدة عالمياً — حتى لو حاول مستخدم إدخال
  // نفس الكرت من جهاز آخر، سيُرفض (spin_claims يحتوي المفتاح نفسه).
  Future<String?> claimVoucherOnce(String voucher, {String? deviceId}) async {
    if (!_available || voucher.isEmpty) return null;
    try {
      final key = voucher.trim();
      final ref = _firestore!.collection('spin_claims').doc(key);
      final result = await _firestore!.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (snap.exists) return 'already'; // مكرر - لن يحتسب
        txn.set(ref, {
          'claimedAt': FieldValue.serverTimestamp(),
        });
        return 'claimed';
      }).timeout(const Duration(seconds: 10));
      return result == 'claimed' ? 'claimed' : 'already';
    } catch (_) {
      return null; // فشل الاتصال - سنحتسب محلياً ونعيد المحاولة لاحقاً
    }
  }

  // تحديد الفئة بدقة من إجمالي الميجا الفعلية للكرت
  // أكبر من 1 جيجا = كبيرة، 1 جيجا أو أقل = صغيرة
  Future<String?> getVoucherCategory(String voucher) async {
    if (!_available || voucher.isEmpty) return null;
    try {
      final doc = await _firestore!
          .collection('voucher_meta')
          .doc(voucher)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      if (data == null) return null;
      final limitBytes = data['limitBytes'] as num?;
      if (limitBytes != null) {
        final mb = limitBytes / (1024 * 1024);
        if (mb > 1024) return 'large';
        return 'small';
      }
      final cat = data['category'] as String?;
      if (cat == 'large' || cat == 'small') return cat;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserSpinData(String voucher, Map<String, dynamic> data) async {
    if (!_available || voucher.isEmpty) return;
    try {
      await _firestore!
          .collection(AppConstants.collectionUserSpinData)
          .doc(voucher)
          .set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // ===== دوال الإدارة العامة =====

  // إعدادات التطبيق المشتركة (روابط + تواصل) - تُتزامن لكل المستخدمين
  Stream<Map<String, dynamic>> getAppSettingsStream() {
    if (!_available) return Stream.value({});
    return _firestore!
        .collection(AppConstants.collectionAppSettings)
        .doc(AppConstants.docAppSettings)
        .snapshots()
        .map((snap) => snap.data() ?? {});
  }

  Future<void> saveAppSetting(String key, String value) async {
    if (!_available || value.isEmpty) return;
    try {
      await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .set({key: value}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getAppSettings() async {
    if (!_available) return {};
    try {
      final doc = await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> verifyAdminPassword(String password) async {
    if (!_available) return _localAdminPasswordCheck(password);
    try {
      // نقرأ أولاً من إعدادات التطبيق المشتركة ثم من admin_settings القديمة
      final settingsDoc = await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (settingsDoc.exists &&
          settingsDoc.data()!.containsKey('adminPassword')) {
        final stored = settingsDoc.data()!['adminPassword'] as String;
        if (stored.isNotEmpty) {
          await StorageService().saveAdminPassword(stored);
          return stored == password;
        }
      }

      final doc = await _firestore!
          .collection('admin_settings')
          .doc('config')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data()!.containsKey('adminPassword')) {
        final stored = doc.data()!['adminPassword'] as String;
        await StorageService().saveAdminPassword(stored);
        return stored == password;
      }
    } catch (_) {}
    return _localAdminPasswordCheck(password);
  }

  bool _localAdminPasswordCheck(String password) {
    return StorageService().adminPassword == password;
  }

  Future<bool> updateAdminPassword(String currentPassword, String newPassword) async {
    if (!_available) return false;
    final valid = await verifyAdminPassword(currentPassword);
    if (!valid) return false;
    try {
      await _firestore!
          .collection('admin_settings')
          .doc('config')
          .set({'adminPassword': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .set({'adminPassword': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await StorageService().saveAdminPassword(newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    if (!_available) return Stream.value([]);
    return _firestore!
        .collection(AppConstants.collectionUsers)
        .orderBy('lastActive', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> toggleUserBlock(String fcmToken, bool blocked) async {
    if (!_available) return;
    await _firestore!
        .collection(AppConstants.collectionUsers)
        .doc(fcmToken)
        .update({'blocked': blocked});
  }

  // ===== دوال السوبر أدمن =====
  Future<bool> verifySuperAdminPassword(String password) async {
    if (!_available) return password == AppConstants.superAdminSecretKey;
    try {
      final settingsDoc = await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (settingsDoc.exists &&
          settingsDoc.data()!.containsKey('superAdminPassword')) {
        final stored = settingsDoc.data()!['superAdminPassword'] as String;
        if (stored.isNotEmpty) {
          await StorageService().saveSuperAdminPassword(stored);
          return stored == password;
        }
      }

      final doc = await _firestore!
          .collection('admin_settings')
          .doc(AppConstants.collectionSuperAdmin)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data()!.containsKey('password')) {
        return doc.data()!['password'] == password;
      }
    } catch (_) {}
    return password == AppConstants.superAdminSecretKey;
  }

  Future<bool> updateSuperAdminPassword(String currentPassword, String newPassword) async {
    if (!_available) return false;
    final valid = await verifySuperAdminPassword(currentPassword);
    if (!valid) return false;
    try {
      await _firestore!
          .collection('admin_settings')
          .doc(AppConstants.collectionSuperAdmin)
          .set({'password': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .set({'superAdminPassword': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await StorageService().saveSuperAdminPassword(newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getNetworkAdminPassword() async {
    if (!_available) return null;
    try {
      final doc = await _firestore!
          .collection('admin_settings')
          .doc('config')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data()!.containsKey('adminPassword')) {
        return doc.data()!['adminPassword'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setNetworkAdminPassword(String newPassword) async {
    await StorageService().saveAdminPassword(newPassword);
    if (!_available) return false;
    try {
      await _firestore!
          .collection('admin_settings')
          .doc('config')
          .set({'adminPassword': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await _firestore!
          .collection(AppConstants.collectionAppSettings)
          .doc(AppConstants.docAppSettings)
          .set({'adminPassword': newPassword}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> getActiveUserCount() async {
    if (!_available) return 0;
    try {
      final result = await _firestore!
          .collection(AppConstants.collectionUsers)
          .where('blocked', isEqualTo: false)
          .count()
          .get();
      return result.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalUserCount() async {
    if (!_available) return 0;
    try {
      final result = await _firestore!
          .collection(AppConstants.collectionUsers)
          .count()
          .get();
      return result.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}