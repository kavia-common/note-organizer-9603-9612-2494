# Android Build Verification Notes (Flutter)

This file documents build-blocking issues found and fixed for Android debug/release APK builds.

## Issues found
1. **NDK version mismatch**
   - Build output indicated plugins require **NDK 27.0.12077973**
   - Project was using **NDK 26.3.11579264** by default.

2. **Dart compilation errors**
   - `SyncEngineState` type used in `notes_list_screen.dart` without importing its definition (`lib/domain/sync_models.dart`).
   - `connectivity_monitor.dart` contained an invalid `import 'dart:io' as io;` statement inside a method body, which is not valid Dart syntax.

## Fixes applied
- Pinned `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts`.
- Added `import '../../../domain/sync_models.dart';` to `notes_list_screen.dart`.
- Simplified `connectivity_monitor.dart` to use a proper top-level `dart:io` import and direct `InternetAddress.lookup`.

## Expected outcome
- `flutter build apk --debug` and `flutter build apk --release` should no longer be blocked by Android NDK selection or Dart compilation errors.
