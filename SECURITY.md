# Security and privacy

## Bugs

If you find anything, please open an issue

## Privacy and Data Handling

Everything is processed locally. No data is sent to any servers. Clips are stored on-device and can be accessed via the app or file explorer. The app does not collect any personal information or usage data.

APP UPDATE: the app provides a fast way to update itself, it makes a request to github to check for new releases, and if there is a new release, the app will download the latest version and prompt the user to install it.

## Permissions

The Android app requests the following permissions and capabilities:

| Permission / Capability | Purpose | Required | Notes |
|---|---|---:|---|
| Camera | Record video for dashcam functionality | Yes | Core to app operation |
| Microphone | Record audio with video (optional) | No | User can enable/disable audio recording |
| Location (fine/coarse) | Provide speed, geotagging and trip data | No | Used for speed/route features; can be disabled |
| Foreground service | Keep recording running while app backgrounded | Yes | Required for continuous recording on Android |
| Notifications | Show recording status and quick actions | No | On Android 13+ notifications permission may be requested |
