import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speedTracker = SpeedTracker(
      onLiveSpeed: (kmh) =>
          unawaited(DashcamPlatformBridge.updateLiveStats(kmh)),
      onEvent: _handleSpeedEvent,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    )..addListener(_onSpeedTrackerChanged);
    _loadInitData();
    unawaited(_syncSpeedTracking());
    _startStatusRefreshTicker();
    _statusSub = DashcamPlatformBridge.watchStatus().listen((s) {
      final recordingStateChanged = s.isRecording != _status.isRecording;
      setState(() {
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
          ),
        );
      case SpeedTrackerEvent.permissionDeniedForever:
        messenger.showSnackBar(
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
      case SpeedTrackerEvent.serviceDisabled:
        messenger.showSnackBar(
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

  void _openQuickActionsSheet() {
    if (!mounted) return;
    unawaited(
      showQuickActionsSheet(
        context,
        isFrontCamera: _isFrontCamera,
        isRecording: _status.isRecording,
        onSwitchLens: () => unawaited(_toggleCamera()),
        onLock: () => unawaited(_lockIncident()),
        onOpenGallery: () => unawaited(_openGallery()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 124),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RecordingStatusHeader(
                  isRecording: _status.isRecording,
                  isPaused: _status.isPaused,
                ),
                const SizedBox(height: 50),
                ElapsedTimer(elapsedSeconds: _status.elapsedSeconds),
                const SizedBox(height: 18),
                SpeedIndicator(
                  speedKmh: _speedTracker.speedKmh,
                  gpsStatus: _speedTracker.gpsStatus,
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Free Storage',
                        value: '${_status.freeStorageMb} MB',
                        icon: Icons.storage_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                if (_status.warning.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  WarningBanner(message: _status.warning),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  WarningBanner(message: _error),
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
                const SizedBox(height: 16),
                Text(
                  _appVersion,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
