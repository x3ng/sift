import 'package:flutter/material.dart';
import '../../main.dart';

/// Mode determines which combinator primitives are active.
enum CombinatorMode { search, tagging }

/// A reusable tag combinator input widget.
///
/// Search mode: #include, -exclude, prefix:period, "fulltext"
/// Tagging mode: plain tags, / hierarchy, done:today -> done/YYYY-MM-DD
class TagCombinator extends StatefulWidget {
  final CombinatorMode mode;
  final List<String> initialTags;
  final void Function(List<String> tags, String? fulltext) onChanged;
  final String? hint;
  final Widget? trailing;
  final bool pinned;

  const TagCombinator({
    super.key,
    required this.mode,
    this.initialTags = const [],
    required this.onChanged,
    this.hint,
    this.trailing,
    this.pinned = false,
  });

  @override
  State<TagCombinator> createState() => TagCombinatorState();
}

class TagCombinatorState extends State<TagCombinator> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _showSuggestions = false;
  final List<String> _tags = [];
  final List<String> _tagsNot = [];
  String? _fulltext;
  List<(String, int)> _allTags = [];

  // ---- PUBLIC API (used by FilterBar, ListScreen) ----

  List<String> get tags => List.from(_tags);
  List<String> get excludeTags => List.from(_tagsNot);
  String? get fulltext => _fulltext;

  /// Reconstruct the combinator query string from current chips.
  String get queryString {
    final parts = <String>[];
    for (final t in _tags) {
      if (_isDateClause(t)) {
        parts.add(t);
      } else {
        parts.add('#$t');
      }
    }
    for (final t in _tagsNot) {
      parts.add('-#$t');
    }
    if (_fulltext != null && _fulltext!.isNotEmpty) {
      parts.add('"$_fulltext"');
    }
    return parts.join(' ');
  }

  bool _isDateClause(String s) {
    final colon = s.indexOf(':');
    if (colon <= 0 || colon == s.length - 1) return false;
    final prefix = s.substring(0, colon);
    final period = s.substring(colon + 1);
    return RegExp(r'^[a-z][a-z-]*$').hasMatch(prefix) && _datePeriods.contains(period);
  }

  static const _datePeriods = {
    'today', 'yesterday', 'tomorrow',
    'this-week', 'last-week', 'next-week',
    'this-month', 'last-month', 'overdue',
  };

  Future<void> reloadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags);
  }

  void applyTokens(List<String> tokens) {
    _tags.clear();
    _tagsNot.clear();
    _fulltext = null;
    for (final t in tokens) {
      if (t.startsWith('-#') && t.length > 2) {
        _tagsNot.add(t.substring(2));
      } else if (t.startsWith('#') && t.length > 1) {
        _tags.add(t.substring(1));
      } else if (_isDateClause(t)) {
        _tags.add(t);  // date clause stored as-is for search
      } else {
        _fulltext = '${_fulltext ?? ''} $t'.trim();
      }
    }
    _emit();
    setState(() {});
  }

  List<String> getTokens() {
    final tokens = <String>[];
    for (final t in _tags) {
      tokens.add(_isDateClause(t) ? t : '#$t');
    }
    for (final t in _tagsNot) { tokens.add('-#$t'); }
    if (_fulltext != null && _fulltext!.isNotEmpty) tokens.add(_fulltext!);
    return tokens;
  }

  // ---- INTERNAL ----

  bool get _isSearch => widget.mode == CombinatorMode.search;

  @override
  void initState() {
    super.initState();
    _tags.addAll(widget.initialTags);
    _loadTags();
    _focus.addListener(() {
      if (_focus.hasFocus) { setState(() => _showSuggestions = true); _loadTags(); }
    });
  }

  Future<void> _loadTags() async {
    final tags = await siftService.allTags();
    if (mounted) setState(() => _allTags = tags);
  }

  void _emit() => widget.onChanged(List.from(_tags), _fulltext);

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() { _tags.add(tag); _ctrl.clear(); _showSuggestions = false; });
      _emit();
    }
  }

  void _addExclude(String tag) {
    if (tag.isNotEmpty && !_tagsNot.contains(tag)) {
      setState(() { _tagsNot.add(tag); _ctrl.clear(); _showSuggestions = false; });
      _emit();
    }
  }

  void _addFulltext(String text) {
    setState(() {
      _fulltext = '${_fulltext ?? ''} $text'.trim();
      _ctrl.clear(); _showSuggestions = false;
    });
    _emit();
  }

  void _removeTag(String tag) { setState(() { _tags.remove(tag); }); _emit(); }
  void _removeNot(String tag) { setState(() { _tagsNot.remove(tag); }); _emit(); }
  void _clearFulltext() { setState(() { _fulltext = null; }); _emit(); }

  void _clearAll() {
    setState(() { _tags.clear(); _tagsNot.clear(); _fulltext = null; _ctrl.clear(); });
    _emit();
  }

  Future<void> _onSubmit(String input) async {
    if (input.trim().isEmpty) return;
    if (!_isSearch) {
      // Tagging mode: every token is a tag, resolve date shorthands
      final tokens = input.trim().split(RegExp(r'\s+'));
      for (final t in tokens) {
        final tag = _resolveDateShorthand(t.trim());
        if (tag.isNotEmpty && !_tags.contains(tag)) _tags.add(tag);
      }
      _ctrl.clear(); _showSuggestions = false; _emit(); setState(() {});
      return;
    }
    // Search mode: delegate parsing to Rust combinator
    _tags.clear();
    _tagsNot.clear();
    _fulltext = null;
    try {
      final pq = await siftService.parseQuery(input.trim());
      _tags.addAll(pq.tagsAnd);
      _tagsNot.addAll(pq.tagsNot);
      for (final dc in pq.dates) {
        _tags.add('${dc.prefix}:${_dateOpDart(dc.op)}');
      }
      if (pq.fulltext != null && pq.fulltext!.isNotEmpty) {
        _fulltext = pq.fulltext;
      }
    } catch (_) {
      _fulltext = input.trim();
    }
    _ctrl.clear(); _showSuggestions = false; _emit(); setState(() {});
  }

  String _resolveDateShorthand(String token) {
    final colon = token.indexOf(':');
    if (colon <= 0 || colon == token.length - 1) return token;
    final prefix = token.substring(0, colon);
    final op = token.substring(colon + 1);
    final now = DateTime.now();
    String? dateStr;
    switch (op) {
      case 'today': dateStr = '${now.year}-${_pad(now.month)}-${_pad(now.day)}'; break;
      case 'yesterday':
        final d = now.subtract(const Duration(days: 1));
        dateStr = '${d.year}-${_pad(d.month)}-${_pad(d.day)}'; break;
      case 'tomorrow':
        final d = now.add(const Duration(days: 1));
        dateStr = '${d.year}-${_pad(d.month)}-${_pad(d.day)}'; break;
      default: return token;
    }
    return '$prefix/$dateStr';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _dateOpDart(String op) {
    switch (op) {
      case 'Today': return 'today';
      case 'Yesterday': return 'yesterday';
      case 'Tomorrow': return 'tomorrow';
      case 'ThisWeek': return 'this-week';
      case 'LastWeek': return 'last-week';
      case 'NextWeek': return 'next-week';
      case 'ThisMonth': return 'this-month';
      case 'LastMonth': return 'last-month';
      case 'Overdue': return 'overdue';
      default: return op;
    }
  }

  String _todayStr() => _dateStr('today');

  String _dateStr(String op) {
    final n = DateTime.now();
    final d = switch (op) {
      'yesterday' => n.subtract(const Duration(days: 1)),
      'tomorrow' => n.add(const Duration(days: 1)),
      _ => n,
    };
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  // ---- SUGGESTIONS ----

  List<Widget> _buildSuggestions() {
    final text = _ctrl.text.toLowerCase().trim();
    final ws = <Widget>[];

    if (_isSearch && text.isEmpty) {
      ws.addAll([
        _chip('done:this-week', 'Done this week', Icons.event_available, () => _addTag('done:this-week')),
        _chip('done:today', 'Done today', Icons.today, () => _addTag('done:today')),
        _chip('due:overdue', 'Overdue', Icons.warning_amber, () => _addTag('due:overdue')),
        _chip('due:this-week', 'Due this week', Icons.date_range, () => _addTag('due:this-week')),
        _chip('created:today', 'Created today', Icons.fiber_new, () => _addTag('created:today')),
      ]);
    } else {
      final tagMatches = _allTags
          .where((t) => t.$1.toLowerCase().contains(text) && !_tags.contains(t.$1))
          .take(6).toList();
      for (final t in tagMatches) {
        ws.add(_chip('#${t.$1}', '${t.$2} entries', Icons.label_outline, () => _addTag(t.$1)));
      }
      // Date shorthands in tagging mode — any prefix:dateop
      if (!_isSearch && text.isNotEmpty) {
        final colon = text.indexOf(':');
        if (colon > 0) {
          // User typed "prefix:" — show date completions for that prefix
          final prefix = text.substring(0, colon);
          final after = text.substring(colon + 1);
          for (final dp in ['today', 'tomorrow', 'yesterday']) {
            if (dp.startsWith(after) || after.isEmpty) {
              final expanded = '$prefix/${_dateStr(dp)}';
              ws.add(_chip('$prefix:$dp → $expanded', 'Date', Icons.today, () => _addTag(expanded)));
            }
          }
        } else {
          // Show date shorthand hint for any prefix match
          for (final prefix in _allTags.take(10).map((t) => t.$1.split('/').first).toSet().take(4)) {
            if (prefix.startsWith(text) && text.isNotEmpty) {
              final expanded = '$prefix/${_todayStr()}';
              ws.add(_chip('$prefix:today → $expanded', 'Date shorthand', Icons.today, () => _addTag(expanded)));
            }
          }
        }
      }
      // Fulltext in search mode
      if (_isSearch && text.isNotEmpty) {
        if (ws.isNotEmpty) ws.add(const Divider());
        ws.add(_chip('"$text"', 'Full-text search', Icons.article_outlined, () => _addFulltext(text)));
      }
    }
    return ws;
  }

  Widget _chip(String label, String subtitle, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
          const SizedBox(width: 8),
          Flexible(child: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline))),
        ]),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  bool get _hasActive => _tags.isNotEmpty || _tagsNot.isNotEmpty || _fulltext != null;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Input row
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: SizedBox(height: 40, child: TextField(
              controller: _ctrl, focusNode: _focus,
              decoration: InputDecoration(
                hintText: widget.hint ?? (_isSearch
                    ? 'Search or filter...  #tag  done:this-week'
                    : 'Add tag...  done:today  work/rtd'),
                prefixIcon: Icon(_isSearch ? Icons.search : Icons.label_outline, size: 18),
                suffixIcon: _hasActive
                    ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: _clearAll)
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
              ),
              onSubmitted: _onSubmit,
              onChanged: (_) => setState(() => _showSuggestions = true),
            ))),
            if (widget.trailing != null) widget.trailing!,
          ]),

          // Active chips
          if (_hasActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 4, runSpacing: 2, children: [
                for (final t in _tags) InputChip(
                  label: Text(_isSearch ? '#$t' : t, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => _removeTag(t),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact, selected: true,
                ),
                if (_isSearch) ...[
                  for (final t in _tagsNot) InputChip(
                    label: Text('-#$t', style: const TextStyle(fontSize: 12, color: Colors.red)),
                    onDeleted: () => _removeNot(t),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact, selected: true,
                  ),
                  if (_fulltext != null) InputChip(
                    label: Text('"$_fulltext"', style: const TextStyle(fontSize: 12)),
                    onDeleted: () => _clearFulltext(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact, selected: true,
                  ),
                ],
              ]),
            ),
          ]),
        ),

      // Suggestions dropdown
      if (_showSuggestions && _focus.hasFocus)
        ..._buildSuggestions(),

      const Divider(height: 1),
    ]);
  }
}
