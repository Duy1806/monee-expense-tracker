import '../../data/models/expense.dart';
import '../constants/app_constants.dart';
import '../constants/expense_categories.dart';

String? validateExpenseFields({
  required String title,
  required double amount,
  required String category,
  required DateTime date,
  DateTime? now,
}) {
  final trimmedTitle = title.trim();

  if (trimmedTitle.isEmpty) {
    return 'Tên giao dịch không được để trống.';
  }

  if (trimmedTitle.length > 120) {
    return 'Tên giao dịch tối đa 120 ký tự.';
  }

  if (!amount.isFinite || amount <= 0) {
    return 'Số tiền phải lớn hơn 0 và hợp lệ.';
  }

  if (amount > kMaxMoneyAmount) {
    return 'Số tiền quá lớn.';
  }

  if (!expenseCategories.contains(category)) {
    return 'Danh mục không hợp lệ.';
  }

  final reference = now ?? DateTime.now();

  if (date.year < 2000 ||
      date.isAfter(reference.add(const Duration(days: 1)))) {
    return 'Ngày giao dịch không hợp lệ.';
  }

  return null;
}

String? validateExpense(Expense expense, {DateTime? now}) {
  return validateExpenseFields(
    title: expense.title,
    amount: expense.amount,
    category: expense.category,
    date: expense.date,
    now: now,
  );
}