import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/recording_config.dart';
import '../domain/dashcam_status.dart';

class DashcamPlatform {
  DashcamPlatform();

  static const MethodChannel _methodChannel =
      MethodChannel('dashcam/control');
  static const EventChannel _eventChannel = EventChannel('dashcam/status');

  Stream<DashcamStatus>? _statusStream;

  Stream<DashcamStatus> get statusStream {
    _statusStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => DashcamStatus.fromMap((event as Map).cast<Object?, Object?>()));
    return _statusStream!;
  }

  Future<DashcamStatus> getStatus() async {
    final map = await _methodChannel.invokeMapMethod<Object?, Object?>('getStatus');
    return DashcamStatus.fromMap(map ?? const <Object?, Object?>{});
  }

  Future<DashcamStatus> startRecording(RecordingConfig config) async {
    final map = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'startRecording',
      config.toMap(),
    );
    return DashcamStatus.fromMap(map ?? const <Object?, Object?>{});
  }

  Future<DashcamStatus> stopRecording() async {
    final map =
        await _methodChannel.invokeMapMethod<Object?, Object?>('stopRecording');
    return DashcamStatus.fromMap(map ?? const <Object?, Object?>{});
  }

  Future<DashcamStatus> lockCurrentSegment() async {
    final map =
        await _methodChannel.invokeMapMethod<Object?, Object?>('lockSegment');
    return DashcamStatus.fromMap(map ?? const <Object?, Object?>{});
  }
}