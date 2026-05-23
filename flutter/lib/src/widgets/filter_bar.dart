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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    reloadTags();
  }

  Future<void> reloadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags);
  }

  void _emit() => widget.onChanged(_selectedTags, _selectedDue);

  @override
  Widget build(BuildContext context) {
    final searchText = _searchCtrl.text.toLowerCase();
    final visible = _allTags
        .where((t) => searchText.isEmpty || t.$1.contains(searchText))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search + date + expand row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filter tags...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Today', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'this-week', label: Text('Week', style: TextStyle(fontSize: 11))),
                ],
                selected: _selectedDue != null ? {_selectedDue!} : {},
                emptySelectionAllowed: true,
                onSelectionChanged: (v) {
                  setState(() => _selectedDue = v.isEmpty ? null : v.first);
                  _emit();
                },
                style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // Active filters as chips
        if (_selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 4,
              children: _selectedTags.map((t) => Chip(
                label: Text('#$t', style: const TextStyle(fontSize: 11)),
                onDeleted: () {
                  setState(() => _selectedTags.remove(t));
                  _emit();
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ),
        // Expandable tag grid
        if (_expanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: visible.take(40).map((t) => FilterChip(
                  label: Text('#${t.$1} (${t.$2})', style: const TextStyle(fontSize: 11)),
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
                )).toList(),
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
