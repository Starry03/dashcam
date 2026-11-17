# AGENTS.md

This file provides repository guidance for coding agents working on Dashcam.
For Claude-specific entry points, also keep [CLAUDE.md](./CLAUDE.md) synchronized.

## Project summary

Dashcam is a private Android-first Flutter app that records camera video in a foreground
service, samples location, maintains rolling segments, and optionally adds GPS/speed
overlays. The Flutter UI and Android native recording implementation communicate through
platform channels.

## Commands

Run Flutter commands from `app/`:

```bash
cd app
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter build apk
flutter build apk --release
```

The release APK is written to
`app/build/app/outputs/flutter-apk/app-release.apk`.
A release workflow builds it automatically on `v*` tags.

Physical Android devices are strongly recommended for validation: camera, audio, location,
foreground services, MediaStore, and installation flows are not fully testable in emulators.

## Architecture

### Flutter

- `app/lib/main.dart` creates the Material 3 app and opens `DashcamHomePage`.
- `app/lib/features/dashcam/presentation/dashcam_home_page.dart` owns the screen state,
  settings, update flow, status polling, and user actions.
- `app/lib/features/dashcam/presentation/widgets/` contains focused UI widgets.
- `app/lib/features/dashcam/data/dashcam_platform.dart` wraps the channels:
  - Method channel: `dashcam/control`
  - Event channel: `dashcam/status`
- `app/lib/features/dashcam/domain/dashcam_status.dart` is the Dart status model.
- `app/lib/features/dashcam/domain/gps_status.dart` defines UI GPS states.
- `app/lib/features/dashcam/services/github_release_service.dart` checks GitHub releases.

Status is delivered as a map and deserialized with `DashcamStatus.fromMap`. Settings are
persisted with `SharedPreferences`; camera lens, loop duration, infinity focus, and overlay
mode are restored and sent to native during initialization.

The UI has recording, pause/resume, incident lock, camera lens, loop recording,
infinity-focus, video-overlay, gallery, update-check, and APK-install flows.

### Android native

| File | Responsibility |
|---|---|
| `MainActivity.kt` | Configures the platform channels and requests runtime permissions. |
| `DashcamStatusStore.kt` | Holds native recording state and emits the `dashcam/status` map; also manages storage warnings and notifications. |
| `DashcamForegroundService.kt` | Owns CameraX and GPS, recording segments, pause/resume, segment locking, loop pruning, and foreground notifications. |
| `DashcamVideoBurnIn.kt` | Builds subtitle/ASS overlays and optionally performs FFmpeg burn-in post-processing. |
| `BootReceiver.kt` | Receives boot completion but intentionally does not auto-start recording. |

Native control methods on `dashcam/control` include `startRecording`, `stopRecording`,
`pauseRecording`, `resumeRecording`, `lockIncident`, `setCameraLens`,
`setLoopRecordingMinutes`, `setInfinityFocus`, `setVideoOverlayMode`, `refreshStatus`,
`openVideoFolder`, `getCacheDir`, and `installApk`.

`DashcamStatusStore` is the native source of truth for status events. Every relevant state
change should call `emitCurrent(context)`. The status includes recording state, pause state,
elapsed time, storage usage/free space, latest segment, lock state, warning, camera lens,
speed, GPS fix, infinity focus, and overlay mode.

### Recording behavior

- CameraX segments roll every 5 minutes (`SEGMENT_MS`).
- Loop recording retains the last 5, 10, 15, or 30 minutes, or saves all clips when set to 0.
- The oldest unlocked segments are pruned when free storage falls below 500 MB.
- A low-storage warning is emitted at 5 GB and reset behavior starts above 6 GB.
- Videos are stored in `Movies/Dashcam/` through MediaStore on Android Q+ and in external
  storage on older Android versions.
- BootReceiver currently implements manual start only.

### Video overlays

`DashcamVideoBurnIn` supports:

- `subtitles`: attach a subtitle track/sidecar without transcoding.
- `burnin`: generate an overlay and transcode with libx264.
- `none`: keep the original segment without an overlay.

Burn-in is optional. It requires
`app/android/app/libs/ffmpeg-kit-full-gpl-6.0-2.aar`.
The Gradle build detects the AAR and enables FFmpeg support when present. Without it,
burn-in processing is skipped and the original clip remains available.

## Change guidelines

- Preserve the MethodChannel and EventChannel names and existing map keys unless both Dart
  and Kotlin sides are updated together.
- Keep `DashcamStatusStore` as the native status source of truth.
- Use `emitCurrent()` for recording-state and configuration changes that Flutter must observe.
- Keep loop pruning locked-clip-safe and never delete the active recording or a locked incident.
- Do not change storage thresholds or segment duration without updating documentation and tests.
- Preserve the Android lifecycle behavior of the foreground service.
- Avoid unrelated refactors in the single-screen Flutter implementation; add or reuse widgets
  under `features/dashcam/presentation/widgets/`.
- Keep settings persistence and native state in sync.
- Update both `AGENTS.md` and `CLAUDE.md` when architecture or repository conventions change.
- Release APK updates require Android apps to keep a stable signing key. Configure
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
  `ANDROID_KEY_PASSWORD` GitHub secrets. Without the keystore, release builds use the debug
  signing key and future updates may fail with a signature mismatch.

## Validation

For Flutter-only changes, run:

```bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/widget_test.dart
```

For native or channel changes, also build and install on a physical Android device:

```bash
cd app
flutter build apk --debug
flutter install
```
