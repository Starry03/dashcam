import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/dashcam_status.dart';

class DashcamPlatformBridge {
  static const MethodChannel _methods = MethodChannel('dashcam/control');
  static const EventChannel _events = EventChannel('dashcam/status');

  static Stream<DashcamStatus> watchStatus() => _events
      .receiveBroadcastStream()
      .map((e) => DashcamStatus.fromMap(Map<Object?, Object?>.from(e as Map)));

  static Future<void> startRecording() =>
      _methods.invokeMethod('startRecording');
  static Future<void> stopRecording() => _methods.invokeMethod('stopRecording');
  static Future<void> pauseRecording() =>
      _methods.invokeMethod('pauseRecording');
  static Future<void> resumeRecording() =>
      _methods.invokeMethod('resumeRecording');
  static Future<void> lockIncident() => _methods.invokeMethod('lockIncident');
  static Future<void> setLoopRecordingMinutes(int minutes) =>
      _methods.invokeMethod('setLoopRecordingMinutes', {'minutes': minutes});
  static Future<void> openVideoFolder() =>
      _methods.invokeMethod('openVideoFolder');
  static Future<void> setCameraLens(bool isFront) =>
      _methods.invokeMethod('setCameraLens', {'isFrontCamera': isFront});
  static Future<void> setInfinityFocus(bool enabled) =>
      _methods.invokeMethod('setInfinityFocus', {'enabled': enabled});
  static Future<void> setVideoOverlayMode(String mode) =>
      _methods.invokeMethod('setVideoOverlayMode', {'mode': mode});
  static Future<String?> getCacheDir() =>
      _methods.invokeMethod<String>('getCacheDir');
  static Future<void> installApk(String filePath) =>
      _methods.invokeMethod('installApk', {'filePath': filePath});
  static Future<void> refreshStatus() => _methods.invokeMethod('refreshStatus');
  static Future<void> updateLiveStats(double speedKmh, {bool hasGpsFix = true}) =>
      _methods.invokeMethod('updateLiveStats', {
        'speedKmh': speedKmh,
        'hasGpsFix': hasGpsFix,
      });
}
