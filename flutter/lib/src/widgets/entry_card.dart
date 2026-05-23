import 'package:flutter/material.dart';
import '../services/api.dart';
import 'tag_chips.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDone;
  const EntryCard({super.key, required this.entry, this.onTap, this.onDone});

  @override
  Widget build(BuildContext context) {
    final tags = entry.displayTags;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.headline,
                  style: TextStyle(
                    fontSize: 15,
                    decoration: entry.isDone ? TextDecoration.lineThrough : null,
                    color: entry.isDone ? cs.outline : null,
                    fontWeight: entry.isDone ? FontWeight.normal : FontWeight.w500,
                  )),
                if (tags.isNotEmpty) const SizedBox(height: 4),
                if (tags.isNotEmpty)
                  TagChips(tags: tags.take(4).toList()),
              ],
            )),
            Checkbox(value: entry.isDone, onChanged: (_) => onDone?.call(),
              visualDensity: VisualDensity.compact),
          ]),
        ),
      ),
    );
  }
}
