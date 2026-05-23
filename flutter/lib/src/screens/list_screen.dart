import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/api.dart';
import '../services/query.dart';
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
  ParsedQuery _query = ParsedQuery(tagsAnd: [], tagsNot: [], dates: []);
  final _filterKey = GlobalKey<FilterBarState>();

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Build date filters map from parsed query
    final dateFilters = <String, String>{};
    for (final dc in _query.dates) {
      dateFilters[dc.prefix] = _opStr(dc.op);
    }

    var result = await siftService.list(
      tagsAnd: _query.tagsAnd,
      tagsNot: _query.tagsNot,
      dateFilters: dateFilters,
    );

    // Client-side fulltext search
    if (_query.fulltext != null && _query.fulltext!.isNotEmpty) {
      final q = _query.fulltext!.toLowerCase();
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
      FilterBar(key: _filterKey, onChanged: (q) {
        _query = q;
        _load();
      }),
      Expanded(child: _buildList()),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final hasFilter = !_query.isEmpty;

    if (_entries.isEmpty) {
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

  String _opStr(DateOp op) {
    switch (op) {
      case DateOp.today: return 'today';
      case DateOp.yesterday: return 'yesterday';
      case DateOp.tomorrow: return 'tomorrow';
      case DateOp.thisWeek: return 'this-week';
      case DateOp.lastWeek: return 'last-week';
      case DateOp.nextWeek: return 'next-week';
      case DateOp.thisMonth: return 'this-month';
      case DateOp.lastMonth: return 'last-month';
      case DateOp.overdue: return 'overdue';
    }
  }
}
