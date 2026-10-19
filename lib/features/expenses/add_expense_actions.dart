import 'package:flutter/material.dart';

import '../receipt_scanner/screens/receipt_scanner_screen.dart';
import 'screens/expense_form_screen.dart';

/// Mở form thêm giao dịch thủ công. Trả về true nếu đã lưu.
Future<bool> openExpenseForm(BuildContext context) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const ExpenseFormScreen()),
  );

  return saved == true;
}

/// Mở màn quét hóa đơn. Trả về true nếu giao dịch đã được lưu.
Future<bool> openReceiptScanner(BuildContext context) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const ReceiptScannerScreen()),
  );

  return saved == true;
}

enum _AddChoice { manual, scan }

/// Hộp chọn "Thêm thủ công" hoặc "Quét hóa đơn".
Future<void> showAddExpenseOptions(BuildContext context) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Thêm thủ công'),
              subtitle: const Text('Nhập tên, số tiền, danh mục và ngày'),
              onTap: () => Navigator.pop(sheetContext, _AddChoice.manual),
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Quét hóa đơn'),
              subtitle: const Text('Chụp hoặc chọn ảnh, tự động điền gợi ý'),
              onTap: () => Navigator.pop(sheetContext, _AddChoice.scan),
            ),
          ],
        ),
      );
    },
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _AddChoice.manual:
      await openExpenseForm(context);
    case _AddChoice.scan:
      await openReceiptScanner(context);
  }
}