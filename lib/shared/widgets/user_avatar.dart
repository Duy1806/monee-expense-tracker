import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarPath,
    this.radius = 28,
  });

  final String name;
  final String? avatarPath;
  final double radius;

  String _initials() {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = radius * 2;

    final fallback = Center(
      child: Text(
        _initials(),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );

    Widget content = fallback;
    final path = avatarPath;

    if (!kIsWeb && path != null && path.isNotEmpty) {
      content = Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Semantics(
      label: 'Ảnh đại diện của $name',
      image: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer,
        ),
        child: content,
      ),
    );
  }
}