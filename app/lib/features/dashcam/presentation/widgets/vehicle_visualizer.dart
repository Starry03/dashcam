import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  State<VehicleVisualizer> createState() => _VehicleVisualizerState();
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 get normalized {
    final len = length;
    return len > 0.00001 ? _Vec3(x / len, y / len, z / len) : const _Vec3(0, 0, 0);
  }
}

// ----------------------------------------------------------------------------
// 3D PERSPECTIVE CAMERA MATH (EXACT REPLICATION OF THREE.JS CAMERA IN HTML)
// ----------------------------------------------------------------------------
class _Camera3D {
  _Camera3D({
    required this.camAngleY,
    required this.camAngleX,
    required this.width,
    required this.height,
  }) {
    const radius = 6.3;
    final cx = math.sin(camAngleY) * math.cos(camAngleX) * radius;
    final cy = math.sin(camAngleX) * radius + 0.25;
    final cz = math.cos(camAngleY) * math.cos(camAngleX) * radius;

    position = _Vec3(cx, cy, cz);
    final target = const _Vec3(0, 0.12, 0);

    forward = (target - position).normalized;
    const worldUp = _Vec3(0, 1, 0);
    right = forward.cross(worldUp).normalized;
    up = right.cross(forward).normalized;

    aspect = width / height;
    tanHalfFov = math.tan((36.0 * math.pi / 180.0) / 2.0); // 36° FOV as in HTML
  }

  late final _Vec3 position;
  late final _Vec3 forward;
  late final _Vec3 right;
  late final _Vec3 up;
  final double camAngleY;
  final double camAngleX;
  final double width;
  final double height;
  late final double aspect;
  late final double tanHalfFov;

  Offset? project(_Vec3 p) {
    final v = p - position;
    final vz = v.dot(forward);
    if (vz <= 0.1) return null; // Behind camera

    final vx = v.dot(right);
    final vy = v.dot(up);

    final xNdc = vx / (vz * tanHalfFov * aspect);
    final yNdc = vy / (vz * tanHalfFov);

    final screenX = (xNdc * 0.5 + 0.5) * width;
    final screenY = (-yNdc * 0.5 + 0.5) * height;

    return Offset(screenX, screenY);
  }
}

// ----------------------------------------------------------------------------
// THREE.JS AUTOMOTIVE SILHOUETTE PAINTER (EXACT SHAPE FROM HTML)
// ----------------------------------------------------------------------------
class _VehiclePainter extends CustomPainter {
  _VehiclePainter({
    required this.camAngleY,
    required this.camAngleX,
    required this.pulseValue,
    required this.wheelRotation,
    required this.isRecording,
    required this.isPaused,
    required this.moving,
    required this.isFrontCamera,
    required this.infinityFocus,
    required this.onAnchorsComputed,
  });

  final double camAngleY;
  final double camAngleX;
  final double pulseValue;
  final double wheelRotation;
  final bool isRecording;
  final bool isPaused;
  final bool moving;
  final bool isFrontCamera;
  final bool infinityFocus;
  final void Function(Offset frontPin, Offset cabinPin) onAnchorsComputed;

  @override
  void paint(Canvas canvas, Size size) {
    final camera = _Camera3D(
      camAngleY: camAngleY,
      camAngleX: camAngleX,
      width: size.width,
      height: size.height,
    );

    Offset? proj(_Vec3 p) => camera.project(p);

    // Compute anchor points (exactly as in HTML lines 1200-1205)
    final front3D = const _Vec3(0.85, 0.62, 0.35);
    final cabin3D = const _Vec3(-0.65, 0.78, -0.25);

    final pFront = proj(front3D) ?? Offset(size.width * 0.68, size.height * 0.45);
    final pCabin = proj(cabin3D) ?? Offset(size.width * 0.35, size.height * 0.38);
    onAnchorsComputed(pFront, pCabin);

    // ------------------------------------------------------------------------
    // 1. FLOOR GRID & RADAR HALO RING (HTML lines 1079-1088)
    // ------------------------------------------------------------------------
    const floorY = -0.62;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.45);

    for (var i = -8; i <= 8; i++) {
      final coord = i * 0.75;
      final p1 = proj(_Vec3(coord, floorY, -6.0));
      final p2 = proj(_Vec3(coord, floorY, 6.0));
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, gridPaint);

      final p3 = proj(_Vec3(-6.0, floorY, coord));
      final p4 = proj(_Vec3(6.0, floorY, coord));
      if (p3 != null && p4 != null) canvas.drawLine(p3, p4, gridPaint);
    }

    // Halo Ground Ring (radius 2.37 at y = -0.61)
    const ringRadius = 2.37;
    final haloPath = Path();
    var firstPoint = true;
    for (var a = 0; a <= 48; a++) {
      final rad = a * (math.pi * 2 / 48);
      final pt = proj(_Vec3(math.cos(rad) * ringRadius, -0.61, math.sin(rad) * ringRadius));
      if (pt != null) {
        if (firstPoint) {
          haloPath.moveTo(pt.dx, pt.dy);
          firstPoint = false;
        } else {
          haloPath.lineTo(pt.dx, pt.dy);
        }
      }
    }
    canvas.drawPath(
      haloPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.32),
    );

    // ------------------------------------------------------------------------
    // 2. AMBIENT SHADOW UNDER VEHICLE
    // ------------------------------------------------------------------------
    final shadowPts = [
      proj(const _Vec3(-2.2, floorY, -0.95)),
      proj(const _Vec3(2.2, floorY, -0.95)),
      proj(const _Vec3(2.2, floorY, 0.95)),
      proj(const _Vec3(-2.2, floorY, 0.95)),
    ];
    if (shadowPts.every((p) => p != null)) {
      final shadowPath = Path()
        ..moveTo(shadowPts[0]!.dx, shadowPts[0]!.dy)
        ..lineTo(shadowPts[1]!.dx, shadowPts[1]!.dy)
        ..lineTo(shadowPts[2]!.dx, shadowPts[2]!.dy)
        ..lineTo(shadowPts[3]!.dx, shadowPts[3]!.dy)
        ..close();
      canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.95), 18, true);
    }

    // ------------------------------------------------------------------------
    // 3. FRONT DASHCAM VOLUMETRIC VISION CONE (HTML lines 1186-1196)
    // ------------------------------------------------------------------------
    final coneApex = proj(const _Vec3(1.85, 0.45, 0.0));
    final coneColor = isRecording
        ? const Color(0xFFEF4444)
        : const Color(0xFF38BDF8);

    if (coneApex != null && isFrontCamera) {
      final conePts = <Offset>[];
      for (var a = 0; a <= 20; a++) {
        final rad = a * (math.pi * 2 / 20);
        final pt = proj(_Vec3(3.9, 0.45 + math.cos(rad) * 0.85, math.sin(rad) * 0.85));
        if (pt != null) conePts.add(pt);
      }

      if (conePts.isNotEmpty) {
        final fovPath = Path()..moveTo(coneApex.dx, coneApex.dy);
        for (final pt in conePts) {
          fovPath.lineTo(pt.dx, pt.dy);
        }
        fovPath.close();

        canvas.drawPath(
          fovPath,
          Paint()
            ..color = coneColor.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill,
        );

        final coneBorder = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = coneColor.withValues(alpha: 0.40);

        for (var i = 0; i < conePts.length; i += 5) {
          canvas.drawLine(coneApex, conePts[i], coneBorder);
        }
      }
    }

    // ------------------------------------------------------------------------
    // 4. SCULPTED 3D CAR BODY (EXACT THREE.JS EXTRUDE PROFILE FROM HTML)
    // ------------------------------------------------------------------------
    // Profile points along (X, Y) from HTML carShape:
    // (-2.15, -0.22) -> (2.15, -0.22) -> nose -> hood -> windshield -> roof -> fastback -> ducktail
    final profile = [
      const _Vec3(-2.15, -0.22, 0), // 0: Rear bottom
      const _Vec3(-1.20, -0.22, 0), // 1: Mid-rear bottom
      const _Vec3( 1.20, -0.22, 0), // 2: Mid-front bottom
      const _Vec3( 2.15, -0.22, 0), // 3: Front bottom
      const _Vec3( 2.27, -0.06, 0), // 4: Front chin
      const _Vec3( 2.22,  0.08, 0), // 5: Front nose
      const _Vec3( 1.75,  0.24, 0), // 6: Hood middle
      const _Vec3( 1.15,  0.30, 0), // 7: Hood cowl
      const _Vec3( 0.45,  0.78, 0), // 8: Windshield top
      const _Vec3(-0.25,  0.80, 0), // 9: Roof apex
      const _Vec3(-1.15,  0.78, 0), // 10: Roof rear
      const _Vec3(-1.95,  0.38, 0), // 11: Fastback decklid
      const _Vec3(-2.22,  0.28, 0), // 12: Ducktail top
      const _Vec3(-2.20,  0.02, 0), // 13: Rear nose
    ];

    void drawPoly(List<_Vec3> pts, Color fill, {Color? stroke, double strokeWidth = 1.0}) {
      final pScreen = pts.map(proj).toList();
      if (pScreen.any((p) => p == null)) return;

      final path = Path()..moveTo(pScreen.first!.dx, pScreen.first!.dy);
      for (final p in pScreen.skip(1)) {
        path.lineTo(p!.dx, p.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..color = fill);
      if (stroke != null && stroke.a > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = stroke,
        );
      }
    }

    // Body extruded depth: z = -0.78 to z = +0.78 with bevel to z = ±0.90
    // Shading colors (obsidian/slate metallic #0F172A as in HTML)
    const bodyBaseColor = Color(0xFF0F172A);
    const bodyTopColor = Color(0xFF162238);
    const bodySideColor = Color(0xFF0C1322);
    const wireColor = Color(0x6038BDF8); // Wireframe 0x38bdf8 with opacity 0.34

    // Left and Right Body Profile Walls
    for (final sign in [-1.0, 1.0]) {
      final z = sign * 0.88;
      final sideColor = sign > 0 ? bodySideColor : const Color(0xFF111A2C);
      final sidePts = profile.map((p) => _Vec3(p.x, p.y, z)).toList();
      drawPoly(sidePts, sideColor, stroke: wireColor, strokeWidth: 1.1);
    }

    // Top & Hood & Roof Facets spanning between Left and Right
    for (var i = 3; i < profile.length - 1; i++) {
      final p1 = profile[i];
      final p2 = profile[i + 1];

      final quadPts = [
        _Vec3(p1.x, p1.y, -0.78),
        _Vec3(p1.x, p1.y,  0.78),
        _Vec3(p2.x, p2.y,  0.78),
        _Vec3(p2.x, p2.y, -0.78),
      ];

      // Roof & glass have slightly lighter metallic reflection
      final facetColor = (i >= 7 && i <= 10)
          ? bodyTopColor
          : (i == 6 ? const Color(0xFF1E2D44) : bodyBaseColor);

      drawPoly(quadPts, facetColor, stroke: wireColor, strokeWidth: 1.1);
    }

    // Bottom Belly Plate
    drawPoly(
      [
        const _Vec3(-2.15, -0.22, -0.78),
        const _Vec3(-2.15, -0.22,  0.78),
        const _Vec3( 2.15, -0.22,  0.78),
        const _Vec3( 2.15, -0.22, -0.78),
      ],
      const Color(0xFF070B12),
      stroke: const Color(0x3038BDF8),
    );

    // ------------------------------------------------------------------------
    // 5. PANORAMIC GLASS CANOPY OVERLAY (HTML lines 1136-1146)
    // ------------------------------------------------------------------------
    // BoxGeometry(1.75, 0.36, 1.38) positioned at (-0.18, 0.56, 0)
    final cabinPts = [
      const _Vec3(-1.05, 0.38, -0.69),
      const _Vec3( 0.70, 0.38, -0.69),
      const _Vec3( 0.70, 0.74, -0.69),
      const _Vec3(-1.05, 0.74, -0.69),
      const _Vec3(-1.05, 0.38,  0.69),
      const _Vec3( 0.70, 0.38,  0.69),
      const _Vec3( 0.70, 0.74,  0.69),
      const _Vec3(-1.05, 0.74,  0.69),
    ];

    // Canopy Roof Glass (color 0x38bdf8 with opacity 0.24)
    drawPoly(
      [cabinPts[3], cabinPts[2], cabinPts[6], cabinPts[7]],
      const Color(0x4438BDF8),
      stroke: const Color(0x8038BDF8),
      strokeWidth: 1.3,
    );
    // Canopy Windshield Glass
    drawPoly(
      [cabinPts[1], cabinPts[2], cabinPts[6], cabinPts[5]],
      const Color(0x5538BDF8),
      stroke: const Color(0xCC38BDF8),
      strokeWidth: 1.4,
    );
    // Canopy Fastback Rear Glass
    drawPoly(
      [cabinPts[0], cabinPts[3], cabinPts[7], cabinPts[4]],
      const Color(0x4438BDF8),
      stroke: const Color(0x9938BDF8),
      strokeWidth: 1.3,
    );

    // ------------------------------------------------------------------------
    // 6. FUTURISTIC FRONT & REAR LED LIGHT BARS (HTML lines 1149-1159)
    // ------------------------------------------------------------------------
    // Front LED Light Bar at (2.26, 0.06, 0) width 1.58, color 0xe0f2fe
    final fLed1 = proj(const _Vec3(2.26, 0.06, -0.79));
    final fLed2 = proj(const _Vec3(2.26, 0.06,  0.79));
    if (fLed1 != null && fLed2 != null) {
      canvas.drawLine(
        fLed1,
        fLed2,
        Paint()
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0F2FE),
      );
      canvas.drawLine(
        fLed1,
        fLed2,
        Paint()
          ..strokeWidth = 5.6
          ..color = const Color(0x60E0F2FE),
      );
    }

    // Rear LED Light Bar at (-2.26, 0.18, 0) width 1.54, color 0xef4444
    final rLed1 = proj(const _Vec3(-2.26, 0.18, -0.77));
    final rLed2 = proj(const _Vec3(-2.26, 0.18,  0.77));
    if (rLed1 != null && rLed2 != null) {
      canvas.drawLine(
        rLed1,
        rLed2,
        Paint()
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFEF4444),
      );
      canvas.drawLine(
        rLed1,
        rLed2,
        Paint()
          ..strokeWidth = 6.0
          ..color = const Color(0x70EF4444),
      );
    }

    // ------------------------------------------------------------------------
    // 7. 4 AERODYNAMIC WHEELS WITH GLOWING RIM RINGS (HTML lines 1162-1183)
    // ------------------------------------------------------------------------
    final wheelCenters = [
      const _Vec3( 1.36, -0.26,  0.86), // Front Right
      const _Vec3( 1.36, -0.26, -0.86), // Front Left
      const _Vec3(-1.36, -0.26,  0.86), // Rear Right
      const _Vec3(-1.36, -0.26, -0.86), // Rear Left
    ];

    for (final wc in wheelCenters) {
      final pWheel = proj(wc);
      if (pWheel == null) continue;

      // Dark Tire (CylinderGeometry radius 0.36)
      canvas.drawCircle(pWheel, 14.5, Paint()..color = const Color(0xFF090D14));
      canvas.drawCircle(
        pWheel,
        14.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF1E293B),
      );

      // Glowing Rim Ring (RingGeometry radius 0.18-0.24, color 0x38bdf8 opacity 0.55)
      canvas.drawCircle(
        pWheel,
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        pWheel,
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF38BDF8),
      );

      // Dark Inner Hub
      canvas.drawCircle(pWheel, 5.0, Paint()..color = const Color(0xFF090D14));
    }

    // ------------------------------------------------------------------------
    // 8. 3D ANCHOR PINS WITH RIPPLE RINGS (HTML lines 188-217)
    // ------------------------------------------------------------------------
    void drawPin(Offset pos, Color color, double pulse) {
      // Animated pulse ring (pulseRing in HTML)
      canvas.drawCircle(
        pos,
        8.0 + pulse * 10.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: (1.0 - pulse) * 0.75),
      );
      // Outer border circle (w-7 h-7 bg-sky-500/20 border-sky-400/70)
      canvas.drawCircle(
        pos,
        7.0,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        pos,
        7.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = color.withValues(alpha: 0.85),
      );
      // Center solid dot (w-2.5 h-2.5)
      canvas.drawCircle(pos, 3.2, Paint()..color = color);
    }

    drawPin(pFront, const Color(0xFF38BDF8), pulseValue);
    drawPin(pCabin, const Color(0xFF10B981), pulseValue);
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter old) =>
      old.camAngleY != camAngleY ||
      old.camAngleX != camAngleX ||
      old.pulseValue != pulseValue ||
      old.wheelRotation != wheelRotation ||
      old.isRecording != isRecording ||
      old.isPaused != isPaused ||
      old.moving != moving ||
      old.isFrontCamera != isFrontCamera ||
      old.infinityFocus != infinityFocus;
}

// ----------------------------------------------------------------------------
// VEHICLE VISUALIZER STATE WITH BUTTERY SMOOTH 3D GESTURES (HTML lines 1208-1288)
// ----------------------------------------------------------------------------
class _VehicleVisualizerState extends State<VehicleVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Ticker _smoothTicker;

  // Angles exactly initialized as in HTML lines 1049-1050
  double _camAngleY = -0.52;
  double _camAngleX = 0.32;
  double _targetCamAngleY = -0.52;
  double _targetCamAngleX = 0.32;

  bool _isDragging = false;
  String? _activeZone; // 'front' or 'cabin'

  Offset _frontPin = const Offset(210, 100);
  Offset _cabinPin = const Offset(110, 80);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 60/120 FPS Buttery Smooth Physics & Ambient Drift (HTML lines 1275-1288)
    _smoothTicker = createTicker((_) {
      // Gentle idle breathing / ambient drift when not dragged (HTML line 1276)
      if (!_isDragging && _activeZone == null) {
        _targetCamAngleY += 0.0018;
      }

      // Smooth easing: camAngle += (target - camAngle) * 0.08 (HTML lines 1280-1281)
      final diffY = (_targetCamAngleY - _camAngleY) * 0.08;
      final diffX = (_targetCamAngleX - _camAngleX) * 0.08;

      if (diffY.abs() > 0.00005 || diffX.abs() > 0.00005 || _pulseController.isAnimating) {
        setState(() {
          _camAngleY += diffY;
          _camAngleX += diffX;
        });
      }
    })..start();
  }

  @override
  void dispose() {
    _smoothTicker.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAnchorsComputed(Offset frontPin, Offset cabinPin) {
    _frontPin = frontPin;
    _cabinPin = cabinPin;
  }

  void _focusVehicleZone(String zone) {
    setState(() {
      if (_activeZone == zone) {
        _activeZone = null;
      } else {
        _activeZone = zone;
        // Smoothly rotate 3D camera toward selected zone (HTML lines 897-903)
        if (zone == 'front') {
          _targetCamAngleY = -0.62;
          _targetCamAngleX = 0.28;
        } else if (zone == 'cabin') {
          _targetCamAngleY = 0.72;
          _targetCamAngleX = 0.42;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final moving = widget.isRecording && !widget.isPaused && widget.speedKmh > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Position the two spatial hotspot buttons (HTML lines 188-217 & 1260-1265)
        final clampedFrontX = _frontPin.dx.clamp(76.0, w - 85.0);
        final clampedFrontY = _frontPin.dy.clamp(32.0, h - 54.0);

        final clampedCabinX = _cabinPin.dx.clamp(76.0, w - 85.0);
        final clampedCabinY = _cabinPin.dy.clamp(32.0, h - 54.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _isDragging = true;
          },
          onPanUpdate: (details) {
            // Drag math matching HTML lines 1220-1221
            final dx = details.delta.dx;
            final dy = details.delta.dy;
            _targetCamAngleY -= dx * 0.0085;
            _targetCamAngleX = (_targetCamAngleX + dy * 0.0065).clamp(0.12, 0.95);
          },
          onPanEnd: (_) {
            _isDragging = false;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 3D Three.js-style Canvas
              Positioned.fill(
                child: CustomPaint(
                  painter: _VehiclePainter(
                    camAngleY: _camAngleY,
                    camAngleX: _camAngleX,
                    pulseValue: _pulseController.value,
                    wheelRotation: moving ? (DateTime.now().millisecondsSinceEpoch * 0.015) : 0.0,
                    isRecording: widget.isRecording,
                    isPaused: widget.isPaused,
                    moving: moving,
                    isFrontCamera: widget.isFrontCamera,
                    infinityFocus: widget.infinityFocus,
                    onAnchorsComputed: _onAnchorsComputed,
                  ),
                ),
              ),

              // --------------------------------------------------------------
              // SPATIAL HOTSPOT 1: Front Windshield / Dashcam (HTML lines 188-201)
              // --------------------------------------------------------------
              Positioned(
                left: clampedFrontX,
                top: clampedFrontY,
                child: FractionalTranslation(
                  translation: const Offset(-0.15, -0.5),
                  child: _SpatialHotspotButton(
                    title: 'FRONT CAM',
                    badgeText: widget.isFrontCamera ? 'Front' : 'Rear',
                    subtitle: 'Ottica & Focus',
                    accentColor: const Color(0xFF38BDF8),
                    active: _activeZone == 'front',
                    onTap: () => _focusVehicleZone('front'),
                  ),
                ),
              ),

              // --------------------------------------------------------------
              // SPATIAL HOTSPOT 2: Cabin / Clip Management (HTML lines 204-217)
              // --------------------------------------------------------------
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
                    accentColor: const Color(0xFF10B981),
                    active: _activeZone == 'cabin',
                    onTap: () => _focusVehicleZone('cabin'),
                  ),
                ),
              ),

              // --------------------------------------------------------------
              // SPATIAL QUICK CARD POPUP (HTML lines 220 & 912-960)
              // --------------------------------------------------------------
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
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xEB111621), // glass-card rgba(17, 22, 33, 0.68)
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accentColor : accentColor.withValues(alpha: 0.35),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
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
    required this.onSwitchLens,
    required this.onToggleInfinityFocus,
    required this.onChangeOverlayMode,
    required this.onClose,
  });

  final bool isRecording;
  final bool isFrontCamera;
  final bool infinityFocus;
  final VoidCallback onSwitchLens;
  final ValueChanged<bool> onToggleInfinityFocus;
  final VoidCallback onChangeOverlayMode;
  final VoidCallback onClose;

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
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF38BDF8))),
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
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
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
                  color: infinityFocus ? const Color(0x3338BDF8) : const Color(0xFF131C28),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onToggleInfinityFocus(!infinityFocus),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: infinityFocus ? const Color(0xFF38BDF8) : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '∞ Focus: ${infinityFocus ? "ON" : "OFF"}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: infinityFocus ? const Color(0xFF38BDF8) : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Overlay Mode
              IconButton(
                onPressed: onChangeOverlayMode,
                icon: const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF38BDF8)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF131C28),
                  padding: const EdgeInsets.all(8),
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
        border: Border.all(color: const Color(0x5510B981), width: 1.2),
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
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
              const SizedBox(width: 6),
              const Text(
                'ABITACOLO · CLIP & LOOP',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
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
                  color: const Color(0x2810B981),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onOpenGallery,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x6610B981)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        'Open Gallery →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF10B981),
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
