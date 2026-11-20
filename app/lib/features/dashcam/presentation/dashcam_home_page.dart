import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/dashcam_platform.dart';
import '../domain/dashcam_status.dart';
import '../services/github_release_service.dart';
import '../domain/gps_status.dart';
import 'widgets/control_panel.dart';
import 'widgets/elapsed_timer.dart';
import 'widgets/recording_status_header.dart';
import 'widgets/speed_indicator.dart';
import 'widgets/stat_card.dart';
import 'widgets/warning_banner.dart';
import 'widgets/vehicle_visualizer.dart';

class DashcamHomePage extends StatefulWidget {
  const DashcamHomePage({super.key});

  @override
  State<DashcamHomePage> createState() => _DashcamHomePageState();
}

class _DashcamHomePageState extends State<DashcamHomePage>
    with WidgetsBindingObserver {
  late final StreamSubscription<DashcamStatus> _statusSub;
  Timer? _statusRefreshTimer;
  DashcamStatus _status = DashcamStatus.idle;
  String _error = '';
  bool _busy = false;
  String _appVersion = 'Loading...';
  String _installedVersion = '';
  bool _didCheckUpdates = false;
  bool _isFrontCamera = false;
  int _loopRecordingMinutes = 0;
  bool _infinityFocus = true;
  String _videoOverlayMode = 'subtitles';
  bool _dismissedWarning = false;

  final GlobalKey<VehicleVisualizerState> _visualizerKey =
      GlobalKey<VehicleVisualizerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitData();
    _startStatusRefreshTicker();
    _statusSub = DashcamPlatformBridge.watchStatus().listen((s) {
      setState(() {
        if (s.warning != _status.warning) {
          _dismissedWarning = false;
        }
        _status = s;
        _error = '';
      });
    }, onError: (e) => setState(() => _error = 'Error: $e'));
  }

  Future<void> _loadInitData() async {
    final prefs = await SharedPreferences.getInstance();
    _isFrontCamera = prefs.getBool('isFrontCamera') ?? false;
    _loopRecordingMinutes = prefs.getInt('loopRecordingMinutes') ?? 0;
    _infinityFocus = prefs.getBool('infinityFocus') ?? true;
    _videoOverlayMode = prefs.getString('videoOverlayMode') ?? 'subtitles';
    await DashcamPlatformBridge.setCameraLens(_isFrontCamera);
    await DashcamPlatformBridge.setLoopRecordingMinutes(_loopRecordingMinutes);
    await DashcamPlatformBridge.setInfinityFocus(_infinityFocus);
    await DashcamPlatformBridge.setVideoOverlayMode(_videoOverlayMode);
    final info = await PackageInfo.fromPlatform();
    _installedVersion = info.version;
    setState(() => _appVersion = 'version ${info.version}');

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

  Future<void> _checkForGithubUpdate({bool manual = false}) async {
    if (_installedVersion.isEmpty) return;

    if (manual && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for updates...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final release = await GithubReleaseService.fetchLatestRelease();
      if (!mounted) return;

      if (release == null) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to reach GitHub for updates.'),
            ),
          );
        }
        return;
      }

      if (!_isVersionNewer(release.version, _installedVersion)) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('App is up to date (v$_installedVersion).')),
          );
        }
        return;
      }

      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Update available'),
            content: Text(
              'A new version (${release.tag}) is available.\n\nCurrent: v$_installedVersion\nLatest: ${release.tag}\n\nDo you want to download and install it directly?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Download & install'),
              ),
            ],
          );
        },
      );

      if (shouldUpdate == true) {
        await _downloadAndInstallApk(release);
      }
    } catch (e) {
      if (manual && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update check failed: $e')));
      }
    }
  }

  Future<void> _downloadAndInstallApk(ReleaseInfo release) async {
    final messenger = ScaffoldMessenger.of(context);
    final downloadUrl = release.apkUrl;

    if (downloadUrl.isEmpty) {
      final uri = Uri.tryParse(release.htmlUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final cancelToken = Completer<void>();
    final progressNotifier = ValueNotifier<double?>(0.0);
    final statusNotifier = ValueNotifier<String>('Starting download...');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Updating Dashcam'),
            content: ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, statusText, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<double?>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(value: progress);
                      },
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!cancelToken.isCompleted) {
                    cancelToken.complete();
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    File? tempFile;
    try {
      final cacheDirPath = await DashcamPlatformBridge.getCacheDir();
      final apkName = 'dashcam-${release.tag}.apk';
      tempFile = File('$cacheDirPath/$apkName');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['Accept'] = 'application/octet-stream';
      request.headers['User-Agent'] = 'Dashcam-App';

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final sink = tempFile.openWrite();
      var cancelled = false;

      final streamSubscription = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            progressNotifier.value = receivedBytes / totalBytes;
            final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(
              1,
            );
            final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            statusNotifier.value = 'Downloading: $mbReceived MB / $mbTotal MB';
          }
        },
        onDone: () {},
        onError: (e) {
          throw e;
        },
        cancelOnError: true,
      );

      await Future.any([
        streamSubscription.asFuture<void>(),
        cancelToken.future.then((_) {
          cancelled = true;
          streamSubscription.cancel();
        }),
      ]);

      await sink.flush();
      await sink.close();
      client.close();

      if (cancelled) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return;
      }

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      statusNotifier.value = 'Launching installer...';
      await DashcamPlatformBridge.installApk(tempFile.path);
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Download or install failed: $e')),
      );
    }
  }

  void _startStatusRefreshTicker() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      unawaited(DashcamPlatformBridge.refreshStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DashcamPlatformBridge.refreshStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefreshTimer?.cancel();
    _statusSub.cancel();
    super.dispose();
  }

  Future<void> _toggleCamera() async {
    if (_busy || _status.isRecording) return;
    final next = !_isFrontCamera;
    setState(() => _isFrontCamera = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFrontCamera', next);
    await DashcamPlatformBridge.setCameraLens(next);
  }

  Future<void> _changeLoopRecording() async {
    const modes = [0, 5, 10, 15, 30];
    final nextIndex = (modes.indexOf(_loopRecordingMinutes) + 1) % modes.length;
    final nextValue = modes[nextIndex];
    setState(() => _loopRecordingMinutes = nextValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loopRecordingMinutes', nextValue);
    await DashcamPlatformBridge.setLoopRecordingMinutes(nextValue);
  }

  Future<void> _changeOverlayMode() async {
    const modes = ['subtitles', 'burnin', 'none'];
    final nextIndex = (modes.indexOf(_videoOverlayMode) + 1) % modes.length;
    final nextValue = modes[nextIndex];
    setState(() => _videoOverlayMode = nextValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('videoOverlayMode', nextValue);
    await DashcamPlatformBridge.setVideoOverlayMode(nextValue);
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

  Future<void> _openGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DashcamPlatformBridge.openVideoFolder();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open video gallery')),
      );
    }
  }

  Future<void> _toggleInfinityFocus(bool enabled) async {
    setState(() => _infinityFocus = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('infinityFocus', enabled);
    await DashcamPlatformBridge.setInfinityFocus(enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Status Header (● READY / ● RECORDING / ● PAUSED)
              RecordingStatusHeader(
                isRecording: _status.isRecording,
                isPaused: _status.isPaused,
              ),
              const SizedBox(height: 8),

              // Elapsed Recording Timer (00:00:00)
              ElapsedTimer(elapsedSeconds: _status.elapsedSeconds),
              const SizedBox(height: 6),

              // Speed & GPS Indicator
              SpeedIndicator(
                speedKmh: _status.speedKmh,
                gpsStatus: _status.hasGpsFix
                    ? GpsUiStatus.active
                    : GpsUiStatus.weakSignal,
              ),
              const SizedBox(height: 4),

              // 3D Automotive Visualizer (Rendered directly on single window)
              Expanded(
                child: VehicleVisualizer(
                  key: _visualizerKey,
                  isRecording: _status.isRecording,
                  isPaused: _status.isPaused,
                  speedKmh: _status.speedKmh,
                  isFrontCamera: _isFrontCamera,
                  infinityFocus: _infinityFocus,
                  videoOverlayMode: _videoOverlayMode,
                  loopRecordingMinutes: _loopRecordingMinutes,
                  onSwitchLens: _toggleCamera,
                  onToggleInfinityFocus: _toggleInfinityFocus,
                  onChangeOverlayMode: _changeOverlayMode,
                  onChangeLoopRecording: _changeLoopRecording,
                  onOpenGallery: _openGallery,
                ),
              ),
              const SizedBox(height: 8),

              // In-line Quick Settings Strip (All on one single window)
              Row(
                children: [
                  Expanded(
                    child: _QuickSettingChip(
                      icon: _isFrontCamera
                          ? Icons.camera_front_rounded
                          : Icons.camera_rear_rounded,
                      label: 'Lens',
                      value: _isFrontCamera ? 'Front' : 'Rear',
                      enabled: !_status.isRecording,
                      onTap: () => unawaited(_toggleCamera()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickSettingChip(
                      icon: Icons.all_inclusive_rounded,
                      label: 'Focus',
                      value: _infinityFocus ? 'Infinity' : 'Auto',
                      active: _infinityFocus,
                      onTap: () =>
                          unawaited(_toggleInfinityFocus(!_infinityFocus)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickSettingChip(
                      icon: Icons.layers_rounded,
                      label: 'Overlay',
                      value: _videoOverlayMode == 'subtitles'
                          ? 'Subtitles'
                          : (_videoOverlayMode == 'burnin' ? 'Burn-in' : 'Off'),
                      onTap: () => unawaited(_changeOverlayMode()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickSettingChip(
                      icon: Icons.loop_rounded,
                      label: 'Loop',
                      value: _loopRecordingMinutes == 0
                          ? 'Off'
                          : '${_loopRecordingMinutes}m',
                      onTap: () => unawaited(_changeLoopRecording()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Free Storage & Last Clip Telemetry Row
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Free Storage',
                      value: _status.freeStorageMb >= 1024
                          ? '${(_status.freeStorageMb / 1024).toStringAsFixed(1)} GB'
                          : '${_status.freeStorageMb} MB',
                      icon: Icons.storage_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Last Clip',
                      value: _status.lastSegment == '-'
                          ? 'None'
                          : _status.lastSegment,
                      icon: Icons.video_file_rounded,
                      onTap: () => unawaited(_openGallery()),
                      trailing: _status.lastSegmentLocked
                          ? const Icon(
                              Icons.shield,
                              color: Colors.orange,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ],
              ),

              // Optional Warnings or Errors
              if (_status.warning.isNotEmpty && !_dismissedWarning ||
                  _error.isNotEmpty) ...[
                const SizedBox(height: 8),
                WarningBanner(
                  message: _error.isNotEmpty ? _error : _status.warning,
                  onDismiss: () => setState(() {
                    if (_error.isNotEmpty) {
                      _error = '';
                    } else {
                      _dismissedWarning = true;
                    }
                  }),
                ),
              ],
              const SizedBox(height: 10),

              // Primary Action Control Panel (Start, Stop, Lock Incident, Pause)
              ControlPanel(
                isRecording: _status.isRecording,
                isPaused: _status.isPaused,
                busy: _busy,
                onToggleRecording: () => unawaited(_toggleRecording()),
                onTogglePause: () => unawaited(_togglePause()),
                onLock: () => unawaited(_lockIncident()),
              ),
              const SizedBox(height: 8),

              // Version & Check Updates
              GestureDetector(
                onTap: () => unawaited(_checkForGithubUpdate(manual: true)),
                child: Text(
                  _appVersion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPACT IN-LINE QUICK SETTING CHIP (ON MAIN SCREEN, NO POPUP WINDOWS)
// ============================================================================

class _QuickSettingChip extends StatelessWidget {
  const _QuickSettingChip({
    required this.icon,
    required this.label,
    required this.value,
    this.active = false,
    this.enabled = true,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF38BDF8)
                  : Colors.white.withAlpha(22),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: enabled
                    ? (active ? const Color(0xFF38BDF8) : Colors.white70)
                    : Colors.white24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
