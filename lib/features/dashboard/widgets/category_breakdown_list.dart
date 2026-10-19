import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../expenses/category_icons.dart';
import '../dashboard_stats.dart';

class CategoryBreakdownList extends StatelessWidget {
  const CategoryBreakdownList({super.key, required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorForCategory(item.category).withAlpha(36),
                  child: Icon(
                    iconForCategory(item.category),
                    size: 17,
                    color: colorForCategory(item.category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.category} · '
                              '${(item.share * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            formatVnd(item.amount),
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.share.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: colorForCategory(item.category),
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}