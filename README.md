# Dashcam

A powerful and lightweight mobile application that transforms your smartphone into a fully functional, reliable dashcam. Built with **Flutter** for a sleek, modern UI, and powered by native **Kotlin & CameraX** on Android for highly efficient background video recording.

## 🌟 Why Dashcam?

The concept is straightforward: you don't need a dedicated, expensive hardware dashcam when your mobile phone is more than capable. Just mount your phone on your dashboard, hit record, and drive safely.

## ✨ Features

- **Continuous Background Recording:** The app records uninterrupted video segments in the background, even if you switch apps or turn off the screen.
- **Smart Loop Recording:** Monitors your device's actual free storage space. When space runs out, the app automatically deletes the oldest, unlocked video segments to make room for new ones.
- **Incident Locking:** Did something happen on the road? Tap the **Lock** button, and the current clip will be permanently saved and protected from auto-deletion.
- **Front & Back Camera Toggle:** Easily switch between the rear camera for the road and the front camera for the cabin interior.
- **Real-Time Dashboard:** View live stats including elapsed recording time, available device storage, and the status (and name) of your most recently recorded clip.
- **Persistent State:** Essential states like your last recorded clip are saved, so they persist even after app restarts.

## 📸 Preview

<img src="./assets/home.jpg" alt="Preview" width="300" />

## 🚀 Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Android Studio & Android SDK (for native building).

### Build from source

If you're familiar with the command line:

```bash
# Clone the repository
git clone https://github.com/Starry03/dashcam.git
cd dashcam/app

# Get Flutter dependencies
flutter pub get

# Build the Android APK
flutter build apk

# Install to your connected device
flutter install
```

### Direct Download
Otherwise, check the **Releases** page on this repository for the latest version and download the `.apk` directly to your phone.

## In progress...

- [ ] iOS support (currently Android-only due to native CameraX integration).
- [ ] Cloud backup options for recorded clips.
