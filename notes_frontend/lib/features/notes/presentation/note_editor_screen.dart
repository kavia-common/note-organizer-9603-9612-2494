import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_frontend/app/providers.dart';
import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:notes_frontend/features/sync/sync_engine.dart';

final noteProvider = StreamProvider.autoDispose.family<Note?, String>((ref, id) {
  return ref.watch(notesRepositoryProvider).watchNote(id);
});

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // Primitive flags only (safe across async gaps).
  bool _didInitControllers = false;
  bool _popAfterSave = false;
  bool _popAfterDelete = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text;
    final content = _contentController.text;

    await ref.read(notesRepositoryProvider).saveNote(
          id: widget.noteId,
          title: title,
          content: content,
        );

    // Trigger sync best-effort after save.
    await ref
        .read(syncEngineProvider)
        .syncNow(trigger: SyncTrigger.afterSave);

    // Only set primitive flag after await.
    setState(() {
      _popAfterSave = true;
    });
  }

  Future<void> _delete() async {
    await ref.read(notesRepositoryProvider).deleteNote(widget.noteId);

    // Trigger sync best-effort after delete.
    await ref
        .read(syncEngineProvider)
        .syncNow(trigger: SyncTrigger.afterDelete);

    setState(() {
      _popAfterDelete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteProvider(widget.noteId));

    // Navigation controlled from build based on flags (avoid context after await).
    if (_popAfterSave || _popAfterDelete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Organizer'),
      ),
      body: noteAsync.when(
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Note not found'));
          }

          if (!_didInitControllers) {
            _titleController.text = note.title;
            _contentController.text = note.content;
            _didInitControllers = true;
          }

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ListView(
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          decoration: const InputDecoration(
                            labelText: 'Content',
                            alignLabelWithHint: true,
                          ),
                          minLines: 12,
                          maxLines: null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('SAVE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete note?'),
                              content: const Text(
                                'This will remove the note from the list. The delete will sync when possible.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await _delete();
                          }
                        },
                        child: const Text('DELETE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load note: $e')),
      ),
    );
  }
}
