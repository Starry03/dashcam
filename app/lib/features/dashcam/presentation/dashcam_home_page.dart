import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/dashcam_platform.dart';
import '../domain/dashcam_status.dart';
import '../services/github_release_service.dart';
import '../services/speed_tracker.dart';
import 'widgets/control_panel.dart';
import 'widgets/elapsed_timer.dart';
import 'widgets/quick_actions_sheet.dart';
import 'widgets/recording_status_header.dart';
import 'widgets/speed_indicator.dart';
import 'widgets/stat_card.dart';
import 'widgets/warning_banner.dart';

class DashcamHomePage extends StatefulWidget {
  const DashcamHomePage({super.key});

  @override
  State<DashcamHomePage> createState() => _DashcamHomePageState();
}

class _DashcamHomePageState extends State<DashcamHomePage>
    with WidgetsBindingObserver {
  late final StreamSubscription<DashcamStatus> _statusSub;
  late final SpeedTracker _speedTracker;
  Timer? _statusRefreshTimer;
  DashcamStatus _status = DashcamStatus.idle;
  String _error = '';
  bool _busy = false;
  String _appVersion = 'Loading...';
  String _installedVersion = '';
  bool _didCheckUpdates = false;
  bool _isFrontCamera = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  int _loopRecordingMinutes = 0;
  bool _infinityFocus = true;
  String _videoOverlayMode = 'subtitles';
  bool _dismissedWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speedTracker = SpeedTracker(
      onLiveSpeed: (kmh, hasFix) =>
          unawaited(DashcamPlatformBridge.updateLiveStats(kmh, hasGpsFix: hasFix)),
      onEvent: _handleSpeedEvent,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    )..addListener(_onSpeedTrackerChanged);
    _loadInitData();
    unawaited(_syncSpeedTracking());
    _startStatusRefreshTicker();
    _statusSub = DashcamPlatformBridge.watchStatus().listen((s) {
      final recordingStateChanged = s.isRecording != _status.isRecording;
      setState(() {
        if (s.warning != _status.warning) {
          _dismissedWarning = false;
        }
        _status = s;
        _error = '';
      });
      if (recordingStateChanged) {
        unawaited(_syncSpeedTracking(showMessages: false));
      }
    }, onError: (e) => setState(() => _error = 'Error: $e'));
  }

  void _onSpeedTrackerChanged() {
    if (mounted) setState(() {});
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
            const SnackBar(content: Text('Unable to reach GitHub for updates.')),
          );
        }
        return;
      }

      if (!_isVersionNewer(release.version, _installedVersion)) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App is up to date (v$_installedVersion).'),
            ),
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
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                label: const Text('Install Now'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldUpdate != true) return;

      await _downloadAndInstallApk(release);
    } catch (e) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndInstallApk(ReleaseInfo release) async {
    final cacheDir = await DashcamPlatformBridge.getCacheDir();
    if (cacheDir == null) {
      final apkUri = Uri.tryParse(release.apkUrl);
      if (apkUri != null && await canLaunchUrl(apkUri)) {
        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final targetFile = File('$cacheDir/update_${release.version}.apk');
    if (targetFile.existsSync()) {
      try {
        targetFile.deleteSync();
      } catch (_) {}
    }

    if (!mounted) return;

    var progress = 0.0;
    var statusText = 'Connecting to GitHub...';
    var hasError = false;
    var errorMessage = '';
    var started = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startDownload() async {
              try {
                final client = http.Client();
                final request = http.Request('GET', Uri.parse(release.apkUrl));
                final response = await client.send(request);

                if (response.statusCode != 200) {
                  throw Exception('HTTP error ${response.statusCode}');
                }

                final totalBytes = response.contentLength ?? 0;
                var receivedBytes = 0;
                final sink = targetFile.openWrite();

                await response.stream.listen(
                  (chunk) {
                    sink.add(chunk);
                    receivedBytes += chunk.length;
                    if (totalBytes > 0) {
                      setModalState(() {
                        progress = receivedBytes / totalBytes;
                        final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                        final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
                        statusText = '$recMb MB / $totMb MB (${(progress * 100).toInt()}%)';
                      });
                    } else {
                      setModalState(() {
                        final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                        statusText = '$recMb MB downloaded';
                      });
                    }
                  },
                  cancelOnError: true,
                ).asFuture<void>();

                await sink.flush();
                await sink.close();
                client.close();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await DashcamPlatformBridge.installApk(targetFile.path);
              } catch (e) {
                setModalState(() {
                  hasError = true;
                  errorMessage = '$e';
                });
              }
            }

            if (!started) {
              started = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                startDownload();
              });
            }

            return AlertDialog(
              title: Text(hasError ? 'Download Failed' : 'Downloading Update'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasError) ...[
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusText,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ] else ...[
                    Text(
                      'Failed to download the update:\n$errorMessage',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                if (hasError) ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      final apkUri = Uri.tryParse(release.apkUrl);
                      if (apkUri != null && await canLaunchUrl(apkUri)) {
                        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Open in Browser'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      try {
                        targetFile.deleteSync();
                      } catch (_) {}
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
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

  Future<void> _changeLoopRecording() async {
    final values = [0, 5, 10, 15, 30];
    final labels = ['Off (Save All)', 'Last 5 Minutes', 'Last 10 Minutes', 'Last 15 Minutes', 'Last 30 Minutes'];
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Loop Recording'),
          content: RadioGroup<int>(
            groupValue: _loopRecordingMinutes,
            onChanged: (val) => Navigator.of(context).pop(val),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(values.length, (i) {
                return RadioListTile<int>(
                  title: Text(labels[i]),
                  value: values[i],
                );
              }),
            ),
          ),
        );
      },
    );
    if (selected != null && selected != _loopRecordingMinutes) {
      setState(() => _loopRecordingMinutes = selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('loopRecordingMinutes', selected);
      await DashcamPlatformBridge.setLoopRecordingMinutes(selected);
    }
  }

  Future<void> _changeOverlayMode() async {
    final values = ['subtitles', 'burnin', 'none'];
    final labels = [
      'Subtitles Track (No Heat - Recommended)',
      'Burn-in on Video (High CPU / Heat)',
      'Off (No Text Overlay)',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Video Overlay'),
          content: RadioGroup<String>(
            groupValue: _videoOverlayMode,
            onChanged: (val) => Navigator.of(context).pop(val),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(values.length, (i) {
                return RadioListTile<String>(
                  title: Text(labels[i]),
                  value: values[i],
                );
              }),
            ),
          ),
        );
      },
    );
    if (selected != null && selected != _videoOverlayMode) {
      setState(() => _videoOverlayMode = selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('videoOverlayMode', selected);
      await DashcamPlatformBridge.setVideoOverlayMode(selected);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speedTracker.removeListener(_onSpeedTrackerChanged);
    _speedTracker.dispose();
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
    unawaited(_syncSpeedTracking(showMessages: false));
  }

  bool get _shouldTrackGps {
    return _status.isRecording ||
        _appLifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _syncSpeedTracking({bool showMessages = true}) async {
    if (_shouldTrackGps) {
      await _speedTracker.start(
        recording: _status.isRecording,
        showMessages: showMessages,
      );
    } else {
      _speedTracker.stop(recording: _status.isRecording);
    }
  }

  void _handleSpeedEvent(SpeedTrackerEvent event) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (event) {
      case SpeedTrackerEvent.permissionDenied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location permission denied: speed unavailable.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case SpeedTrackerEvent.permissionDeniedForever:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission blocked: enable it in settings.',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      case SpeedTrackerEvent.serviceDisabled:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Enable GPS to display speed.'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open GPS',
              onPressed: Geolocator.openLocationSettings,
            ),
          ),
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

  void _openQuickActionsSheet() {
    if (!mounted) return;
    unawaited(
      showQuickActionsSheet(
        context,
        isFrontCamera: _isFrontCamera,
        isRecording: _status.isRecording,
        loopRecordingMinutes: _loopRecordingMinutes,
        infinityFocus: _infinityFocus,
        videoOverlayMode: _videoOverlayMode,
        onSwitchLens: () => unawaited(_toggleCamera()),
        onLock: () => unawaited(_lockIncident()),
        onOpenGallery: () => unawaited(_openGallery()),
        onChangeLoopRecording: () => unawaited(_changeLoopRecording()),
        onToggleInfinityFocus: (val) => unawaited(_toggleInfinityFocus(val)),
        onChangeOverlayMode: () => unawaited(_changeOverlayMode()),
        onCheckUpdates: () => unawaited(_checkForGithubUpdate(manual: true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RecordingStatusHeader(
                  isRecording: _status.isRecording,
                  isPaused: _status.isPaused,
                ),
                const SizedBox(height: 24),
                ElapsedTimer(elapsedSeconds: _status.elapsedSeconds),
                const SizedBox(height: 12),
                SpeedIndicator(
                  speedKmh: _speedTracker.speedKmh > 0
                      ? _speedTracker.speedKmh
                      : _status.speedKmh,
                  gpsStatus: _speedTracker.gpsStatus,
                ),
                const SizedBox(height: 20),
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
                    const SizedBox(width: 12),
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
                if (_status.warning.isNotEmpty && !_dismissedWarning) ...[
                  const SizedBox(height: 12),
                  WarningBanner(
                    message: _status.warning,
                    onDismiss: () => setState(() => _dismissedWarning = true),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  WarningBanner(
                    message: _error,
                    onDismiss: () => setState(() => _error = ''),
                  ),
                ],
                const SizedBox(height: 16),
                ControlPanel(
                  isRecording: _status.isRecording,
                  isPaused: _status.isPaused,
                  busy: _busy,
                  onToggleRecording: () => unawaited(_toggleRecording()),
                  onTogglePause: () => unawaited(_togglePause()),
                  onLock: () => unawaited(_lockIncident()),
                  onQuickActions: _openQuickActionsSheet,
                ),
                const SizedBox(height: 12),
                Text(
                  _appVersion,
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
