# CLAUDE.md

This file provides Claude-specific repository guidance. The canonical agent reference is
[AGENTS.md](./AGENTS.md); keep both files synchronized.

## Quick commands

```bash
cd app
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter build apk --release
```

## Architecture reminder

- Flutter UI and Android native code communicate through `dashcam/control` and
  `dashcam/status`.
- `DashcamStatusStore` is the native status source of truth and emits through
  `emitCurrent()`.
- `DashcamForegroundService` owns CameraX, GPS, segments, loop retention, and lock/pruning.
- `DashcamVideoBurnIn` handles optional subtitles or libx264 burn-in.
- Boot does not currently auto-start recording.

Follow [AGENTS.md](./AGENTS.md) for the complete current codebase, conventions, and validation guidance.
