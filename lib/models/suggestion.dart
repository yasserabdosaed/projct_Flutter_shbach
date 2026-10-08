class SuggestionReply {
  final String sender; // 'user' | 'admin'
  final String text;
  final DateTime createdAt;

  SuggestionReply({
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  factory SuggestionReply.fromFirestore(Map<String, dynamic> map) =>
      SuggestionReply(
        sender: map['sender'] as String? ?? 'user',
        text: map['text'] as String? ?? '',
        createdAt: Suggestion.parseTime(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'sender': sender,
        'text': text,
        'createdAt': createdAt,
      };
}

class Suggestion {
  final String id;
  final String userName;
  final String title;
  final String body;
  final DateTime createdAt;
  final String status;
  final List<SuggestionReply> replies;

  Suggestion({
    required this.id,
    required this.userName,
    required this.title,
    required this.body,
    required this.createdAt,
    this.status = 'pending',
    this.replies = const [],
  });

  /// تحليل التاريخ من صيغ متعددة: Timestamp من الخادم، نص ISO-8601، عدد ميلي ثانية.
  static DateTime parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    try {
      final t = (v as dynamic).toDate();
      if (t is DateTime) return t;
    } catch (_) {}
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory Suggestion.fromFirestore(Map<String, dynamic> map, String docId) =>
      Suggestion(
        id: docId,
        userName: map['userName'] as String? ?? 'مستخدم',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: parseTime(map['createdAt']),
        status: map['status'] as String? ?? 'pending',
        replies: (map['replies'] as List?)
                ?.map((e) => SuggestionReply.fromFirestore(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );

  Suggestion copyWith({List<SuggestionReply>? replies, String? status}) =>
      Suggestion(
        id: id,
        userName: userName,
        title: title,
        body: body,
        createdAt: createdAt,
        status: status ?? this.status,
        replies: replies ?? this.replies,
      );
}