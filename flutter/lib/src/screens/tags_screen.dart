import 'package:flutter/material.dart';
import '../../main.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tags.isEmpty) return const Center(child: Text('No tags yet'));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _tags.length,
      itemBuilder: (ctx, i) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${_tags[i].$2}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        title: Text('#${_tags[i].$1}'),
      ),
    );
  }
}
