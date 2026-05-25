import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
  String _bodyType = 'text'; // 'text' | 'file'
  String? _filePath;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _filePath = result.files.single.path);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final FrbBody body;
    switch (_bodyType) {
      case 'file':
        if (_filePath == null || _filePath!.isEmpty) {
          body = const FrbBody.empty();
        } else {
          // Pass the file path for now; the Rust side will import it
          // We use a special marker - the FFI layer will handle file import
          body = FrbBody.file(_filePath!);
        }
        break;
      default:
        final text = _bodyCtrl.text.trim();
        body = text.isNotEmpty ? FrbBody.text(text) : const FrbBody.empty();
    }

    await siftService.add(name, body: body, tags: _tags);
    if (mounted) {
      _nameCtrl.clear(); _bodyCtrl.clear();
      setState(() { _tags.clear(); _filePath = null; _bodyType = 'text'; });
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            hintText: 'Name',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: 12),

        // Body type selector
        Row(children: [
          ChoiceChip(
            label: const Text('Text', style: TextStyle(fontSize: 12)),
            selected: _bodyType == 'text',
            onSelected: (_) => setState(() => _bodyType = 'text'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('File', style: TextStyle(fontSize: 12)),
            selected: _bodyType == 'file',
            onSelected: (_) => setState(() => _bodyType = 'file'),
            visualDensity: VisualDensity.compact,
          ),
        ]),

        const SizedBox(height: 8),

        if (_bodyType == 'text')
          TextField(
            controller: _bodyCtrl,
            decoration: InputDecoration(
              hintText: 'Body (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          )
        else ...[
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _filePath != null ? cs.primary : cs.outlineVariant,
                  style: _filePath != null ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              child: Column(children: [
                Icon(
                  _filePath != null ? Icons.insert_drive_file : Icons.cloud_upload_outlined,
                  size: 28,
                  color: _filePath != null ? cs.primary : cs.outline,
                ),
                const SizedBox(height: 6),
                Text(
                  _filePath != null
                      ? _filePath!.split('/').last
                      : 'Tap to pick a file',
                  style: TextStyle(
                    fontSize: 13,
                    color: _filePath != null ? cs.primary : cs.outline,
                  ),
                ),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 16),

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
