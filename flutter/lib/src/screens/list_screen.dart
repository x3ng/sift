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
  List<String> _activeTags = [];
  String? _activeDue;
  final _filterKey = GlobalKey<FilterBarState>();

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await siftService.list(
      tagsAnd: _activeTags,
      due: _activeDue,
      showDone: true,  // show done entries, just strikethrough
    );
    if (mounted) {
      setState(() { _entries = result; _loading = false; });
      _filterKey.currentState?.reloadTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FilterBar(key: _filterKey, onChanged: (tags, due) {
        _activeTags = tags;
        _activeDue = due;
        _load();
      }),
      Expanded(child: _buildList()),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) {
      final hasFilter = _activeTags.isNotEmpty || _activeDue != null;
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasFilter ? Icons.filter_list_off : Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(hasFilter ? 'No matching entries' : 'No entries yet', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 15)),
          if (!hasFilter) ...[
            const SizedBox(height: 4),
            Text('Tap + to add one', style: TextStyle(color: Theme.of(context).colorScheme.outline.withAlpha(150), fontSize: 13)),
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
        onDone: () async {
          await (_entries[i].isDone
              ? siftService.undo(_entries[i].idPrefix)
              : siftService.done(_entries[i].idPrefix));
          _load();
        },
      ),
    );
  }
}
