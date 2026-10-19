import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/expense_categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money_parser.dart';
import '../../../data/models/expense.dart';
import '../../receipt_scanner/expense_draft.dart';
import '../category_icons.dart';
import '../providers/expense_controller.dart';
import '../widgets/receipt_image.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.expense, this.draft});

  /// Giao dịch đang sửa. null nghĩa là thêm mới.
  final Expense? expense;

  /// Dữ liệu gợi ý từ OCR (chưa được lưu).
  final ExpenseDraft? draft;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final ExpenseController _controller;

  late String _category;
  late DateTime _date;

  /// Ảnh mới chọn (còn ở thư mục tạm, chưa lưu bền vững).
  String? _newReceiptPath;
  bool _removeReceipt = false;

  bool _saving = false;
  bool _saved = false;
  String? _error;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    _controller = context.read<ExpenseController>();

    final expense = widget.expense;
    final draft = widget.draft;
    final today = DateTime.now();

    if (expense != null) {
      _titleController = TextEditingController(text: expense.title);
      _amountController = TextEditingController(
        text: expense.amount.round().toString(),
      );
      _category = expenseCategories.contains(expense.category)
          ? expense.category
          : otherExpenseCategory;
      _date = expense.date;
    } else if (draft != null) {
      _titleController = TextEditingController(text: draft.title);
      _amountController = TextEditingController(
        text: draft.amount == null ? '' : draft.amount!.round().toString(),
      );
      _category = expenseCategories.contains(draft.category)
          ? draft.category
          : otherExpenseCategory;
      _date = draft.date;
      _newReceiptPath = draft.receiptSourcePath;
    } else {
      _titleController = TextEditingController();
      _amountController = TextEditingController();
      _category = defaultExpenseCategory;
      _date = DateTime(today.year, today.month, today.day);
    }
  }

  @override
  void dispose() {
    // Người dùng thoát mà không lưu: dọn ảnh tạm còn sót.
    final leftover = _newReceiptPath;

    if (!_saved && leftover != null) {
      _controller.discardTemporaryImage(leftover);
    }

    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // VALIDATE
  // ----------------------------------------------------------

  String? _validateTitle(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return 'Tên giao dịch không được để trống.';
    if (text.length > 120) return 'Tên giao dịch tối đa 120 ký tự.';

    return null;
  }

  String? _validateAmount(String? value) {
    final amount = parseAmountInput(value ?? '');

    if (amount == null) {
      return 'Số tiền không hợp lệ. Ví dụ: 50000 hoặc 50.000';
    }

    if (amount <= 0) return 'Số tiền phải lớn hơn 0.';
    if (amount > kMaxMoneyAmount) return 'Số tiền quá lớn.';

    return null;
  }

  // ----------------------------------------------------------
  // HÀNH ĐỘNG
  // ----------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final initial = _date.isAfter(lastDate) ? lastDate : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      helpText: 'Chọn ngày giao dịch',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 90,
      );

      if (picked == null) return;

      if (!mounted) {
        _controller.discardTemporaryImage(picked.path);
        return;
      }

      final previous = _newReceiptPath;

      setState(() {
        _newReceiptPath = picked.path;
        _removeReceipt = false;
      });

      if (previous != null && previous != picked.path) {
        _controller.discardTemporaryImage(previous);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể mở camera hoặc thư viện ảnh. '
            'Hãy kiểm tra quyền truy cập.',
          ),
        ),
      );
    }
  }

  Future<void> _showReceiptOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh hóa đơn'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickReceipt(source);
    }
  }

  void _removeCurrentReceipt() {
    final previous = _newReceiptPath;

    setState(() {
      _newReceiptPath = null;
      _removeReceipt = true;
    });

    if (previous != null) {
      _controller.discardTemporaryImage(previous);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = parseAmountInput(_amountController.text);

    if (amount == null) return;

    final hadNewReceipt = _newReceiptPath != null;

    setState(() {
      _saving = true;
      _error = null;
    });

    final original = widget.expense;
    final title = _titleController.text.trim();

    final String? error;

    if (original == null) {
      error = await _controller.add(
        title: title,
        amount: amount,
        category: _category,
        date: _date,
        receiptSourcePath: _newReceiptPath,
      );
    } else {
      error = await _controller.update(
        original,
        title: title,
        amount: amount,
        category: _category,
        date: _date,
        newReceiptSourcePath: _newReceiptPath,
        removeReceipt: _removeReceipt,
      );
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        // Controller đã dọn ảnh tạm sau lần lưu này, cần chọn lại.
        _newReceiptPath = null;
        _error = hadNewReceipt
            ? '$error Vui lòng đính kèm lại ảnh hóa đơn.'
            : error;
      });
      return;
    }

    _saved = true;
    Navigator.pop(context, true);
  }

  // ----------------------------------------------------------
  // GIAO DIỆN
  // ----------------------------------------------------------

  String get _title {
    if (_isEditing) return 'Sửa giao dịch';
    if (widget.draft != null) return 'Xác nhận hóa đơn';

    return 'Thêm giao dịch';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (draft != null) _OcrBanner(draft: draft),
                    if (_error != null) _ErrorBanner(message: _error!),
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Tên giao dịch',
                        prefixIcon: Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Số tiền',
                        prefixIcon: Icon(Icons.payments_outlined),
                        suffixText: 'đ',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Danh mục',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in expenseCategories)
                          ChoiceChip(
                            avatar: Icon(
                              iconForCategory(category),
                              size: 18,
                              color: colorForCategory(category),
                            ),
                            label: Text(category),
                            selected: _category == category,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _saving ? null : _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày giao dịch',
                          prefixIcon: Icon(Icons.event_outlined),
                          suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(formatDate(_date)),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 20),
                      _buildReceiptSection(scheme),
                    ],
                    if (draft?.rawText != null &&
                        draft!.rawText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Văn bản OCR đã nhận dạng'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [SelectableText(draft.rawText!)],
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isEditing ? 'Lưu thay đổi' : 'Lưu giao dịch',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSection(ColorScheme scheme) {
    final existing = widget.expense?.receiptImagePath;
    final String? shownPath =
        _newReceiptPath ?? (_removeReceipt ? null : existing);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ảnh hóa đơn (không bắt buộc)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (shownPath != null) ...[
              ReceiptImage(path: shownPath, height: 180),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _showReceiptOptions,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(shownPath == null ? 'Đính kèm ảnh' : 'Đổi ảnh'),
                  ),
                ),
                if (shownPath != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Gỡ ảnh hóa đơn',
                    onPressed: _saving ? null : _removeCurrentReceipt,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrBanner extends StatelessWidget {
  const _OcrBanner({required this.draft});

  final ExpenseDraft draft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final message = draft.rawText == null
        ? 'Hãy nhập thông tin giao dịch cho hóa đơn này.'
        : 'Dữ liệu được nhận dạng tự động và chỉ mang tính gợi ý. '
            'Hãy kiểm tra, sửa nếu cần rồi mới lưu.'
            '${draft.amount == null ? '\nChưa nhận diện được số tiền, vui lòng nhập.' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 20,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}