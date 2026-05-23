import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/query.dart';

/// Three-layer filter discovery:
///   1. Quick presets — always visible date/action chips
///   2. Tag bar — horizontal scroll of all tags
///   3. Input suggestions — context-aware dropdown while typing

class FilterBar extends StatefulWidget {
  final void Function(ParsedQuery query) onChanged;
  const FilterBar({super.key, required this.onChanged});

  @override
  State<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends State<FilterBar> {
  ParsedQuery _query = ParsedQuery(tagsAnd: [], tagsNot: [], dates: []);
  List<(String, int)> _allTags = [];
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override void initState() {
    super.initState();
    reloadTags();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _showSuggestions = true);
    });
  }

  Future<void> reloadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags);
  }

  void _emit() => widget.onChanged(_query);

  void _addAnd(String tag) { if (!_query.tagsAnd.contains(tag)) { _query.tagsAnd.add(tag); _searchCtrl.clear(); _showSuggestions = false; _emit(); setState(() {}); } }
  void _addDate(String prefix, DateOp op) { _query.dates.add(DateClause(prefix, op)); _searchCtrl.clear(); _showSuggestions = false; _emit(); setState(() {}); }
  void _addFulltext(String text) { _query.fulltext = (_query.fulltext ?? '') + ' $text'.trim(); _searchCtrl.clear(); _showSuggestions = false; _emit(); setState(() {}); }

  void _onSubmit(String input) {
    final q = parseQuery(input);
    _query = ParsedQuery(
      tagsAnd: [..._query.tagsAnd, ...q.tagsAnd],
      tagsNot: [..._query.tagsNot, ...q.tagsNot],
      dates: [..._query.dates, ...q.dates],
      fulltext: q.fulltext ?? _query.fulltext,
    );
    _searchCtrl.clear();
    _showSuggestions = false;
    _emit();
    setState(() {});
  }

  void _clearAll() { _query = ParsedQuery(tagsAnd: [], tagsNot: [], dates: []); _searchCtrl.clear(); _emit(); setState(() {}); }

  // Build suggestion list based on current input
  List<Widget> _buildSuggestions() {
    final text = _searchCtrl.text.toLowerCase().trim();
    final ws = <Widget>[];

    if (text.isEmpty) {
      // Show quick date presets
      ws.addAll([
        _suggestionChip('done:this-week', 'Done this week', Icons.event_available, () => _addDate('done', DateOp.thisWeek)),
        _suggestionChip('done:today', 'Done today', Icons.today, () => _addDate('done', DateOp.today)),
        _suggestionChip('due:overdue', 'Overdue', Icons.warning_amber, () => _addDate('due', DateOp.overdue)),
        _suggestionChip('due:this-week', 'Due this week', Icons.date_range, () => _addDate('due', DateOp.thisWeek)),
        _suggestionChip('created:today', 'Created today', Icons.fiber_new, () => _addDate('created', DateOp.today)),
      ]);
    } else {
      // Match tags
      final tagMatches = _allTags.where((t) => t.$1.toLowerCase().contains(text)).take(6).toList();
      for (final t in tagMatches) {
        ws.add(_suggestionChip('#${t.$1}', '${t.$2} entries', Icons.label_outline, () => _addAnd(t.$1)));
      }

      // Date completions
      if ('done'.contains(text) && text.isNotEmpty) {
        ws.add(_suggestionChip('done:this-week', 'Date filter', Icons.event_available, () => _addDate('done', DateOp.thisWeek)));
        ws.add(_suggestionChip('done:today', 'Date filter', Icons.today, () => _addDate('done', DateOp.today)));
      }
      if ('due'.contains(text) && text.isNotEmpty) {
        ws.add(_suggestionChip('due:overdue', 'Date filter', Icons.warning_amber, () => _addDate('due', DateOp.overdue)));
        ws.add(_suggestionChip('due:this-week', 'Date filter', Icons.date_range, () => _addDate('due', DateOp.thisWeek)));
      }
      if ('created'.contains(text) && text.isNotEmpty) {
        ws.add(_suggestionChip('created:today', 'Date filter', Icons.fiber_new, () => _addDate('created', DateOp.today)));
      }

      // Full-text fallback
      if (text.isNotEmpty && ws.isEmpty) {
        ws.add(_suggestionChip('"$text"', 'Search in text', Icons.search, () => _addFulltext(text)));
      }
      // Full-text option always
      if (ws.isNotEmpty) {
        ws.add(const Divider());
        ws.add(_suggestionChip('"$text"', 'Full-text search', Icons.article_outlined, () => _addFulltext(text)));
      }
    }
    return ws;
  }

  Widget _suggestionChip(String label, String subtitle, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ]),
      ),
    );
  }

  @override void dispose() { _searchCtrl.dispose(); _focusNode.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final hasActive = !_query.isEmpty;
    final topTags = _allTags.take(30).toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Search field + active filter chips
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Search row
          SizedBox(height: 40, child: TextField(
            controller: _searchCtrl, focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: hasActive ? 'Add filter...' : 'Search or filter...  #tag  done:this-week',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: hasActive ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: _clearAll) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
            ),
            onSubmitted: _onSubmit,
            onChanged: (_) => setState(() => _showSuggestions = true),
          )),

          // Active filter chips
          if (hasActive) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 4, runSpacing: 2, children: [
              for (final t in _query.tagsAnd) InputChip(
                label: Text('#$t', style: const TextStyle(fontSize: 12)),
                onDeleted: () { _query.tagsAnd.remove(t); _emit(); setState(() {}); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact, selected: true,
              ),
              for (final t in _query.tagsNot) InputChip(
                label: Text('-#$t', style: const TextStyle(fontSize: 12, color: Colors.red)),
                onDeleted: () { _query.tagsNot.remove(t); _emit(); setState(() {}); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact, selected: true,
              ),
              for (final d in _query.dates) InputChip(
                label: Text('${d.prefix}:${_opLabel(d.op)}', style: const TextStyle(fontSize: 12)),
                onDeleted: () { _query.dates.remove(d); _emit(); setState(() {}); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact, selected: true,
              ),
              if (_query.fulltext != null) InputChip(
                label: Text('"${_query.fulltext}"', style: const TextStyle(fontSize: 12)),
                onDeleted: () { _query.fulltext = null; _emit(); setState(() {}); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact, selected: true,
              ),
            ]),
          ),
        ]),
      ),

      // Suggestions dropdown
      if (_showSuggestions && _focusNode.hasFocus)
        ..._buildSuggestions(),

      // Always-visible tag bar
      if (!_showSuggestions || !_focusNode.hasFocus)
        SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          children: topTags.map((t) => Padding(padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('#${t.$1}  ${t.$2}', style: const TextStyle(fontSize: 11)),
              selected: _query.tagsAnd.contains(t.$1),
              onSelected: (_) => _addAnd(t.$1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ))).toList())),

      const Divider(height: 1),
    ]);
  }

  String _opLabel(DateOp op) {
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
