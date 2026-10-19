import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    super.key,
    required this.path,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 16,
  });

  final String path;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: kIsWeb
          ? _Placeholder(
              height: height,
              message: 'Ảnh hóa đơn chưa hỗ trợ xem trên web.',
            )
          : Image.file(
              File(path),
              height: height,
              width: double.infinity,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return _Placeholder(
                  height: height,
                  message: 'Không tìm thấy ảnh hóa đơn.',
                );
              },
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, required this.message});

  final double? height;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height ?? 120,
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Xem ảnh hóa đơn toàn màn hình, có thể phóng to/thu nhỏ.
class ReceiptViewerScreen extends StatelessWidget {
  const ReceiptViewerScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ảnh hóa đơn'),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: ReceiptImage(
              path: path,
              fit: BoxFit.contain,
              borderRadius: 0,
            ),
          ),
        ),
      ),
    );
  }
}