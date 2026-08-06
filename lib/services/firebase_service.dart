import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'storage_service.dart';
import '../models/admin_message.dart';
import '../models/suggestion.dart';
import '../models/review.dart';
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
        // handled automatically
      });
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<void> saveUserToken([String? voucher]) async {
    if (!_available || _fcmToken == null) return;
    final data = <String, dynamic>{
      'fcmToken': _fcmToken,
      'lastActive': FieldValue.serverTimestamp(),
    };
    if (voucher != null && voucher.isNotEmpty) {
      data['voucher'] = voucher;
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

  Future<void> _sendFcmNotification(String title, String body) async {
    final serverKey = StorageService().fcmServerKey;
    if (serverKey.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=$serverKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': '/topics/all',
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'type': 'admin_message',
            'title': title,
            'body': body,
          },
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ===== الاقتراحات =====
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

  Future<void> addSuggestion(String title, String body) async {
    if (!_available) return;
    await _firestore!.collection(AppConstants.collectionSuggestions).add({
      'title': title,
      'body': body,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== الآراء =====
  Stream<List<Review>> getReviewsStream() {
    if (!_available) return Stream.value([]);
    return _firestore!
        .collection(AppConstants.collectionReviews)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> addReview(String userName, String comment, double rating) async {
    if (!_available) return;
    await _firestore!.collection(AppConstants.collectionReviews).add({
      'userName': userName,
      'comment': comment,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
  Future<bool> verifyAdminPassword(String password) async {
    if (!_available) return _localAdminPasswordCheck(password);
    try {
      final doc = await _firestore!
          .collection('admin_settings')
          .doc('config')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data()!.containsKey('adminPassword')) {
        return doc.data()!['adminPassword'] == password;
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