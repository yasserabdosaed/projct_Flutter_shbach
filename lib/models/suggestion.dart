class Suggestion {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String status;

  Suggestion({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.status = 'pending',
  });

  factory Suggestion.fromFirestore(Map<String, dynamic> map, String docId) =>
      Suggestion(
        id: docId,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        status: map['status'] as String? ?? 'pending',
      );
}
