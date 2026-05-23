/// Mini query parser for sift search bar.
///
/// Syntax:
///   #tag           → exact tag match
///   #prefix/*      → wildcard prefix match
///   -tag           → exclude tag (supports *)
///   prefix:period  → date filter on tag prefix
///   plain word     → full-text search in headline/body/tags

class ParsedQuery {
  List<String> tagsAnd;
  List<String> tagsNot;
  List<DateClause> dates;
  String? fulltext;

  ParsedQuery({required this.tagsAnd, required this.tagsNot, required this.dates, this.fulltext});

  bool get isEmpty => tagsAnd.isEmpty && tagsNot.isEmpty && dates.isEmpty && fulltext == null;

  @override String toString() => 'Query(and:$tagsAnd not:$tagsNot dates:$dates ft:"$fulltext")';
}

class DateClause {
  final String prefix;   // e.g. "done", "created", "due"
  final DateOp op;
  DateClause(this.prefix, this.op);
  @override String toString() => '$prefix:$op';
}

enum DateOp {
  today, yesterday, tomorrow,
  thisWeek, lastWeek, nextWeek,
  thisMonth, lastMonth,
  overdue,
}

/// Parse a search string into a structured query.
ParsedQuery parseQuery(String input) {
  final tagsAnd = <String>[];
  final tagsNot = <String>[];
  final dates = <DateClause>[];
  final fulltextWords = <String>[];

  // Split by whitespace, respecting quotes (basic)
  final tokens = _tokenize(input);

  for (final token in tokens) {
    if (token.startsWith('-#') || token.startsWith('-@')) {
      // Exclude tag: -#work/rtd  or  -@work/rtd
      final tag = token.substring(2);
      if (tag.isNotEmpty) tagsNot.add(tag);

    } else if (token.startsWith('#') || token.startsWith('@')) {
      // Include tag: #work/rtd  or  @work/rtd
      final tag = token.substring(1);
      if (tag.isNotEmpty) tagsAnd.add(tag);

    } else if (_isDateClause(token)) {
      // Date filter: done:this-week, created:today, due:overdue
      final parts = token.split(':');
      final prefix = parts[0];
      final period = parts[1];
      final op = _parseDateOp(period);
      if (op != null) {
        dates.add(DateClause(prefix, op));
      } else {
        // Unknown date period, treat as fulltext
        fulltextWords.add(token);
      }

    } else {
      // Full-text word
      fulltextWords.add(token);
    }
  }

  return ParsedQuery(
    tagsAnd: tagsAnd,
    tagsNot: tagsNot,
    dates: dates,
    fulltext: fulltextWords.isEmpty ? null : fulltextWords.join(' '),
  );
}

/// Split input into tokens, handling basic quoting
List<String> _tokenize(String input) {
  final tokens = <String>[];
  final buf = StringBuffer();
  bool inQuote = false;

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '"') {
      inQuote = !inQuote;
      continue;
    }
    if (c == ' ' && !inQuote) {
      if (buf.isNotEmpty) { tokens.add(buf.toString()); buf.clear(); }
    } else {
      buf.write(c);
    }
  }
  if (buf.isNotEmpty) tokens.add(buf.toString());
  return tokens;
}

bool _isDateClause(String token) {
  // Matches: prefix:period where prefix is alphabetic, period is known
  final colon = token.indexOf(':');
  if (colon <= 0 || colon == token.length - 1) return false;
  final prefix = token.substring(0, colon);
  final period = token.substring(colon + 1);
  if (!RegExp(r'^[a-z][a-z-]*$').hasMatch(prefix)) return false;
  return _parseDateOp(period) != null;
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
