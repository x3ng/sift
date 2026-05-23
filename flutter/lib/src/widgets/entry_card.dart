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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.headline, style: TextStyle(
              fontSize: 15,
              decoration: entry.isDone ? TextDecoration.lineThrough : null,
              color: entry.isDone ? Theme.of(context).colorScheme.outline : null,
            )),
            if (tags.isNotEmpty) const SizedBox(height: 4),
            if (tags.isNotEmpty) TagChips(tags: tags.take(5).toList()),
          ])),
          Checkbox(value: entry.isDone, onChanged: (_) => onDone?.call()),
        ])),
      ),
    );
  }
}
