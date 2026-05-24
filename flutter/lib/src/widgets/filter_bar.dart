import 'package:flutter/material.dart';
import '../services/query.dart';
import 'tag_combinator.dart';

/// Filter bar — thin wrapper over TagCombinator in search mode.
class FilterBar extends StatefulWidget {
  final void Function(ParsedQuery query) onChanged;
  final Widget? trailing;
  const FilterBar({super.key, required this.onChanged, this.trailing});

  @override
  State<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends State<FilterBar> {
  final _key = GlobalKey<TagCombinatorState>();

  ParsedQuery _toQuery() {
    final s = _key.currentState!;
    final tagsAnd = <String>[];
    final dates = <DateClause>[];
    for (final t in s.tags) {
      final colon = t.indexOf(':');
      if (colon > 0) {
        final prefix = t.substring(0, colon);
        final period = t.substring(colon + 1);
        final op = _parseDateOp(period);
        if (op != null) {
          dates.add(DateClause(prefix, op));
          continue;
        }
      }
      tagsAnd.add(t);
    }
    return ParsedQuery(
      tagsAnd: tagsAnd,
      tagsNot: s.excludeTags,
      dates: dates,
      fulltext: s.fulltext,
    );
  }

  DateOp? _parseDateOp(String s) {
    switch (s) {
      case 'today': return DateOp.today;
      case 'yesterday': return DateOp.yesterday;
      case 'tomorrow': return DateOp.tomorrow;
      case 'this-week': case 'thisweek': return DateOp.thisWeek;
      case 'last-week': case 'lastweek': return DateOp.lastWeek;
      case 'next-week': case 'nextweek': return DateOp.nextWeek;
      case 'this-month': case 'thismonth': return DateOp.thisMonth;
      case 'last-month': case 'lastmonth': return DateOp.lastMonth;
      case 'overdue': return DateOp.overdue;
      default: return null;
    }
  }

  Future<void> reloadTags() => _key.currentState!.reloadTags();
  void applyTokens(List<String> t) => _key.currentState!.applyTokens(t);
  List<String> getTokens() => _key.currentState!.getTokens();

  @override
  Widget build(BuildContext context) => TagCombinator(
    key: _key,
    mode: CombinatorMode.search,
    trailing: widget.trailing,
    onChanged: (_, _) => widget.onChanged(_toQuery()),
  );
}
