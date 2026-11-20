import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

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

// VEHICLE VISUALIZER STATE - GLB rendering handled by Flutter3DController
// -----------------------------------------------------------------------------
class VehicleVisualizerState extends State<VehicleVisualizer> {
  final Flutter3DController _modelController = Flutter3DController();
  String? _activeZone;

  @override
  void initState() {
    super.initState();
    _modelController.onModelLoaded.addListener(_onModelLoaded);
  }

  void _onModelLoaded() {
    if (_modelController.onModelLoaded.value) {
      _applyDefaultCamera();
    }
  }

  void _applyDefaultCamera() {
    _modelController.setCameraTarget(0, 0.45, 0);
    _modelController.setCameraOrbit(-30, 72, 75);
  }

  @override
  void dispose() {
    _modelController.onModelLoaded.removeListener(_onModelLoaded);
    super.dispose();
  }

  void resetCameraOrbit() {
    setState(() => _activeZone = null);
    _applyDefaultCamera();
  }

  void _focusVehicleZone(String zone) {
    setState(() {
      if (_activeZone == zone) {
        _activeZone = null;
        _applyDefaultCamera();
      } else {
        _activeZone = zone;
        if (zone == 'front') {
          _modelController.setCameraTarget(0.2, 0.5, 0.2);
          _modelController.setCameraOrbit(-36, 74, 65);
        } else if (zone == 'cabin') {
          _modelController.setCameraTarget(-0.2, 0.55, -0.1);
          _modelController.setCameraOrbit(42, 66, 68);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final clampedFrontX = (w * 0.68).clamp(76.0, w - 85.0);
        final clampedFrontY = (h * 0.45).clamp(32.0, h - 54.0);
        final clampedCabinX = (w * 0.35).clamp(76.0, w - 85.0);
        final clampedCabinY = (h * 0.38).clamp(32.0, h - 54.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: resetCameraOrbit,
                child: Flutter3DViewer(
                  src: 'assets/models/sedan-sports.glb',
                  controller: _modelController,
                  activeGestureInterceptor: true,
                  enableTouch: true,
                  progressBarColor: Colors.transparent,
                  onLoad: (_) => _applyDefaultCamera(),
                ),
              ),
            ),
            Positioned(
              left: clampedFrontX,
              top: clampedFrontY,
              child: FractionalTranslation(
                translation: const Offset(-0.15, -0.5),
                child: _SpatialHotspotButton(
                  title: 'FRONT CAM',
                  badgeText: widget.isFrontCamera ? 'Front' : 'Rear',
                  subtitle:
                      'Ottica & Focus · ${widget.videoOverlayMode == 'subtitles'
                          ? 'Sub'
                          : widget.videoOverlayMode == 'burnin'
                          ? 'Burn'
                          : 'No OVL'}',
                  accentColor: const Color(0xFF38BDF8),
                  active: _activeZone == 'front',
                  onTap: () => _focusVehicleZone('front'),
                ),
              ),
            ),
            Positioned(
              left: clampedCabinX,
              top: clampedCabinY,
              child: FractionalTranslation(
                translation: const Offset(-0.85, -0.5),
                child: _SpatialHotspotButton(
                  title: 'CABIN HUB',
                  badgeText: widget.loopRecordingMinutes == 0
                      ? 'Loop Off'
                      : '${widget.loopRecordingMinutes}m',
                  subtitle: 'Clip & Galleria',
                  accentColor: const Color(0xFF38BDF8),
                  active: _activeZone == 'cabin',
                  onTap: () => _focusVehicleZone('cabin'),
                ),
              ),
            ),
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
                        onClose: () => setState(() => _activeZone = null),
                      )
                    : _CabinHubQuickCard(
                        loopRecordingMinutes: widget.loopRecordingMinutes,
                        onChangeLoopRecording: widget.onChangeLoopRecording,
                        onOpenGallery: widget.onOpenGallery,
                        onClose: () => setState(() => _activeZone = null),
                      ),
              ),
          ],
        );
      },
    );
  }
}

// SPATIAL HOTSPOT PIN & GLASS CARD (EXACT HTML lines 188-217)
// ----------------------------------------------------------------------------
class _SpatialHotspotButton extends StatelessWidget {
  const _SpatialHotspotButton({
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.accentColor,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String badgeText;
  final String subtitle;
  final Color accentColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular pulsing beacon ring + center dot (matches user screenshot and HTML)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.20),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.75),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(
                0xEB111621,
              ), // glass-card rgba(17, 22, 33, 0.68)
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? accentColor
                    : accentColor.withValues(alpha: 0.35),
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 8,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
