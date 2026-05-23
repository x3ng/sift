import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/api.dart';
import '../widgets/tag_chips.dart';

class DetailScreen extends StatefulWidget {
  final Entry entry;
  final VoidCallback? onChanged;
  const DetailScreen({super.key, required this.entry, this.onChanged});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Entry _entry;
  final _tagCtrl = TextEditingController();
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadAllTags();
  }

  Future<void> _loadAllTags() async {
    final tags = await siftService.allTags();
    if (mounted) {
      setState(() => _allTags = tags.map((t) => t.$1).toList());
    }
  }

  Future<void> _reload() async {
    final results = await siftService.search(_entry.idPrefix);
    if (results.isNotEmpty && mounted) {
      setState(() => _entry = results.first);
    }
  }

  Future<void> _notify() async {
    _reload();
    widget.onChanged?.call();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${_entry.headline}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await siftService.delete(_entry.idPrefix);
      widget.onChanged?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addTag(String tag) async {
    if (tag.isEmpty) return;
    await siftService.tag(_entry.idPrefix, addTags: [tag]);
    _notify();
    _tagCtrl.clear();
  }

  Future<void> _rmTag(String tag) async {
    await siftService.tag(_entry.idPrefix, rmTags: [tag]);
    _notify();
  }

  Future<void> _editHeadline() async {
    final ctrl = TextEditingController(text: _entry.headline);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Headline'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (r != null && r.isNotEmpty) {
      await siftService.edit(_entry.idPrefix, headline: r);
      _notify();
    }
  }

  Future<void> _editBody() async {
    final ctrl = TextEditingController(text: _entry.body);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Body'),
        content: TextField(controller: ctrl, maxLines: 5, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (r != null) {
      await siftService.edit(_entry.idPrefix, body: r);
      _notify();
    }
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = List<String>.from(_entry.tags);
    final suggestions = _allTags
        .where((t) => t.contains(_tagCtrl.text.toLowerCase()) && !_entry.tags.contains(t))
        .take(6)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'delete') _delete(); },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _buildBody(context, tags, suggestions),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, List<String> tags, List<String> suggestions) {
    final cs = Theme.of(context).colorScheme;

    return [
      // Headline
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: _editHeadline,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  _entry.headline,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: _editHeadline),
        ],
      ),

      const SizedBox(height: 12),

      // Tags
      if (tags.isNotEmpty) TagChips(tags: tags, onRemove: _rmTag),
      if (tags.isEmpty)
        const Text('No tags', style: TextStyle(color: Colors.grey, fontSize: 13)),

      const SizedBox(height: 8),

      // Add tag
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _tagCtrl,
              decoration: InputDecoration(
                hintText: 'Add tag...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withAlpha(60),
              ),
              onSubmitted: (v) => _addTag(v.trim()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _addTag(_tagCtrl.text.trim()),
          icon: const Icon(Icons.add, size: 18),
        ),
      ]),

      // Tag suggestions
      if (suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: suggestions.map((t) => ActionChip(
              label: Text('#$t', style: const TextStyle(fontSize: 12)),
              onPressed: () => _addTag(t),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ),

      const Divider(height: 24),

      // Body header
      Row(children: [
        Text('Body', style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: _editBody),
      ]),

      const SizedBox(height: 4),

      // Body content
      if (_entry.body.isNotEmpty)
        InkWell(onTap: _editBody, child: Text(_entry.body))
      else
        TextButton(onPressed: _editBody, child: const Text('Add body...')),
    ];
  }
}
