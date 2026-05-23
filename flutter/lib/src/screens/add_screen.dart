import 'package:flutter/material.dart';
import '../../main.dart';

class AddScreen extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddScreen({super.key, this.onAdded});
  @override State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _headlineCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];
  List<String> _allTags = [];
  final _focusNode = FocusNode();

  @override void initState() {
    super.initState();
    _loadTags();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _loadTags();
    });
  }

  Future<void> _loadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags.map((t) => t.$1).toList());
  }

  Future<void> _submit() async {
    final headline = _headlineCtrl.text.trim();
    if (headline.isEmpty) return;
    await siftService.add(headline, body: _bodyCtrl.text.trim(), tags: _tags);
    if (mounted) {
      _headlineCtrl.clear(); _bodyCtrl.clear(); _tagCtrl.clear();
      setState(() => _tags.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Added'), duration: Duration(seconds: 1),
      ));
      widget.onAdded?.call();
    }
  }

  void _addTag(String t) {
    if (t.isNotEmpty && !_tags.contains(t)) setState(() => _tags.add(t));
  }

  @override Widget build(BuildContext context) {
    final suggestions = _allTags
        .where((t) => t.contains(_tagCtrl.text.toLowerCase()) && !_tags.contains(t))
        .take(8).toList();

    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextField(controller: _headlineCtrl,
        decoration: const InputDecoration(labelText: 'Headline', border: OutlineInputBorder()),
        autofocus: true, textInputAction: TextInputAction.next),
      const SizedBox(height: 12),
      TextField(controller: _bodyCtrl,
        decoration: const InputDecoration(labelText: 'Body (optional)', border: OutlineInputBorder()),
        maxLines: 3, textInputAction: TextInputAction.next),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _tagCtrl, focusNode: _focusNode,
          decoration: const InputDecoration(labelText: 'Add tag', border: OutlineInputBorder()),
          onSubmitted: (v) { _addTag(v.trim()); _tagCtrl.clear(); },
          onChanged: (_) => setState(() {}))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: () { _addTag(_tagCtrl.text.trim()); _tagCtrl.clear(); },
            icon: const Icon(Icons.add)),
      ]),
      if (suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(spacing: 4, runSpacing: 0, children: suggestions.map((t) => ActionChip(
            label: Text('#$t', style: const TextStyle(fontSize: 12)),
            onPressed: () { _addTag(t); _tagCtrl.clear(); },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )).toList()),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: _tags.map((t) => Chip(
        label: Text('#$t'),
        onDeleted: () => setState(() => _tags.remove(t)),
      )).toList()),
      const Spacer(),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check), label: const Text('Add Entry'))),
    ]));
  }
}
