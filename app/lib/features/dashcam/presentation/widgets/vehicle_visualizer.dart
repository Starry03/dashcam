import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ============================================================================
// 3D MATH PRIMITIVES (PERSPECTIVE CAMERA MATH)
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
// CAR SILHOUETTE GEOMETRY (SCULPTED CURVES APPROVED BY USER)
// ============================================================================

List<_Vec2> _buildCarSilhouette() {
  final pts = <_Vec2>[
    const _Vec2(-2.15, -0.22), // 0: Rear bumper bottom
    const _Vec2(2.15, -0.22), // 1: Front splitter bottom
  ];

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
// VEHICLE VISUALIZER WIDGET (SEAMLESS 3D CANVAS, NO SUB-WINDOWS)
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
    this.onResetCamera,
  });

  final bool isRecording;
  final bool isPaused;
  final double speedKmh;
  final bool isFrontCamera;
  final bool infinityFocus;
  final String videoOverlayMode;
  final int loopRecordingMinutes;
  final VoidCallback? onResetCamera;

  @override
  State<VehicleVisualizer> createState() => VehicleVisualizerState();
}

class VehicleVisualizerState extends State<VehicleVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Ticker _smoothTicker;

  double _camAngleY = -0.52;
  double _camAngleX = 0.32;
  double _targetCamAngleY = -0.52;
  double _targetCamAngleX = 0.32;

  double _dragVelocityY = 0.0;
  bool _isDragging = false;
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
    });
  }

  void _onTick(Duration elapsed) {
    final dtSec = _lastTickTime == Duration.zero
        ? 0.016
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;
    final clampedDt = dtSec.clamp(0.001, 0.04);

    if (!_isDragging) {
      _targetCamAngleY += 0.0018 * (clampedDt / 0.016);
      if (_dragVelocityY.abs() > 0.0001) {
        _targetCamAngleY += _dragVelocityY * clampedDt;
        _dragVelocityY *= math.pow(0.90, clampedDt / 0.016);
      }
    }

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

  @override
  Widget build(BuildContext context) {
    final moving =
        widget.isRecording && !widget.isPaused && widget.speedKmh > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _isDragging = true;
            _dragVelocityY = 0.0;
          },
          onPanUpdate: (details) {
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

        // Subtle Reset Camera View Button
        Positioned(
          top: 6,
          left: 6,
          child: GestureDetector(
            onTap: resetCamera,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x551E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                size: 15,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SPATIAL VEHICLE CUSTOM PAINTER (TRUE 3D SCULPTED AUTOMOTIVE MESH)
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
    // 1. FLOOR GRID & RADAR HALO RING
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

    // Halo ground ring
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
    canvas.drawPath(
      haloPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.28),
    );

    // Segmented loop buffer arcs (cool cyan, no green)
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
    // 2. SOFT GROUND SHADOW
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
    // 3. SCULPTED 3D CAR BODY (EXTRUDE SILHOUETTE APPROVED BY USER)
    // ------------------------------------------------------------------------
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

    const bodyBaseColor = Color(0xFF0F172A);
    const bodyTopColor = Color(0xFF162238);
    const bodySideColor = Color(0xFF0D1424);
    const wireColor = Color(0x5538BDF8);
    const contourColor = Color(0x9938BDF8);

    final camSide = camera.position.z >= 0 ? 1.0 : -1.0;
    final farSideZ = -camSide * 0.88;
    final nearSideZ = camSide * 0.88;

    // Far Side Wall
    final farWall = profile.map((p) => _Vec3(p.x, p.y, farSideZ)).toList();
    drawPolygon(
      farWall,
      const Color(0xFF090E1A),
      stroke: const Color(0x3038BDF8),
      strokeWidth: 1.0,
    );

    // Belly Plate
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

    // Extruded Facets along profile
    for (var i = 0; i < profile.length - 1; i++) {
      final p1 = profile[i];
      final p2 = profile[i + 1];

      final quadPts = [
        _Vec3(p1.x, p1.y, -0.78),
        _Vec3(p1.x, p1.y, 0.78),
        _Vec3(p2.x, p2.y, 0.78),
        _Vec3(p2.x, p2.y, -0.78),
      ];

      Color facetColor;
      if (p1.y > 0.4) {
        facetColor = bodyTopColor;
      } else if (p1.y > 0.1 && p1.x > 0.8) {
        facetColor = const Color(0xFF182840);
      } else {
        facetColor = bodyBaseColor;
      }

      drawPolygon(quadPts, facetColor, stroke: wireColor, strokeWidth: 1.0);
    }

    // Near Side Wall
    final nearWall = profile.map((p) => _Vec3(p.x, p.y, nearSideZ)).toList();
    drawPolygon(
      nearWall,
      bodySideColor,
      stroke: contourColor,
      strokeWidth: 1.4,
    );

    // ------------------------------------------------------------------------
    // 4. PANORAMIC GLASS CANOPY OVERLAY
    // ------------------------------------------------------------------------
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

    drawPolygon(
      [cabinPts[3], cabinPts[2], cabinPts[6], cabinPts[7]],
      const Color(0x3E38BDF8),
      stroke: const Color(0x8838BDF8),
      strokeWidth: 1.2,
    );
    drawPolygon(
      [cabinPts[1], cabinPts[2], cabinPts[6], cabinPts[5]],
      const Color(0x4C38BDF8),
      stroke: const Color(0xCC38BDF8),
      strokeWidth: 1.4,
    );
    drawPolygon(
      [cabinPts[0], cabinPts[3], cabinPts[7], cabinPts[4]],
      const Color(0x3E38BDF8),
      stroke: const Color(0x8838BDF8),
      strokeWidth: 1.2,
    );

    // ------------------------------------------------------------------------
    // 5. 4 AERODYNAMIC WHEELS IN TRUE 3D PERSPECTIVE
    // ------------------------------------------------------------------------
    final wheelPositions = [
      const _Vec3(1.36, -0.26, 0.86),
      const _Vec3(1.36, -0.26, -0.86),
      const _Vec3(-1.36, -0.26, 0.86),
      const _Vec3(-1.36, -0.26, -0.86),
    ];

    final sortedWheels = List<_Vec3>.from(wheelPositions)
      ..sort((a, b) => camera.depth(b).compareTo(camera.depth(a)));

    for (final wc in sortedWheels) {
      final wzSign = wc.z >= 0 ? 1.0 : -1.0;
      final rimZ = wc.z + (wzSign * 0.125);

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

      canvas.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55),
      );
      canvas.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF38BDF8),
      );

      final hubPt = proj(_Vec3(wc.x, wc.y, rimZ));
      if (hubPt != null) {
        canvas.drawCircle(hubPt, 3.5, Paint()..color = const Color(0xFF090D14));
      }
    }

    // ------------------------------------------------------------------------
    // 6. FRONT & REAR LED LIGHT BARS
    // ------------------------------------------------------------------------
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
    // 7. DASHCAM VISION CONE (MIRRORS ACTIVE LENS)
    // ------------------------------------------------------------------------
    final isFront = !isFrontCamera;
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

        canvas.drawPath(
          conePath,
          Paint()
            ..color = coneColor.withValues(alpha: coneAlpha)
            ..style = PaintingStyle.fill,
        );

        final rayPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = coneColor.withValues(alpha: coneAlpha + 0.20);

        for (var i = 0; i < coneBasePts.length; i += 6) {
          canvas.drawLine(coneApex, coneBasePts[i], rayPaint);
        }

        final baseRingPath = Path()
          ..moveTo(coneBasePts.first.dx, coneBasePts.first.dy);
        for (final pt in coneBasePts.skip(1)) {
          baseRingPath.lineTo(pt.dx, pt.dy);
        }
        baseRingPath.close();
        canvas.drawPath(baseRingPath, rayPaint);

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
