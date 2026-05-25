import 'package:flutter/material.dart';
import 'tag_combinator.dart';

/// Filter bar — thin wrapper over TagCombinator in search mode.
/// Passes the raw query string to the parent; Rust does the parsing.
class FilterBar extends StatefulWidget {
  final VoidCallback onChanged;
  final Widget? trailing;
  const FilterBar({super.key, required this.onChanged, this.trailing});

  @override
  State<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends State<FilterBar> {
  final _key = GlobalKey<TagCombinatorState>();

  /// The combinator query string built from active chips.
  String get queryString => _key.currentState!.queryString;

  Future<void> reloadTags() => _key.currentState!.reloadTags();
  void applyTokens(List<String> t) => _key.currentState!.applyTokens(t);
  List<String> getTokens() => _key.currentState!.getTokens();

  @override
  Widget build(BuildContext context) => TagCombinator(
    key: _key,
    mode: CombinatorMode.search,
    trailing: widget.trailing,
    onChanged: (_, _) => widget.onChanged(),
  );
}
