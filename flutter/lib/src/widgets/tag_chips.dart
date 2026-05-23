import 'package:flutter/material.dart';

class TagChips extends StatelessWidget {
  final List<String> tags;
  final void Function(String)? onRemove;
  final void Function(String)? onTap;
  const TagChips({super.key, required this.tags, this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 4, runSpacing: 4, children: tags.map((tag) => InputChip(
      label: Text('#$tag', style: const TextStyle(fontSize: 12)),
      onPressed: onTap != null ? () => onTap!(tag) : null,
      onDeleted: onRemove != null ? () => onRemove!(tag) : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    )).toList());
  }
}
