class Expense {
  const Expense({
    this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.receiptImagePath,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int userId;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String? receiptImagePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense copyWith({
    int? id,
    int? userId,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? receiptImagePath,
    bool clearReceiptImage = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      receiptImagePath: clearReceiptImage
          ? null
          : (receiptImagePath ?? this.receiptImagePath),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'receipt_image_path': receiptImagePath,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    DateTime? parseOptional(Object? value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Expense(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      title: map['title'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      receiptImagePath: map['receipt_image_path'] as String?,
      createdAt: parseOptional(map['created_at']),
      updatedAt: parseOptional(map['updated_at']),
    );
  }
}