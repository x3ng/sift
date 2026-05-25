import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/ffi_service.dart';
import '../services/prefs.dart';
import 'detail_screen.dart';
import '../widgets/entry_card.dart';
import '../widgets/filter_bar.dart';

class ListScreen extends StatefulWidget {
  final String? tagFilter;
  final VoidCallback? onFilterApplied;
  const ListScreen({super.key, this.tagFilter, this.onFilterApplied});

  @override State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<FrbEntry> _entries = [];
  bool _loading = true;
  final _filterKey = GlobalKey<FilterBarState>();
  bool _filterPinned = false;

  // Selection state
  bool _selectionMode = false;
  final _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDefaultFilter();
  }

  Future<void> _loadDefaultFilter() async {
    if (widget.tagFilter != null && mounted) {
      _filterKey.currentState?.applyTokens(['#${widget.tagFilter}']);
      widget.onFilterApplied?.call();
      return;
    }
    final tokens = await Prefs.getDefaultFilter();
    if (tokens != null && tokens.isNotEmpty && mounted) {
      _filterPinned = true;
      _filterKey.currentState?.applyTokens(tokens);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = _filterKey.currentState?.queryString ?? '';
    try {
      final result = await siftService.listParsed(q, showDone: false);
      if (mounted) {
        setState(() { _entries = result; _loading = false; });
        _filterKey.currentState?.reloadTags();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _entries = []; _loading = false; });
      }
    }
  }

  Widget _buildPinChip() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pinCurrentFilter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _filterPinned ? cs.primaryContainer : null,
          border: _filterPinned ? null : Border.all(color: cs.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_filterPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 14,
              color: _filterPinned ? cs.primary : cs.outline),
          if (_filterPinned) ...[
            const SizedBox(width: 4),
            Text('Saved', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w500)),
          ],
        ]),
      ),
    );
  }

  Future<void> _pinCurrentFilter() async {
    final tokens = _filterKey.currentState?.getTokens() ?? [];
    await Prefs.setDefaultFilter(tokens);
    setState(() => _filterPinned = tokens.isNotEmpty);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tokens.isEmpty ? 'Default filter cleared' : 'Default filter saved'),
        duration: const Duration(seconds: 1)));
    }
  }

  // -- Selection --

  void _enterSelection(FrbEntry entry) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(entry.idPrefix);
    });
  }

  void _toggleSelection(FrbEntry entry) {
    setState(() {
      if (_selectedIds.contains(entry.idPrefix)) {
        _selectedIds.remove(entry.idPrefix);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(entry.idPrefix);
      }
    });
  }

  void _exitSelection() {
    setState(() { _selectionMode = false; _selectedIds.clear(); });
  }

  Future<void> _batchTag() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Batch Tag'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'tag1 tag2 ... (space separated)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add Tags')),
      ],
    ));
    if (r == null || r.trim().isEmpty) return;
    final addTags = r.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final count = await siftService.batchTag(_selectedIds.toList(), addTags: addTags);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tagged $count entries'), duration: const Duration(seconds: 1)));
      _exitSelection();
      _load();
    }
  }

  Future<void> _batchDelete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Selected'),
      content: Text('Delete ${_selectedIds.length} entries? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok != true) return;
    final count = await siftService.batchDelete(_selectedIds.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted $count entries'), duration: const Duration(seconds: 1)));
      _exitSelection();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FilterBar(key: _filterKey, onChanged: () => _load(),
        trailing: _selectionMode ? null : _buildPinChip()),
      Expanded(child: _buildList()),
      if (_selectionMode) _buildActionBar(),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final hasFilter = (_filterKey.currentState?.queryString ?? '').isNotEmpty;

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
        selectionMode: _selectionMode,
        selected: _selectedIds.contains(_entries[i].idPrefix),
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(_entries[i]);
          } else {
            Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => DetailScreen(entry: _entries[i], onChanged: _load),
            )).then((_) => _load());
          }
        },
        onLongPress: () => _enterSelection(_entries[i]),
      ),
    );
  }

  Widget _buildActionBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(children: [
        Text('${_selectedIds.length} selected',
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: _batchTag,
          icon: const Icon(Icons.label_outline, size: 18),
          label: const Text('Tag'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: _batchDelete,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          label: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
          tooltip: 'Cancel selection',
        ),
      ]),
    );
  }
}
