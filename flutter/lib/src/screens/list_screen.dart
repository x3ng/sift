import 'package:flutter/material.dart';
import '../../main.dart';
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

  @override void initState() {
    super.initState();
    _activeTags = widget.filters;
    _activeDue = widget.dueFilter;
    _load();
  }

  @override void didUpdateWidget(covariant ListScreen old) {
    super.didUpdateWidget(old);
    if (old.filters != widget.filters || old.dueFilter != widget.dueFilter) {
      _activeTags = widget.filters;
      _activeDue = widget.dueFilter;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await siftService.list(
      tagsAnd: _activeTags,
      due: _activeDue,
    );
    if (mounted) setState(() { _entries = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FilterBar(onChanged: (tags, due) {
        setState(() { _activeTags = tags; _activeDue = due; });
        _load();
      }),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _entries.isEmpty
          ? const Center(child: Text('(no entries)', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) => EntryCard(
                entry: _entries[i],
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => DetailScreen(entry: _entries[i]),
                )).then((_) => _load()),
                onDone: () async {
                  if (_entries[i].isDone) {
                    await siftService.undo(_entries[i].idPrefix);
                  } else {
                    await siftService.done(_entries[i].idPrefix);
                  }
                  _load();
                },
              ),
            ),
      ),
    ]);
  }
}
