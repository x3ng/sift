import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// GUI-managed preferences — doesn't touch CLI's entries.jsonl.
/// Stores default filter, layout preferences, etc.
class Prefs {
  static Future<File> _file() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/prefs.json');
    }
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final sep = Platform.pathSeparator;
    final dataDir = Platform.environment['XDG_DATA_HOME'] ?? '$home$sep.local${sep}share';
    final dir = Directory('$dataDir${sep}sift');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${sep}prefs.json');
  }

  static Future<Map<String, dynamic>> _load() async {
    final f = await _file();
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, dynamic> data) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(data));
  }

  /// Save default filter query tokens
  static Future<void> setDefaultFilter(List<String> tokens) async {
    final data = await _load();
    data['default_filter'] = tokens;
    await _save(data);
  }

  /// Load default filter tokens, or null if none saved
  static Future<List<String>?> getDefaultFilter() async {
    final data = await _load();
    final raw = data['default_filter'];
    if (raw is List) return raw.cast<String>();
    return null;
  }

  /// Clear the default filter
  static Future<void> clearDefaultFilter() async {
    final data = await _load();
    data.remove('default_filter');
    await _save(data);
  }
}
