import 'package:notes_frontend/features/notes/domain/note.dart';

abstract class NotesSyncService {
  Future<void> pushNotes(List<Note> notes);

  Future<List<Note>> pullNotes({required int sinceMillis});
}
