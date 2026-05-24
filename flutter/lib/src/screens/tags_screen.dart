import 'package:flutter/material.dart';
import '../../main.dart';

class TagsScreen extends StatefulWidget {
  final void Function(String tag)? onTagTap;
  const TagsScreen({super.key, this.onTagTap});

  @override State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  List<(String, int)> _tags = [];
  bool _loading = true;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tags = await siftService.allTags();
    if (mounted) setState(() { _tags = tags; _loading = false; });
  }

  Future<void> _renameTag(String old) async {
    final ctrl = TextEditingController(text: old);
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename Tag'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'new tag name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rename')),
      ],
    ));
    if (r == null || r.isEmpty || r == old) return;
    final count = await siftService.renameTag(old, r);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Renamed #$old → #$r ($count entries)'),
        duration: const Duration(seconds: 2),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const Center(child: Text('No tags yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _tags.length,
                  itemBuilder: (ctx, i) {
                    final tag = _tags[i].$1;
                    final count = _tags[i].$2;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        radius: 16,
                        child: Text('$count',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer)),
                      ),
                      title: Text('#$tag'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: widget.onTagTap != null ? () => widget.onTagTap!(tag) : null,
                      onLongPress: () => _renameTag(tag),
                    );
                  },
                ),
    );
  }
}
