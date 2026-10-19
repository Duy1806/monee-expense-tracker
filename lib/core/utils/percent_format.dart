/// Định dạng phần trăm làm tròn, ví dụ `+12%`, `-8%`, `0%`.
String formatPercent(double value, {bool showSign = true}) {
  if (!value.isFinite) return '0%';

  final rounded = value.round();

  if (rounded == 0) return '0%';

  final sign = showSign && rounded > 0 ? '+' : '';

  return '$sign$rounded%';
}

/// Câu mô tả thay đổi so với một mốc, ví dụ
/// `Tăng 50% so với tháng trước`.
String describeChange(double? percent, String baseline) {
  if (percent == null || !percent.isFinite) {
    return 'Chưa có dữ liệu $baseline để so sánh';
  }

  final rounded = percent.round();

  if (rounded == 0) return 'Không đổi so với $baseline';

  final verb = rounded > 0 ? 'Tăng' : 'Giảm';

  return '$verb ${rounded.abs()}% so với $baseline';
}