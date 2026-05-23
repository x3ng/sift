import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/api.dart';
import '../widgets/tag_chips.dart';

class DetailScreen extends StatefulWidget {
  final Entry entry;
  const DetailScreen({super.key, required this.entry});
  @override State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Entry _entry;
  final _tagCtrl = TextEditingController();

  @override void initState() { super.initState(); _entry = widget.entry; }

  Future<void> _toggleDone() async {
    if (_entry.isDone) {
      await siftService.undo(_entry.idPrefix);
    } else {
      await siftService.done(_entry.idPrefix);
    }
    _refresh();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete "${_entry.headline}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      await siftService.delete(_entry.idPrefix);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addTag(String tag) async {
    await siftService.tag(_entry.idPrefix, addTags: [tag]);
    _refresh();
  }

  Future<void> _rmTag(String tag) async {
    await siftService.tag(_entry.idPrefix, rmTags: [tag]);
    _refresh();
  }

  Future<void> _editHeadline() async {
    final ctrl = TextEditingController(text: _entry.headline);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Headline'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
      ],
    ));
    if (result != null && result.isNotEmpty) {
      await siftService.edit(_entry.idPrefix, headline: result);
      _refresh();
    }
  }

  Future<void> _editBody() async {
    final ctrl = TextEditingController(text: _entry.body);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Body'),
      content: TextField(controller: ctrl, maxLines: 5, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
      ],
    ));
    if (result != null) {
      await siftService.edit(_entry.idPrefix, body: result);
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final results = await siftService.search(_entry.idPrefix);
    if (results.isNotEmpty && mounted) setState(() => _entry = results.first);
  }

  @override Widget build(BuildContext context) {
    final tags = _entry.displayTags;

    return Scaffold(appBar: AppBar(title: const Text('Entry'), actions: [
      IconButton(
        icon: Icon(_entry.isDone ? Icons.undo : Icons.check_circle_outline),
        tooltip: _entry.isDone ? 'Undo' : 'Mark done',
        onPressed: _toggleDone),
      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: InkWell(onTap: _editHeadline, child: Text(_entry.headline,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            decoration: _entry.isDone ? TextDecoration.lineThrough : null)))),
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: _editHeadline),
      ]),
      if (_entry.isDone) const Padding(padding: EdgeInsets.only(top: 4),
        child: Chip(label: Text('done'), avatar: Icon(Icons.check, size: 16))),
      const SizedBox(height: 12),
      TagChips(tags: tags, onRemove: _rmTag),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _tagCtrl,
          decoration: const InputDecoration(labelText: 'Add tag', border: OutlineInputBorder(), isDense: true),
          onSubmitted: (v) { if (v.isNotEmpty) { _addTag(v); _tagCtrl.clear(); }})),
        const SizedBox(width: 8),
        IconButton(onPressed: () { if (_tagCtrl.text.isNotEmpty) { _addTag(_tagCtrl.text); _tagCtrl.clear(); }},
            icon: const Icon(Icons.add)),
      ]),
      const Divider(height: 32),
      if (_entry.body.isNotEmpty) ...[
        Row(children: [
          const Text('Body', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: _editBody),
        ]),
        const SizedBox(height: 4),
        InkWell(onTap: _editBody, child: Text(_entry.body)),
      ] else ...[
        TextButton.icon(onPressed: _editBody,
          icon: const Icon(Icons.add), label: const Text('Add body')),
      ],
    ]));
  }
}
