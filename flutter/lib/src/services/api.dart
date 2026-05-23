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

  /// List entries with optional tag/due filtering. No special filtering for any tag.
  Future<List<Entry>> list({
    List<String> tagsAnd = const [],
    List<String> tagsOr = const [],
    List<String> tagsNot = const [],
    String? due,
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

  Future<List<Entry>> search(String query) async {
    await _load();
    final q = query.toLowerCase();
    return _entries.where((e) =>
        e.headline.toLowerCase().contains(q) ||
        e.body.toLowerCase().contains(q) ||
        e.tags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }
}
