import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/api.dart';
import 'detail_screen.dart';
import '../widgets/entry_card.dart';
import '../widgets/filter_bar.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Entry> _entries = [];
  bool _loading = true;
  List<String> _tagsAnd = [];
  List<String> _tagsNot = [];
  String? _fulltext;
  final _filterKey = GlobalKey<FilterBarState>();

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Apply tag AND/NOT filtering
    var result = await siftService.list(
      tagsAnd: _tagsAnd,
      tagsNot: _tagsNot,
    );

    // Apply full-text search client-side if active
    if (_fulltext != null && _fulltext!.isNotEmpty) {
      final q = _fulltext!.toLowerCase();
      result = result.where((e) =>
          e.headline.toLowerCase().contains(q) ||
          e.body.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }

    if (mounted) {
      setState(() { _entries = result; _loading = false; });
      _filterKey.currentState?.reloadTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FilterBar(key: _filterKey, onChanged: (andTags, notTags, fulltext) {
        _tagsAnd = andTags;
        _tagsNot = notTags;
        _fulltext = fulltext;
        _load();
      }),
      Expanded(child: _buildList()),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) {
      final hasFilter = _tagsAnd.isNotEmpty || _tagsNot.isNotEmpty || _fulltext != null;
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasFilter ? Icons.filter_list_off : Icons.inbox_outlined, size: 48,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(hasFilter ? 'No matching entries' : 'No entries yet',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 15)),
          if (!hasFilter) ...[
            const SizedBox(height: 4),
            Text('Tap + to add one',
                style: TextStyle(color: Theme.of(context).colorScheme.outline.withAlpha(150), fontSize: 13)),
          ],
        ],
      )));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _entries.length,
      itemBuilder: (ctx, i) => EntryCard(
        entry: _entries[i],
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => DetailScreen(entry: _entries[i], onChanged: _load),
          ));
          _load();
        },
      ),
    );
  }
}
