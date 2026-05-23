import 'package:flutter/material.dart';
import '../../main.dart';

/// FilterBar — unified search + tag filter.
///
/// The search field accepts:
///   - #tagname        → exact tag AND match
///   - #prefix/*       → wildcard prefix match
///   - -#tagname       → exclude entries with this tag
///   - plain text      → full-text search in headline/body
///
/// Tag chips below provide quick one-tap tag selection.
class FilterBar extends StatefulWidget {
  final void Function(List<String> tagsAnd, List<String> tagsNot, String? fulltext) onChanged;
  const FilterBar({super.key, required this.onChanged});

  @override
  State<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends State<FilterBar> {
  final List<String> _andTags = [];
  final List<String> _notTags = [];
  String? _fulltextQuery;
  List<(String, int)> _allTags = [];
  final _searchCtrl = TextEditingController();

  @override void initState() {
    super.initState();
    reloadTags();
  }

  Future<void> reloadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags);
  }

  void _emit() => widget.onChanged(List.from(_andTags), List.from(_notTags), _fulltextQuery);

  // Parse search input: #tag adds AND filter, -#tag adds NOT filter, plain text = fulltext
  void _parseSearch(String input) {
    setState(() {
      _andTags.clear();
      _notTags.clear();
      _fulltextQuery = null;

      final parts = input.trim().split(RegExp(r'\s+'));
      for (final p in parts) {
        if (p.startsWith('-#')) {
          _notTags.add(p.substring(2));
        } else if (p.startsWith('#')) {
          _andTags.add(p.substring(1));
        } else if (p.isNotEmpty) {
          _fulltextQuery = (_fulltextQuery ?? '') + ' $p';
        }
      }
      _fulltextQuery = _fulltextQuery?.trim();
      if (_fulltextQuery?.isEmpty == true) _fulltextQuery = null;
    });
    _emit();
  }

  void _toggleAndTag(String tag) {
    setState(() {
      if (_andTags.contains(tag)) { _andTags.remove(tag); }
      else { _andTags.add(tag); }
    });
    _emit();
  }

  @override void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final searchText = _searchCtrl.text.toLowerCase();
    final hasActiveFilters = _andTags.isNotEmpty || _notTags.isNotEmpty || _fulltextQuery != null;

    // Tags matching search input for quick-add suggestions
    final suggestions = searchText.isNotEmpty
        ? _allTags.where((t) => t.$1.contains(searchText)).take(12).toList()
        : <(String, int)>[];

    // All tags for the scrollable chip bar (most-used first)
    final topTags = _allTags.take(30).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search...  #tag  -#exclude  text',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: hasActiveFilters
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () { _searchCtrl.clear(); _parseSearch(''); },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
              ),
              onSubmitted: _parseSearch,
              onChanged: (v) {
                if (v.isEmpty) _parseSearch('');
                setState(() {});  // Update suggestions
              },
            ),
          ),
        ),

        // Active filter chips
        if (hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 4, runSpacing: 2, children: [
              ..._andTags.map((t) => InputChip(
                label: Text('#$t', style: const TextStyle(fontSize: 12)),
                onDeleted: () { setState(() => _andTags.remove(t)); _emit(); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                selected: true,
              )),
              ..._notTags.map((t) => InputChip(
                label: Text('-#$t', style: const TextStyle(fontSize: 12, color: Colors.red)),
                onDeleted: () { setState(() => _notTags.remove(t)); _emit(); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                selected: true,
              )),
              if (_fulltextQuery != null)
                InputChip(
                  label: Text('"${_fulltextQuery}"', style: const TextStyle(fontSize: 12)),
                  onDeleted: () { _fulltextQuery = null; _emit(); },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  selected: true,
                ),
            ]),
          ),

        // Search suggestions (when typing in search field)
        if (suggestions.isNotEmpty)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: suggestions.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text('#${t.$1}  ${t.$2}', style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _toggleAndTag(t.$1);
                    _searchCtrl.clear();
                    _parseSearch('');
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              )).toList(),
            ),
          ),

        // Always-visible tag bar
        if (suggestions.isEmpty)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: topTags.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('#${t.$1}  ${t.$2}', style: const TextStyle(fontSize: 11)),
                  selected: _andTags.contains(t.$1),
                  onSelected: (_) => _toggleAndTag(t.$1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              )).toList(),
            ),
          ),

        const Divider(height: 1),
      ],
    );
  }
}
