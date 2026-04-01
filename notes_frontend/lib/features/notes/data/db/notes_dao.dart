import 'dart:async';

import 'package:notes_frontend/features/notes/data/db/notes_database.dart';
import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:sqflite/sqflite.dart';

class NotesDao {
  NotesDao({required NotesDatabase db}) : _db = db;

  final NotesDatabase _db;

  Stream<List<Note>> watchNotes({required String query}) async* {
    // Emit immediately and then on every change tick.
    yield await _queryNotes(query: query);

    await for (final _ in _db.changeStream) {
      yield await _queryNotes(query: query);
    }
  }

  Stream<Note?> watchNoteById(String id) async* {
    yield await getNoteById(id);
    await for (final _ in _db.changeStream) {
      yield await getNoteById(id);
    }
  }

  Future<Note?> getNoteById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<void> upsertLocal(Note note) async {
    final db = await _db.database;
    await db.insert(
      'notes',
      _toRow(note),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _db.notifyChanged();
  }

  Future<void> markDeleted({
    required String id,
    required int updatedAtMillis,
  }) async {
    final db = await _db.database;
    await db.update(
      'notes',
      {
        'deleted': 1,
        'updated_at': updatedAtMillis,
        'sync_status': SyncStatus.dirty.name,
        'last_synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notifyChanged();
  }

  Future<void> setSyncStatus({
    required List<String> ids,
    required SyncStatus status,
    int? lastSyncedAtMillis,
  }) async {
    if (ids.isEmpty) return;
    final db = await _db.database;

    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'notes',
        {
          'sync_status': status.name,
          if (lastSyncedAtMillis != null) 'last_synced_at': lastSyncedAtMillis,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    _db.notifyChanged();
  }

  Future<List<Note>> getNotesForPush() async {
    final db = await _db.database;
    final rows = await db.query(
      'notes',
      where: "sync_status != ?",
      whereArgs: [SyncStatus.clean.name],
    );
    return rows.map(_mapRow).toList();
  }

  Future<int> getLastSyncAtMillis() async {
    final db = await _db.database;
    final rows = await db.query(
      'sync_state',
      columns: ['last_sync_at'],
      where: 'key = ?',
      whereArgs: ['notes'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['last_sync_at'] as int?) ?? 0;
  }

  Future<void> updateLastSyncAtMillis(int millis) async {
    final db = await _db.database;
    final current = await getLastSyncAtMillis();
    final next = millis > current ? millis : current;

    await db.update(
      'sync_state',
      {'last_sync_at': next},
      where: 'key = ?',
      whereArgs: ['notes'],
    );
    _db.notifyChanged();
  }

  Future<void> reconcileRemoteNotes(List<Note> remoteNotes) async {
    // Deterministic LWW + Kotlin tie-break: keep local on equal updatedAt.
    final db = await _db.database;
    final batch = db.batch();

    for (final remote in remoteNotes) {
      final localRows = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [remote.id],
        limit: 1,
      );

      if (localRows.isEmpty) {
        batch.insert(
          'notes',
          _toRow(
            remote.copyWith(
              syncStatus: SyncStatus.clean,
            ),
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        continue;
      }

      final local = _mapRow(localRows.first);

      final remoteMs = remote.updatedAt.millisecondsSinceEpoch;
      final localMs = local.updatedAt.millisecondsSinceEpoch;

      final shouldApplyRemote = remoteMs > localMs;

      if (shouldApplyRemote) {
        batch.update(
          'notes',
          _toRow(
            remote.copyWith(
              syncStatus: SyncStatus.clean,
            ),
          ),
          where: 'id = ?',
          whereArgs: [remote.id],
        );
      } else {
        // keep local (also keep dirty/failed states)
      }
    }

    await batch.commit(noResult: true);
    _db.notifyChanged();
  }

  Future<void> purgeSyncedTombstones() async {
    // Kotlin parity: delete rows that are tombstoned AND clean AND have last_synced_at.
    final db = await _db.database;
    await db.delete(
      'notes',
      where: 'deleted = 1 AND sync_status = ? AND last_synced_at IS NOT NULL',
      whereArgs: [SyncStatus.clean.name],
    );
    _db.notifyChanged();
  }

  Future<List<Note>> _queryNotes({required String query}) async {
    final db = await _db.database;

    const baseWhere = 'deleted = 0';
    const orderBy = 'updated_at DESC';

    if (query.trim().isEmpty) {
      final rows = await db.query(
        'notes',
        where: baseWhere,
        orderBy: orderBy,
      );
      return rows.map(_mapRow).toList();
    }

    final escaped = _escapeLike(query.trim());
    final pattern = '%$escaped%';

    // Escape for literal substring matching, consistent with Kotlin's wildcard-escaping.
    final rows = await db.query(
      'notes',
      where:
          "$baseWhere AND (title LIKE ? ESCAPE '\\' OR content LIKE ? ESCAPE '\\')",
      whereArgs: [pattern, pattern],
      orderBy: orderBy,
    );

    return rows.map(_mapRow).toList();
  }

  String _escapeLike(String input) {
    // Escape order matters: escape backslash first.
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Note _mapRow(Map<String, Object?> row) {
    final statusStr = (row['sync_status'] as String?) ?? SyncStatus.clean.name;
    final status = SyncStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => SyncStatus.clean,
    );

    final lastSyncedMillis = row['last_synced_at'] as int?;
    return Note(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
        isUtc: true,
      ),
      isDeleted: (row['deleted'] as int) == 1,
      syncStatus: status,
      lastSyncedAt: lastSyncedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSyncedMillis, isUtc: true),
    );
  }

  Map<String, Object?> _toRow(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'created_at': note.createdAt.millisecondsSinceEpoch,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
      'deleted': note.isDeleted ? 1 : 0,
      'sync_status': note.syncStatus.name,
      'last_synced_at': note.lastSyncedAt?.millisecondsSinceEpoch,
    };
  }
}
