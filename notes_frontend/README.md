# notes_frontend

Unified Flutter notes app.

## Sync behavior

The app syncs in the foreground using a serialized `SyncEngine`:

- on app resume/foreground
- when connectivity returns (offline → online)
- when a user-initiated action triggers sync (if present in UI)

### Background sync scheduling (best-effort)

True background sync is platform dependent in Flutter. This project uses a
plugin-friendly abstraction so we can support background schedulers when
available while keeping the app fully functional when they are not.

Implementation:
- `lib/data/sync/background_sync_scheduler.dart`
  - `BackgroundSyncScheduler` abstraction
  - current implementation: `ForegroundResumedSyncScheduler` (safe fallback)

Behavior guarantees:
- If background execution is not available, the app still syncs on resume and
  connectivity changes (no crashes, no blocked startup).

#### How to enable real background execution (future step)

To support true periodic background sync, add a scheduler plugin and create a
new implementation behind `BackgroundSyncSchedulerFactory`, for example:
- `workmanager` (Android + iOS, requires native setup)
- `background_fetch` (Android + iOS, requires native setup)

Notes:
- iOS requires enabling background modes and configuring permitted task
  identifiers.
- Android requires appropriate JobScheduler/WorkManager configuration and
  permissions.

This codebase is intentionally structured so adding a plugin does **not** require
changing the repository or sync engine logic.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
