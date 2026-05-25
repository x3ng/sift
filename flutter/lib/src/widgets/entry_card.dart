import 'package:flutter/material.dart';
import '../services/ffi_service.dart';
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
    final FrbBody? body = entry.body;
    final bool isFile = body?.type == 'file';
    final bool isDone = tags.any((t) => t.startsWith('done/'));
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 0,
      color: selected ? cs.primaryContainer.withAlpha(80) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? cs.primary : Colors.transparent,
          width: selected ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    Row(children: [
                      Expanded(
                        child: Text(
                          entry.name.toString(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? cs.outline : null,
                          ),
                        ),
                      ),
                      if (isFile)
                        Icon(Icons.attach_file, size: 14, color: cs.outline.withAlpha(150)),
                    ]),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      TagChips(tags: tags.take(5).toList()),
                    ],
                    if (body != null && !body.isEmpty) ...[
                      const SizedBox(height: 6),
                      if (isFile)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.insert_drive_file_outlined, size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Flexible(child: Text(body.path ?? '', maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.primary))),
                        ])
                      else
                        Text(body.text, maxLines: 2, overflow: TextOverflow.ellipsis,
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
