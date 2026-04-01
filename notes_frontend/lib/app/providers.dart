import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_frontend/features/notes/data/db/notes_database.dart';
import 'package:notes_frontend/features/notes/data/db/notes_dao.dart';
import 'package:notes_frontend/features/notes/data/notes_repository.dart';
import 'package:notes_frontend/features/sync/background_sync_scheduler.dart';
import 'package:notes_frontend/features/sync/connectivity_monitor.dart';
import 'package:notes_frontend/features/sync/in_memory_notes_sync_service.dart';
import 'package:notes_frontend/features/sync/sync_engine.dart';
import 'package:notes_frontend/shared/clock.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final notesDbProvider = Provider<NotesDatabase>((ref) {
  final db = NotesDatabase();
  ref.onDispose(db.close);
  return db;
});

final notesDaoProvider = Provider<NotesDao>((ref) {
  return NotesDao(db: ref.watch(notesDbProvider));
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(
    dao: ref.watch(notesDaoProvider),
    clock: ref.watch(clockProvider),
  );
});

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityMonitorProvider).isOnlineStream;
});

final syncServiceProvider = Provider<NotesSyncService>((ref) {
  // Kotlin-parity: in-memory "remote" so app works without backend.
  return InMemoryNotesSyncService(clock: ref.watch(clockProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    repository: ref.watch(notesRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final syncEngineStateProvider = StreamProvider<SyncEngineState>((ref) {
  return ref.watch(syncEngineProvider).stateStream;
});

/// Owns WidgetsBindingObserver and triggers sync on resume.
///
/// IMPORTANT: no BuildContext usage here, only repository/sync calls.
class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver({required this.onResumed});

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Fire-and-forget. Any errors are handled within SyncEngine.
      unawaited(onResumed());
    }
  }
}

final appBindingsProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);

  // 1) Sync on app resume/foreground.
  final observer = _AppLifecycleObserver(
    onResumed: () => engine.syncNow(trigger: SyncTrigger.appResumed),
  );
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

  // 2) Sync on offline -> online transition.
  bool? lastOnline;
  final sub = ref.watch(isOnlineStreamProvider.stream).listen((isOnline) {
    final wasOnline = lastOnline;
    lastOnline = isOnline;
    if (wasOnline == false && isOnline == true) {
      unawaited(engine.syncNow(trigger: SyncTrigger.connectivityRegained));
    }
  });
  ref.onDispose(sub.cancel);

  // 3) Best-effort background scheduling abstraction (safe no-op/foreground fallback).
  final scheduler = ForegroundResumedSyncScheduler(engine: engine);
  scheduler.start();
  ref.onDispose(scheduler.dispose);
});
