import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../services/receipt_ocr.dart';
import '../../expenses/providers/expense_controller.dart';
import '../../expenses/screens/expense_form_screen.dart';
import '../../expenses/widgets/receipt_image.dart';
import '../expense_draft.dart';
import '../providers/receipt_scan_controller.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key, this.controller});

  /// Chỉ dùng cho test. Khi null, màn hình tự tạo controller dùng
  /// camera/thư viện thật và ML Kit.
  final ReceiptScanController? controller;

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  late final ReceiptScanController _scan;
  late final ExpenseController _expenses;
  ReceiptOcr? _ocr;
  bool _ownsController = false;

  /// Đã chuyển quyền sở hữu ảnh sang form.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();

    _expenses = context.read<ExpenseController>();

    final injected = widget.controller;

    if (injected != null) {
      _scan = injected;
    } else {
      final ocr = ReceiptOcr();

      _ocr = ocr;
      _ownsController = true;
      _scan = ReceiptScanController(
        pickImage: _pickImage,
        recognizeText: ocr.recognizeText,
      );
    }
  }

  @override
  void dispose() {
    final leftover = _scan.pickedImagePath;

    if (!_handedOver && leftover != null) {
      _expenses.discardTemporaryImage(leftover);
    }

    _ocr?.close();

    if (_ownsController) {
      _scan.dispose();
    }

    super.dispose();
  }

  Future<String?> _pickImage(ReceiptImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source == ReceiptImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 90,
    );

    return picked?.path;
  }

  Future<void> _startScan(ReceiptImageSource source) async {
    final previous = _scan.pickedImagePath;

    final draft = await _scan.scan(source);

    // Ảnh cũ đã bị thay bằng ảnh mới: dọn ảnh cũ.
    if (previous != null && _scan.pickedImagePath != previous) {
      _expenses.discardTemporaryImage(previous);
    }

    if (!mounted || draft == null) return;

    _openForm(draft);
  }

  Future<void> _retry() async {
    final draft = await _scan.retryRecognition();

    if (!mounted || draft == null) return;

    _openForm(draft);
  }

  void _openManual() {
    _openForm(_scan.manualDraft());
  }

  void _openForm(ExpenseDraft draft) {
    _handedOver = true;

    Navigator.of(context).pushReplacement<bool, bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ExpenseFormScreen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: kIsWeb ? _buildUnsupported() : _buildScanner(),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupported() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.desktop_access_disabled_outlined,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Quét hóa đơn chỉ hỗ trợ Android và iOS.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Trên trình duyệt bạn vẫn có thể nhập giao dịch thủ công.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openManual,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Nhập thủ công'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return ListenableBuilder(
      listenable: _scan,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final picked = _scan.pickedImagePath;
        final recognizing = _scan.recognizing;
        final failed = _scan.status == ReceiptScanStatus.failed;
        final hasImage = picked != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasImage)
              ReceiptImage(path: picked, height: 260, fit: BoxFit.contain)
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 56,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chụp hoặc chọn ảnh hóa đơn',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (recognizing)
              Semantics(
                liveRegion: true,
                child: const Column(
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang nhận dạng hóa đơn trên thiết bị…'),
                  ],
                ),
              )
            else ...[
              if (failed && _scan.errorMessage != null)
                Semantics(
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
                            _scan.errorMessage!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (failed && hasImage) ...[
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử nhận dạng lại'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.tonalIcon(
                onPressed: () => _startScan(ReceiptImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(hasImage ? 'Chụp lại' : 'Chụp ảnh hóa đơn'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _startScan(ReceiptImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(hasImage ? 'Chọn ảnh khác' : 'Chọn từ thư viện'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openManual,
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  hasImage ? 'Nhập thủ công (giữ ảnh)' : 'Nhập thủ công',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nhận dạng chạy hoàn toàn trên thiết bị, không cần Internet. '
                'Kết quả chỉ là gợi ý: bạn sẽ kiểm tra và xác nhận trước khi lưu.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}