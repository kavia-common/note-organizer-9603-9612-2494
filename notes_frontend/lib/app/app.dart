import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_frontend/app/providers.dart';
import 'package:notes_frontend/app/theme.dart';
import 'package:notes_frontend/features/notes/presentation/notes_list_screen.dart';

class NotesApp extends ConsumerWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure lifecycle + connectivity bindings are initialized early.
    ref.watch(appBindingsProvider);

    return MaterialApp(
      title: 'Notes',
      debugShowCheckedModeBanner: false,
      theme: buildNotesTheme(),
      home: const NotesListScreen(),
    );
  }
}
