import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VehicleVisualizer extends StatefulWidget {
  const VehicleVisualizer({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.speedKmh,
    required this.isFrontCamera,
    required this.infinityFocus,
    required this.videoOverlayMode,
    required this.loopRecordingMinutes,
    required this.onSwitchLens,
    required this.onToggleInfinityFocus,
    required this.onChangeOverlayMode,
    required this.onChangeLoopRecording,
    required this.onOpenGallery,
  });

  final bool isRecording;
  final bool isPaused;
  final double speedKmh;
  final bool isFrontCamera;
  final bool infinityFocus;
  final String videoOverlayMode;
  final int loopRecordingMinutes;
  final VoidCallback onSwitchLens;
  final ValueChanged<bool> onToggleInfinityFocus;
  final VoidCallback onChangeOverlayMode;
  final VoidCallback onChangeLoopRecording;
  final VoidCallback onOpenGallery;

  @override
  State<VehicleVisualizer> createState() => VehicleVisualizerState();
}

// VEHICLE VISUALIZER STATE - GLB rendering handled by model-viewer
// -----------------------------------------------------------------------------
class VehicleVisualizerState extends State<VehicleVisualizer> {
  InAppWebViewController? _viewerController;
  bool _viewerReady = false;
  String? _activeZone;

  void resetCameraOrbit() {
    setState(() => _activeZone = null);
    _runViewerCommand('resetCamera()');
  }

  void _focusVehicleZone(String zone) {
    final nextZone = _activeZone == zone ? null : zone;
    setState(() => _activeZone = nextZone);
    _runViewerCommand('setActiveZone(${_jsString(nextZone)})');
    if (nextZone == null) {
      _runViewerCommand('resetCamera()');
    } else {
      _runViewerCommand('focusZone(${_jsString(nextZone)})');
    }
  }

  String _jsString(String? value) {
    if (value == null) return 'null';
    return "'${value.replaceAll("'", r"\'")}'";
  }

  void _runViewerCommand(String command) {
    if (!_viewerReady) return;
    _viewerController?.evaluateJavascript(source: command);
  }

  void _onViewerCreated(InAppWebViewController controller) {
    _viewerController = controller;
    controller.addJavaScriptHandler(
      handlerName: 'hotspotTapped',
      callback: (args) {
        final zone = args.isNotEmpty ? args.first : null;
        if (zone is String && (zone == 'front' || zone == 'cabin')) {
          _focusVehicleZone(zone);
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'viewerReady',
      callback: (_) {
        _viewerReady = true;
        _runViewerCommand('setActiveZone(${_jsString(_activeZone)})');
        _syncViewerBadges();
        return null;
      },
    );
    unawaited(_loadViewer(controller));
  }

  Future<void> _loadViewer(InAppWebViewController controller) async {
    final template = await rootBundle.loadString('assets/viewer.html');
    final modelViewerScript = await rootBundle.loadString(
      'packages/flutter_3d_controller/assets/model_viewer.min.js',
    );
    final model = await rootBundle.load('assets/models/sedan-sports.glb');
    final modelData = base64Encode(
      model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
    );
    final html = template
        .replaceFirst('__MODEL_VIEWER_SCRIPT__', modelViewerScript)
        .replaceFirst('__MODEL_DATA__', modelData);

    await controller.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri('https://dashcam.local/'),
    );
  }

  void _syncViewerBadges() {
    final lens = widget.isFrontCamera ? 'Front' : 'Rear';
    final loop = widget.loopRecordingMinutes == 0
        ? 'Loop Off'
        : '${widget.loopRecordingMinutes}m';
    _runViewerCommand("updateBadge('badge-lens', ${_jsString(lens)})");
    _runViewerCommand("updateBadge('badge-loop', ${_jsString(loop)})");
  }

  @override
  void didUpdateWidget(covariant VehicleVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFrontCamera != widget.isFrontCamera ||
        oldWidget.loopRecordingMinutes != widget.loopRecordingMinutes) {
      _syncViewerBadges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildViewer()),
        if (_activeZone != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: _activeZone == 'front'
                ? _FrontOpticsQuickCard(
                    isRecording: widget.isRecording,
                    isFrontCamera: widget.isFrontCamera,
                    infinityFocus: widget.infinityFocus,
                    videoOverlayMode: widget.videoOverlayMode,
                    onSwitchLens: widget.onSwitchLens,
                    onToggleInfinityFocus: widget.onToggleInfinityFocus,
                    onChangeOverlayMode: widget.onChangeOverlayMode,
                    onClose: () => setState(() {
                      _activeZone = null;
                      _runViewerCommand('setActiveZone(null)');
                    }),
                  )
                : _CabinHubQuickCard(
                    loopRecordingMinutes: widget.loopRecordingMinutes,
                    onChangeLoopRecording: widget.onChangeLoopRecording,
                    onOpenGallery: widget.onOpenGallery,
                    onClose: () => setState(() {
                      _activeZone = null;
                      _runViewerCommand('setActiveZone(null)');
                    }),
                  ),
          ),
      ],
    );
  }

  Widget _buildViewer() {
    // Widget tests do not register a platform implementation.
    if (InAppWebViewPlatform.instance == null) {
      return const SizedBox.expand();
    }
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        javaScriptEnabled: true,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: _onViewerCreated,
    );
  }
}

// ----------------------------------------------------------------------------
// SPATIAL QUICK CARDS (HTML lines 917-960)
// ----------------------------------------------------------------------------
class _FrontOpticsQuickCard extends StatelessWidget {
  const _FrontOpticsQuickCard({
    required this.isRecording,
    required this.isFrontCamera,
    required this.infinityFocus,
    required this.videoOverlayMode,
    required this.onSwitchLens,
    required this.onToggleInfinityFocus,
    required this.onChangeOverlayMode,
    required this.onClose,
  });

  final bool isRecording;
  final bool isFrontCamera;
  final bool infinityFocus;
  final String videoOverlayMode;
  final VoidCallback onSwitchLens;
  final ValueChanged<bool> onToggleInfinityFocus;
  final VoidCallback onChangeOverlayMode;
  final VoidCallback onClose;

  String get _overlayLabel {
    switch (videoOverlayMode) {
      case 'subtitles':
        return 'Overlay: Sub';
      case 'burnin':
        return 'Overlay: Burn';
      default:
        return 'Overlay: Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF20B0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x5538BDF8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (HTML line 918)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'PARABREZZA · DASHCAM OPTICS',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Actions Row (HTML line 927)
          Row(
            children: [
              // Lens Switch
              Expanded(
                child: Material(
                  color: const Color(0xFF131C28),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: isRecording ? null : onSwitchLens,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Lens: ${isFrontCamera ? "Front" : "Rear"}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isRecording ? Colors.white30 : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Road Focus Toggle
              Expanded(
                child: Material(
                  color: infinityFocus
                      ? const Color(0x3338BDF8)
                      : const Color(0xFF131C28),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onToggleInfinityFocus(!infinityFocus),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: infinityFocus
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '∞ Focus: ${infinityFocus ? "ON" : "OFF"}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: infinityFocus
                              ? const Color(0xFF38BDF8)
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Overlay Mode — shows current value, cycles on tap
              Expanded(
                child: Material(
                  color: videoOverlayMode != 'none'
                      ? const Color(0x2238BDF8)
                      : const Color(0xFF131C28),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onChangeOverlayMode,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: videoOverlayMode != 'none'
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _overlayLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: videoOverlayMode != 'none'
                              ? const Color(0xFF38BDF8)
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CabinHubQuickCard extends StatelessWidget {
  const _CabinHubQuickCard({
    required this.loopRecordingMinutes,
    required this.onChangeLoopRecording,
    required this.onOpenGallery,
    required this.onClose,
  });

  final int loopRecordingMinutes;
  final VoidCallback onChangeLoopRecording;
  final VoidCallback onOpenGallery;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF50B0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x5538BDF8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (HTML line 940)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'ABITACOLO · CLIP & LOOP',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Actions Row (HTML line 949)
          Row(
            children: [
              // Loop Retention Selector
              Expanded(
                child: Material(
                  color: const Color(0xFF131C28),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onChangeLoopRecording,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Loop: ${loopRecordingMinutes == 0 ? "Off" : "${loopRecordingMinutes}m"}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Open Gallery (HTML line 955)
              Expanded(
                child: Material(
                  color: const Color(0x2838BDF8),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onOpenGallery,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x6638BDF8)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        'Open Gallery →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
