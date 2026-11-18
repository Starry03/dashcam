import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ============================================================================
// 3D MATH PRIMITIVES (EXACT MATCH FOR THREE.JS VECTOR & PERSPECTIVE CAMERA)
// ============================================================================

class _Vec2 {
  const _Vec2(this.x, this.y);
  final double x;
  final double y;
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

  _Vec3 cross(_Vec3 o) =>
      _Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 get normalized {
    final len = length;
    return len > 0.00001
        ? _Vec3(x / len, y / len, z / len)
        : const _Vec3(0, 0, 0);
  }
}

class _Camera3D {
  _Camera3D({
    required this.camAngleY,
    required this.camAngleX,
    required this.width,
    required this.height,
  }) {
    // Exact Three.js Camera from HTML lines 1060 & 1283-1287:
    // radius = 6.3, lookAt = (0, 0.12, 0), vertical FOV = 36 deg
    const radius = 6.3;
    final cx = math.sin(camAngleY) * math.cos(camAngleX) * radius;
    final cy = math.sin(camAngleX) * radius + 0.25;
    final cz = math.cos(camAngleY) * math.cos(camAngleX) * radius;

    position = _Vec3(cx, cy, cz);
    target = const _Vec3(0, 0.12, 0);

    forward = (target - position).normalized;
    const worldUp = _Vec3(0, 1, 0);
    right = forward.cross(worldUp).normalized;
    up = right.cross(forward).normalized;

    aspect = width / height;
    tanHalfFov = math.tan((36.0 * math.pi / 180.0) / 2.0);
  }

  late final _Vec3 position;
  late final _Vec3 target;
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
    if (vz <= 0.1) return null;

    final vx = v.dot(right);
    final vy = v.dot(up);

    final xNdc = vx / (vz * tanHalfFov * aspect);
    final yNdc = vy / (vz * tanHalfFov);

    final screenX = (xNdc * 0.5 + 0.5) * width;
    final screenY = (-yNdc * 0.5 + 0.5) * height;

    return Offset(screenX, screenY);
  }

  double depth(_Vec3 p) => (p - position).dot(forward);
}

// ============================================================================
// CAR SILHOUETTE GEOMETRY (EXACT THREE.JS SHAPE SAMPLE FROM HTML LINES 1095-1104)
// ============================================================================

List<_Vec2> _buildCarSilhouette() {
  final pts = <_Vec2>[
    const _Vec2(-2.15, -0.22), // 0: Rear bumper bottom
    const _Vec2(2.15, -0.22), // 1: Front splitter bottom
  ];

  // Helper to sample quadratic curves exactly like Three.js quadraticCurveTo
  void sampleQuad(_Vec2 p0, _Vec2 p1, _Vec2 p2, int count) {
    for (var i = 1; i <= count; i++) {
      final t = i / count;
      final omt = 1.0 - t;
      final x = omt * omt * p0.x + 2 * omt * t * p1.x + t * t * p2.x;
      final y = omt * omt * p0.y + 2 * omt * t * p1.y + t * t * p2.y;
      pts.add(_Vec2(x, y));
    }
  }

  // Front chin & nose
  sampleQuad(
    const _Vec2(2.15, -0.22),
    const _Vec2(2.28, -0.10),
    const _Vec2(2.22, 0.08),
    8,
  );
  // Sculpted hood
  sampleQuad(
    const _Vec2(2.22, 0.08),
    const _Vec2(1.75, 0.24),
    const _Vec2(1.15, 0.30),
    8,
  );
  // Windshield & aerodynamic roof
  sampleQuad(
    const _Vec2(1.15, 0.30),
    const _Vec2(0.45, 0.78),
    const _Vec2(-0.25, 0.80),
    10,
  );
  // Fastback rear glass
  sampleQuad(
    const _Vec2(-0.25, 0.80),
    const _Vec2(-1.15, 0.78),
    const _Vec2(-1.95, 0.38),
    10,
  );
  // Rear ducktail
  sampleQuad(
    const _Vec2(-1.95, 0.38),
    const _Vec2(-2.22, 0.28),
    const _Vec2(-2.20, 0.02),
    6,
  );

  return pts;
}

final List<_Vec2> _kCarSilhouette = _buildCarSilhouette();

// ============================================================================
// VEHICLE VISUALIZER WIDGET
// ============================================================================

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
    this.onResetCamera,
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
  final VoidCallback? onResetCamera;

  @override
  State<VehicleVisualizer> createState() => VehicleVisualizerState();
}

class VehicleVisualizerState extends State<VehicleVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Ticker _smoothTicker;

  // Angles exactly initialized as in HTML lines 1040-1043
  double _camAngleY = -0.52;
  double _camAngleX = 0.32;
  double _targetCamAngleY = -0.52;
  double _targetCamAngleX = 0.32;

  double _dragVelocityY = 0.0;
  bool _isDragging = false;
  String? _activeZone; // 'front' or 'cabin'

  Duration _lastTickTime = Duration.zero;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _smoothTicker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _smoothTicker.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void resetCamera() {
    setState(() {
      _targetCamAngleY = -0.52;
      _targetCamAngleX = 0.32;
      _dragVelocityY = 0.0;
      _activeZone = null;
    });
  }

  void _onTick(Duration elapsed) {
    final dtSec = _lastTickTime == Duration.zero
        ? 0.016
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;
    final clampedDt = dtSec.clamp(0.001, 0.04);

    // Idle ambient drift when not dragging (HTML line 1276)
    if (!_isDragging && _activeZone == null) {
      _targetCamAngleY += 0.0018 * (clampedDt / 0.016);

      // Inertia momentum decay
      if (_dragVelocityY.abs() > 0.0001) {
        _targetCamAngleY += _dragVelocityY * clampedDt;
        _dragVelocityY *= math.pow(0.90, clampedDt / 0.016);
      }
    }

    // Smooth exponential damping (Three.js 0.08 easing factor)
    final easeFactor = 1.0 - math.pow(1.0 - 0.08, clampedDt / 0.016);
    final diffY = (_targetCamAngleY - _camAngleY) * easeFactor;
    final diffX = (_targetCamAngleX - _camAngleX) * easeFactor;

    if (diffY.abs() > 0.00001 || diffX.abs() > 0.00001) {
      setState(() {
        _camAngleY += diffY;
        _camAngleX += diffX;
      });
    }
  }

  void _toggleFrontOptics() {
    setState(() {
      if (_activeZone == 'front') {
        _activeZone = null;
      } else {
        _activeZone = 'front';
        _targetCamAngleY = -0.62;
        _targetCamAngleX = 0.28;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final moving =
        widget.isRecording && !widget.isPaused && widget.speedKmh > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final camera = _Camera3D(
          camAngleY: _camAngleY,
          camAngleX: _camAngleX,
          width: w,
          height: h,
        );
        final pFront =
            camera.project(const _Vec3(0.85, 0.62, 0.35)) ??
            Offset(w * 0.68, h * 0.45);

        final clampedFrontX = pFront.dx.clamp(20.0, w - 165.0);
        final clampedFrontY = pFront.dy.clamp(24.0, h - 85.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.05,
                colors: [
                  Color(0x1F38BDF8),
                  Color(0x0638BDF8),
                  Color(0xF006080C),
                ],
                stops: [0.0, 0.38, 0.85],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ------------------------------------------------------------
                // 3D THREE.JS WEBGL REPLICATOR CANVAS & GESTURE RECOGNIZER
                // ------------------------------------------------------------
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    _isDragging = true;
                    _dragVelocityY = 0.0;
                  },
                  onPanUpdate: (details) {
                    // Exact sensitivity from HTML lines 1220-1221
                    final dx = details.delta.dx;
                    final dy = details.delta.dy;
                    _targetCamAngleY -= dx * 0.0085;
                    _targetCamAngleX = (_targetCamAngleX + dy * 0.0065).clamp(
                      0.12,
                      0.95,
                    );
                    _dragVelocityY = -dx * 0.12;
                  },
                  onPanEnd: (_) {
                    _isDragging = false;
                  },
                  child: CustomPaint(
                    painter: _VehiclePainter(
                      camAngleY: _camAngleY,
                      camAngleX: _camAngleX,
                      pulseValue: _pulseController.value,
                      wheelRotation: moving
                          ? (DateTime.now().millisecondsSinceEpoch * 0.015)
                          : 0.0,
                      isRecording: widget.isRecording,
                      isPaused: widget.isPaused,
                      moving: moving,
                      isFrontCamera: widget.isFrontCamera,
                      infinityFocus: widget.infinityFocus,
                      loopRecordingMinutes: widget.loopRecordingMinutes,
                      videoOverlayMode: widget.videoOverlayMode,
                    ),
                  ),
                ),

                // ------------------------------------------------------------
                // TOP HORIZON HINT & RESET CAMERA BUTTON (HTML lines 135 & 184)
                // ------------------------------------------------------------
                Positioned(
                  top: 10,
                  left: 14,
                  child: GestureDetector(
                    onTap: resetCamera,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0x99111621),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: const Text(
                      '360° SPATIAL VIEW',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                // ------------------------------------------------------------
                // SPATIAL HOTSPOT 1: FRONT CAM (HTML lines 188-201 & SCREENSHOT)
                // ------------------------------------------------------------
                Positioned(
                  left: clampedFrontX,
                  top: clampedFrontY,
                  child: FractionalTranslation(
                    translation: const Offset(-0.10, -0.5),
                    child: _SpatialHotspotButton(
                      title: 'FRONT CAM',
                      badgeText: widget.isFrontCamera ? 'Front' : 'Rear',
                      subtitle: 'Ottica & Focus',
                      accentColor: const Color(0xFF38BDF8),
                      active: _activeZone == 'front',
                      pulseValue: _pulseController.value,
                      onTap: _toggleFrontOptics,
                    ),
                  ),
                ),

                // ------------------------------------------------------------
                // SPATIAL QUICK CARD POPUP (Ottica & Focus)
                // ------------------------------------------------------------
                if (_activeZone == 'front')
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: _FrontOpticsQuickCard(
                      isRecording: widget.isRecording,
                      isFrontCamera: widget.isFrontCamera,
                      infinityFocus: widget.infinityFocus,
                      videoOverlayMode: widget.videoOverlayMode,
                      onSwitchLens: widget.onSwitchLens,
                      onToggleInfinityFocus: widget.onToggleInfinityFocus,
                      onChangeOverlayMode: widget.onChangeOverlayMode,
                      onClose: () => setState(() => _activeZone = null),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SPATIAL VEHICLE CUSTOM PAINTER (SCULPTED 3D MESH WITH TRUE PERSPECTIVE)
// ============================================================================

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
    required this.loopRecordingMinutes,
    required this.videoOverlayMode,
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
  final int loopRecordingMinutes;
  final String videoOverlayMode;

  @override
  void paint(Canvas canvas, Size size) {
    final camera = _Camera3D(
      camAngleY: camAngleY,
      camAngleX: camAngleX,
      width: size.width,
      height: size.height,
    );

    Offset? proj(_Vec3 p) => camera.project(p);

    // ------------------------------------------------------------------------
    // 1. FLOOR GRID & SPATIAL RADAR HALO RING (HTML lines 1079-1088)
    // ------------------------------------------------------------------------
    const floorY = -0.62;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.40);

    for (var i = -8; i <= 8; i++) {
      final c = i * 0.75;
      final p1 = proj(_Vec3(c, floorY, -5.5));
      final p2 = proj(_Vec3(c, floorY, 5.5));
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, gridPaint);

      final p3 = proj(_Vec3(-5.5, floorY, c));
      final p4 = proj(_Vec3(5.5, floorY, c));
      if (p3 != null && p4 != null) canvas.drawLine(p3, p4, gridPaint);
    }

    // Spatial Radar Halo Ring (RingGeometry radius 2.37 at y = -0.61)
    const haloRadius = 2.37;
    final haloPath = Path();
    var firstPt = true;
    for (var a = 0; a <= 48; a++) {
      final rad = a * (math.pi * 2 / 48);
      final pt = proj(
        _Vec3(math.cos(rad) * haloRadius, -0.61, math.sin(rad) * haloRadius),
      );
      if (pt != null) {
        if (firstPt) {
          haloPath.moveTo(pt.dx, pt.dy);
          firstPt = false;
        } else {
          haloPath.lineTo(pt.dx, pt.dy);
        }
      }
    }
    // Ambient cyan halo ring
    canvas.drawPath(
      haloPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.28),
    );

    // If loop recording is active, display segmented loop buffer arcs
    if (loopRecordingMinutes > 0) {
      final activeArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.65);

      final segAngle = (math.pi * 2) / 3;
      final rotOffset =
          (DateTime.now().millisecondsSinceEpoch % 6000) / 6000.0 * math.pi * 2;
      for (var s = 0; s < 3; s++) {
        final startA = rotOffset + s * segAngle;
        final arcPath = Path();
        var isFirst = true;
        for (var step = 0; step <= 8; step++) {
          final rad = startA + (step / 8) * (segAngle * 0.65);
          final pt = proj(
            _Vec3(
              math.cos(rad) * haloRadius,
              -0.61,
              math.sin(rad) * haloRadius,
            ),
          );
          if (pt != null) {
            if (isFirst) {
              arcPath.moveTo(pt.dx, pt.dy);
              isFirst = false;
            } else {
              arcPath.lineTo(pt.dx, pt.dy);
            }
          }
        }
        canvas.drawPath(arcPath, activeArcPaint);
      }
    }

    // ------------------------------------------------------------------------
    // 2. SOFT GROUND SHADOW BENEATH CAR
    // ------------------------------------------------------------------------
    final groundShadow = [
      proj(const _Vec3(-2.2, floorY, -0.92)),
      proj(const _Vec3(2.2, floorY, -0.92)),
      proj(const _Vec3(2.2, floorY, 0.92)),
      proj(const _Vec3(-2.2, floorY, 0.92)),
    ];
    if (groundShadow.every((p) => p != null)) {
      final sPath = Path()
        ..moveTo(groundShadow[0]!.dx, groundShadow[0]!.dy)
        ..lineTo(groundShadow[1]!.dx, groundShadow[1]!.dy)
        ..lineTo(groundShadow[2]!.dx, groundShadow[2]!.dy)
        ..lineTo(groundShadow[3]!.dx, groundShadow[3]!.dy)
        ..close();
      canvas.drawShadow(sPath, Colors.black.withValues(alpha: 0.95), 16, true);
    }

    // ------------------------------------------------------------------------
    // 3. SCULPTED 3D CAR BODY (EXTRUDE GEOMETRY FROM THREE.JS)
    // ------------------------------------------------------------------------
    // Profile points from Three.js carShape
    final profile = _kCarSilhouette;

    void drawPolygon(
      List<_Vec3> pts,
      Color fill, {
      Color? stroke,
      double strokeWidth = 1.0,
    }) {
      final screenPts = pts.map(proj).toList();
      if (screenPts.any((p) => p == null)) return;

      final path = Path()..moveTo(screenPts.first!.dx, screenPts.first!.dy);
      for (final p in screenPts.skip(1)) {
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

    // Three.js body colors & metallic highlights
    const bodyBaseColor = Color(0xFF0F172A); // Obsidian slate 0x0F172A
    const bodyTopColor = Color(0xFF162238); // Specular top reflection
    const bodySideColor = Color(0xFF0D1424); // Side shadow
    const wireColor = Color(0x5538BDF8); // Edge wireframe 0x38BDF8 opacity 0.34
    const contourColor = Color(0x9938BDF8); // Crisp character contour

    // Determine camera vantage relative to car sides (Z axis)
    final camSide = camera.position.z >= 0 ? 1.0 : -1.0;
    final farSideZ = -camSide * 0.88;
    final nearSideZ = camSide * 0.88;

    // Draw Far Side Wall first
    final farWall = profile.map((p) => _Vec3(p.x, p.y, farSideZ)).toList();
    drawPolygon(
      farWall,
      const Color(0xFF090E1A),
      stroke: const Color(0x3038BDF8),
      strokeWidth: 1.0,
    );

    // Draw Belly Plate
    drawPolygon(
      [
        _Vec3(-2.15, -0.22, -0.78),
        _Vec3(-2.15, -0.22, 0.78),
        _Vec3(2.15, -0.22, 0.78),
        _Vec3(2.15, -0.22, -0.78),
      ],
      const Color(0xFF070B12),
      stroke: const Color(0x2538BDF8),
    );

    // Draw Extruded Facets along the curved profile
    for (var i = 0; i < profile.length - 1; i++) {
      final p1 = profile[i];
      final p2 = profile[i + 1];

      final quadPts = [
        _Vec3(p1.x, p1.y, -0.78),
        _Vec3(p1.x, p1.y, 0.78),
        _Vec3(p2.x, p2.y, 0.78),
        _Vec3(p2.x, p2.y, -0.78),
      ];

      // Lighting gradient based on elevation & surface normal
      Color facetColor;
      if (p1.y > 0.4) {
        facetColor = bodyTopColor; // Windshield & roof
      } else if (p1.y > 0.1 && p1.x > 0.8) {
        facetColor = const Color(0xFF182840); // Hood
      } else {
        facetColor = bodyBaseColor;
      }

      drawPolygon(quadPts, facetColor, stroke: wireColor, strokeWidth: 1.0);
    }

    // Draw Near Side Wall
    final nearWall = profile.map((p) => _Vec3(p.x, p.y, nearSideZ)).toList();
    drawPolygon(
      nearWall,
      bodySideColor,
      stroke: contourColor,
      strokeWidth: 1.4,
    );

    // ------------------------------------------------------------------------
    // 4. PANORAMIC GLASS CANOPY OVERLAY (HTML lines 1136-1146)
    // ------------------------------------------------------------------------
    // BoxGeometry(1.75, 0.36, 1.38) at (-0.18, 0.56, 0)
    final cabinPts = [
      const _Vec3(-1.055, 0.38, -0.69),
      const _Vec3(0.695, 0.38, -0.69),
      const _Vec3(0.695, 0.74, -0.69),
      const _Vec3(-1.055, 0.74, -0.69),
      const _Vec3(-1.055, 0.38, 0.69),
      const _Vec3(0.695, 0.38, 0.69),
      const _Vec3(0.695, 0.74, 0.69),
      const _Vec3(-1.055, 0.74, 0.69),
    ];

    // Roof glass
    drawPolygon(
      [cabinPts[3], cabinPts[2], cabinPts[6], cabinPts[7]],
      const Color(0x3E38BDF8),
      stroke: const Color(0x8838BDF8),
      strokeWidth: 1.2,
    );
    // Windshield glass
    drawPolygon(
      [cabinPts[1], cabinPts[2], cabinPts[6], cabinPts[5]],
      const Color(0x4C38BDF8),
      stroke: const Color(0xCC38BDF8),
      strokeWidth: 1.4,
    );
    // Rear fastback glass
    drawPolygon(
      [cabinPts[0], cabinPts[3], cabinPts[7], cabinPts[4]],
      const Color(0x3E38BDF8),
      stroke: const Color(0x8838BDF8),
      strokeWidth: 1.2,
    );

    // ------------------------------------------------------------------------
    // 5. 4 AERODYNAMIC WHEELS IN TRUE 3D PERSPECTIVE (HTML lines 1162-1183)
    // ------------------------------------------------------------------------
    final wheelPositions = [
      const _Vec3(1.36, -0.26, 0.86), // Front Right
      const _Vec3(1.36, -0.26, -0.86), // Front Left
      const _Vec3(-1.36, -0.26, 0.86), // Rear Right
      const _Vec3(-1.36, -0.26, -0.86), // Rear Left
    ];

    // Sort wheels back to front for proper depth occlusion
    final sortedWheels = List<_Vec3>.from(wheelPositions)
      ..sort((a, b) => camera.depth(b).compareTo(camera.depth(a)));

    for (final wc in sortedWheels) {
      final wzSign = wc.z >= 0 ? 1.0 : -1.0;
      final rimZ = wc.z + (wzSign * 0.125);

      // 1. Dark Tire Cylinder (radius 0.36) projected as true 3D ellipse
      final tirePath = Path();
      var isFirstTire = true;
      for (var a = 0; a <= 20; a++) {
        final rad = a * (math.pi * 2 / 20);
        final pt = proj(
          _Vec3(wc.x + 0.36 * math.cos(rad), wc.y + 0.36 * math.sin(rad), rimZ),
        );
        if (pt != null) {
          if (isFirstTire) {
            tirePath.moveTo(pt.dx, pt.dy);
            isFirstTire = false;
          } else {
            tirePath.lineTo(pt.dx, pt.dy);
          }
        }
      }
      tirePath.close();
      canvas.drawPath(tirePath, Paint()..color = const Color(0xFF090D14));
      canvas.drawPath(
        tirePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF1E293B),
      );

      // 2. Glowing Cyan Rim Ring (RingGeometry radius 0.18-0.24, color 0x38BDF8 opacity 0.55)
      final rimPath = Path();
      var isFirstRim = true;
      for (var a = 0; a <= 20; a++) {
        final rad = a * (math.pi * 2 / 20) + (moving ? wheelRotation : 0.0);
        final pt = proj(
          _Vec3(wc.x + 0.21 * math.cos(rad), wc.y + 0.21 * math.sin(rad), rimZ),
        );
        if (pt != null) {
          if (isFirstRim) {
            rimPath.moveTo(pt.dx, pt.dy);
            isFirstRim = false;
          } else {
            rimPath.lineTo(pt.dx, pt.dy);
          }
        }
      }
      rimPath.close();

      // Outer glow
      canvas.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55),
      );
      // Sharp core
      canvas.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF38BDF8),
      );

      // Inner Hub
      final hubPt = proj(_Vec3(wc.x, wc.y, rimZ));
      if (hubPt != null) {
        canvas.drawCircle(hubPt, 3.5, Paint()..color = const Color(0xFF090D14));
      }
    }

    // ------------------------------------------------------------------------
    // 6. FUTURISTIC FRONT & REAR LED LIGHT BARS (HTML lines 1149-1159)
    // ------------------------------------------------------------------------
    // Front LED Light Bar at (2.26, 0.06, 0) width 1.58, color 0xE0F2FE
    final fLed1 = proj(const _Vec3(2.26, 0.06, -0.79));
    final fLed2 = proj(const _Vec3(2.26, 0.06, 0.79));
    if (fLed1 != null && fLed2 != null) {
      canvas.drawLine(
        fLed1,
        fLed2,
        Paint()
          ..strokeWidth = 5.0
          ..color = const Color(0x60E0F2FE),
      );
      canvas.drawLine(
        fLed1,
        fLed2,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0F2FE),
      );
    }

    // Rear LED Light Bar at (-2.26, 0.18, 0) width 1.54, color 0xEF4444
    final rLed1 = proj(const _Vec3(-2.26, 0.18, -0.77));
    final rLed2 = proj(const _Vec3(-2.26, 0.18, 0.77));
    if (rLed1 != null && rLed2 != null) {
      canvas.drawLine(
        rLed1,
        rLed2,
        Paint()
          ..strokeWidth = 6.0
          ..color = const Color(0x70EF4444),
      );
      canvas.drawLine(
        rLed1,
        rLed2,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFEF4444),
      );
    }

    // ------------------------------------------------------------------------
    // 7. FRONT / REAR VOLUMETRIC DASHCAM VISION BEAM (HTML lines 1186-1196)
    // ------------------------------------------------------------------------
    // Mirrors active lens: Front windshield camera or Rear window camera
    final isFront =
        !isFrontCamera; // In dashcam domain, isFrontCamera=false is the default rear-facing phone camera pointing out windshield
    final coneSign = isFront ? 1.0 : -1.0;
    final coneApex = proj(_Vec3(1.85 * coneSign, 0.45, 0.0));
    final coneColor = isRecording
        ? const Color(0xFFEF4444)
        : const Color(0xFF38BDF8);
    final coneAlpha = isRecording ? 0.34 : 0.16;

    if (coneApex != null) {
      final beamDist = infinityFocus ? 2.8 : 2.0;
      final beamRadius = infinityFocus ? 0.90 : 1.15;
      final baseX = (1.85 + beamDist) * coneSign;

      final coneBasePts = <Offset>[];
      for (var a = 0; a <= 24; a++) {
        final rad = a * (math.pi * 2 / 24);
        final pt = proj(
          _Vec3(
            baseX,
            0.45 + math.cos(rad) * beamRadius,
            math.sin(rad) * beamRadius,
          ),
        );
        if (pt != null) coneBasePts.add(pt);
      }

      if (coneBasePts.isNotEmpty) {
        final conePath = Path()..moveTo(coneApex.dx, coneApex.dy);
        for (final pt in coneBasePts) {
          conePath.lineTo(pt.dx, pt.dy);
        }
        conePath.close();

        // Translucent vision beam volume
        canvas.drawPath(
          conePath,
          Paint()
            ..color = coneColor.withValues(alpha: coneAlpha)
            ..style = PaintingStyle.fill,
        );

        // Core boundary rays
        final rayPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = coneColor.withValues(alpha: coneAlpha + 0.20);

        for (var i = 0; i < coneBasePts.length; i += 6) {
          canvas.drawLine(coneApex, coneBasePts[i], rayPaint);
        }

        // Base ring
        final baseRingPath = Path()
          ..moveTo(coneBasePts.first.dx, coneBasePts.first.dy);
        for (final pt in coneBasePts.skip(1)) {
          baseRingPath.lineTo(pt.dx, pt.dy);
        }
        baseRingPath.close();
        canvas.drawPath(baseRingPath, rayPaint);

        // If Infinity Focus is ON, project road collimation laser grid
        if (infinityFocus) {
          final laserP1 = proj(_Vec3(baseX, floorY, -0.65));
          final laserP2 = proj(_Vec3(baseX, floorY, 0.65));
          final laserP0 = proj(_Vec3(1.85 * coneSign, floorY, 0));
          if (laserP0 != null && laserP1 != null && laserP2 != null) {
            canvas.drawLine(
              laserP1,
              laserP2,
              Paint()
                ..strokeWidth = 1.4
                ..color = coneColor.withValues(alpha: 0.55),
            );
          }
        }
      }
    }
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
      old.infinityFocus != infinityFocus ||
      old.loopRecordingMinutes != loopRecordingMinutes ||
      old.videoOverlayMode != videoOverlayMode;
}

// ============================================================================
// SPATIAL HOTSPOT PIN & GLASS BADGE (EXACT HTML LINES 188-217 & SCREENSHOT)
// ============================================================================

class _SpatialHotspotButton extends StatelessWidget {
  const _SpatialHotspotButton({
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.accentColor,
    required this.active,
    required this.pulseValue,
    required this.onTap,
  });

  final String title;
  final String badgeText;
  final String subtitle;
  final Color accentColor;
  final bool active;
  final double pulseValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing Pin Circle with Pulsing Ring (w-7 h-7, pulse-ring in HTML)
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulse wave ring (scale 0.85 -> 1.9, opacity -> 0)
              Transform.scale(
                scale: 0.85 + pulseValue * 1.05,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(
                        alpha: (1.0 - pulseValue) * 0.75,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Main pin container
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Glass Card Badge (HTML lines 193-200 & 209-216)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xEB111621), // glass-card
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? accentColor
                    : accentColor.withValues(alpha: 0.35),
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.80),
                  blurRadius: 14,
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
                        fontSize: 9,
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
                          fontSize: 8.5,
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
                    fontSize: 11,
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

// ============================================================================
// SPATIAL QUICK CARDS (EXACT POPUPS FROM HTML LINES 917-960)
// ============================================================================

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF20B0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x6638BDF8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
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

              // Road Focus (Infinity) Toggle
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

              // Overlay Mode Button
              IconButton(
                onPressed: onChangeOverlayMode,
                icon: const Icon(
                  Icons.layers_rounded,
                  size: 18,
                  color: Color(0xFF38BDF8),
                ),
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
