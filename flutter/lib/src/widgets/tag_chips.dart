import 'package:flutter/material.dart';

class TagChips extends StatelessWidget {
  final List<String> tags;
  final void Function(String)? onRemove;
  final void Function(String)? onTap;
  const TagChips({super.key, required this.tags, this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(spacing: 3, runSpacing: 3, children: tags.map((tag) {
      final isDate = tag.contains('/');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDate
              ? cs.tertiaryContainer.withAlpha(isDark ? 60 : 50)
              : cs.surfaceContainerHighest.withAlpha(isDark ? 120 : 80),
          borderRadius: BorderRadius.circular(4),
        ),
        child: GestureDetector(
          onTap: onTap != null ? () => onTap!(tag) : null,
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isDate ? FontWeight.w500 : FontWeight.w400,
              color: isDate
                  ? cs.tertiary.withAlpha(isDark ? 200 : 220)
                  : cs.onSurface.withAlpha(isDark ? 150 : 170),
            ),
          ),
        ),
      );
    }).toList());
  }
}
