import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/ffi_service.dart';
import '../widgets/tag_combinator.dart';

class AddScreen extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddScreen({super.key, this.onAdded});
  @override State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nameCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final List<String> _tags = [];

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final bodyText = _bodyCtrl.text.trim();
    final body = bodyText.isNotEmpty ? FrbBody.text(bodyText) : const FrbBody.empty();
    await siftService.add(name, body: body, tags: _tags);
    if (mounted) {
      _nameCtrl.clear(); _bodyCtrl.clear();
      setState(() => _tags.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Added'), duration: Duration(seconds: 1),
      ));
      widget.onAdded?.call();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          autofocus: true, textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          decoration: const InputDecoration(labelText: 'Body (optional)', border: OutlineInputBorder()),
          maxLines: 3, textInputAction: TextInputAction.next),
        const SizedBox(height: 12),

        TagCombinator(
          mode: CombinatorMode.tagging,
          initialTags: _tags,
          hint: 'Add tag...  done:today  work/rtd',
          onChanged: (tags, _) {
            _tags.clear();
            _tags.addAll(tags);
          },
        ),

        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6,
              children: _tags.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                onDeleted: () => setState(() => _tags.remove(t)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList()),
          ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Add Entry')),
        ),
      ]),
    );
  }
}
