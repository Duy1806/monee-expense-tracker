import '../core/constants/app_constants.dart';

class ReceiptData {
  const ReceiptData({
    required this.title,
    required this.amount,
    required this.date,
  });

  final String title;

  /// null nghĩa là không nhận diện được; người dùng phải tự nhập.
  final double? amount;
  final DateTime date;
}

// ------------------------------------------------------------
// Các biểu thức chính quy được giữ nguyên từ main.dart cũ.
// ------------------------------------------------------------

final RegExp _transferPattern = RegExp(
  r'(chuyển khoản|chuyen khoan|giao dịch thành công|giao dich thanh cong|người nhận|nguoi nhan|người chuyển|nguoi chuyen|tài khoản thụ hưởng|tai khoan thu huong|beneficiary|transaction id|mã giao dịch|ma giao dich|ngân hàng|ngan hang|transfer successful)',
  caseSensitive: false,
);

final RegExp _amountPattern = RegExp(r'\d[\d.,\s]*\d|\d');

final RegExp _accountOrIdLine = RegExp(
  r'(số tài khoản|so tai khoan|stk\b|tài khoản|tai khoan|account number|account no|số thẻ|so the|mã giao dịch|ma giao dich|transaction id|ref(erence)?\s*(no|number)?|số hóa đơn|so hoa don|invoice\s*(no|number)?|điện thoại|dien thoai|phone|sđt)',
  caseSensitive: false,
);

final RegExp _dateOrCountLine = RegExp(
  r'(ngày|ngay|date|giờ|gio|time|số lượng|so luong|quantity|địa chỉ|dia chi|address)',
  caseSensitive: false,
);

final RegExp _receiptAmountLabel = RegExp(
  r'(số tiền giao dịch|so tien giao dich|số tiền chuyển|so tien chuyen|số tiền|so tien|amount|transaction amount|transfer amount|tổng tiền|tong tien|tổng cộng|tong cong|thành tiền|thanh tien|total amount|grand total|amount due|total|phải trả|phai tra|payable)',
  caseSensitive: false,
);

final RegExp _bankAmountLabel = RegExp(
  r'(số tiền giao dịch|so tien giao dich|số tiền chuyển|so tien chuyen|số tiền|so tien|amount|transaction amount|transfer amount)',
  caseSensitive: false,
);

final RegExp _currencyLine = RegExp(
  r'(vnd|vnđ|đồng|dong|\bđ\b|₫|\$|\busd\b)',
  caseSensitive: false,
);

final RegExp _longNumberSkip = RegExp(
  r'(mã|ma so|zip|postal|tax|vat|bàn|ban|table)',
  caseSensitive: false,
);

final RegExp _dmyPattern = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b');
final RegExp _ymdPattern = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');

final RegExp _recipientLabel = RegExp(
  r'(tên người nhận|ten nguoi nhan|người nhận|nguoi nhan|tên người thụ hưởng|ten nguoi thu huong|beneficiary name|recipient name|đến người nhận|den nguoi nhan)',
  caseSensitive: false,
);

final RegExp _excludedTitle = RegExp(
  r'(hóa đơn|hoa don|invoice|receipt|địa chỉ|dia chi|address|đường|duong|phố|pho|phường|phuong|quận|quan|huyện|huyen|tỉnh|tinh|thành phố|thanh pho|mã số|ma so|số hóa đơn|so hoa don|ngày|ngay|date|subtotal|total|tổng|tong|thành tiền|thanh tien|cashier|thu ngân|tax|vat|vnd|vnđ|đồng|dong|hotline|website|www\.|\.com|điện thoại|dien thoai|phone|stk|tài khoản|tai khoan)',
  caseSensitive: false,
);

final RegExp _addressLike = RegExp(
  r'(\b\d{1,5}\s+.*\b(đường|duong|phố|pho|street|road|phường|phuong|quận|quan|ward|district)\b|\b(đường|duong|phố|pho|street|road|phường|phuong|quận|quan|ward|district)\b|\b\d{5,}\b)',
  caseSensitive: false,
);

class ReceiptParser {
  const ReceiptParser();

  /// [now] chỉ dùng làm ngày mặc định khi không đọc được ngày trên hóa đơn.
  ReceiptData parse(String text, {DateTime? now}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .toList();

    // Nhận diện phiếu chuyển khoản để không lấy số tài khoản làm số tiền.
    final isTransfer = _transferPattern.hasMatch(text.toLowerCase());

    final amount = _extractAmount(lines, isTransfer);
    final date = _extractDate(lines) ?? (now ?? DateTime.now());
    var title = _extractTitle(lines, isTransfer) ??
        (isTransfer ? 'Chuyển khoản' : 'Chi tiêu từ hóa đơn');

    if (title.length > 120) {
      title = title.substring(0, 120);
    }

    return ReceiptData(title: title, amount: amount, date: date);
  }

  double? _amountFromLine(String line, {bool allowShort = false}) {
    if (_accountOrIdLine.hasMatch(line) || _dateOrCountLine.hasMatch(line)) {
      return null;
    }

    final matches = _amountPattern.allMatches(line).toList();

    for (final match in matches.reversed) {
      final raw = match.group(0)!;
      final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');

      if (digitsOnly.isEmpty || (!allowShort && digitsOnly.length < 3)) {
        continue;
      }

      final parsed = double.tryParse(digitsOnly);

      if (parsed != null && parsed > 0 && parsed <= kMaxMoneyAmount) {
        return parsed;
      }
    }

    return null;
  }

  double? _extractAmount(List<String> lines, bool isTransfer) {
    final label = isTransfer ? _bankAmountLabel : _receiptAmountLabel;

    // 1) Ưu tiên dòng có nhãn số tiền. OCR đôi khi tách nhãn và giá trị
    //    sang dòng kế tiếp; không nhảy qua dòng STK/ngày.
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (!label.hasMatch(line)) continue;

      final onSameLine = _amountFromLine(line, allowShort: true);

      if (onSameLine != null) return onSameLine;

      for (var offset = 1; offset <= 2 && i + offset < lines.length; offset++) {
        final next = lines[i + offset];

        if (_accountOrIdLine.hasMatch(next) || _dateOrCountLine.hasMatch(next)) {
          break;
        }

        final onNextLine = _amountFromLine(next, allowShort: true);

        if (onNextLine != null) return onNextLine;
      }
    }

    // 2) Các dòng có đơn vị tiền tệ, bỏ dòng STK/mã giao dịch.
    for (final line in lines) {
      if (_accountOrIdLine.hasMatch(line) || _dateOrCountLine.hasMatch(line)) {
        continue;
      }

      if (!_currencyLine.hasMatch(line)) continue;

      final amount = _amountFromLine(line);

      if (amount != null) return amount;
    }

    // 3) Dự phòng cho hóa đơn giấy. Phiếu chuyển khoản không dùng bước này
    //    vì rất dễ lấy nhầm số tài khoản.
    if (!isTransfer) {
      for (final line in lines.reversed) {
        if (_accountOrIdLine.hasMatch(line) || _dateOrCountLine.hasMatch(line)) {
          continue;
        }

        if (_longNumberSkip.hasMatch(line)) continue;

        final candidate = _amountFromLine(line);

        if (candidate != null && candidate >= 1000) return candidate;
      }
    }

    return null;
  }

  DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);

    // DateTime tự cuộn ngày (31/02 -> 03/03); từ chối các ngày bị cuộn.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final dmy = _dmyPattern.firstMatch(line);
      final ymd = _ymdPattern.firstMatch(line);
      DateTime? candidate;

      if (dmy != null) {
        candidate = _validDate(
          int.parse(dmy.group(3)!),
          int.parse(dmy.group(2)!),
          int.parse(dmy.group(1)!),
        );
      } else if (ymd != null) {
        candidate = _validDate(
          int.parse(ymd.group(1)!),
          int.parse(ymd.group(2)!),
          int.parse(ymd.group(3)!),
        );
      }

      if (candidate != null) return candidate;
    }

    return null;
  }

  String? _extractTitle(List<String> lines, bool isTransfer) {
    // Ưu tiên tên người nhận trên phiếu chuyển khoản.
    if (isTransfer) {
      for (var i = 0; i < lines.length; i++) {
        if (!_recipientLabel.hasMatch(lines[i])) continue;

        final afterColon =
            lines[i].split(RegExp(r'[:：]')).skip(1).join(':').trim();

        if (afterColon.isNotEmpty && !_accountOrIdLine.hasMatch(afterColon)) {
          return afterColon;
        }

        if (i + 1 < lines.length &&
            !_accountOrIdLine.hasMatch(lines[i + 1]) &&
            !_dateOrCountLine.hasMatch(lines[i + 1])) {
          return lines[i + 1];
        }
      }
    }

    // Hóa đơn giấy: bỏ dòng địa chỉ/điện thoại/mã số, ưu tiên tên cửa hàng.
    for (final line in lines) {
      if (_excludedTitle.hasMatch(line) || _addressLike.hasMatch(line)) {
        continue;
      }

      if (!RegExp(r'[a-zA-ZÀ-ỹ]').hasMatch(line)) continue;
      if (RegExp(r'^\d+[\d.,\s]*$').hasMatch(line)) continue;
      if (line.length > 60) continue;

      return line;
    }

    return null;
  }
}

/// Đoán danh mục từ tên giao dịch. Quy tắc cũ được giữ nguyên; ba nhóm
/// Sức khỏe, Giải trí, Giáo dục là phần bổ sung.
String guessCategory(String title) {
  final value = title.toLowerCase();

  if (RegExp(r'cafe|cà phê|coffee|nhà hàng|restaurant|ăn|food|trà sữa')
      .hasMatch(value)) {
    return 'Ăn uống';
  }

  if (RegExp(r'grab|taxi|xăng|gas|xe|be\b|di chuyển|parking')
      .hasMatch(value)) {
    return 'Di chuyển';
  }

  if (RegExp(r'siêu thị|shopping|shop|quần áo|mua sắm|store')
      .hasMatch(value)) {
    return 'Mua sắm';
  }

  if (RegExp(r'điện|nước|internet|hóa đơn|bill').hasMatch(value)) {
    return 'Hóa đơn';
  }

  if (RegExp(r'thuốc|pharmacy|bệnh viện|phòng khám|y tế').hasMatch(value)) {
    return 'Sức khỏe';
  }

  if (RegExp(r'rạp|cinema|phim|karaoke|game').hasMatch(value)) {
    return 'Giải trí';
  }

  if (RegExp(r'học phí|khóa học|sách|school|course|trường').hasMatch(value)) {
    return 'Giáo dục';
  }

  return 'Khác';
}