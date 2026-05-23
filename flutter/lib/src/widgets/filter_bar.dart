import 'package:flutter/material.dart';
import '../../main.dart';

class FilterBar extends StatefulWidget {
  final void Function(List<String> tags, String? due) onChanged;
  const FilterBar({super.key, required this.onChanged});

  @override
  State<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends State<FilterBar> {
  final List<String> _selectedTags = [];
  String? _selectedDue;
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

  void _emit() => widget.onChanged(_selectedTags, _selectedDue);

  @override void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final searchText = _searchCtrl.text.toLowerCase();
    final filtered = _allTags
        .where((t) => searchText.isEmpty || t.$1.contains(searchText))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search + date row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchCtrl.clear(); setState(() {}); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'today', label: Text('Today', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'week', label: Text('Week', style: TextStyle(fontSize: 11))),
              ],
              selected: _selectedDue != null ? {_selectedDue!} : {},
              emptySelectionAllowed: true,
              onSelectionChanged: (v) {
                setState(() => _selectedDue = v.isEmpty ? null : v.first);
                _emit();
              },
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ]),
        ),
        // Active filters
        if (_selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 4, runSpacing: 2,
              children: _selectedTags.map((t) => InputChip(
                label: Text('#$t', style: const TextStyle(fontSize: 12)),
                onDeleted: () { setState(() => _selectedTags.remove(t)); _emit(); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ),
        // Tag chips — always visible, scrollable
        SizedBox(
          height: _selectedTags.isNotEmpty ? 36 : 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: filtered.take(50).map((t) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text('#${t.$1}  ${t.$2}', style: const TextStyle(fontSize: 11)),
                selected: _selectedTags.contains(t.$1),
                onSelected: (sel) {
                  setState(() {
                    if (sel) { _selectedTags.add(t.$1); }
                    else { _selectedTags.remove(t.$1); }
                  });
                  _emit();
                },
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
