/// SiftService — reads/writes the same JSONL as sift CLI.
/// No special semantics for any tag — "done" is just a tag like any other.

import 'dart:convert';
import 'dart:io';

class Entry {
  final String id;
  String headline;
  String body;
  List<String> tags;

  Entry({required this.id, required this.headline, this.body = '', List<String>? tags})
      : tags = tags ?? [];

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as String,
        headline: json['headline'] as String,
        body: (json['body'] as String?) ?? '',
        tags: List<String>.from((json['tags'] as List?) ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'headline': headline,
        'body': body,
        'tags': tags,
      };

  String get idPrefix => id.substring(0, id.length.clamp(0, 8));
}

class SiftService {
  late String _dataPath;
  List<Entry> _entries = [];

  Future<void> init() async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final sep = Platform.pathSeparator;
    final dataDir = Platform.environment['XDG_DATA_HOME'] ?? '$home$sep.local${sep}share';
    _dataPath = '$dataDir${sep}sift${sep}entries.jsonl';
    await _load();
  }

  Future<void> _load() async {
    final file = File(_dataPath);
    if (!file.existsSync()) { _entries = []; return; }
    final lines = await file.readAsLines();
    _entries = lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => Entry.fromJson(jsonDecode(l)))
        .toList();
  }

  Future<void> _save() async {
    final file = File(_dataPath);
    file.parent.createSync(recursive: true);
    final lines = _entries.map((e) => jsonEncode(e.toJson())).join('\n');
    final sink = file.openWrite();
    sink.write('$lines\n');
    await sink.flush();
    await sink.close();
  }

  String _newId() {
    final bytes = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch.abs() % 256);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// List entries with optional tag/date filtering.
  /// [dateFilters] maps tag prefix (e.g. "done", "created") to date op string.
  Future<List<Entry>> list({
    List<String> tagsAnd = const [],
    List<String> tagsOr = const [],
    List<String> tagsNot = const [],
    Map<String, String> dateFilters = const {},
  }) async {
    await _load();
    var result = List<Entry>.from(_entries);

    for (final tag in tagsAnd) {
      if (tag.endsWith('*')) {
        final prefix = tag.substring(0, tag.length - 1);
        result.retainWhere((e) => e.tags.any((t) => t.startsWith(prefix)));
      } else {
        result.retainWhere((e) => e.tags.contains(tag));
      }
    }
    if (tagsOr.isNotEmpty) {
      result.retainWhere((e) => e.tags.any((t) => tagsOr.contains(t)));
    }
    for (final tag in tagsNot) {
      if (tag.endsWith('*')) {
        final prefix = tag.substring(0, tag.length - 1);
        result.removeWhere((e) => e.tags.any((t) => t.startsWith(prefix)));
      } else {
        result.removeWhere((e) => e.tags.any((t) => t == tag));
      }
    }

    // Date filters on any tag prefix
    for (final entry in dateFilters.entries) {
      final prefix = '${entry.key}/';
      final op = entry.value;
      result = _applyDateFilter(result, prefix, op);
    }

    return result;
  }

  Future<Entry> add(String headline, {String body = '', List<String> tags = const []}) async {
    final entry = Entry(id: _newId(), headline: headline, body: body, tags: List<String>.from(tags));
    _entries.add(entry);
    await _save();
    return entry;
  }

  Future<bool> edit(String idPrefix, {String? headline, String? body}) async {
    final e = _entries.where((e) => e.id.startsWith(idPrefix)).firstOrNull;
    if (e == null) return false;
    if (headline != null) e.headline = headline;
    if (body != null) e.body = body;
    await _save();
    return true;
  }

  Future<bool> delete(String idPrefix) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id.startsWith(idPrefix));
    if (_entries.length == before) return false;
    await _save();
    return true;
  }

  /// Generic tag add/remove. All tags are equal.
  Future<bool> tag(String idPrefix, {List<String> addTags = const [], List<String> rmTags = const []}) async {
    final e = _entries.where((e) => e.id.startsWith(idPrefix)).firstOrNull;
    if (e == null) return false;
    for (final tag in addTags) {
      if (!e.tags.contains(tag)) e.tags.add(tag);
    }
    for (final pattern in rmTags) {
      if (pattern.endsWith('*')) {
        final prefix = pattern.substring(0, pattern.length - 1);
        e.tags.removeWhere((t) => t.startsWith(prefix));
      } else {
        e.tags.remove(pattern);
      }
    }
    await _save();
    return true;
  }

  Future<List<(String, int)>> allTags() async {
    await _load();
    final counts = <String, int>{};
    for (final e in _entries) {
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final result = counts.entries.map((e) => (e.key, e.value)).toList();
    result.sort((a, b) => b.$2.compareTo(a.$2));
    return result;
  }

  /// Apply a date filter: entries must have a tag starting with [prefix] whose date
  /// satisfies [op]. Supported ops: today, yesterday, tomorrow, this-week, last-week,
  /// next-week, this-month, last-month, overdue.
  List<Entry> _applyDateFilter(List<Entry> entries, String prefix, String op) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate date boundaries for the op
    DateTime? after;  // inclusive
    DateTime? before; // inclusive

    switch (op) {
      case 'today':
        after = today;
        before = today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'yesterday':
        after = today.subtract(const Duration(days: 1));
        before = today.subtract(const Duration(seconds: 1));
        break;
      case 'tomorrow':
        after = today.add(const Duration(days: 1));
        before = today.add(const Duration(days: 2)).subtract(const Duration(seconds: 1));
        break;
      case 'this-week':
        after = today.subtract(Duration(days: today.weekday - 1));
        before = today.add(Duration(days: 7 - today.weekday)).add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'last-week':
        after = today.subtract(Duration(days: today.weekday + 6));
        before = today.subtract(Duration(days: today.weekday)).subtract(const Duration(seconds: 1));
        break;
      case 'next-week':
        after = today.add(Duration(days: 8 - today.weekday));
        before = today.add(Duration(days: 14 - today.weekday)).add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'this-month':
        after = DateTime(today.year, today.month, 1);
        before = DateTime(today.year, today.month + 1, 1).subtract(const Duration(seconds: 1));
        break;
      case 'last-month':
        after = DateTime(today.year, today.month - 1, 1);
        before = DateTime(today.year, today.month, 1).subtract(const Duration(seconds: 1));
        break;
      case 'overdue':
        before = today.subtract(const Duration(seconds: 1));
        break;
      default:
        return entries;
    }

    return entries.where((e) {
      final dates = e.tags
          .where((t) => t.startsWith(prefix))
          .map((t) => _parseTagDate(t.substring(prefix.length)))
          .where((d) => d != null);
      return dates.any((d) {
        if (after != null && d!.isBefore(after)) return false;
        if (before != null && d!.isAfter(before)) return false;
        return true;
      });
    }).toList();
  }

  /// Try to parse a date string from a tag value (supports multiple formats)
  DateTime? _parseTagDate(String s) {
    // Try ISO format: 2026-05-23 or 2026-05-23T10:00
    try {
      return DateTime.parse(s);
    } catch (_) {}
    // Try 2026.05.23
    try {
      return DateTime.parse(s.replaceAll('.', '-'));
    } catch (_) {}
    return null;
  }

  /// Export all entries to a JSONL file
  Future<void> exportTo(String path) async {
    await _load();
    final file = File(path);
    file.parent.createSync(recursive: true);
    final lines = _entries.map((e) => jsonEncode(e.toJson())).join('\n');
    await file.writeAsString('$lines\n');
  }

  /// Import entries from a JSONL file (merge: skip duplicates by id)
  Future<int> importFrom(String path) async {
    final file = File(path);
    if (!file.existsSync()) throw Exception('File not found: $path');
    final lines = await file.readAsLines();
    await _load();

    final existingIds = _entries.map((e) => e.id).toSet();
    var added = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final entry = Entry.fromJson(jsonDecode(line));
        if (!existingIds.contains(entry.id)) {
          _entries.add(entry);
          existingIds.add(entry.id);
          added++;
        }
      } catch (_) {}
    }
    if (added > 0) await _save();
    return added;
  }

  Future<List<Entry>> search(String query) async {
    await _load();
    final q = query.toLowerCase();
    return _entries.where((e) =>
        e.headline.toLowerCase().contains(q) ||
        e.body.toLowerCase().contains(q) ||
        e.tags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }

  /// Delete multiple entries by id prefixes. Returns count deleted.
  Future<int> batchDelete(List<String> idPrefixes) async {
    await _load();
    var deleted = 0;
    for (final prefix in idPrefixes) {
      final before = _entries.length;
      _entries.removeWhere((e) => e.id.startsWith(prefix));
      if (_entries.length < before) deleted++;
    }
    if (deleted > 0) await _save();
    return deleted;
  }

  /// Add/remove tags on multiple entries. Returns count modified.
  Future<int> batchTag(List<String> idPrefixes, {List<String> addTags = const [], List<String> rmTags = const []}) async {
    await _load();
    var modified = 0;
    for (final prefix in idPrefixes) {
      final e = _entries.where((e) => e.id.startsWith(prefix)).firstOrNull;
      if (e == null) continue;
      var changed = false;
      for (final tag in addTags) {
        if (!e.tags.contains(tag)) { e.tags.add(tag); changed = true; }
      }
      for (final pattern in rmTags) {
        if (pattern.endsWith('*')) {
          final p = pattern.substring(0, pattern.length - 1);
          final before = e.tags.length;
          e.tags.removeWhere((t) => t.startsWith(p));
          if (e.tags.length < before) changed = true;
        } else {
          if (e.tags.remove(pattern)) changed = true;
        }
      }
      if (changed) { e.tags.sort(); e.tags = e.tags.toSet().toList(); modified++; }
    }
    if (modified > 0) await _save();
    return modified;
  }
}
