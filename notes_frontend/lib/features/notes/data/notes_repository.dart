import 'package:notes_frontend/features/notes/data/db/notes_dao.dart';
import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:notes_frontend/shared/clock.dart';
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required NotesDao dao,
    required Clock clock,
  })  : _dao = dao,
        _clock = clock;

  final NotesDao _dao;
  final Clock _clock;

  Stream<List<Note>> watchNotes({required String query}) {
    return _dao.watchNotes(query: query);
  }

  Stream<Note?> watchNote(String id) {
    return _dao.watchNoteById(id);
  }

  Future<Note> createNote() async {
    final now = _clock.now();
    const uuid = Uuid();
    final note = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      syncStatus: SyncStatus.dirty,
      lastSyncedAt: null,
    );
    await _dao.upsertLocal(note);
    return note;
  }

  Future<void> saveNote({
    required String id,
    required String title,
    required String content,
  }) async {
    final existing = await _dao.getNoteById(id);
    final now = _clock.now();
    final createdAt = existing?.createdAt ?? now;

    final note = Note(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: now,
      isDeleted: false,
      syncStatus: SyncStatus.dirty,
      lastSyncedAt: null,
    );
    await _dao.upsertLocal(note);
  }

  Future<void> deleteNote(String id) async {
    final now = _clock.now();
    await _dao.markDeleted(id: id, updatedAtMillis: now.millisecondsSinceEpoch);
  }

  Future<List<Note>> getNotesForPush() => _dao.getNotesForPush();

  Future<void> markNotesSyncing(List<String> ids) async {
    await _dao.setSyncStatus(ids: ids, status: SyncStatus.syncing);
  }

  Future<void> markNotesPushedClean({
    required List<String> ids,
    required DateTime lastSyncedAt,
  }) async {
    await _dao.setSyncStatus(
      ids: ids,
      status: SyncStatus.clean,
      lastSyncedAtMillis: lastSyncedAt.millisecondsSinceEpoch,
    );
  }

  Future<void> markNotesFailed(List<String> ids) async {
    await _dao.setSyncStatus(ids: ids, status: SyncStatus.failed);
  }

  Future<int> getLastSyncAtMillis() => _dao.getLastSyncAtMillis();

  Future<void> updateLastSyncAtMillis(int millis) =>
      _dao.updateLastSyncAtMillis(millis);

  Future<void> reconcileRemoteNotes(List<Note> remoteNotes) =>
      _dao.reconcileRemoteNotes(remoteNotes);

  Future<void> purgeSyncedTombstones() => _dao.purgeSyncedTombstones();
}
