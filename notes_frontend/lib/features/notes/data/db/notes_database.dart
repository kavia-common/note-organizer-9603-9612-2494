import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// NotesDatabase abstracts persistence for notes.
///
/// On mobile/desktop it uses sqflite. On Flutter Web (preview), sqflite is not
/// supported, so we fall back to an in-memory database that satisfies the same
/// DAO queries used by the app.
///
/// This keeps the app previewable without changing repository/DAO code.
class NotesDatabase {
  NotesDatabase() : _impl = kIsWeb ? _InMemoryNotesDatabaseImpl() : _SqfliteNotesDatabaseImpl();

  final _NotesDatabaseImpl _impl;

  Stream<int> get changeStream => _impl.changeStream;

  Future<Database> get database => _impl.database;

  void notifyChanged() => _impl.notifyChanged();

  Future<void> close() => _impl.close();
}

abstract class _NotesDatabaseImpl {
  Stream<int> get changeStream;
  Future<Database> get database;
  void notifyChanged();
  Future<void> close();
}

final class _SqfliteNotesDatabaseImpl implements _NotesDatabaseImpl {
  static const _dbName = 'notes.db';
  static const _dbVersion = 1;

  Database? _db;

  final _changeController = StreamController<int>.broadcast();
  int _changeTick = 0;

  @override
  Stream<int> get changeStream => _changeController.stream;

  @override
  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/$_dbName';

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE notes(
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL,
  last_synced_at INTEGER
);
''');

        await db.execute('''
CREATE INDEX idx_notes_updated_at ON notes(updated_at DESC);
''');

        await db.execute('''
CREATE TABLE sync_state(
  key TEXT PRIMARY KEY,
  last_sync_at INTEGER NOT NULL
);
''');

        // Seed sync_state with a default marker.
        await db.insert(
          'sync_state',
          {'key': 'notes', 'last_sync_at': 0},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      },
    );

    _db = db;
    return db;
  }

  @override
  void notifyChanged() {
    _changeTick++;
    _changeController.add(_changeTick);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    await _changeController.close();
  }
}

/// Web-only fallback using sqflite's in-memory database.
///
/// sqflite uses platform channels and isn't available on web, but the `sqflite`
/// API types are still available at compile-time. We avoid calling any web-
/// unsupported functions (like getDatabasesPath/openDatabase with a file path)
/// by using `openDatabase(inMemoryDatabasePath)`, which maps to an in-memory
/// database for supported platforms; on web this avoids filesystem/path usage.
///
/// If the preview environment still lacks sqflite method channel support, this
/// implementation ensures we never invoke those platform channels by not
/// calling into sqflite at all (see the guarded initializer below).
final class _InMemoryNotesDatabaseImpl implements _NotesDatabaseImpl {
  Database? _db;

  final _changeController = StreamController<int>.broadcast();
  int _changeTick = 0;

  @override
  Stream<int> get changeStream => _changeController.stream;

  @override
  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    // On web, calling into sqflite's method channel will fail.
    // Instead, use a lightweight FakeDatabase implementation backed by memory.
    final db = await _FakeWebDatabase.open();

    _db = db;
    return db;
  }

  @override
  void notifyChanged() {
    _changeTick++;
    _changeController.add(_changeTick);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    await _changeController.close();
  }
}

/// Minimal in-memory Database implementation for Flutter Web preview.
///
/// It only supports the subset of sqflite APIs used by NotesDao/NotesRepository:
/// - query/insert/update/delete
/// - batch().update/insert + commit(noResult: true)
///
/// This is NOT intended for production web persistence; it is to unblock preview.
final class _FakeWebDatabase implements Database {
  _FakeWebDatabase._();

  static Future<Database> open() async {
    final db = _FakeWebDatabase._();
    db._initSchema();
    return db;
  }

  final Map<String, Map<String, Map<String, Object?>>> _tablesByPk = {};
  final Map<String, String> _primaryKeyByTable = {};

  void _initSchema() {
    _tablesByPk['notes'] = {};
    _primaryKeyByTable['notes'] = 'id';

    _tablesByPk['sync_state'] = {};
    _primaryKeyByTable['sync_state'] = 'key';

    // Seed sync_state
    _tablesByPk['sync_state']!['notes'] = {'key': 'notes', 'last_sync_at': 0};
  }

  @override
  Batch batch() => _FakeWebBatch(this);

  @override
  Database get database => this;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = _tablesByPk[table]?.values.toList() ?? <Map<String, Object?>>[];

    Iterable<Map<String, Object?>> filtered = rows;

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      filtered = _applyWhere(filtered, where, whereArgs);
    } else if (where != null) {
      filtered = _applyWhere(filtered, where, const []);
    }

    final selectedColumns = columns;
    final projected = selectedColumns == null
        ? filtered
        : filtered.map((r) => {for (final c in selectedColumns) c: r[c]});

    final sorted = _applyOrderBy(projected.toList(), orderBy);

    final start = offset ?? 0;
    final endExclusive =
        limit == null ? sorted.length : (start + limit).clamp(0, sorted.length);
    if (start >= sorted.length) return <Map<String, Object?>>[];
    return sorted.sublist(start, endExclusive);
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    int? bufferSize,
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    throw UnsupportedError('Cursor queries not supported in preview DB');
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    throw UnsupportedError('Cursor queries not supported in preview DB');
  }

  Iterable<Map<String, Object?>> _applyWhere(
    Iterable<Map<String, Object?>> input,
    String where,
    List<Object?> whereArgs,
  ) {
    final w = where.trim();

    if (w == 'deleted = 0') {
      return input.where((r) => (r['deleted'] as int? ?? 0) == 0);
    }

    if (w == 'id = ?') {
      final id = whereArgs.first as String;
      return input.where((r) => r['id'] == id);
    }

    if (w == 'key = ?') {
      final key = whereArgs.first as String;
      return input.where((r) => r['key'] == key);
    }

    if (w == 'sync_status != ?') {
      final status = whereArgs.first as String;
      return input.where((r) => r['sync_status'] != status);
    }

    if (w ==
        'deleted = 1 AND sync_status = ? AND last_synced_at IS NOT NULL') {
      final status = whereArgs.first as String;
      return input.where((r) {
        final deleted = (r['deleted'] as int? ?? 0) == 1;
        final okStatus = r['sync_status'] == status;
        final hasLastSynced = r['last_synced_at'] != null;
        return deleted && okStatus && hasLastSynced;
      });
    }

    if (w.startsWith('deleted = 0 AND (title LIKE') &&
        whereArgs.length >= 2) {
      final pattern1 = (whereArgs[0] as String).toLowerCase();
      final pattern2 = (whereArgs[1] as String).toLowerCase();
      final needle1 = pattern1.replaceAll('%', '');
      final needle2 = pattern2.replaceAll('%', '');
      return input.where((r) {
        if ((r['deleted'] as int? ?? 0) != 0) return false;
        final title = (r['title'] as String? ?? '').toLowerCase();
        final content = (r['content'] as String? ?? '').toLowerCase();
        return title.contains(needle1) || content.contains(needle2);
      });
    }

    return input;
  }

  List<Map<String, Object?>> _applyOrderBy(
    List<Map<String, Object?>> rows,
    String? orderBy,
  ) {
    if (orderBy == null || orderBy.trim().isEmpty) return rows;
    if (orderBy.trim().toLowerCase() == 'updated_at desc') {
      rows.sort((a, b) =>
          ((b['updated_at'] as int? ?? 0)).compareTo(a['updated_at'] as int? ?? 0));
    }
    return rows;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final pk = _primaryKeyByTable[table];
    if (pk == null) throw UnsupportedError('Unknown table: $table');

    final key = values[pk]?.toString();
    if (key == null) {
      throw ArgumentError('Missing primary key $pk for table $table');
    }

    final existing = _tablesByPk[table]!;
    if (existing.containsKey(key) &&
        conflictAlgorithm != ConflictAlgorithm.replace) {
      return 0;
    }
    existing[key] = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final rows = await query(table, where: where, whereArgs: whereArgs);
    if (rows.isEmpty) return 0;

    final pk = _primaryKeyByTable[table]!;
    int updated = 0;
    for (final row in rows) {
      final key = row[pk]!.toString();
      final existing = _tablesByPk[table]![key];
      if (existing == null) continue;
      existing.addAll(values);
      updated++;
    }
    return updated;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = await query(table, where: where, whereArgs: whereArgs);
    if (rows.isEmpty) return 0;

    final pk = _primaryKeyByTable[table]!;
    int deleted = 0;
    for (final row in rows) {
      final key = row[pk]!.toString();
      if (_tablesByPk[table]!.remove(key) != null) deleted++;
    }
    return deleted;
  }

  @override
  Future<T> readTransaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    throw UnsupportedError('Read transactions not supported in preview DB');
  }

  // --- Unused Database APIs for this project; keep minimal stubs. ---

  @override
  Future<void> close() async {}

  @override
  bool get isOpen => true;

  @override
  String get path => ':memory:';

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    throw UnsupportedError('Transactions not supported in preview DB');
  }

  @override
  Future<int> execute(String sql, [List<Object?>? arguments]) {
    throw UnsupportedError('execute() not supported in preview DB');
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) {
    throw UnsupportedError('rawQuery() not supported in preview DB');
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    throw UnsupportedError('rawInsert() not supported in preview DB');
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    throw UnsupportedError('rawUpdate() not supported in preview DB');
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    throw UnsupportedError('rawDelete() not supported in preview DB');
  }

  Future<void> setVersion(int version) => Future.value();

  Future<int> getVersion() async => 1;

  Future<void> setMaxSize(int maxSize) => Future.value();

  Future<int> getMaxSize() async => 0;

  Future<void> setPageSize(int pageSize) => Future.value();

  Future<int> getPageSize() async => 0;

  Future<void> setLocale(String locale) => Future.value();

  Future<void> setLockingEnabled(bool enabled) => Future.value();

  Future<void> compact() => Future.value();

  Future<void> deleteDatabase(String path) => Future.value();

  DatabaseFactory get factory => throw UnsupportedError('factory not supported');

  Future<List<String>> getDatabasesPath() => throw UnsupportedError('Not supported');

  Future<void> updateDatabase(String path, int version) => Future.value();

  Future<void> onConfigure(Database db) => Future.value();

  Future<void> onCreate(Database db, int version) => Future.value();

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) => Future.value();

  Future<void> onDowngrade(Database db, int oldVersion, int newVersion) => Future.value();

  Future<void> onOpen(Database db) => Future.value();

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    throw UnsupportedError('Not supported');
  }

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) {
    throw UnsupportedError('Not supported');
  }
}

final class _FakeWebBatch implements Batch {
  _FakeWebBatch(this._db);

  final _FakeWebDatabase _db;
  final List<Future<void> Function()> _ops = [];

  @override
  int get length => _ops.length;

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? nullColumnHack,
  }) {
    _ops.add(() async {
      await _db.insert(
        table,
        values,
        conflictAlgorithm: conflictAlgorithm,
        nullColumnHack: nullColumnHack,
      );
    });
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _ops.add(() async {
      await _db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
    });
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _ops.add(() async {
      await _db.delete(table, where: where, whereArgs: whereArgs);
    });
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _ops.add(() async {});
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    for (final op in _ops) {
      await op();
    }
    return <Object?>[];
  }

  @override
  Future<List<Object?>> apply({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) =>
      commit(
        exclusive: exclusive,
        noResult: noResult,
        continueOnError: continueOnError,
      );

  // Unused
  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {}

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {}

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {}

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}
}
