import 'dart:async';

import 'package:notes_frontend/features/sync/sync_engine.dart';

abstract class BackgroundSyncScheduler {
  void start();
  void dispose();
}

/// Safe fallback that does nothing beyond allowing the DI shape to exist.
///
/// Real implementations can be swapped in later with plugins.
class ForegroundResumedSyncScheduler implements BackgroundSyncScheduler {
  ForegroundResumedSyncScheduler({required SyncEngine engine}) : _engine = engine;

  final SyncEngine _engine;
  Timer? _timer;

  @override
  void start() {
    // Best-effort periodic sync while app is running (no guarantees).
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(_engine.syncNow(trigger: SyncTrigger.manual));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
  }
}
