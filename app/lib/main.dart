import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashcamHomePage(),
    );
  }
}

class DashcamStatus {
  const DashcamStatus({
    required this.isRecording, required this.elapsedSeconds, required this.storageUsedMb, required this.freeStorageMb,
    required this.lastSegment, required this.lastSegmentLocked, required this.warning, required this.isFrontCamera,
  });

  final bool isRecording; final int elapsedSeconds; final int storageUsedMb; final int freeStorageMb;
  final String lastSegment; final bool lastSegmentLocked; final String warning; final bool isFrontCamera;

  factory DashcamStatus.fromMap(Map<Object?, Object?> map) {
    return DashcamStatus(
      isRecording: map['isRecording'] as bool? ?? false, elapsedSeconds: map['elapsedSeconds'] as int? ?? 0,
      storageUsedMb: map['storageUsedMb'] as int? ?? 0, freeStorageMb: map['freeStorageMb'] as int? ?? 0,
      lastSegment: map['lastSegment'] as String? ?? '-' , lastSegmentLocked: map['lastSegmentLocked'] as bool? ?? false,
      warning: map['warning'] as String? ?? '' , isFrontCamera: map['isFrontCamera'] as bool? ?? false,
    );
  }

  static const idle = DashcamStatus(isRecording: false, elapsedSeconds: 0, storageUsedMb: 0, freeStorageMb: 0, lastSegment: '-' , lastSegmentLocked: false, warning: '' , isFrontCamera: false);
}

class DashcamPlatformBridge {
  static const MethodChannel _methods = MethodChannel('dashcam/control');
  static const EventChannel _events = EventChannel('dashcam/status');
  static Stream<DashcamStatus> watchStatus() => _events.receiveBroadcastStream().map((e) => DashcamStatus.fromMap(Map<Object?, Object?>.from(e as Map)));
  static Future<void> startRecording() => _methods.invokeMethod('startRecording');
  static Future<void> stopRecording() => _methods.invokeMethod('stopRecording');
  static Future<void> lockIncident() => _methods.invokeMethod('lockIncident');
  static Future<void> openVideoFolder() => _methods.invokeMethod('openVideoFolder');
  static Future<void> setCameraLens(bool isFront) => _methods.invokeMethod('setCameraLens', {'isFrontCamera': isFront});
}

class DashcamHomePage extends StatefulWidget {
  const DashcamHomePage({super.key});
  @override
  State<DashcamHomePage> createState() => _DashcamHomePageState();
}

class _DashcamHomePageState extends State<DashcamHomePage> {
  late final StreamSubscription<DashcamStatus> _statusSub;
  DashcamStatus _status = DashcamStatus.idle;
  String _error = '';
  bool _busy = false;
  String _appVersion = 'Caricamento...';
  bool _isFrontCamera = false;
  String _persistedLastSegment = '-';
  bool _persistedLastSegmentLocked = false;

  @override
  void initState() {
    super.initState();
    _loadInitData();
    _statusSub = DashcamPlatformBridge.watchStatus().listen((s) async { 
      setState(() { _status = s; _error = ''; }); 
      if (s.lastSegment != '-') {
        if (s.lastSegment != _persistedLastSegment || s.lastSegmentLocked != _persistedLastSegmentLocked) {
          _persistedLastSegment = s.lastSegment;
          _persistedLastSegmentLocked = s.lastSegmentLocked;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastSegment', s.lastSegment);
          await prefs.setBool('lastSegmentLocked', s.lastSegmentLocked);
          if (mounted) setState(() {});
        }
      }
    }, onError: (e) => setState(() => _error = 'Error: $e'));
  }

  Future<void> _loadInitData() async {
    final prefs = await SharedPreferences.getInstance();
    _isFrontCamera = prefs.getBool('isFrontCamera') ?? false;
    _persistedLastSegment = prefs.getString('lastSegment') ?? '-';
    _persistedLastSegmentLocked = prefs.getBool('lastSegmentLocked') ?? false;
    await DashcamPlatformBridge.setCameraLens(_isFrontCamera);
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = 'version ${info.version}');
  }
  
  Future<void> _toggleCamera() async {
    if (_status.isRecording || _busy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stoppa la registrazione per cambiare fotocamera')));
      return;
    }
    setState(() => _isFrontCamera = !_isFrontCamera);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFrontCamera', _isFrontCamera);
    await DashcamPlatformBridge.setCameraLens(_isFrontCamera);
  }

  @override
  void dispose() { _statusSub.cancel(); super.dispose(); }

  Future<void> _toggleRecording() async {
    if (_busy) return;
    setState(() { _busy = true; _error = ''; });
    try {
      if (_status.isRecording) await DashcamPlatformBridge.stopRecording();
      else await DashcamPlatformBridge.startRecording();
    } on PlatformException catch (e) { setState(() => _error = e.message ?? 'Platform error: ${e.code}'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _lockIncident() async {
    try {
      await DashcamPlatformBridge.lockIncident();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident marker saved.')));
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed.')));
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '00:00:00';
    final d = Duration(seconds: seconds);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Widget? trailing}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(25))),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Text(value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                if (trailing != null) ...[const SizedBox(width: 4), trailing],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRec = _status.isRecording;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, color: isRec ? Colors.redAccent : Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(isRec ? 'RECORDING' : 'READY', style: TextStyle(color: isRec ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 50),
              Text(_formatDuration(_status.elapsedSeconds), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w200, fontFamily: 'monospace')),
              const SizedBox(height: 40),
              Row(
                children: [
                   _buildStatCard('Free Storage', '${_status.freeStorageMb} MB', Icons.storage_rounded),
                  const SizedBox(width: 16),
                  _buildStatCard('Last Clip', (_status.lastSegment == '-' ? _persistedLastSegment : _status.lastSegment) == '-' ? 'None' : (_status.lastSegment == '-' ? _persistedLastSegment : _status.lastSegment), Icons.video_file_rounded, trailing: (_status.lastSegment == '-' ? _persistedLastSegmentLocked : _status.lastSegmentLocked) ? const Icon(Icons.shield, color: Colors.orange, size: 16) : null),
                ],
              ),
              if (_status.warning.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.withAlpha(38), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withAlpha(76))),
                  child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 12), Expanded(child: Text(_status.warning, style: const TextStyle(color: Colors.orange)))])
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), width: 96, height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isRec ? Colors.transparent : Colors.redAccent, border: Border.all(color: Colors.redAccent, width: 4), boxShadow: isRec ? null : [BoxShadow(color: Colors.redAccent.withAlpha(102), blurRadius: 20)]),
                  child: Center(
                    child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: isRec ? 36 : 96, height: isRec ? 36 : 96, decoration: BoxDecoration(borderRadius: BorderRadius.circular(isRec ? 8 : 48), color: Colors.redAccent))
                  )
                )
              ),
              const SizedBox(height: 16),
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _toggleCamera(), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Icon(_isFrontCamera ? Icons.camera_front_rounded : Icons.camera_rear_rounded, color: isRec ? Colors.white30 : Colors.white, size: 28), const SizedBox(height: 8), Text('Lens', style: TextStyle(color: isRec ? Colors.white30 : Colors.white, fontWeight: FontWeight.bold))])))),
                  Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: isRec ? _lockIncident : null, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Icon(Icons.lock_rounded, color: isRec ? Colors.white : Colors.white30, size: 28), const SizedBox(height: 8), Text('Lock Clip', style: TextStyle(color: isRec ? Colors.white : Colors.white30, fontWeight: FontWeight.bold))])))),
                  Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () async { try { await DashcamPlatformBridge.openVideoFolder(); } catch(e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile aprire la galleria videos'))); } }, child: const Padding(padding: EdgeInsets.all(16.0), child: Column(children: [Icon(Icons.video_library_rounded, color: Colors.white, size: 28), SizedBox(height: 8), Text('Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])))),
                ],
              ),
              const SizedBox(height: 16),
              Text(_appVersion, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
