import 'dart:async';
import 'dart:math';

import 'package:notes_frontend/features/notes/data/notes_repository.dart';
import 'package:notes_frontend/features/notes/domain/note.dart';
import 'package:notes_frontend/features/sync/connectivity_monitor.dart';
import 'package:notes_frontend/features/sync/notes_sync_service.dart';

enum SyncTrigger {
  manual,
  appResumed,
  connectivityRegained,
  afterSave,
  afterDelete,
}

enum SyncEngineStatus {
  idle,
  syncing,
  success,
  failed,
  offline,
}

class SyncEngineState {
  const SyncEngineState({
    required this.status,
    required this.lastMessage,
    required this.lastCompletedAt,
  });

  final SyncEngineStatus status;
  final String? lastMessage;
  final DateTime? lastCompletedAt;

  SyncEngineState copyWith({
    SyncEngineStatus? status,
    String? lastMessage,
    DateTime? lastCompletedAt,
  }) {
    return SyncEngineState(
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }

  static const initial = SyncEngineState(
    status: SyncEngineStatus.idle,
    lastMessage: null,
    lastCompletedAt: null,
  );
}

class SyncEngine {
  SyncEngine({
    required NotesRepository repository,
    required NotesSyncService syncService,
    required ConnectivityMonitor connectivity,
  })  : _repository = repository,
        _syncService = syncService,
        _connectivity = connectivity {
    _stateController.add(SyncEngineState.initial);
  }

  final NotesRepository _repository;
  final NotesSyncService _syncService;
  final ConnectivityMonitor _connectivity;

  final _stateController = StreamController<SyncEngineState>.broadcast();
  SyncEngineState _state = SyncEngineState.initial;

  Stream<SyncEngineState> get stateStream => _stateController.stream;

  bool _syncInProgress = false;
  int _consecutiveFailures = 0;
  Timer? _retryTimer;

  void dispose() {
    _retryTimer?.cancel();
    _stateController.close();
  }

  Future<void> syncNow({required SyncTrigger trigger}) async {
    // Serialize; ignore overlapping triggers.
    if (_syncInProgress) return;

    if (!_connectivity.isOnline) {
      _emit(_state.copyWith(
        status: SyncEngineStatus.offline,
        lastMessage: 'Offline',
      ));
      return;
    }

    _syncInProgress = true;
    _retryTimer?.cancel();

    _emit(_state.copyWith(
      status: SyncEngineStatus.syncing,
      lastMessage: 'Syncing…',
    ));

    try {
      final dirty = await _repository.getNotesForPush();
      final dirtyIds = dirty.map((e) => e.id).toList();

      // Push
      if (dirty.isNotEmpty) {
        await _repository.markNotesSyncing(dirtyIds);
        await _syncService.pushNotes(dirty);

        final now = DateTime.now().toUtc();
        await _repository.markNotesPushedClean(ids: dirtyIds, lastSyncedAt: now);
      }

      // Pull
      final lastSyncAt = await _repository.getLastSyncAtMillis();
      final remote = await _syncService.pullNotes(sinceMillis: lastSyncAt);
      await _repository.reconcileRemoteNotes(remote);

      // Monotonic sync marker.
      final maxRemoteUpdatedAtMillis = remote.isEmpty
          ? lastSyncAt
          : remote
              .map((n) => n.updatedAt.millisecondsSinceEpoch)
              .reduce(max);
      await _repository.updateLastSyncAtMillis(maxRemoteUpdatedAtMillis);

      // Kotlin parity: purge tombstones after successful sync cycle.
      await _repository.purgeSyncedTombstones();

      _consecutiveFailures = 0;
      _emit(_state.copyWith(
        status: SyncEngineStatus.success,
        lastMessage: 'Sync complete',
        lastCompletedAt: DateTime.now().toUtc(),
      ));
    } catch (e) {
      // Mark any notes still in syncing as failed for visibility and retries.
      try {
        final syncing = await _repository.getNotesForPush();
        final syncingIds = syncing
            .where((n) => n.syncStatus == SyncStatus.syncing)
            .map((n) => n.id)
            .toList();
        await _repository.markNotesFailed(syncingIds);
      } catch (_) {
        // Ignore secondary errors.
      }

      _consecutiveFailures++;
      _emit(_state.copyWith(
        status: SyncEngineStatus.failed,
        lastMessage: 'Sync failed',
        lastCompletedAt: DateTime.now().toUtc(),
      ));

      _scheduleRetryIfOnline();
    } finally {
      _syncInProgress = false;
    }
  }

  void _scheduleRetryIfOnline() {
    if (!_connectivity.isOnline) return;

    const baseDelaySeconds = 2;
    const maxDelaySeconds = 60;

    final exponent = min(_consecutiveFailures - 1, 10);
    final delay = min(maxDelaySeconds, baseDelaySeconds * (1 << exponent));

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), () {
      unawaited(syncNow(trigger: SyncTrigger.manual));
    });
  }

  void _emit(SyncEngineState next) {
    _state = next;
    _stateController.add(next);
  }
}
