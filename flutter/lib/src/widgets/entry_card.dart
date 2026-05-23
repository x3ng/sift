import 'package:flutter/material.dart';
import 'tag_chips.dart';

class EntryCard extends StatelessWidget {
  final dynamic entry;
  final VoidCallback? onTap;
  const EntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tags = (entry.tags as List).cast<String>();
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.headline.toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              if (tags.isNotEmpty) const SizedBox(height: 4),
              if (tags.isNotEmpty)
                TagChips(tags: tags.take(6).toList()),
            ],
          ),
        ),
      ),
    );
  }
}
