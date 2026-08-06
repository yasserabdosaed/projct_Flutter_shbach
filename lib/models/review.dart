class Review {
  final String id;
  final String userName;
  final String comment;
  final double rating;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userName,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });

  factory Review.fromFirestore(Map<String, dynamic> map, String docId) =>
      Review(
        id: docId,
        userName: map['userName'] as String? ?? 'مستخدم',
        comment: map['comment'] as String? ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );
}
