class Budget {
  const Budget({
    this.id,
    required this.userId,
    required this.month,
    required this.amount,
  });

  final int? id;
  final int userId;

  /// Định dạng yyyy-MM, ví dụ 2026-10.
  final String month;
  final double amount;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'month': month,
      'amount': amount,
    };
  }

  factory Budget.fromMap(Map<String, Object?> map) {
    return Budget(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      month: map['month'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}