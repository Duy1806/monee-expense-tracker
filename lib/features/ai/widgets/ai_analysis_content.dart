import 'package:flutter/material.dart';

class AiAnalysisContent extends StatelessWidget {
  const AiAnalysisContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 13,
      height: 1.55,
    );

    final widgets = <Widget>[];

    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 5));
        continue;
      }

      final isNumberedHeading = RegExp(r'^\d+[.)]\s*\*\*').hasMatch(line);
      final isBoldHeading = line.startsWith('**') && line.endsWith('**');

      if (isNumberedHeading || isBoldHeading) {
        final heading = line
            .replaceAll('**', '')
            .replaceAll(RegExp(r'^\d+[.)]\s*'), '')
            .trim();

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 19,
                  margin: const EdgeInsets.only(right: 9, top: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: Text(
                    heading,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('- ') ||
          line.startsWith('• ') ||
          line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 3, top: 3, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 9),
                  child: Icon(Icons.circle, size: 6, color: scheme.primary),
                ),
                Expanded(
                  child: SelectableText(
                    line.substring(2).replaceAll('**', '').trim(),
                    style: bodyStyle,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: SelectableText(
              line.replaceAll('**', ''),
              style: bodyStyle,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}