import 'dart:collection';

import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:notes_frontend/features/sync/notes_sync_service.dart';
import 'package:notes_frontend/shared/clock.dart';

class InMemoryNotesSyncService implements NotesSyncService {
  InMemoryNotesSyncService({required Clock clock}) : _clock = clock;

  final Clock _clock;

  // Simple in-memory "remote" store.
  final Map<String, Note> _remote = HashMap();

  @override
  Future<void> pushNotes(List<Note> notes) async {
    // Mimic server accepting client notes, with no transformation.
    for (final note in notes) {
      _remote[note.id] = note;
    }

    // Touch a "server time" moment to allow pulls to advance markers if needed.
    // (We still prefer using max(updatedAt) from pulled notes on the client.)
    _clock.now();
  }

  @override
  Future<List<Note>> pullNotes({required int sinceMillis}) async {
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMillis, isUtc: true);

    final out = <Note>[];
    for (final note in _remote.values) {
      if (note.updatedAt.isAfter(since) || note.updatedAt.isAtSameMomentAs(since)) {
        out.add(note);
      }
    }
    return out;
  }
}
