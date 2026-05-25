import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/ffi_service.dart';
import '../widgets/tag_chips.dart';
import '../widgets/tag_combinator.dart';

class DetailScreen extends StatefulWidget {
  final FrbEntry entry;
  final VoidCallback? onChanged;
  const DetailScreen({super.key, required this.entry, this.onChanged});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late FrbEntry _entry;
  bool _editingBody = false;
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _bodyCtrl.text = _entry.body;
  }

  @override
  void didUpdateWidget(DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _entry = widget.entry;
      _bodyCtrl.text = _entry.body;
      _editingBody = false;
    }
  }

  Future<void> _reload() async {
    final e = await siftService.getEntry(_entry.idPrefix);
    if (e != null && mounted) {
      setState(() { _entry = e; _bodyCtrl.text = e.body; });
    }
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

  Future<void> _rmTag(String tag) async {
    await siftService.tag(_entry.idPrefix, rmTags: [tag]);
    await _reload();
    widget.onChanged?.call();
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
      await _reload();
      widget.onChanged?.call();
    }
  }

  Future<void> _renameTag(String old) async {
    final ctrl = TextEditingController(text: old);
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename Tag'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'new tag name', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rename')),
      ],
    ));
    if (r == null || r.isEmpty || r == old) return;
    await siftService.renameTag(old, r);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Renamed #$old → #$r'), duration: const Duration(seconds: 1)));
      await _reload();
      widget.onChanged?.call();
    }
  }

  Future<void> _saveBody() async {
    final text = _bodyCtrl.text.trim();
    if (text == _entry.body) {
      setState(() => _editingBody = false);
      return;
    }
    await siftService.edit(_entry.idPrefix, body: text.isEmpty ? '' : text);
    setState(() => _editingBody = false);
    await _reload();
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = List<String>.from(_entry.tags);

    return PopScope(
      canPop: !_editingBody,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editingBody) _saveBody();
      },
      child: Scaffold(
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
          children: _buildBody(context, tags),
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, List<String> tags) {
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
                child: Text(_entry.headline, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: _editHeadline),
        ],
      ),

      const SizedBox(height: 12),

      // Tags
      if (tags.isNotEmpty) TagChips(tags: tags, onRemove: _rmTag, onTap: _renameTag),
      if (tags.isEmpty)
        const Text('No tags', style: TextStyle(color: Colors.grey, fontSize: 13)),

      const SizedBox(height: 8),

      // Tag input
      TagCombinator(
        mode: CombinatorMode.tagging,
        initialTags: List.from(_entry.tags),
        hint: 'Add tag...  done:today  work/rtd',
        onChanged: (tags, _) async {
          final current = Set<String>.from(_entry.tags);
          final incoming = Set<String>.from(tags);
          final toAdd = incoming.difference(current).toList();
          final toRemove = current.difference(incoming).toList();
          if (toAdd.isNotEmpty || toRemove.isNotEmpty) {
            await siftService.tag(_entry.idPrefix, addTags: toAdd, rmTags: toRemove);
            await _reload();
            widget.onChanged?.call();
          }
        },
      ),

      const Divider(height: 24),

      // Body
      Row(children: [
        Text('Body', style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        if (_editingBody)
          TextButton(onPressed: _saveBody, child: const Text('Done'))
        else
          IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => setState(() => _editingBody = true)),
      ]),

      const SizedBox(height: 4),

      if (_editingBody)
        TextField(
          controller: _bodyCtrl,
          maxLines: null,
          minLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Markdown, plain text, anything...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withAlpha(80),
          ),
        )
      else if (_entry.body.isNotEmpty)
        InkWell(
          onTap: () => setState(() => _editingBody = true),
          child: Text(_entry.body),
        )
      else
        TextButton(
          onPressed: () => setState(() => _editingBody = true),
          child: const Text('Add body...'),
        ),
    ];
  }
}
