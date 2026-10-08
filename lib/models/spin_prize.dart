import 'package:cloud_firestore/cloud_firestore.dart';

class SpinPrize {
  final String id;
  final String name;
  final String value;
  final String type; // 'small' أو 'large'
  final List<String> cards; // مخزون الكروت الحقيقية (أرقام تسجيل الدخول)

  SpinPrize({
    required this.id,
    required this.name,
    required this.value,
    required this.type,
    this.cards = const [],
  });

  int get cardCount => cards.length;

  SpinPrize copyWith({List<String>? cards}) {
    return SpinPrize(
      id: id,
      name: name,
      value: value,
      type: type,
      cards: cards ?? this.cards,
    );
  }

  factory SpinPrize.fromFirestore(Map<String, dynamic> map, String docId) {
    return SpinPrize(
      id: docId,
      name: map['name'] as String? ?? '',
      value: map['value'] as String? ?? '',
      type: map['type'] as String? ?? 'small',
      cards: (map['cards'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'value': value,
      'type': type,
      'cards': cards,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory SpinPrize.fromJson(Map<String, dynamic> json) {
    return SpinPrize(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      type: json['type'] as String? ?? 'small',
      cards: (json['cards'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'type': type,
      'cards': cards,
    };
  }
}