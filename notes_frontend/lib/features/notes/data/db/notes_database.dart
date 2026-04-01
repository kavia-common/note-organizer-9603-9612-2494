import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class NotesDatabase {
  NotesDatabase();

  static const _dbName = 'notes.db';
  static const _dbVersion = 1;

  Database? _db;

  final _changeController = StreamController<int>.broadcast();
  int _changeTick = 0;

  Stream<int> get changeStream => _changeController.stream;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

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

  void notifyChanged() {
    _changeTick++;
    _changeController.add(_changeTick);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    await _changeController.close();
  }
}
