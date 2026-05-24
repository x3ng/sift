import 'package:flutter/material.dart';
import 'tag_chips.dart';

class EntryCard extends StatelessWidget {
  final dynamic entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;

  const EntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final tags = (entry.tags as List).cast<String>();
    final body = (entry.body as String?) ?? '';
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 0,
      color: selected ? cs.primaryContainer.withAlpha(80) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant.withAlpha(80),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected ? cs.primary : cs.outline,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.headline.toString(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      TagChips(tags: tags.take(6).toList()),
                    ],
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.outline)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
