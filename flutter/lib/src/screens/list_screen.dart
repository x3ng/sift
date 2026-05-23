import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/api.dart';
import 'detail_screen.dart';
import '../widgets/entry_card.dart';
import '../widgets/filter_bar.dart';

class ListScreen extends StatefulWidget {
  final List<String> filters;
  final String? dueFilter;
  const ListScreen({super.key, this.filters = const [], this.dueFilter});

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
    _activeTags = widget.filters;
    _activeDue = widget.dueFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await siftService.list(
      tagsAnd: _activeTags,
      due: _activeDue,
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
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _entries.isEmpty
          ? Center(child: Text(
              _activeTags.isNotEmpty || _activeDue != null ? '(no matching entries)' : '(no entries)',
              style: const TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) => EntryCard(
                entry: _entries[i],
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => DetailScreen(entry: _entries[i]),
                )).then((_) => _load()),
                onDone: () async {
                  await (_entries[i].isDone
                      ? siftService.undo(_entries[i].idPrefix)
                      : siftService.done(_entries[i].idPrefix));
                  _load();
                },
              ),
            ),
      ),
    ]);
  }
}
