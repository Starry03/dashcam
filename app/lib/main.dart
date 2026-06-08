import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashcamApp());
}

class DashcamApp extends StatelessWidget {
  const DashcamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashcam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashcamHomePage(),
    );
  }
}

class DashcamStatus {
  const DashcamStatus({
    required this.isRecording,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.storageUsedMb,
    required this.freeStorageMb,
    required this.lastSegment,
    required this.lastSegmentLocked,
    required this.warning,
    required this.isFrontCamera,
  });

  final bool isRecording;
  final bool isPaused;
  final int elapsedSeconds;
  final int storageUsedMb;
  final int freeStorageMb;
  final String lastSegment;
  final bool lastSegmentLocked;
  final String warning;
  final bool isFrontCamera;

  factory DashcamStatus.fromMap(Map<Object?, Object?> map) {
    return DashcamStatus(
      isRecording: map['isRecording'] as bool? ?? false,
      isPaused: map['isPaused'] as bool? ?? false,
      elapsedSeconds: map['elapsedSeconds'] as int? ?? 0,
      storageUsedMb: map['storageUsedMb'] as int? ?? 0,
      freeStorageMb: map['freeStorageMb'] as int? ?? 0,
      lastSegment: map['lastSegment'] as String? ?? '-',
      lastSegmentLocked: map['lastSegmentLocked'] as bool? ?? false,
      warning: map['warning'] as String? ?? '',
      isFrontCamera: map['isFrontCamera'] as bool? ?? false,
    );
  }

  static const idle = DashcamStatus(
    isRecording: false,
    isPaused: false,
    elapsedSeconds: 0,
    storageUsedMb: 0,
    freeStorageMb: 0,
    lastSegment: '-',
    lastSegmentLocked: false,
    warning: '',
    isFrontCamera: false,
  );
}

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
  static Future<void> openVideoFolder() =>
      _methods.invokeMethod('openVideoFolder');
  static Future<void> setCameraLens(bool isFront) =>
      _methods.invokeMethod('setCameraLens', {'isFrontCamera': isFront});
  static Future<void> refreshStatus() => _methods.invokeMethod('refreshStatus');
  static Future<void> updateLiveStats(double speedKmh) =>
      _methods.invokeMethod('updateLiveStats', {'speedKmh': speedKmh});
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.htmlUrl,
    required this.tag,
  });

  final String version;
  final String apkUrl;
  final String htmlUrl;
  final String tag;
}

class GithubReleaseService {
  static const String _owner = 'Starry03';
  static const String _repo = 'dashcam';

  static Future<ReleaseInfo?> fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$_owner/$_repo/releases/latest',
    );

    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );

    if (response.statusCode != 200) return null;

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final tag = (decoded['tag_name'] as String? ?? '').trim();
    final htmlUrl = (decoded['html_url'] as String? ?? '').trim();
    final assets = decoded['assets'];

    String? apkUrl;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final url = (asset['browser_download_url'] as String? ?? '').trim();
        if (url.toLowerCase().endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    if (tag.isEmpty || htmlUrl.isEmpty || apkUrl == null || apkUrl.isEmpty) {
      return null;
    }

    return ReleaseInfo(
      version: _normalizeVersion(tag),
      apkUrl: apkUrl,
      htmlUrl: htmlUrl,
      tag: tag,
    );
  }

  static String _normalizeVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }
}

class DashcamHomePage extends StatefulWidget {
  const DashcamHomePage({super.key});
  @override
  State<DashcamHomePage> createState() => _DashcamHomePageState();
}

enum GpsUiStatus { checking, permissionDenied, gpsDisabled, weakSignal, active }

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

class _DashcamHomePageState extends State<DashcamHomePage>
    with WidgetsBindingObserver {
  late final StreamSubscription<DashcamStatus> _statusSub;
  StreamSubscription<Position>? _speedSub;
  Timer? _statusRefreshTimer;
  DashcamStatus _status = DashcamStatus.idle;
  String _error = '';
  bool _busy = false;
  String _appVersion = 'Loading...';
  String _installedVersion = '';
  bool _didCheckUpdates = false;
  bool _isFrontCamera = false;
  double _speedKmh = 0;
  double _lastNativeSpeedKmh = -1;
  DateTime? _lastNativeSpeedPushAt;
  final List<_GpsSample> _speedSamples = <_GpsSample>[];
  GpsUiStatus _gpsUiStatus = GpsUiStatus.checking;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitData();
    _initSpeedTracking();
    _startStatusRefreshTicker();
    _statusSub = DashcamPlatformBridge.watchStatus().listen((s) {
      final recordingStateChanged = s.isRecording != _status.isRecording;
      setState(() {
        _status = s;
        _error = '';
      });
      if (recordingStateChanged) {
        if (_shouldTrackGps) {
          unawaited(_initSpeedTracking(showMessages: false));
        } else {
          _stopSpeedTracking();
        }
      }
    }, onError: (e) => setState(() => _error = 'Error: $e'));
  }

  Future<void> _loadInitData() async {
    final prefs = await SharedPreferences.getInstance();
    _isFrontCamera = prefs.getBool('isFrontCamera') ?? false;
    await DashcamPlatformBridge.setCameraLens(_isFrontCamera);
    final info = await PackageInfo.fromPlatform();
    _installedVersion = info.version;
    setState(() => _appVersion = 'version ${info.version}');

    // Run once after app startup to avoid repeated dialogs on hot states.
    if (!_didCheckUpdates) {
      _didCheckUpdates = true;
      unawaited(_checkForGithubUpdate());
    }
  }

  List<int> _parseSemver(String raw) {
    final clean = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final main = clean.split('-').first;
    return main
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  bool _isVersionNewer(String candidate, String installed) {
    final a = _parseSemver(candidate);
    final b = _parseSemver(installed);
    final maxLen = math.max(a.length, b.length);
    for (var i = 0; i < maxLen; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai > bi) return true;
      if (ai < bi) return false;
    }
    return false;
  }

  Future<void> _checkForGithubUpdate() async {
    if (_installedVersion.isEmpty) return;

    try {
      final release = await GithubReleaseService.fetchLatestRelease();
      if (!mounted || release == null) return;

      if (!_isVersionNewer(release.version, _installedVersion)) {
        return;
      }

      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Update available'),
            content: Text(
              'A new version (${release.tag}) is available on GitHub.\n\nCurrent: $_installedVersion\nLatest: ${release.version}\n\nDo you want to download and install it now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Update'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (shouldUpdate == true) {
        final apkUri = Uri.tryParse(release.apkUrl);
        if (apkUri != null && await canLaunchUrl(apkUri)) {
          await launchUrl(apkUri, mode: LaunchMode.externalApplication);
          return;
        }

        final releaseUri = Uri.tryParse(release.htmlUrl);
        if (releaseUri != null) {
          await launchUrl(releaseUri, mode: LaunchMode.externalApplication);
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open the update link.')),
          );
        }
        return;
      }
    } catch (_) {
      // Silent failure: startup must remain smooth if release API is unavailable.
    }
  }

  Future<void> _toggleCamera() async {
    if (_status.isRecording || _busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop recording to change camera lens')),
      );
      return;
    }
    setState(() => _isFrontCamera = !_isFrontCamera);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFrontCamera', _isFrontCamera);
    await DashcamPlatformBridge.setCameraLens(_isFrontCamera);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speedSub?.cancel();
    _statusRefreshTimer?.cancel();
    _statusSub.cancel();
    super.dispose();
  }

  void _startStatusRefreshTicker() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(DashcamPlatformBridge.refreshStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (_shouldTrackGps) {
      unawaited(_initSpeedTracking(showMessages: false));
    } else {
      _stopSpeedTracking();
    }
  }

  bool get _shouldTrackGps {
    return _status.isRecording ||
        _appLifecycleState == AppLifecycleState.resumed;
  }

  void _stopSpeedTracking() {
    _speedSub?.cancel();
    _speedSub = null;
    if (mounted && !_status.isRecording) {
      setState(() {
        _gpsUiStatus = GpsUiStatus.checking;
      });
    }
  }

  void _recordSpeedSample(Position position, DateTime timestamp) {
    _speedSamples.add(
      _GpsSample(
        timestamp: timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );

    final cutoff = timestamp.subtract(const Duration(seconds: 5));
    while (_speedSamples.length > 2 &&
        _speedSamples.first.timestamp.isBefore(cutoff)) {
      _speedSamples.removeAt(0);
    }

    while (_speedSamples.length > 8) {
      _speedSamples.removeAt(0);
    }
  }

  double? _estimateWindowSpeedMps() {
    if (_speedSamples.length < 2) return null;

    double distanceMeters = 0;
    for (var index = 1; index < _speedSamples.length; index++) {
      final previous = _speedSamples[index - 1];
      final current = _speedSamples[index];
      distanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }

    final elapsedSeconds =
        _speedSamples.last.timestamp
            .difference(_speedSamples.first.timestamp)
            .inMilliseconds /
        1000;
    if (elapsedSeconds < 2.0) return null;

    final speedMps = distanceMeters / elapsedSeconds;
    if (!speedMps.isFinite || speedMps > 70) return null;
    return speedMps;
  }

  Future<void> _initSpeedTracking({bool showMessages = true}) async {
    if (!_shouldTrackGps) {
      _stopSpeedTracking();
      return;
    }

    if (mounted) {
      setState(() => _gpsUiStatus = GpsUiStatus.checking);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() => _gpsUiStatus = GpsUiStatus.permissionDenied);
      }
      if (mounted) {
        if (showMessages) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied: speed unavailable.'),
            ),
          );
        }
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _gpsUiStatus = GpsUiStatus.permissionDenied);
      }
      if (mounted) {
        if (showMessages) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission blocked: enable it in settings.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
      }
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _gpsUiStatus = GpsUiStatus.gpsDisabled);
      }
      if (mounted) {
        if (showMessages) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Enable GPS to display speed.'),
              action: SnackBarAction(
                label: 'Open GPS',
                onPressed: Geolocator.openLocationSettings,
              ),
            ),
          );
        }
      }
      return;
    }

    final settings = LocationSettings(
      accuracy: _status.isRecording
          ? LocationAccuracy.bestForNavigation
          : LocationAccuracy.high,
      distanceFilter: _status.isRecording ? 0 : 3,
    );

    _speedSub?.cancel();
    _speedSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _handlePositionUpdate,
      onError: (Object e) {
        if (!mounted) return;
        if (_gpsUiStatus != GpsUiStatus.weakSignal) {
          setState(() => _gpsUiStatus = GpsUiStatus.weakSignal);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GPS error: $e')));
      },
    );
  }

  void _handlePositionUpdate(Position position) {
    // Keep only reliable samples to avoid speed spikes from noisy GPS readings.
    if (position.accuracy > 35) {
      if (mounted) {
        if (_gpsUiStatus != GpsUiStatus.weakSignal) {
          setState(() => _gpsUiStatus = GpsUiStatus.weakSignal);
        }
      }
      return;
    }

    final now = position.timestamp;
    _recordSpeedSample(position, now);

    final nativeSpeedValid =
        position.speed >= 0 &&
        position.speed <= 70 &&
        (!position.speedAccuracy.isFinite || position.speedAccuracy <= 6.0);

    final windowSpeedMps = _estimateWindowSpeedMps();
    double? speedMps;
    if (nativeSpeedValid && position.speedAccuracy <= 6.0) {
      speedMps = position.speed;
    } else {
      speedMps = windowSpeedMps ?? (nativeSpeedValid ? position.speed : null);
    }

    if (speedMps == null) {
      return;
    }

    final speedKmh = math.max(0.0, math.min(250.0, speedMps * 3.6)).toDouble();
    final double smoothingAlpha = speedKmh < 15 ? 0.45 : 0.30;
    final double smoothedKmh =
        (_speedKmh * (1 - smoothingAlpha)) + (speedKmh * smoothingAlpha);
    final double liveSpeedKmh = smoothedKmh < 1 ? 0.0 : smoothedKmh;

    if (!mounted) return;
    final shouldRefreshUi =
        _gpsUiStatus != GpsUiStatus.active ||
        (_speedKmh - liveSpeedKmh).abs() >= 0.2;
    if (shouldRefreshUi) {
      setState(() {
        _gpsUiStatus = GpsUiStatus.active;
        _speedKmh = liveSpeedKmh;
      });
    }

    final nowForPush = DateTime.now();
    final reachedPushInterval =
        _lastNativeSpeedPushAt == null ||
        nowForPush.difference(_lastNativeSpeedPushAt!).inMilliseconds >= 1000;
    final changedEnoughForPush =
        (_lastNativeSpeedKmh - liveSpeedKmh).abs() >= 0.7;
    if (reachedPushInterval || changedEnoughForPush) {
      _lastNativeSpeedKmh = liveSpeedKmh;
      _lastNativeSpeedPushAt = nowForPush;
      unawaited(DashcamPlatformBridge.updateLiveStats(liveSpeedKmh));
    }
  }

  ({String label, Color color, IconData icon}) _gpsStatusStyle() {
    switch (_gpsUiStatus) {
      case GpsUiStatus.active:
        return (
          label: 'GPS',
          color: Colors.white60,
          icon: Icons.gps_fixed_rounded,
        );
      case GpsUiStatus.weakSignal:
        return (
          label: 'Weak GPS',
          color: Colors.orange.shade200,
          icon: Icons.gps_not_fixed_rounded,
        );
      case GpsUiStatus.permissionDenied:
        return (
          label: 'GPS not allowed',
          color: Colors.red.shade200,
          icon: Icons.location_disabled_rounded,
        );
      case GpsUiStatus.gpsDisabled:
        return (
          label: 'GPS off',
          color: Colors.red.shade200,
          icon: Icons.gps_off_rounded,
        );
      case GpsUiStatus.checking:
        return (
          label: 'GPS...',
          color: Colors.white54,
          icon: Icons.gps_not_fixed_rounded,
        );
    }
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_status.isRecording) {
        await DashcamPlatformBridge.stopRecording();
      } else {
        await DashcamPlatformBridge.startRecording();
      }
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'Platform error: ${e.code}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _togglePause() async {
    if (_busy || !_status.isRecording) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_status.isPaused) {
        await DashcamPlatformBridge.resumeRecording();
      } else {
        await DashcamPlatformBridge.pauseRecording();
      }
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'Platform error: ${e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lockIncident() async {
    try {
      await DashcamPlatformBridge.lockIncident();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident marker saved.')));
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed.')));
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '00:00:00';
    final d = Duration(seconds: seconds);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(76)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickActionsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1D1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isFrontCamera
                        ? Icons.camera_front_rounded
                        : Icons.camera_rear_rounded,
                    color: _status.isRecording ? Colors.white38 : Colors.white,
                  ),
                  title: const Text('Switch Lens'),
                  subtitle: Text(
                    _isFrontCamera ? 'Front' : 'Rear',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  enabled: !_status.isRecording,
                  onTap: _status.isRecording
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _toggleCamera();
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.lock_rounded,
                    color: _status.isRecording ? Colors.white : Colors.white38,
                  ),
                  title: const Text('Lock Current Clip'),
                  subtitle: Text(
                    _status.isRecording
                        ? 'Protects the active segment'
                        : 'Available only while recording',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  enabled: _status.isRecording,
                  onTap: _status.isRecording
                      ? () async {
                          Navigator.of(sheetContext).pop();
                          await _lockIncident();
                        }
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.video_library_rounded,
                    color: Colors.white,
                  ),
                  title: const Text('Open Gallery'),
                  subtitle: const Text(
                    'Saved clips',
                    style: TextStyle(color: Colors.white54),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(sheetContext).pop();
                    try {
                      await DashcamPlatformBridge.openVideoFolder();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open video gallery'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRec = _status.isRecording;
    final bool isPaused = _status.isPaused;
    final gpsStyle = _gpsStatusStyle();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 124),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: isRec ? Colors.redAccent : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRec ? (isPaused ? 'PAUSED' : 'RECORDING') : 'READY',
                          style: TextStyle(
                            color: isRec
                                ? (isPaused
                                      ? Colors.orangeAccent
                                      : Colors.redAccent)
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Text(
                      _formatDuration(_status.elapsedSeconds),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.speed_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_speedKmh.toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: _gpsUiStatus == GpsUiStatus.active ? 0.72 : 0.9,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(gpsStyle.icon, size: 12, color: gpsStyle.color),
                          const SizedBox(width: 4),
                          Text(
                            gpsStyle.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                              color: gpsStyle.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        _buildStatCard(
                          'Free Storage',
                          '${_status.freeStorageMb} MB',
                          Icons.storage_rounded,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          'Last Clip',
                          _status.lastSegment == '-'
                              ? 'None'
                              : _status.lastSegment,
                          Icons.video_file_rounded,
                          trailing: _status.lastSegmentLocked
                              ? const Icon(
                                  Icons.shield,
                                  color: Colors.orange,
                                  size: 16,
                                )
                              : null,
                        ),
                      ],
                    ),
                    if (_status.warning.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildWarningBanner(_status.warning),
                    ],
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildWarningBanner(_error),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _toggleRecording,
                            icon: Icon(
                              isRec
                                  ? Icons.stop_rounded
                                  : Icons.fiber_manual_record,
                            ),
                            label: Text(isRec ? 'Stop' : 'Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRec
                                  ? Colors.redAccent
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _busy || !isRec ? null : _togglePause,
                            icon: Icon(
                              isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                            ),
                            label: Text(isPaused ? 'Resume' : 'Pause'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _lockIncident,
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Lock Clip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _openQuickActionsSheet,
                        icon: const Icon(Icons.menu_rounded),
                        label: const Text('Quick Actions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _appVersion,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
