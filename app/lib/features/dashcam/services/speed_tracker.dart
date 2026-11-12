import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/gps_status.dart';

/// Reasons the GPS pipeline can fail to start, surfaced to the UI so it can
/// show the appropriate prompt/action.
enum SpeedTrackerEvent {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

class _GpsSample {
  const _GpsSample({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
}

/// Owns the GPS position stream and turns raw fixes into a smoothed speed.
/// UI-independent: it exposes [speedKmh]/[gpsStatus] via [ChangeNotifier] and
/// reports failures and live-speed pushes through injected callbacks.
class SpeedTracker extends ChangeNotifier {
  SpeedTracker({
    required this.onLiveSpeed,
    required this.onEvent,
    required this.onError,
  });

  /// Called when a new live speed (km/h) should be pushed to the recorder,
  /// with indicator whether GPS has active fix.
  final void Function(double speedKmh, bool hasGpsFix) onLiveSpeed;
  final void Function(SpeedTrackerEvent event) onEvent;
  final void Function(String message) onError;

  StreamSubscription<Position>? _sub;
  final List<_GpsSample> _samples = <_GpsSample>[];
  double _speedKmh = 0;
  double _lastPushedKmh = -1;
  DateTime? _lastPushAt;
  GpsUiStatus _status = GpsUiStatus.checking;

  double get speedKmh => _speedKmh;
  GpsUiStatus get gpsStatus => _status;

  void _setStatus(GpsUiStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  Future<void> start({
    required bool recording,
    bool showMessages = true,
  }) async {
    _setStatus(GpsUiStatus.checking);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _setStatus(GpsUiStatus.permissionDenied);
      if (showMessages) onEvent(SpeedTrackerEvent.permissionDenied);
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _setStatus(GpsUiStatus.permissionDenied);
      if (showMessages) onEvent(SpeedTrackerEvent.permissionDeniedForever);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setStatus(GpsUiStatus.gpsDisabled);
      if (showMessages) onEvent(SpeedTrackerEvent.serviceDisabled);
      return;
    }

    final settings = LocationSettings(
      accuracy: recording
          ? LocationAccuracy.bestForNavigation
          : LocationAccuracy.high,
      distanceFilter: recording ? 0 : 3,
    );

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _handlePositionUpdate,
      onError: (Object e) {
        _setStatus(GpsUiStatus.weakSignal);
        onError('GPS error: $e');
      },
    );
  }

  /// Stops the position stream. When [recording] is false the displayed status
  /// is reset to [GpsUiStatus.checking].
  void stop({bool recording = false}) {
    _sub?.cancel();
    _sub = null;
    if (!recording) {
      _setStatus(GpsUiStatus.checking);
    }
  }

  void _recordSample(Position position, DateTime timestamp) {
    _samples.add(
      _GpsSample(
        timestamp: timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );

    final cutoff = timestamp.subtract(const Duration(seconds: 3));
    while (_samples.length > 2 && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeAt(0);
    }

    while (_samples.length > 6) {
      _samples.removeAt(0);
    }
  }

  double? _estimateWindowSpeedMps() {
    if (_samples.length < 2) return null;

    double distanceMeters = 0;
    for (var index = 1; index < _samples.length; index++) {
      final previous = _samples[index - 1];
      final current = _samples[index];
      distanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }

    final elapsedSeconds =
        _samples.last.timestamp
            .difference(_samples.first.timestamp)
            .inMilliseconds /
        1000;
    if (elapsedSeconds < 0.8) return null;

    final speedMps = distanceMeters / elapsedSeconds;
    if (!speedMps.isFinite || speedMps > 70) return null;
    return speedMps;
  }

  void _handlePositionUpdate(Position position) {
    // Keep only reliable samples to avoid speed spikes from noisy GPS readings.
    if (position.accuracy > 45) {
      _setStatus(GpsUiStatus.weakSignal);
      onLiveSpeed(0.0, false);
      return;
    }

    final now = position.timestamp;
    _recordSample(position, now);

    final nativeSpeedValid =
        position.speed > 0.2 &&
        position.speed <= 70 &&
        (!position.speedAccuracy.isFinite || position.speedAccuracy <= 6.0);

    final windowSpeedMps = _estimateWindowSpeedMps();
    double? speedMps;
    if (nativeSpeedValid) {
      speedMps = position.speed;
    } else {
      speedMps = windowSpeedMps ?? (position.speed >= 0 ? position.speed : null);
    }

    if (speedMps == null) {
      return;
    }

    final speedKmh = math.max(0.0, math.min(250.0, speedMps * 3.6)).toDouble();
    final double smoothingAlpha = speedKmh < 0.5 ? 1.0 : 0.80;
    final double smoothedKmh =
        (_speedKmh * (1 - smoothingAlpha)) + (speedKmh * smoothingAlpha);
    final double liveSpeedKmh = smoothedKmh < 0.5 ? 0.0 : smoothedKmh;

    final shouldRefreshUi =
        _status != GpsUiStatus.active ||
        (_speedKmh - liveSpeedKmh).abs() >= 0.1;
    if (shouldRefreshUi) {
      _status = GpsUiStatus.active;
      _speedKmh = liveSpeedKmh;
      notifyListeners();
    }

    final nowForPush = DateTime.now();
    final reachedPushInterval =
        _lastPushAt == null ||
        nowForPush.difference(_lastPushAt!).inMilliseconds >= 300;
    final changedEnoughForPush = (_lastPushedKmh - liveSpeedKmh).abs() >= 0.2;
    if (reachedPushInterval || changedEnoughForPush) {
      _lastPushedKmh = liveSpeedKmh;
      _lastPushAt = nowForPush;
      onLiveSpeed(liveSpeedKmh, true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
