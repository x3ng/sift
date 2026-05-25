import 'package:flutter/material.dart';
import '../services/ffi_service.dart';
import 'tag_chips.dart';

class EntryCard extends StatelessWidget {
  final FrbEntry entry;
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
    final tags = entry.tags;
    final FrbBody body = entry.body;
    final bool isFile = body.type == 'file';
    final bool isDone = tags.any((t) => t.startsWith('done/'));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: selected
            ? cs.primaryContainer.withAlpha(isDark ? 60 : 40)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 3),
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 22,
                      color: selected ? cs.primary : cs.outline.withAlpha(80),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? cs.outline.withAlpha(150)
                                  : cs.onSurface.withAlpha(isDark ? 230 : 220),
                            ),
                          ),
                        ),
                        if (isFile)
                          Icon(Icons.attach_file_rounded, size: 14,
                              color: cs.outline.withAlpha(100)),
                      ]),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        TagChips(tags: tags.where((t) => !t.startsWith('done/')).take(5).toList()),
                      ],
                      if (!body.isEmpty) ...[
                        const SizedBox(height: 5),
                        if (isFile)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.insert_drive_file_outlined, size: 13, color: cs.primary.withAlpha(150)),
                            const SizedBox(width: 5),
                            Flexible(child: Text(
                              body.path?.split('/').last ?? 'File',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: cs.primary.withAlpha(150)),
                            )),
                          ])
                        else
                          Text(
                            body.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: cs.onSurface.withAlpha(isDark ? 120 : 140),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
