import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notes_frontend/app/providers.dart';
import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:notes_frontend/features/notes/presentation/note_editor_screen.dart';
import 'package:notes_frontend/features/sync/sync_engine.dart';

final notesQueryProvider = StateProvider<String>((ref) => '');

final notesStreamProvider =
    StreamProvider.autoDispose<List<Note>>((ref) {
  final query = ref.watch(notesQueryProvider);
  return ref.watch(notesRepositoryProvider).watchNotes(query: query);
});

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  String _previewText(Note note) {
    final content = note.content.trim();
    if (content.isNotEmpty) return content;

    final title = note.title.trim();
    if (title.isNotEmpty) return ' ';
    return ' ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final syncStateAsync = ref.watch(syncEngineStateProvider);

    final syncSubtitle = syncStateAsync.when(
      data: (s) {
        switch (s.status) {
          case SyncEngineStatus.syncing:
            return 'Syncing…';
          case SyncEngineStatus.success:
            return 'Sync complete';
          case SyncEngineStatus.failed:
            return 'Sync failed';
          case SyncEngineStatus.offline:
            return 'Offline';
          case SyncEngineStatus.idle:
            return null;
        }
      },
      loading: () => null,
      error: (_, __) => 'Sync status unavailable',
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notes'),
            if (syncSubtitle != null)
              Text(
                syncSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withAlpha(230),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync',
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(syncEngineProvider).syncNow(trigger: SyncTrigger.manual);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final note = await ref.read(notesRepositoryProvider).createNote();

          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(noteId: note.id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search notes...',
              ),
              onChanged: (value) {
                ref.read(notesQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return const Center(child: Text('No notes yet'));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.dividerColor,
                      ),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final title = note.title.trim().isEmpty
                            ? '(Untitled)'
                            : note.title.trim();

                        final updated = DateFormat.yMMMd()
                            .add_jm()
                            .format(note.updatedAt.toLocal());

                        final preview = _previewText(note);

                        return ListTile(
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Updated: $updated',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    NoteEditorScreen(noteId: note.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load notes: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
