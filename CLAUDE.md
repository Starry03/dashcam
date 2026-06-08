# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All Flutter commands run from the `app/` directory.

```bash
cd app
flutter pub get          # install dependencies
flutter run              # run on connected device (debug)
flutter build apk        # build release APK
flutter analyze          # static analysis / linting
flutter test             # run unit/widget tests
flutter test test/widget_test.dart  # run a single test file
```

A release APK is also built automatically by GitHub Actions whenever a `v*` tag is pushed (see `.github/workflows/android-release-on-tag.yml`). The APK lands at `app/build/app/outputs/flutter-apk/app-release.apk`.

Physical Android device is strongly recommended — camera and GPS are not available in emulators.

## Architecture

The app is split into two layers that communicate through Flutter platform channels.

### Flutter UI (`app/lib/main.dart`)

The entire Flutter side lives in a single file. Key classes:

- **`DashcamPlatformBridge`** — static wrapper around the two platform channels:
  - `dashcam/control` (MethodChannel) — sends commands to native: `startRecording`, `stopRecording`, `pauseRecording`, `resumeRecording`, `lockIncident`, `setCameraLens`, `refreshStatus`, `updateLiveStats`, `openVideoFolder`.
  - `dashcam/status` (EventChannel) — receives a continuous stream of `DashcamStatus` maps pushed from native.
- **`DashcamStatus`** — plain data class deserialized from native map events (recording state, elapsed time, storage, last segment, warnings, camera lens).
- **`_DashcamHomePageState`** — single-screen stateful widget. Manages GPS tracking via `geolocator`, computes a smoothed speed from a sliding window of position samples, and pushes speed back to native via `updateLiveStats`. GPS tracking is suspended when the app is backgrounded and recording is inactive.
- **`GithubReleaseService`** — checks the GitHub releases API on startup and prompts the user to update if a newer version is available.

### Native Android (`app/android/app/src/main/kotlin/com/example/app/`)

| File | Role |
|---|---|
| `MainActivity.kt` | Hosts both platform channels; routes MethodChannel calls to `DashcamStatusStore`; wires the EventChannel sink into `DashcamStatusStore.onStatus`. |
| `DashcamStatusStore.kt` | Singleton holding all recording state. The single source of truth for Flutter events: every state mutation calls `emitCurrent()` which fires `onStatus`. Also handles low-storage notifications (threshold: 5 GB) and "recording started" notifications. |
| `DashcamForegroundService.kt` | `LifecycleService` that owns CameraX. Starts/stops/pauses CameraX `Recording` objects, rolls to a new segment every 5 minutes (`SEGMENT_MS`), manages the `segments` list, and prunes the oldest unlocked clips when free space drops below 500 MB. On segment finalize, queues a burn-in job via `burnInExecutor`. |
| `DashcamVideoBurnIn.kt` | Post-processes each finished segment on a background thread using FFmpeg Kit. Generates an ASS subtitle file from per-second (timestamp, speed) samples collected during recording, then burns that overlay into the video with `libx264`. Requires the optional FFmpeg AAR. |
| `BootReceiver.kt` | BroadcastReceiver wired for device boot (not currently auto-starting recording; inspect before extending). |

### FFmpeg burn-in (optional)

`DashcamVideoBurnIn` requires `ffmpeg-kit-full-gpl-6.0-2.aar`. Place it at:

```
app/android/app/libs/ffmpeg-kit-full-gpl-6.0-2.aar
```

The Gradle build detects it automatically (`build.gradle.kts` checks `file("libs/ffmpeg-kit-full-gpl-6.0-2.aar").exists()`). Without it, segments are saved without the overlay and `DashcamVideoBurnIn.processSegment` returns `processed = false`.

### Data flow summary

```
Flutter UI
  │  (MethodChannel "dashcam/control")
  ▼
MainActivity ──► DashcamStatusStore ──► DashcamForegroundService
                        │                       │
                        │   (EventChannel)       │ CameraX segments
                        ▼                       ▼
                   Flutter UI          DashcamVideoBurnIn
                   (status stream)     (FFmpeg burn-in thread)
```

Videos are saved to `Movies/Dashcam/` in MediaStore (Android Q+) or directly to external storage (pre-Q).
