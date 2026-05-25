import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ── C function signatures ────────────────────────────────────────
// Native = C side types (Uint8 for bool), Dart = Dart side types (int for bool)

typedef SiftInitNative = Pointer<Utf8> Function(Pointer<Utf8> dataDir);
typedef SiftInitDart = Pointer<Utf8> Function(Pointer<Utf8> dataDir);

typedef SiftListParsedNative = Pointer<Utf8> Function(Pointer<Utf8> query, Uint8 showDone);
typedef SiftListParsedDart = Pointer<Utf8> Function(Pointer<Utf8> query, int showDone);

typedef SiftGetEntryNative = Pointer<Utf8> Function(Pointer<Utf8> idPrefix);
typedef SiftGetEntryDart = Pointer<Utf8> Function(Pointer<Utf8> idPrefix);

typedef SiftAllTagsNative = Pointer<Utf8> Function();
typedef SiftAllTagsDart = Pointer<Utf8> Function();

typedef SiftSearchNative = Pointer<Utf8> Function(Pointer<Utf8> query);
typedef SiftSearchDart = Pointer<Utf8> Function(Pointer<Utf8> query);

typedef SiftStatsNative = Pointer<Utf8> Function();
typedef SiftStatsDart = Pointer<Utf8> Function();

typedef SiftParseQueryNative = Pointer<Utf8> Function(Pointer<Utf8> input);
typedef SiftParseQueryDart = Pointer<Utf8> Function(Pointer<Utf8> input);

typedef SiftAddNative = Pointer<Utf8> Function(Pointer<Utf8> headline, Pointer<Utf8> body, Pointer<Utf8> tagsJson);
typedef SiftAddDart = Pointer<Utf8> Function(Pointer<Utf8> headline, Pointer<Utf8> body, Pointer<Utf8> tagsJson);

typedef SiftDeleteNative = Pointer<Utf8> Function(Pointer<Utf8> id);
typedef SiftDeleteDart = Pointer<Utf8> Function(Pointer<Utf8> id);

typedef SiftEditNative = Pointer<Utf8> Function(Pointer<Utf8> id, Pointer<Utf8> headline, Pointer<Utf8> body);
typedef SiftEditDart = Pointer<Utf8> Function(Pointer<Utf8> id, Pointer<Utf8> headline, Pointer<Utf8> body);

typedef SiftTagNative = Pointer<Utf8> Function(Pointer<Utf8> id, Pointer<Utf8> addJson, Pointer<Utf8> rmJson);
typedef SiftTagDart = Pointer<Utf8> Function(Pointer<Utf8> id, Pointer<Utf8> addJson, Pointer<Utf8> rmJson);

typedef SiftRenameTagNative = Pointer<Utf8> Function(Pointer<Utf8> old, Pointer<Utf8> newTag);
typedef SiftRenameTagDart = Pointer<Utf8> Function(Pointer<Utf8> old, Pointer<Utf8> newTag);

typedef SiftBatchDeleteNative = Pointer<Utf8> Function(Pointer<Utf8> idsJson);
typedef SiftBatchDeleteDart = Pointer<Utf8> Function(Pointer<Utf8> idsJson);

typedef SiftBatchTagNative = Pointer<Utf8> Function(Pointer<Utf8> idsJson, Pointer<Utf8> addJson, Pointer<Utf8> rmJson);
typedef SiftBatchTagDart = Pointer<Utf8> Function(Pointer<Utf8> idsJson, Pointer<Utf8> addJson, Pointer<Utf8> rmJson);

typedef SiftExportNative = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef SiftExportDart = Pointer<Utf8> Function(Pointer<Utf8> path);

typedef SiftImportNative = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef SiftImportDart = Pointer<Utf8> Function(Pointer<Utf8> path);

typedef SiftFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef SiftFreeStringDart = void Function(Pointer<Utf8> ptr);

// ── Dart models ──────────────────────────────────────────────────

class FrbBody {
  final String type; // "text", "markdown", "file", "empty"
  final String? content;
  final String? path;

  FrbBody({required this.type, this.content, this.path});

  factory FrbBody.text(String content) => FrbBody(type: 'text', content: content);
  factory FrbBody.file(String path) => FrbBody(type: 'file', path: path);
  const FrbBody.empty() : type = 'empty', content = null, path = null;

  factory FrbBody.fromJson(Map<String, dynamic> json) => FrbBody(
        type: json['type'] as String,
        content: json['content'] as String?,
        path: json['path'] as String?,
      );

  Map<String, dynamic> toJson() {
    switch (type) {
      case 'text': return {'type': 'text', 'content': content};
      case 'file': return {'type': 'file', 'path': path};
      default: return {'type': 'empty'};
    }
  }

  bool get isEmpty => type == 'empty';
  String get text => content ?? path ?? '';
}

class FrbEntry {
  final String id;
  final String name;
  final FrbBody body;
  final List<String> tags;

  FrbEntry({required this.id, required this.name, this.body = const FrbBody.empty(), List<String>? tags})
      : tags = tags ?? [];

  factory FrbEntry.fromJson(Map<String, dynamic> json) => FrbEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        body: json['body'] is Map
            ? FrbBody.fromJson(json['body'] as Map<String, dynamic>)
            : FrbBody.text((json['body'] as String?) ?? ''),
        tags: List<String>.from((json['tags'] as List?) ?? []),
      );

  String get idPrefix => id.substring(0, id.length.clamp(0, 8));
}

class FrbParsedQuery {
  final List<String> tagsAnd;
  final List<String> tagsOr;
  final List<String> tagsNot;
  final List<FrbDateClause> dates;
  final String? fulltext;
  final bool isEmpty;

  FrbParsedQuery({
    required this.tagsAnd,
    required this.tagsOr,
    required this.tagsNot,
    required this.dates,
    this.fulltext,
  }) : isEmpty = tagsAnd.isEmpty && tagsOr.isEmpty && tagsNot.isEmpty && dates.isEmpty && fulltext == null;

  factory FrbParsedQuery.fromJson(Map<String, dynamic> json) {
    final dates = (json['dates'] as List?)
        ?.map((d) => FrbDateClause.fromJson(d as Map<String, dynamic>))
        .toList() ?? [];
    return FrbParsedQuery(
      tagsAnd: List<String>.from((json['tags_and'] as List?) ?? []),
      tagsOr: List<String>.from((json['tags_or'] as List?) ?? []),
      tagsNot: List<String>.from((json['tags_not'] as List?) ?? []),
      dates: dates,
      fulltext: json['fulltext'] as String?,
    );
  }
}

class FrbDateClause {
  final String prefix;
  final String op;
  FrbDateClause(this.prefix, this.op);
  factory FrbDateClause.fromJson(Map<String, dynamic> json) =>
      FrbDateClause(json['prefix'] as String, json['op'] as String);
}

// ── NativeService ─────────────────────────────────────────────────

class NativeService {
  late final DynamicLibrary _lib;
  bool _initialized = false;

  // Function bindings (Dart-side signatures)
  late final SiftInitDart _siftInit;
  late final SiftListParsedDart _siftListParsed;
  late final SiftGetEntryDart _siftGetEntry;
  late final SiftAllTagsDart _siftAllTags;
  late final SiftSearchDart _siftSearch;
  late final SiftStatsDart _siftStats;
  late final SiftParseQueryDart _siftParseQuery;
  late final SiftAddDart _siftAdd;
  late final SiftDeleteDart _siftDelete;
  late final SiftEditDart _siftEdit;
  late final SiftTagDart _siftTag;
  late final SiftRenameTagDart _siftRenameTag;
  late final SiftBatchDeleteDart _siftBatchDelete;
  late final SiftBatchTagDart _siftBatchTag;
  late final SiftExportDart _siftExport;
  late final SiftImportDart _siftImport;
  late final SiftFreeStringDart _siftFreeString;

  Future<void> init({String? dataDir}) async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libsift_ffi.so');
    } else if (Platform.isLinux) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      _lib = DynamicLibrary.open('$exeDir/lib/libsift_ffi.so');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libsift_ffi.dylib');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('sift_ffi.dll');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    _bind();

    final dirPtr = dataDir != null ? dataDir.toNativeUtf8() : nullptr;
    final ptr = _siftInit(dirPtr);
    calloc.free(dirPtr);
    final result = _decode(ptr);
    if (result['ok'] != true) {
      throw Exception('sift init failed: ${result['error']}');
    }
    _initialized = true;
  }

  void _bind() {
    _siftInit = _lib.lookupFunction<SiftInitNative, SiftInitDart>('sift_init');
    _siftListParsed = _lib.lookupFunction<SiftListParsedNative, SiftListParsedDart>('sift_list_parsed');
    _siftGetEntry = _lib.lookupFunction<SiftGetEntryNative, SiftGetEntryDart>('sift_get_entry');
    _siftAllTags = _lib.lookupFunction<SiftAllTagsNative, SiftAllTagsDart>('sift_all_tags');
    _siftSearch = _lib.lookupFunction<SiftSearchNative, SiftSearchDart>('sift_search');
    _siftStats = _lib.lookupFunction<SiftStatsNative, SiftStatsDart>('sift_stats');
    _siftParseQuery = _lib.lookupFunction<SiftParseQueryNative, SiftParseQueryDart>('sift_parse_query');
    _siftAdd = _lib.lookupFunction<SiftAddNative, SiftAddDart>('sift_add');
    _siftDelete = _lib.lookupFunction<SiftDeleteNative, SiftDeleteDart>('sift_delete');
    _siftEdit = _lib.lookupFunction<SiftEditNative, SiftEditDart>('sift_edit');
    _siftTag = _lib.lookupFunction<SiftTagNative, SiftTagDart>('sift_tag');
    _siftRenameTag = _lib.lookupFunction<SiftRenameTagNative, SiftRenameTagDart>('sift_rename_tag');
    _siftBatchDelete = _lib.lookupFunction<SiftBatchDeleteNative, SiftBatchDeleteDart>('sift_batch_delete');
    _siftBatchTag = _lib.lookupFunction<SiftBatchTagNative, SiftBatchTagDart>('sift_batch_tag');
    _siftExport = _lib.lookupFunction<SiftExportNative, SiftExportDart>('sift_export');
    _siftImport = _lib.lookupFunction<SiftImportNative, SiftImportDart>('sift_import');
    _siftFreeString = _lib.lookupFunction<SiftFreeStringNative, SiftFreeStringDart>('sift_free_string');
  }

  Map<String, dynamic> _decode(Pointer<Utf8> ptr) {
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _decodeList(Pointer<Utf8> ptr, String errorContext) {
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    final decoded = jsonDecode(json);
    if (decoded is Map && decoded.containsKey('error')) {
      throw Exception('$errorContext: ${decoded['error']}');
    }
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  // ── public API ──────────────────────────────────────────────

  Future<List<FrbEntry>> listParsed(String query, {bool showDone = false}) async {
    final qPtr = query.toNativeUtf8();
    final ptr = _siftListParsed(qPtr, showDone ? 1 : 0);
    calloc.free(qPtr);
    return _decodeList(ptr, 'listParsed').map((e) => FrbEntry.fromJson(e)).toList();
  }

  Future<FrbParsedQuery> parseQuery(String input) async {
    final p = input.toNativeUtf8();
    final ptr = _siftParseQuery(p);
    calloc.free(p);
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    return FrbParsedQuery.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<List<(String, int)>> allTags() async {
    final ptr = _siftAllTags();
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    final list = jsonDecode(json) as List;
    return list.map((e) => (e[0] as String, e[1] as int)).toList();
  }

  Future<List<FrbEntry>> search(String query) async {
    final qPtr = query.toNativeUtf8();
    final ptr = _siftSearch(qPtr);
    calloc.free(qPtr);
    return _decodeList(ptr, 'search').map((e) => FrbEntry.fromJson(e)).toList();
  }

  Future<FrbEntry?> getEntry(String idPrefix) async {
    final p = idPrefix.toNativeUtf8();
    final ptr = _siftGetEntry(p);
    calloc.free(p);
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    final decoded = jsonDecode(json);
    if (decoded == null) return null;
    if (decoded is Map && decoded.containsKey('error')) throw Exception(decoded['error']);
    return FrbEntry.fromJson(decoded as Map<String, dynamic>);
  }

  Future<List<FrbEntry>> getViews() async {
    final qPtr = '#\$view'.toNativeUtf8();
    final ptr = _siftListParsed(qPtr, 1);
    calloc.free(qPtr);
    return _decodeList(ptr, 'getViews').map((e) => FrbEntry.fromJson(e)).toList();
  }

  Future<void> saveView(String name, String expression) async {
    await add(name, body: FrbBody.text(expression), tags: ['view']);
  }

  Future<void> deleteView(String id) async {
    await delete(id);
  }

  Future<FrbStatsData> stats() async {
    final ptr = _siftStats();
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    return FrbStatsData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<FrbEntry> add(String name, {FrbBody body = const FrbBody.empty(), List<String> tags = const []}) async {
    final nPtr = name.toNativeUtf8();
    final bPtr = jsonEncode(body.toJson()).toNativeUtf8();
    final tPtr = jsonEncode(tags).toNativeUtf8();
    final ptr = _siftAdd(nPtr, bPtr, tPtr);
    calloc.free(nPtr); calloc.free(bPtr); calloc.free(tPtr);
    final json = ptr.toDartString();
    _siftFreeString(ptr);
    final decoded = jsonDecode(json);
    if (decoded is Map && decoded.containsKey('error')) throw Exception(decoded['error']);
    return FrbEntry.fromJson(decoded as Map<String, dynamic>);
  }

  Future<bool> delete(String id) async {
    final idPtr = id.toNativeUtf8();
    final ptr = _siftDelete(idPtr);
    calloc.free(idPtr);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['ok'] == true;
  }

  Future<bool> edit(String id, {String? name, FrbBody? body}) async {
    final idPtr = id.toNativeUtf8();
    final nPtr = (name != null ? jsonEncode(name) : 'null').toNativeUtf8();
    final bPtr = (body != null ? jsonEncode(body.toJson()) : 'null').toNativeUtf8();
    final ptr = _siftEdit(idPtr, nPtr, bPtr);
    calloc.free(idPtr); calloc.free(nPtr); calloc.free(bPtr);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['ok'] == true;
  }

  Future<bool> tag(String id, {List<String> addTags = const [], List<String> rmTags = const []}) async {
    final idPtr = id.toNativeUtf8();
    final addPtr = jsonEncode(addTags).toNativeUtf8();
    final rmPtr = jsonEncode(rmTags).toNativeUtf8();
    final ptr = _siftTag(idPtr, addPtr, rmPtr);
    calloc.free(idPtr); calloc.free(addPtr); calloc.free(rmPtr);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['ok'] == true;
  }

  Future<int> renameTag(String old, String newTag) async {
    final oldPtr = old.toNativeUtf8();
    final newPtr = newTag.toNativeUtf8();
    final ptr = _siftRenameTag(oldPtr, newPtr);
    calloc.free(oldPtr); calloc.free(newPtr);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['count'] as int;
  }

  Future<int> batchDelete(List<String> ids) async {
    final p = jsonEncode(ids).toNativeUtf8();
    final ptr = _siftBatchDelete(p);
    calloc.free(p);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['count'] as int;
  }

  Future<int> batchTag(List<String> ids, {List<String> addTags = const [], List<String> rmTags = const []}) async {
    final idPtr = jsonEncode(ids).toNativeUtf8();
    final addPtr = jsonEncode(addTags).toNativeUtf8();
    final rmPtr = jsonEncode(rmTags).toNativeUtf8();
    final ptr = _siftBatchTag(idPtr, addPtr, rmPtr);
    calloc.free(idPtr); calloc.free(addPtr); calloc.free(rmPtr);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['count'] as int;
  }

  Future<void> exportTo(String path) async {
    final p = path.toNativeUtf8();
    final ptr = _siftExport(p);
    calloc.free(p);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
  }

  Future<int> importFrom(String path) async {
    final p = path.toNativeUtf8();
    final ptr = _siftImport(p);
    calloc.free(p);
    final result = _decode(ptr);
    if (result.containsKey('error')) throw Exception(result['error']);
    return result['count'] as int;
  }
}

// Re-export for convenience
class FrbStatsData {
  final int total;
  final int active;
  final int done;
  final int uniqueTags;
  FrbStatsData({required this.total, required this.active, required this.done, required this.uniqueTags});
  factory FrbStatsData.fromJson(Map<String, dynamic> json) => FrbStatsData(
        total: json['total'] as int,
        active: json['active'] as int,
        done: json['done'] as int,
        uniqueTags: json['unique_tags'] as int,
      );
}
