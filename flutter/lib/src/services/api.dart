/// SiftService wraps future flutter_rust_bridge calls.
/// Currently uses a stub implementation that reads JSONL directly.
/// Replace stub methods with FRB-generated calls after codegen.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  bool get isDone => tags.any((t) => t.startsWith('done/'));

  List<String> get displayTags =>
      tags.where((t) => !t.startsWith('created/') && !t.startsWith('done/')).toList();
}

class StatsData {
  final int total, active, done, uniqueTags;
  StatsData({required this.total, required this.active, required this.done, required this.uniqueTags});
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
    await file.writeAsString(lines + '\n');
  }

  String _newId() {
    final bytes = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch.abs() % 256);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<Entry>> list({
    List<String> tagsAnd = const [],
    List<String> tagsOr = const [],
    List<String> tagsNot = const [],
    String? due,
    bool showDone = false,
  }) async {
    await _load();
    var result = List<Entry>.from(_entries);

    if (!showDone) result.removeWhere((e) => e.isDone);

    for (final tag in tagsAnd) {
      result.retainWhere((e) => e.tags.any((t) => t == tag));
    }
    if (tagsOr.isNotEmpty) {
      result.retainWhere((e) => e.tags.any((t) => tagsOr.contains(t)));
    }
    for (final tag in tagsNot) {
      result.removeWhere((e) => e.tags.any((t) => t == tag));
    }

    return result;
  }

  Future<Entry> add(String headline, {String body = '', List<String> tags = const []}) async {
    final entry = Entry(
      id: _newId(),
      headline: headline,
      body: body,
      tags: List<String>.from(tags),
    );
    _entries.add(entry);
    await _save();
    return entry;
  }

  Future<bool> done(String idPrefix) async {
    final e = _entries.where((e) => e.id.startsWith(idPrefix)).firstOrNull;
    if (e == null) return false;
    final now = DateTime.now().toIso8601String().substring(0, 16);
    if (!e.tags.any((t) => t.startsWith('done/'))) {
      e.tags.add('done/$now');
    }
    await _save();
    return true;
  }

  Future<bool> undo(String idPrefix) async {
    final e = _entries.where((e) => e.id.startsWith(idPrefix)).firstOrNull;
    if (e == null) return false;
    e.tags.removeWhere((t) => t.startsWith('done/'));
    await _save();
    return true;
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
        if (!t.startsWith('created/') && !t.startsWith('done/')) {
          counts[t] = (counts[t] ?? 0) + 1;
        }
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

  Future<StatsData> stats() async {
    await _load();
    final active = _entries.where((e) => !e.isDone).length;
    final tags = <String>{};
    for (final e in _entries) {
      for (final t in e.tags) { tags.add(t); }
    }
    return StatsData(
      total: _entries.length,
      active: active,
      done: _entries.length - active,
      uniqueTags: tags.length,
    );
  }
}
