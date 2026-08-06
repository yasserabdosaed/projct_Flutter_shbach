class AdminMessage {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  AdminMessage({
    required this.id,
    required this.title,
    required this.body,
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AdminMessage.fromFirestore(Map<String, dynamic> map, String docId) =>
      AdminMessage(
        id: docId,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        read: map['read'] as bool? ?? false,
        createdAt: (map['createdAt'] as dynamic)?.toDate(),
      );

  factory AdminMessage.fromJson(Map<String, dynamic> map) => AdminMessage(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        read: map['read'] as bool? ?? false,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };

  AdminMessage copyWith({
    String? id,
    String? title,
    String? body,
    bool? read,
    DateTime? createdAt,
  }) =>
      AdminMessage(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        read: read ?? this.read,
        createdAt: createdAt ?? this.createdAt,
      );
}
