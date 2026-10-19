import '../../core/utils/text_utils.dart';
import '../../data/models/expense.dart';

enum ExpenseSort { dateDesc, dateAsc, amountDesc, amountAsc }

class ExpenseFilter {
  const ExpenseFilter({
    this.query = '',
    this.category,
    this.start,
    this.end,
    this.sort = ExpenseSort.dateDesc,
  });

  final String query;
  final String? category;
  final DateTime? start;
  final DateTime? end;
  final ExpenseSort sort;

  bool get isActive =>
      query.trim().isNotEmpty ||
      category != null ||
      start != null ||
      end != null;

  ExpenseFilter copyWith({String? query, ExpenseSort? sort}) {
    return ExpenseFilter(
      query: query ?? this.query,
      category: category,
      start: start,
      end: end,
      sort: sort ?? this.sort,
    );
  }

  ExpenseFilter withCategory(String? value) {
    return ExpenseFilter(
      query: query,
      category: value,
      start: start,
      end: end,
      sort: sort,
    );
  }

  ExpenseFilter withDateRange(DateTime? newStart, DateTime? newEnd) {
    return ExpenseFilter(
      query: query,
      category: category,
      start: newStart,
      end: newEnd,
      sort: sort,
    );
  }

  /// Xóa mọi bộ lọc nhưng giữ cách sắp xếp.
  ExpenseFilter cleared() => ExpenseFilter(sort: sort);
}

int compareExpensesNewestFirst(Expense a, Expense b) {
  final byDate = b.date.compareTo(a.date);

  if (byDate != 0) return byDate;

  return (b.id ?? 0).compareTo(a.id ?? 0);
}

int _compare(Expense a, Expense b, ExpenseSort sort) {
  switch (sort) {
    case ExpenseSort.dateDesc:
      return compareExpensesNewestFirst(a, b);
    case ExpenseSort.dateAsc:
      {
        final byDate = a.date.compareTo(b.date);

        if (byDate != 0) return byDate;

        return (a.id ?? 0).compareTo(b.id ?? 0);
      }
    case ExpenseSort.amountDesc:
      {
        final byAmount = b.amount.compareTo(a.amount);

        if (byAmount != 0) return byAmount;

        return compareExpensesNewestFirst(a, b);
      }
    case ExpenseSort.amountAsc:
      {
        final byAmount = a.amount.compareTo(b.amount);

        if (byAmount != 0) return byAmount;

        return compareExpensesNewestFirst(a, b);
      }
  }
}

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

List<Expense> applyExpenseFilter(List<Expense> source, ExpenseFilter filter) {
  final query = normalizeForSearch(filter.query);
  final start = filter.start == null ? null : _dayOnly(filter.start!);
  final end = filter.end == null ? null : _dayOnly(filter.end!);

  final result = source.where((expense) {
    if (filter.category != null && expense.category != filter.category) {
      return false;
    }

    if (query.isNotEmpty &&
        !normalizeForSearch(expense.title).contains(query)) {
      return false;
    }

    final day = _dayOnly(expense.date);

    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;

    return true;
  }).toList();

  result.sort((a, b) => _compare(a, b, filter.sort));

  return result;
}

double sumAmount(Iterable<Expense> expenses) {
  return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
}