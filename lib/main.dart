
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'data/expense_repository.dart' as data;
import 'services/receipt_ocr.dart';

void main() {
  runApp(const ExpenseApp());
}

const green = Color(0xFF168568);
const dark = Color(0xFF173B32);
const bg = Color(0xFFF5F7F6);
const muted = Color(0xFF89938F);

String money(double value) {
  final digits = value.round().toString();
  final result = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      result.write('.');
    }
    result.write(digits[i]);
  }
  return '${result.toString()} đ';
}

class Expense {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final IconData icon;

  Expense({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.icon,
  });
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monee - Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        fontFamily: 'Arial',
      ),
      home: const ExpenseHome(),
    );
  }
}

class ExpenseHome extends StatefulWidget {
  const ExpenseHome({super.key});

  @override
  State<ExpenseHome> createState() => _ExpenseHomeState();
}

class _ExpenseHomeState extends State<ExpenseHome> {
  int selectedTab = 0;
  final double budget = 8000000;
  late List<Expense> expenses;

  final data.ExpenseRepository _repository =
      data.ExpenseRepository();

  bool _isLoading = true;

  
  @override
  void initState() {
    super.initState();

    expenses = [];
    _loadExpenses();
  }

Future<void> _loadExpenses() async {
  try {
    final savedExpenses = await _repository.getAll();

    if (!mounted) return;

    setState(() {
      expenses = savedExpenses.map((item) {
        return Expense(
          id: item.id,
          title: item.title,
          category: item.category,
          amount: item.amount,
          date: item.date,
          icon: _iconForCategory(item.category),
        );
      }).toList();

      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể tải giao dịch: $e')),
    );
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Ăn uống':
      return Icons.restaurant_rounded;
    case 'Di chuyển':
      return Icons.directions_bike_rounded;
    case 'Mua sắm':
      return Icons.shopping_bag_rounded;
    case 'Hóa đơn':
      return Icons.receipt_long_rounded;
    case 'Giải trí':
      return Icons.movie_rounded;
    default:
      return Icons.receipt_rounded;
  }
}

  // Tổng tiền của tất cả giao dịch trong lịch sử (mọi tháng).
  double get totalSpent =>
      expenses.fold(0, (sum, item) => sum + item.amount);

  // Chỉ tính giao dịch thuộc tháng/năm hiện tại để đối chiếu ngân sách tháng.
  double get monthlySpent {
    final now = DateTime.now();
    return expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get todaySpent {
    final now = DateTime.now();
    return expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0, (sum, e) => sum + e.amount);
  }

  List<Expense> get recentExpenses {
    final result = [...expenses];
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Map<String, double> get categoryTotals {
    final result = <String, double>{};
    for (final e in expenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    return result;
  }

  List<double> get weeklyTotals {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      return expenses
          .where((e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .fold(0.0, (sum, e) => sum + e.amount);
    });
  }


  Future<void> addExpense() async {
    final expense = await showDialog<Expense>(
      context: context,
      builder: (_) => const AddExpenseDialog(),
    );

    if (expense == null) return;

    try {
      // Lưu giao dịch vào bộ nhớ trước
      final savedExpense = await _repository.add(
        data.Expense(
          title: expense.title,
          category: expense.category,
          amount: expense.amount,
          date: expense.date,
        ),
      );

      if (!mounted) return;

      // Chuyển dữ liệu đã lưu về model giao diện
      final displayExpense = Expense(
        id: savedExpense.id,
        title: savedExpense.title,
        category: savedExpense.category,
        amount: savedExpense.amount,
        date: savedExpense.date,
        icon: _iconForCategory(savedExpense.category),
      );

      setState(() {
        expenses.add(displayExpense);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm giao dịch thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu giao dịch: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }



  Future<void> deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text('Bạn muốn xóa "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (expense.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy ID giao dịch để xóa.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _repository.delete(expense.id!);

      if (!mounted) return;

      setState(() {
        expenses.removeWhere((item) => item.id == expense.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa giao dịch thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa giao dịch: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;

            return Row(
              children: [
                if (wide) _sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(wide),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: wide ? 36 : 18,
                            vertical: 24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 1150),
                              child: _pageContent(wide),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 850
          ? NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (value) {
                setState(() => selectedTab = value);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Tổng quan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'Giao dịch',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Thống kê',
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addExpense,
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm chi tiêu'),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 235,
      color: Colors.white,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'monee.',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 42),
          const Text(
            'MENU',
            style: TextStyle(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _navItem(0, Icons.grid_view_rounded, 'Tổng quan'),
          _navItem(1, Icons.receipt_long_rounded, 'Giao dịch'),
          _navItem(2, Icons.insights_rounded, 'Thống kê'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: green, size: 27),
                SizedBox(height: 10),
                Text(
                  'Chi tiêu thông minh',
                  style: TextStyle(
                    color: dark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Theo dõi thói quen và quản lý ngân sách của bạn.',
                  style: TextStyle(
                    color: Color(0xFF668177),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = selectedTab == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        selected: active,
        selectedTileColor: const Color(0xFFE7F4EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(icon, color: active ? green : muted),
        title: Text(
          label,
          style: TextStyle(
            color: active ? green : const Color(0xFF53615B),
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => selectedTab = index),
      ),
    );
  }

  Widget _topBar(bool wide) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 36 : 18,
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'Tổng quan tài chính',
                    'Lịch sử giao dịch',
                    'Phân tích chi tiêu',
                  ][selectedTab],
                  style: const TextStyle(
                    fontSize: 20,
                    color: dark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quản lý tiền bạc, sống chủ động hơn.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: dark,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDDEEE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded, color: green),
          ),
        ],
      ),
    );
  }

  Widget _pageContent(bool wide) {
    if (selectedTab == 1) {
      return _transactionsPage();
    }

    if (selectedTab == 2) {
      return _analyticsPage(wide);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _welcome(),
        const SizedBox(height: 22),
        _summaryCards(wide),
        const SizedBox(height: 22),
        _charts(wide),
        const SizedBox(height: 22),
        _aiCard(),
        const SizedBox(height: 22),
        _transactions(),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _welcome() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xin chào! 👋',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Đây là tình hình chi tiêu của bạn hôm nay.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _scanReceipt,
          icon: const Icon(Icons.document_scanner_outlined, size: 18),
          label: const Text('Quét hóa đơn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: green,
            side: const BorderSide(color: Color(0xFFB7D9CA)),
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _scanReceipt() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR hóa đơn hiện hỗ trợ Android/iOS. Hãy chạy app trên điện thoại.',
          ),
        ),
      );
      return;
    }

    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đang nhận dạng chữ trên hóa đơn...'),
            duration: Duration(seconds: 30),
          ),
        );

      final ocr = ReceiptOcr();
      late final String recognizedText;
      try {
        recognizedText = await ocr.recognizeText(image.path);
      } finally {
        await ocr.close();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (recognizedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không đọc được chữ. Hãy thử chụp hóa đơn rõ và đủ sáng hơn nhé.',
            ),
          ),
        );
        return;
      }

      final extracted = _extractReceiptData(recognizedText);
      final expense = await showDialog<Expense>(
        context: context,
        builder: (_) => ReceiptConfirmDialog(
          initialTitle: extracted.title,
          initialAmount: extracted.amount,
          initialDate: extracted.date,
          rawText: recognizedText,
        ),
      );
      if (expense == null || !mounted) return;

      final savedExpense = await _repository.add(
        data.Expense(
          title: expense.title,
          category: expense.category,
          amount: expense.amount,
          date: expense.date,
        ),
      );
      if (!mounted) return;

      setState(() {
        expenses.add(
          Expense(
            id: savedExpense.id,
            title: savedExpense.title,
            category: savedExpense.category,
            amount: savedExpense.amount,
            date: savedExpense.date,
            icon: _iconForCategory(savedExpense.category),
          ),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã quét và lưu giao dịch thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Không thể quét/lưu hóa đơn: $e')),
        );
    }
  }

  _ReceiptData _extractReceiptData(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .toList();
    final normalized = text.toLowerCase();

    // Nhận diện phiếu chuyển khoản để tuyệt đối không lấy STK làm số tiền.
    final isTransfer = RegExp(
      r'(chuyển khoản|chuyen khoan|giao dịch thành công|giao dich thanh cong|người nhận|nguoi nhan|người chuyển|nguoi chuyen|tài khoản thụ hưởng|tai khoan thu huong|beneficiary|transaction id|mã giao dịch|ma giao dich|ngân hàng|ngan hang|transfer successful)',
      caseSensitive: false,
    ).hasMatch(normalized);

    final amountPattern = RegExp(r'\d[\d.,\s]*\d|\d');
    final accountOrIdLine = RegExp(
      r'(số tài khoản|so tai khoan|stk\b|tài khoản|tai khoan|account number|account no|số thẻ|so the|mã giao dịch|ma giao dich|transaction id|ref(erence)?\s*(no|number)?|số hóa đơn|so hoa don|invoice\s*(no|number)?|điện thoại|dien thoai|phone|sđt)',
      caseSensitive: false,
    );
    final dateOrCountLine = RegExp(
      r'(ngày|ngay|date|giờ|gio|time|số lượng|so luong|quantity|địa chỉ|dia chi|address)',
      caseSensitive: false,
    );

    double? amountFromLine(String line, {bool allowShort = false}) {
      if (accountOrIdLine.hasMatch(line) || dateOrCountLine.hasMatch(line)) {
        return null;
      }
      final matches = amountPattern.allMatches(line).toList();
      for (final match in matches.reversed) {
        final raw = match.group(0)!;
        final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.isEmpty || (!allowShort && digitsOnly.length < 3)) continue;
        final parsed = double.tryParse(digitsOnly);
        if (parsed != null && parsed > 0) return parsed;
      }
      return null;
    }

    double? amount;
    final transferAmountLabel = RegExp(
      r'(số tiền giao dịch|so tien giao dich|số tiền chuyển|so tien chuyen|số tiền|so tien|amount|transaction amount|transfer amount|tổng tiền|tong tien|tổng cộng|tong cong|thành tiền|thanh tien|total amount|grand total|amount due|total|phải trả|phai tra|payable)',
      caseSensitive: false,
    );
    final bankAmountLabel = RegExp(
      r'(số tiền giao dịch|so tien giao dich|số tiền chuyển|so tien chuyen|số tiền|so tien|amount|transaction amount|transfer amount)',
      caseSensitive: false,
    );

    // Ưu tiên nhãn số tiền. Với phiếu chuyển khoản, bỏ qua mọi dòng chứa thông tin tài khoản.
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final hasAmountLabel = (isTransfer ? bankAmountLabel : transferAmountLabel)
          .hasMatch(line);
      if (!hasAmountLabel) continue;
      amount = amountFromLine(line, allowShort: true);
      if (amount != null) break;
      // OCR đôi khi tách nhãn và giá trị sang dòng kế tiếp; không nhảy qua dòng STK.
      for (var offset = 1; offset <= 2 && i + offset < lines.length; offset++) {
        final next = lines[i + offset];
        if (accountOrIdLine.hasMatch(next) || dateOrCountLine.hasMatch(next)) break;
        amount = amountFromLine(next, allowShort: true);
        if (amount != null) break;
      }
      if (amount != null) break;
    }

    // Tiếp theo thử các dòng có đơn vị tiền tệ, nhưng không bao giờ dùng dòng STK/mã giao dịch.
    if (amount == null) {
      final currencyLine = RegExp(
        r'(vnd|vnđ|đồng|dong|\bđ\b|₫|\$|\busd\b)',
        caseSensitive: false,
      );
      for (final line in lines) {
        if (accountOrIdLine.hasMatch(line) || dateOrCountLine.hasMatch(line)) continue;
        if (!currencyLine.hasMatch(line)) continue;
        amount = amountFromLine(line);
        if (amount != null) break;
      }
    }

    // Dự phòng cho hóa đơn giấy: chỉ xét dòng số dài, không xét dòng có vẻ là địa chỉ/mã/ngày.
    // Riêng phiếu chuyển khoản không dùng fallback số bất kỳ vì rất dễ lấy nhầm STK.
    if (amount == null && !isTransfer) {
      for (final line in lines.reversed) {
        if (accountOrIdLine.hasMatch(line) || dateOrCountLine.hasMatch(line)) continue;
        if (RegExp(r'(mã|ma so|zip|postal|tax|vat|bàn|ban|table)', caseSensitive: false)
            .hasMatch(line)) continue;
        final candidate = amountFromLine(line);
        if (candidate != null && candidate >= 1000) {
          amount = candidate;
          break;
        }
      }
    }

    DateTime? parsedDate;
    final datePatterns = <RegExp>[
      RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b'),
      RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b'),
    ];
    for (final line in lines) {
      final dmy = datePatterns[0].firstMatch(line);
      final ymd = datePatterns[1].firstMatch(line);
      try {
        if (dmy != null) {
          parsedDate = DateTime(
            int.parse(dmy.group(3)!),
            int.parse(dmy.group(2)!),
            int.parse(dmy.group(1)!),
          );
        } else if (ymd != null) {
          parsedDate = DateTime(
            int.parse(ymd.group(1)!),
            int.parse(ymd.group(2)!),
            int.parse(ymd.group(3)!),
          );
        }
      } catch (_) {
        parsedDate = null;
      }
      if (parsedDate != null && parsedDate.month >= 1 && parsedDate.month <= 12) break;
      parsedDate = null;
    }

    String? title;
    // Ưu tiên tên người nhận trên phiếu chuyển khoản.
    if (isTransfer) {
      final recipientLabel = RegExp(
        r'(tên người nhận|ten nguoi nhan|người nhận|nguoi nhan|tên người thụ hưởng|ten nguoi thu huong|beneficiary name|recipient name|đến người nhận|den nguoi nhan)',
        caseSensitive: false,
      );
      for (var i = 0; i < lines.length; i++) {
        if (!recipientLabel.hasMatch(lines[i])) continue;
        final afterColon = lines[i].split(RegExp(r'[:：]')).skip(1).join(':').trim();
        if (afterColon.isNotEmpty && !accountOrIdLine.hasMatch(afterColon)) {
          title = afterColon;
        } else if (i + 1 < lines.length &&
            !accountOrIdLine.hasMatch(lines[i + 1]) &&
            !dateOrCountLine.hasMatch(lines[i + 1])) {
          title = lines[i + 1];
        }
        if (title != null) break;
      }
    }

    // Với hóa đơn giấy, bỏ dòng địa chỉ/điện thoại/mã số; ưu tiên tên cửa hàng hơn địa chỉ.
    final excluded = RegExp(
      r'(hóa đơn|hoa don|invoice|receipt|địa chỉ|dia chi|address|đường|duong|phố|pho|phường|phuong|quận|quan|huyện|huyen|tỉnh|tinh|thành phố|thanh pho|mã số|ma so|số hóa đơn|so hoa don|ngày|ngay|date|subtotal|total|tổng|tong|thành tiền|thanh tien|cashier|thu ngân|tax|vat|vnd|vnđ|đồng|dong|hotline|website|www\.|\.com|điện thoại|dien thoai|phone|stk|tài khoản|tai khoan)',
      caseSensitive: false,
    );
    final addressLike = RegExp(
      r'(\b\d{1,5}\s+.*\b(đường|duong|phố|pho|street|road|phường|phuong|quận|quan|ward|district)\b|\b(đường|duong|phố|pho|street|road|phường|phuong|quận|quan|ward|district)\b|\b\d{5,}\b)',
      caseSensitive: false,
    );
    if (title == null) {
      for (final line in lines) {
        if (excluded.hasMatch(line) || addressLike.hasMatch(line)) continue;
        if (!RegExp(r'[a-zA-ZÀ-ỹ]').hasMatch(line)) continue;
        if (RegExp(r'^\d+[\d.,\s]*$').hasMatch(line)) continue;
        // Tránh lấy nguyên dòng dài thường là địa chỉ hoặc thông tin phụ.
        if (line.length > 60) continue;
        title = line;
        break;
      }
    }

    return _ReceiptData(
      title: title ?? (isTransfer ? 'Chuyển khoản' : 'Chi tiêu từ hóa đơn'),
      amount: amount,
      date: parsedDate ?? DateTime.now(),
    );
  }

  Widget _summaryCards(bool wide) {
    final cards = [
      _summaryCard(
        'Tổng chi tiêu',
        money(totalSpent),
        Icons.account_balance_wallet_rounded,
        const Color(0xFFE0F2E9),
        'Tất cả giao dịch mẫu',
      ),
      _summaryCard(
        'Chi tiêu hôm nay',
        money(todaySpent),
        Icons.trending_down_rounded,
        const Color(0xFFFFEBDD),
        'Trong ngày hiện tại',
      ),
      _summaryCard(
        'Ngân sách còn lại',
        money(math.max(0, budget - monthlySpent).toDouble()),
        Icons.savings_rounded,
        const Color(0xFFE4E9FF),
        'Chi tiêu tháng này / ngân sách 8 triệu',
      ),
    ];

    if (!wide) {
      return Column(
        children: [
          for (final card in cards) ...[
            card,
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 15),
        ],
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String amount,
    IconData icon,
    Color iconBg,
    String note,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEAEFEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: green, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: dark,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            note,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _charts(bool wide) {
    final donut = _donutCard();
    final bars = _weeklyCard();

    if (!wide) {
      return Column(
        children: [
          donut,
          const SizedBox(height: 16),
          bars,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: donut),
        const SizedBox(width: 16),
        Expanded(flex: 6, child: bars),
      ],
    );
  }

  Widget _donutCard() {
    final totals = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      green,
      const Color(0xFFF0B65C),
      const Color(0xFF7296E8),
      const Color(0xFFE78E8E),
      const Color(0xFFAD8ED6),
      const Color(0xFF73B8BC),
    ];

    final sections = <DonutSection>[];
    for (int i = 0; i < totals.length; i++) {
      sections.add(
        DonutSection(
          label: totals[i].key,
          value: totals[i].value,
          color: colors[i % colors.length],
        ),
      );
    }

    return _panel(
      title: 'Cơ cấu chi tiêu',
      subtitle: 'Theo danh mục',
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 205,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: DonutPainter(sections),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tổng cộng',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      money(totalSpent),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < totals.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      totals[i].key,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  Text(
                    money(totals[i].value),
                    style: const TextStyle(
                      fontSize: 12,
                      color: dark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _weeklyCard() {
    final values = weeklyTotals;
    final maxValue = values.fold(0.0, math.max);
    final average = values.fold(0.0, (a, b) => a + b) / 7;

    return _panel(
      title: 'Chi tiêu hằng tuần',
      subtitle: '7 ngày gần nhất',
      trailing: const Icon(
        Icons.bar_chart_rounded,
        color: green,
        size: 25,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            money(values.fold(0.0, (a, b) => a + b)),
            style: const TextStyle(
              color: dark,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tổng chi tiêu trong 7 ngày',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: WeeklyBarPainter(
                values: values,
                maxValue: maxValue,
                today: DateTime.now().weekday,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, color: green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trung bình ${money(average)} mỗi ngày.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAEFEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _aiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B32), Color(0xFF246C53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✦ SMART FINANCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chi tiêu thông minh hơn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phân tích thói quen, tìm khoản chi lớn '
                  'và đề xuất mục tiêu tiết kiệm cùng AI.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 17),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Trợ lý tài chính AI'),
                        content: Text(
                          'Bạn đã ghi nhận ${expenses.length} giao dịch '
                          'với tổng số tiền ${money(totalSpent)}. '
                          'Bước tiếp theo sẽ tích hợp Gemini để phân tích '
                          'chi tiêu và đề xuất ngân sách. '
                          'Hiện tại đây chưa phải kết quả do Gemini tạo.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: const Text('Khám phá AI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.psychology_alt_rounded,
            color: Color(0xFFB5E7CE),
            size: 70,
          ),
        ],
      ),
    );
  }

  Widget _transactions() {
    return _panel(
      title: 'Giao dịch gần đây',
      subtitle: '${expenses.length} giao dịch',
      trailing: TextButton(
        onPressed: () => setState(() => selectedTab = 1),
        child: const Text(
          'Xem tất cả →',
          style: TextStyle(color: green, fontWeight: FontWeight.bold),
        ),
      ),
      child: _expenseList(recentExpenses.take(5).toList()),
    );
  }

  Widget _transactionsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          title: 'Tất cả giao dịch',
          subtitle: '${expenses.length} giao dịch đã ghi nhận',
          trailing: IconButton(
            onPressed: addExpense,
            icon: const Icon(Icons.add_circle, color: green, size: 30),
          ),
          child: _expenseList(recentExpenses),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _expenseList(List<Expense> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(25),
        child: Center(child: Text('Chưa có giao dịch nào.')),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Divider(height: 20, color: Color(0xFFEDF0EE)),
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  items[i].icon,
                  color: green,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].title,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${items[i].category} • ${items[i].date.day.toString().padLeft(2, '0')}/${items[i].date.month.toString().padLeft(2, '0')}/${items[i].date.year}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '-${money(items[i].amount)}',
                style: const TextStyle(
                  color: dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (value) {
                  if (value == 'delete') deleteExpense(items[i]);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa giao dịch'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _analyticsPage(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCards(wide),
        const SizedBox(height: 20),
        _charts(wide),
        const SizedBox(height: 20),
        _panel(
          title: 'Ngân sách tháng',
          subtitle: 'So sánh chi tiêu với giới hạn',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Đã sử dụng',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${(monthlySpent / budget * 100).clamp(0, 100).round()}%',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (monthlySpent / budget).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE5EBE7),
                  color: monthlySpent > budget ? Colors.red : green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${money(monthlySpent)} / ${money(budget)}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }
}

class _ReceiptData {
  final String title;
  final double? amount;
  final DateTime date;

  const _ReceiptData({
    required this.title,
    required this.amount,
    required this.date,
  });
}

class ReceiptConfirmDialog extends StatefulWidget {
  final String initialTitle;
  final double? initialAmount;
  final DateTime initialDate;
  final String rawText;

  const ReceiptConfirmDialog({
    super.key,
    required this.initialTitle,
    required this.initialAmount,
    required this.initialDate,
    required this.rawText,
  });

  @override
  State<ReceiptConfirmDialog> createState() => _ReceiptConfirmDialogState();
}

class _ReceiptConfirmDialogState extends State<ReceiptConfirmDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  String category = 'Ăn uống';
  late DateTime date;

  final categories = <String, IconData>{
    'Ăn uống': Icons.restaurant_rounded,
    'Di chuyển': Icons.directions_bike_rounded,
    'Mua sắm': Icons.shopping_bag_rounded,
    'Hóa đơn': Icons.receipt_long_rounded,
    'Giải trí': Icons.movie_rounded,
    'Khác': Icons.category_rounded,
  };

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle);
    amountController = TextEditingController(
      text: widget.initialAmount == null
          ? ''
          : widget.initialAmount!.round().toString(),
    );
    date = widget.initialDate;
    category = _guessCategory(widget.initialTitle);
  }

  String _guessCategory(String title) {
    final value = title.toLowerCase();
    if (RegExp(r'cafe|cà phê|coffee|nhà hàng|restaurant|ăn|food|trà sữa').hasMatch(value)) {
      return 'Ăn uống';
    }
    if (RegExp(r'grab|taxi|xăng|gas|xe|be\b|di chuyển|parking').hasMatch(value)) {
      return 'Di chuyển';
    }
    if (RegExp(r'siêu thị|shopping|shop|quần áo|mua sắm|store').hasMatch(value)) {
      return 'Mua sắm';
    }
    if (RegExp(r'điện|nước|internet|hóa đơn|bill').hasMatch(value)) {
      return 'Hóa đơn';
    }
    return 'Khác';
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận giao dịch'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Thông tin được tự động nhận diện. Hãy kiểm tra và sửa nếu cần.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tên cửa hàng / giao dịch',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên giao dịch'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số tiền (VNĐ)',
                    border: const OutlineInputBorder(),
                    helperText: widget.initialAmount == null
                        ? 'Chưa tự nhận diện được số tiền; hãy nhập thủ công.'
                        : 'Kiểm tra số tiền trước khi lưu.',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                    return parsed == null || parsed <= 0
                        ? 'Nhập số tiền lớn hơn 0'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: categories.keys
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => category = value);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date.isAfter(DateTime.now()) ? DateTime.now() : date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text('Ngày ${date.day}/${date.month}/${date.year}'),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Xem nội dung OCR gốc'),
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          widget.rawText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: green),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final amount = double.parse(
              amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            Navigator.pop(
              context,
              Expense(
                title: titleController.text.trim(),
                category: category,
                amount: amount,
                date: date,
                icon: categories[category]!,
              ),
            );
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('Lưu giao dịch'),
        ),
      ],
    );
  }
}

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final amountController = TextEditingController();

  String category = 'Ăn uống';
  DateTime date = DateTime.now();

  final categories = <String, IconData>{
    'Ăn uống': Icons.restaurant_rounded,
    'Di chuyển': Icons.directions_bike_rounded,
    'Mua sắm': Icons.shopping_bag_rounded,
    'Hóa đơn': Icons.receipt_long_rounded,
    'Giải trí': Icons.movie_rounded,
    'Khác': Icons.category_rounded,
  };

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Thêm chi tiêu',
        style: TextStyle(fontWeight: FontWeight.w800, color: dark),
      ),
      content: SizedBox(
        width: 390,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tên giao dịch',
                    hintText: 'Ví dụ: Ăn trưa',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tên giao dịch'
                          : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền (VNĐ)',
                    hintText: 'Ví dụ: 50000',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', ''),
                    );
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Số tiền phải lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: categories.keys
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => category = value);
                  },
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) {
                      setState(() => date = selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    'Ngày ${date.day}/${date.month}/${date.year}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: green),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;

            final amount = double.parse(
              amountController.text.trim().replaceAll(',', ''),
            );

            Navigator.pop(
              context,
              Expense(
                title: titleController.text.trim(),
                category: category,
                amount: amount,
                date: date,
                icon: categories[category]!,
              ),
            );
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Lưu giao dịch'),
        ),
      ],
    );
  }
}

class DonutSection {
  final String label;
  final double value;
  final Color color;

  const DonutSection({
    required this.label,
    required this.value,
    required this.color,
  });
}

class DonutPainter extends CustomPainter {
  final List<DonutSection> sections;

  DonutPainter(this.sections);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;

    final total = sections.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) {
      paint.color = const Color(0xFFE5EBE7);
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    double start = -math.pi / 2;

    for (final section in sections) {
      final sweep = section.value / total * math.pi * 2;
      paint.color = section.color;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - 0.035),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) => true;
}

class WeeklyBarPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final int today;

  WeeklyBarPainter({
    required this.values,
    required this.maxValue,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 5.0;
    const bottom = 25.0;
    const top = 8.0;
    final chartHeight = size.height - bottom - top;
    final chartWidth = size.width - left * 2;
    final slot = chartWidth / 7;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDF1EE)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - left, y),
        gridPaint,
      );
    }

    final now = DateTime.now();
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    for (int i = 0; i < 7; i++) {
      final barHeight = maxValue <= 0
          ? 3.0
          : chartHeight * values[i] / maxValue;

      final x = left + i * slot + slot * 0.23;
      final barWidth = slot * 0.54;
      final y = top + chartHeight - barHeight;

      final date = now.subtract(Duration(days: 6 - i));
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final paint = Paint()
        ..color = isToday ? green : const Color(0xFFCBE7D8);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          y,
          barWidth,
          math.min(chartHeight, barHeight),
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, paint);

      final weekday = date.weekday;
      final label = labels[weekday - 1];

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          color: isToday ? green : muted,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + (barWidth - textPainter.width) / 2,
          size.height - 17,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyBarPainter oldDelegate) => true;
}
