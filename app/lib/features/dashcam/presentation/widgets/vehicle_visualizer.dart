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

class _Point3 {
  const _Point3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

Offset _projectPoint(
  _Point3 p,
  double cx,
  double cy,
  double scale,
  double yaw,
  double pitch,
) {
  final cosYaw = math.cos(yaw);
  final sinYaw = math.sin(yaw);
  final rx = p.x * cosYaw - p.y * sinYaw;
  final ry = p.x * sinYaw + p.y * cosYaw;
  return Offset(cx + rx * scale, cy + (ry * pitch - p.z) * scale);
}

class _VehiclePainter extends CustomPainter {
  _VehiclePainter({
    required this.isRecording,
    required this.isPaused,
    required this.moving,
    required this.yaw,
    required this.pitch,
    required this.zoomScale,
    required this.wheelRotation,
    required this.pulseValue,
    required this.speedKmh,
    required this.isFrontCamera,
    required this.infinityFocus,
    required this.videoOverlayMode,
    required this.loopRecordingMinutes,
    required this.onAnchorsComputed,
  });

  final bool isRecording;
  final bool isPaused;
  final bool moving;
  final double yaw;
  final double pitch;
  final double zoomScale;
  final double wheelRotation;
  final double pulseValue;
  final double speedKmh;
  final bool isFrontCamera;
  final bool infinityFocus;
  final String videoOverlayMode;
  final int loopRecordingMinutes;
  final void Function(Offset frontPin, Offset cabinPin) onAnchorsComputed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.52;
    final scale = math.min(size.width / 320, size.height / 320) * zoomScale;

    Offset project(_Point3 p) => _projectPoint(p, cx, cy, scale, yaw, pitch);

    // Compute anchor positions for floating cards in 2D
    final frontAnchor3D = isFrontCamera
        ? const _Point3(24, -40, 36)
        : const _Point3(22, 75, 29);
    final cabinAnchor3D = const _Point3(-24, 15, 46);

    final frontPinPos = project(frontAnchor3D);
    final cabinPinPos = project(cabinAnchor3D);
    onAnchorsComputed(frontPinPos, cabinPinPos);

    void drawPolygon(List<_Point3> points, Color fill, {Color? stroke, double strokeWidth = 1.0}) {
      final path = Path()..moveTo(project(points.first).dx, project(points.first).dy);
      for (final p in points.skip(1)) {
        final off = project(p);
        path.lineTo(off.dx, off.dy);
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

    // ------------------------------------------------------------------------
    // 1. GROUND RADAR GRID & ORBITAL BOUNDARY RING (CYBERPUNK / TRON STYLE)
    // ------------------------------------------------------------------------
    final gridLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = -6; i <= 6; i++) {
      final dist = (1.0 - (i.abs() / 7.0)).clamp(0.08, 0.7);
      gridLinePaint.color = const Color(0xFF29B6F6).withValues(alpha: dist * 0.12);

      final x = i * 28.0;
      canvas.drawLine(project(_Point3(x, -190, 0)), project(_Point3(x, 180, 0)), gridLinePaint);

      final y = i * 28.0;
      canvas.drawLine(project(_Point3(-180, y, 0)), project(_Point3(180, y, 0)), gridLinePaint);
    }

    // Ground Radar Orbit Ring around vehicle
    final ringRadius = 155.0;
    final ringPath = Path();
    for (var a = 0; a <= 40; a++) {
      final rad = a * (math.pi * 2 / 40);
      final pt = project(_Point3(math.sin(rad) * ringRadius * 0.75, math.cos(rad) * ringRadius, 0));
      if (a == 0) {
        ringPath.moveTo(pt.dx, pt.dy);
      } else {
        ringPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      ringPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35),
    );

    // Dynamic Road guide streaks when moving
    if (moving) {
      final speedLinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * scale
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.55);
      final offsetStep = (wheelRotation * 18.0) % 52.0;
      for (var y = -190.0 + offsetStep; y < 180.0; y += 52.0) {
        canvas.drawLine(
          project(_Point3(0, y, 0)),
          project(_Point3(0, y + 26.0, 0)),
          speedLinePaint,
        );
      }
    }

    // ------------------------------------------------------------------------
    // 2. CAMERA LENS FOV VISION CONE (FORWARD / REAR HOLOGRAPHIC PROJECTION)
    // ------------------------------------------------------------------------
    final fovColor = isRecording
        ? const Color(0xFFFF1744)
        : const Color(0xFF00E5FF);

    if (isFrontCamera) {
      final apex = project(_Point3(0, -42, 36));
      final pLeft = project(_Point3(-95, -195, 0));
      final pRight = project(_Point3(95, -195, 0));

      final fovPath = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(pLeft.dx, pLeft.dy)
        ..lineTo(pRight.dx, pRight.dy)
        ..close();

      canvas.drawPath(
        fovPath,
        Paint()
          ..shader = RadialGradient(
            colors: [
              fovColor.withValues(alpha: 0.22),
              fovColor.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65, 1.0],
          ).createShader(Rect.fromPoints(apex, Offset((pLeft.dx + pRight.dx) / 2, pLeft.dy))),
      );

      final fovBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..color = fovColor.withValues(alpha: 0.45);
      canvas.drawLine(apex, pLeft, fovBorder);
      canvas.drawLine(apex, pRight, fovBorder);
      canvas.drawLine(pLeft, pRight, fovBorder..strokeWidth = 0.8 * scale);

      // Focus Reticle in 3D Space
      final targetPt = project(_Point3(0, -195, 0));
      if (infinityFocus) {
        final tp = TextPainter(
          text: TextSpan(
            text: '[ ∞ INFINITY FOCUS LOCK ]',
            style: TextStyle(
              color: const Color(0xFF64FFDA),
              fontSize: 8.5 * scale,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              shadows: const [Shadow(color: Color(0x9964FFDA), blurRadius: 8)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, targetPt - Offset(tp.width / 2, tp.height + 4));
      }
    } else {
      final apex = project(_Point3(0, 88, 30));
      final pLeft = project(_Point3(-85, 175, 0));
      final pRight = project(_Point3(85, 175, 0));

      final fovPath = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(pLeft.dx, pLeft.dy)
        ..lineTo(pRight.dx, pRight.dy)
        ..close();

      canvas.drawPath(
        fovPath,
        Paint()
          ..shader = RadialGradient(
            colors: [
              fovColor.withValues(alpha: 0.22),
              fovColor.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65, 1.0],
          ).createShader(Rect.fromPoints(apex, Offset((pLeft.dx + pRight.dx) / 2, pLeft.dy))),
      );

      final fovBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..color = fovColor.withValues(alpha: 0.45);
      canvas.drawLine(apex, pLeft, fovBorder);
      canvas.drawLine(apex, pRight, fovBorder);
    }

    // ------------------------------------------------------------------------
    // 3. VEHICLE SHADOW (SOFT UNDERBODY AMBIENT OCCLUSION)
    // ------------------------------------------------------------------------
    final shadow = Path()
      ..moveTo(project(_Point3(-64, -125, 0)).dx, project(_Point3(-64, -125, 0)).dy)
      ..lineTo(project(_Point3(64, -125, 0)).dx, project(_Point3(64, -125, 0)).dy)
      ..lineTo(project(_Point3(68, 122, 0)).dx, project(_Point3(68, 122, 0)).dy)
      ..lineTo(project(_Point3(-68, 122, 0)).dx, project(_Point3(-68, 122, 0)).dy)
      ..close();
    canvas.drawShadow(shadow, Colors.black.withValues(alpha: 0.95), 18 * scale, true);

    // ------------------------------------------------------------------------
    // 4. 3D CAR BODY PANELS (CYBERPUNK / HIGH-END COUPE WIREFRAME AESTHETIC)
    // ------------------------------------------------------------------------

    // Underbody chassis plate
    drawPolygon(
      [
        const _Point3(-58, -122, 7),
        const _Point3(58, -122, 7),
        const _Point3(60, 118, 7),
        const _Point3(-60, 118, 7),
      ],
      const Color(0xFF070B0E),
      stroke: const Color(0x3300E5FF),
    );

    // Front chin splitter
    drawPolygon(
      [
        const _Point3(-54, -126, 6),
        const _Point3(54, -126, 6),
        const _Point3(50, -118, 14),
        const _Point3(-50, -118, 14),
      ],
      const Color(0xFF0F151B),
      stroke: const Color(0x6600E5FF),
      strokeWidth: 1.2,
    );

    // Front Fascia / Bumper
    drawPolygon(
      [
        const _Point3(-50, -124, 14),
        const _Point3(50, -124, 14),
        const _Point3(46, -116, 22),
        const _Point3(-46, -116, 22),
      ],
      const Color(0xFF141C24),
      stroke: const Color(0x884FC3F7),
      strokeWidth: 1.2,
    );

    // Hood Main Panel (Aerodynamic Raked Surface)
    drawPolygon(
      [
        const _Point3(-46, -116, 22),
        const _Point3(46, -116, 22),
        const _Point3(42, -42, 29),
        const _Point3(-42, -42, 29),
      ],
      const Color(0xFF19232D),
      stroke: const Color(0xAA4FC3F7),
      strokeWidth: 1.2,
    );

    // Raked Windshield (Tinted Cockpit Glass)
    drawPolygon(
      [
        const _Point3(-42, -42, 29),
        const _Point3(42, -42, 29),
        const _Point3(36, -10, 45),
        const _Point3(-36, -10, 45),
      ],
      const Color(0xD80B1A24),
      stroke: const Color(0xFF00E5FF),
      strokeWidth: 1.5,
    );

    // Roof Panel
    drawPolygon(
      [
        const _Point3(-36, -10, 45),
        const _Point3(36, -10, 45),
        const _Point3(34, 38, 44),
        const _Point3(-34, 38, 44),
      ],
      const Color(0xFF121B22),
      stroke: const Color(0x884FC3F7),
      strokeWidth: 1.2,
    );

    // Rear Windshield / Fastback Glass
    drawPolygon(
      [
        const _Point3(-34, 38, 44),
        const _Point3(34, 38, 44),
        const _Point3(40, 88, 28),
        const _Point3(-40, 88, 28),
      ],
      const Color(0xD00E1C27),
      stroke: const Color(0xBB4FC3F7),
      strokeWidth: 1.3,
    );

    // Trunk Decklid
    drawPolygon(
      [
        const _Point3(-40, 88, 28),
        const _Point3(40, 88, 28),
        const _Point3(44, 118, 24),
        const _Point3(-44, 118, 24),
      ],
      const Color(0xFF19222B),
      stroke: const Color(0x884FC3F7),
      strokeWidth: 1.2,
    );

    // Rear Bumper / Diffuser
    drawPolygon(
      [
        const _Point3(-48, 118, 24),
        const _Point3(48, 118, 24),
        const _Point3(46, 122, 10),
        const _Point3(-46, 122, 10),
      ],
      const Color(0xFF10161C),
      stroke: const Color(0x5500E5FF),
    );

    // Left Body Flank & Side Skirt
    drawPolygon(
      [
        const _Point3(-46, -116, 22),
        const _Point3(-42, -42, 29),
        const _Point3(-40, 88, 28),
        const _Point3(-48, 118, 24),
        const _Point3(-56, 86, 14),
        const _Point3(-56, -78, 14),
      ],
      const Color(0xFF131C24),
      stroke: const Color(0x664FC3F7),
    );

    // Right Body Flank & Side Skirt
    drawPolygon(
      [
        const _Point3(46, -116, 22),
        const _Point3(42, -42, 29),
        const _Point3(40, 88, 28),
        const _Point3(48, 118, 24),
        const _Point3(56, 86, 14),
        const _Point3(56, -78, 14),
      ],
      const Color(0xFF222E3A),
      stroke: const Color(0x884FC3F7),
    );

    // Side Windows (Left Glass)
    drawPolygon(
      [
        const _Point3(-42, -40, 30),
        const _Point3(-36, -10, 45),
        const _Point3(-34, 38, 44),
        const _Point3(-40, 84, 29),
      ],
      const Color(0xD00A1721),
      stroke: const Color(0x8800E5FF),
    );

    // Side Windows (Right Glass)
    drawPolygon(
      [
        const _Point3(42, -40, 30),
        const _Point3(36, -10, 45),
        const _Point3(34, 38, 44),
        const _Point3(40, 84, 29),
      ],
      const Color(0xE0122330),
      stroke: const Color(0xAA00E5FF),
    );

    // ------------------------------------------------------------------------
    // 5. GLOWING NEON CYAN WAISTLINE / SHOULDER CONTOUR STRIP (LIKE IN IMAGE!)
    // ------------------------------------------------------------------------
    final neonGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * scale
      ..color = const Color(0x5500E5FF);

    final neonCorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00E5FF);

    for (final dir in [-1.0, 1.0]) {
      final shoulderPath = Path()
        ..moveTo(project(_Point3(dir * 46, -116, 22)).dx, project(_Point3(dir * 46, -116, 22)).dy)
        ..lineTo(project(_Point3(dir * 42, -42, 29)).dx, project(_Point3(dir * 42, -42, 29)).dy)
        ..lineTo(project(_Point3(dir * 36, -10, 45)).dx, project(_Point3(dir * 36, -10, 45)).dy)
        ..lineTo(project(_Point3(dir * 34, 38, 44)).dx, project(_Point3(dir * 34, 38, 44)).dy)
        ..lineTo(project(_Point3(dir * 40, 88, 28)).dx, project(_Point3(dir * 40, 88, 28)).dy)
        ..lineTo(project(_Point3(dir * 46, 118, 24)).dx, project(_Point3(dir * 46, 118, 24)).dy);

      canvas.drawPath(shoulderPath, neonGlowPaint);
      canvas.drawPath(shoulderPath, neonCorePaint);
    }

    // ------------------------------------------------------------------------
    // 6. WHEELS WITH GLOWING NEON CYAN RIMS (TRON / CYBER WHEELS AS IN IMAGE!)
    // ------------------------------------------------------------------------
    final wheels = [
      const _Point3(-62, -76, 11),
      const _Point3(62, -76, 11),
      const _Point3(-62, 80, 11),
      const _Point3(62, 80, 11),
    ];

    for (final wheel in wheels) {
      final p = project(wheel);

      // Dark Tire
      canvas.drawCircle(p, 14.5 * scale, Paint()..color = const Color(0xFF06090C));

      // Outer Neon Rim Glow (Soft cyan halo)
      canvas.drawCircle(
        p,
        10.5 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8 * scale
          ..color = const Color(0x6600E5FF),
      );

      // Sharp Neon Rim Circle (Bright cyan ring)
      canvas.drawCircle(
        p,
        10.5 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * scale
          ..color = const Color(0xFF00E5FF),
      );

      // Dark Inner Hub
      canvas.drawCircle(p, 6.5 * scale, Paint()..color = const Color(0xFF080D12));

      // Center Neon Dot
      canvas.drawCircle(p, 2.2 * scale, Paint()..color = const Color(0xFF00E5FF));
    }

    // ------------------------------------------------------------------------
    // 7. REAR LIGHTBAR & FRONT HEADLIGHT PROJECTORS
    // ------------------------------------------------------------------------
    final tailStart = project(const _Point3(-46, 118, 24));
    final tailCenter = project(const _Point3(0, 119, 24.5));
    final tailEnd = project(const _Point3(46, 118, 24));

    final tailPath = Path()
      ..moveTo(tailStart.dx, tailStart.dy)
      ..lineTo(tailCenter.dx, tailCenter.dy)
      ..lineTo(tailEnd.dx, tailEnd.dy);

    canvas.drawPath(
      tailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * scale
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF1744),
    );
    canvas.drawPath(
      tailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 * scale
        ..color = const Color(0x66FF1744),
    );

    // Front Headlight Bars
    for (final dir in [-1.0, 1.0]) {
      final p1 = project(_Point3(dir * 44, -120, 19));
      final p2 = project(_Point3(dir * 26, -123, 20));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 2.4 * scale
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0F7FA),
      );
    }

    // ------------------------------------------------------------------------
    // 8. 3D ANCHOR PINS WITH RIPPLE RINGS (CYAN FOR FRONT, GREEN FOR CABIN)
    // ------------------------------------------------------------------------
    void drawPin(Offset pos, Color color, double pulse) {
      // Outer ripple
      canvas.drawCircle(
        pos,
        (7.0 + pulse * 10.0) * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale
          ..color = color.withValues(alpha: (1.0 - pulse) * 0.65),
      );
      // Ring boundary
      canvas.drawCircle(
        pos,
        6.5 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * scale
          ..color = color,
      );
      // Solid center dot
      canvas.drawCircle(pos, 3.2 * scale, Paint()..color = color);
    }

    drawPin(frontPinPos, const Color(0xFF00E5FF), pulseValue);
    drawPin(cabinPinPos, const Color(0xFF00E676), pulseValue);

    // Leader lines connecting pins to cards
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;

    // Leader line for Front Cam Card (points up-right)
    final frontCardTarget = frontPinPos + Offset(28 * scale, -18 * scale);
    canvas.drawLine(
      frontPinPos,
      frontCardTarget,
      linePaint..color = const Color(0xFF00E5FF).withValues(alpha: 0.7),
    );

    // Leader line for Cabin Hub Card (points up-left)
    final cabinCardTarget = cabinPinPos + Offset(-24 * scale, -18 * scale);
    canvas.drawLine(
      cabinPinPos,
      cabinCardTarget,
      linePaint..color = const Color(0xFF00E676).withValues(alpha: 0.7),
    );

    // ------------------------------------------------------------------------
    // 9. TELEMETRY SPEED DISPLAY (IF MOVING)
    // ------------------------------------------------------------------------
    if (moving) {
      final speedPos = project(const _Point3(0, -155, 4));
      final speedTp = TextPainter(
        text: TextSpan(
          text: '${speedKmh.toStringAsFixed(0)} KM/H',
          style: TextStyle(
            color: const Color(0xFF80D8FF),
            fontSize: 9.5 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            shadows: const [Shadow(color: Color(0x8800E5FF), blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      speedTp.paint(canvas, speedPos - Offset(speedTp.width / 2, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter old) =>
      old.isRecording != isRecording ||
      old.isPaused != isPaused ||
      old.moving != moving ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoomScale != zoomScale ||
      old.wheelRotation != wheelRotation ||
      old.pulseValue != pulseValue ||
      old.speedKmh != speedKmh ||
      old.isFrontCamera != isFrontCamera ||
      old.infinityFocus != infinityFocus ||
      old.videoOverlayMode != videoOverlayMode ||
      old.loopRecordingMinutes != loopRecordingMinutes;
}

// ----------------------------------------------------------------------------
// STATEFUL VEHICLE VISUALIZER WITH FLUID SMOOTH 3D PHYSICS
// ----------------------------------------------------------------------------

class _VehicleVisualizerState extends State<VehicleVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _wheelController;
  late final AnimationController _pulseController;
  late final Ticker _physicsTicker;

  // Rendered angles & scale
  double _yaw = -0.42;
  double _pitch = 0.38;
  double _scale = 1.0;

  // Target angles & scale (for silky damping)
  double _targetYaw = -0.42;
  double _targetPitch = 0.38;
  double _targetScale = 1.0;

  // Inertia momentum velocities
  double _yawVelocity = 0.0;
  double _pitchVelocity = 0.0;
  bool _isInteracting = false;

  // 2D Anchor points for the floating hotspot cards
  Offset _frontPinPos = const Offset(190, 95);
  Offset _cabinPinPos = const Offset(90, 60);

  // Active settings dialog/sheet
  bool _showOpticsSheet = false;
  bool _showCabinSheet = false;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // High refresh rate physics ticker for 100% fluid, buttery navigation
    _physicsTicker = createTicker((_) {
      if (!_isInteracting) {
        // Apply smooth momentum decay (friction)
        _targetYaw += _yawVelocity;
        _targetPitch += _pitchVelocity;

        _yawVelocity *= 0.91;
        _pitchVelocity *= 0.91;

        if (_yawVelocity.abs() < 0.00005) _yawVelocity = 0.0;
        if (_pitchVelocity.abs() < 0.00005) _pitchVelocity = 0.0;
      }

      _targetPitch = _targetPitch.clamp(0.18, 0.68);
      _targetScale = _targetScale.clamp(0.85, 1.30);

      // Exponential damping towards targets (silky smooth lerp)
      final diffYaw = (_targetYaw - _yaw) * 0.22;
      final diffPitch = (_targetPitch - _pitch) * 0.22;
      final diffScale = (_targetScale - _scale) * 0.22;

      if (diffYaw.abs() > 0.0001 || diffPitch.abs() > 0.0001 || diffScale.abs() > 0.0001 || _wheelController.isAnimating) {
        setState(() {
          _yaw += diffYaw;
          _pitch += diffPitch;
          _scale += diffScale;
        });
      }
    })..start();
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _wheelController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAnchorsComputed(Offset frontPin, Offset cabinPin) {
    _frontPinPos = frontPin;
    _cabinPinPos = cabinPin;
  }

  @override
  Widget build(BuildContext context) {
    final moving = widget.isRecording && !widget.isPaused && widget.speedKmh > 1;
    if (moving && !_wheelController.isAnimating) {
      _wheelController.repeat();
    } else if (!moving && _wheelController.isAnimating) {
      _wheelController.stop();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Position the two floating cards anchored to 3D pins (with safe clamping)
        final frontCardLeft = (_frontPinPos.dx + 20).clamp(10.0, w - 145.0);
        final frontCardTop = (_frontPinPos.dy - 35).clamp(10.0, h - 65.0);

        final cabinCardLeft = (_cabinPinPos.dx - 135).clamp(10.0, w - 150.0);
        final cabinCardTop = (_cabinPinPos.dy - 40).clamp(10.0, h - 65.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _isInteracting = true;
            _yawVelocity = 0.0;
            _pitchVelocity = 0.0;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 1) {
              // Smooth 1-finger orbit
              final dx = details.focalPointDelta.dx;
              final dy = details.focalPointDelta.dy;

              _targetYaw += dx * 0.007;
              _targetPitch -= dy * 0.005;

              _yawVelocity = dx * 0.0035;
              _pitchVelocity = -dy * 0.0025;
            } else if (details.pointerCount >= 2) {
              // Smooth 2-finger pinch zoom
              _targetScale = (_targetScale * details.scale).clamp(0.85, 1.30);
            }
          },
          onScaleEnd: (details) {
            _isInteracting = false;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 3D CustomPaint
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_wheelController, _pulseController]),
                  builder: (context, child) => CustomPaint(
                    painter: _VehiclePainter(
                      isRecording: widget.isRecording,
                      isPaused: widget.isPaused,
                      moving: moving,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoomScale: _scale,
                      wheelRotation: _wheelController.value * math.pi * 2,
                      pulseValue: _pulseController.value,
                      speedKmh: widget.speedKmh,
                      isFrontCamera: widget.isFrontCamera,
                      infinityFocus: widget.infinityFocus,
                      videoOverlayMode: widget.videoOverlayMode,
                      loopRecordingMinutes: widget.loopRecordingMinutes,
                      onAnchorsComputed: _onAnchorsComputed,
                    ),
                  ),
                ),
              ),

              // --------------------------------------------------------------
              // CARD 1: FRONT CAM (Ottica & Focus) - Anchored in 3D!
              // --------------------------------------------------------------
              Positioned(
                left: frontCardLeft,
                top: frontCardTop,
                child: _FloatingHotspotCard(
                  title: 'FRONT CAM',
                  pillText: widget.isFrontCamera ? 'Front' : 'Rear',
                  subtitle: 'Ottica & Focus',
                  accentColor: const Color(0xFF00E5FF),
                  active: _showOpticsSheet,
                  onTap: () => setState(() {
                    _showOpticsSheet = !_showOpticsSheet;
                    _showCabinSheet = false;
                  }),
                ),
              ),

              // --------------------------------------------------------------
              // CARD 2: CABIN HUB (Clip & Galleria) - Anchored in 3D!
              // --------------------------------------------------------------
              Positioned(
                left: cabinCardLeft,
                top: cabinCardTop,
                child: _FloatingHotspotCard(
                  title: 'CABIN HUB',
                  pillText: widget.loopRecordingMinutes == 0
                      ? 'Loop Off'
                      : '${widget.loopRecordingMinutes}m Loop',
                  subtitle: 'Clip & Galleria',
                  accentColor: const Color(0xFF00E676),
                  active: _showCabinSheet,
                  onTap: () => setState(() {
                    _showCabinSheet = !_showCabinSheet;
                    _showOpticsSheet = false;
                  }),
                ),
              ),

              // Expanded Options Popup for FRONT CAM (Ottica & Focus)
              if (_showOpticsSheet)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _OpticsControlsSheet(
                    isRecording: widget.isRecording,
                    isFrontCamera: widget.isFrontCamera,
                    infinityFocus: widget.infinityFocus,
                    videoOverlayMode: widget.videoOverlayMode,
                    onSwitchLens: widget.onSwitchLens,
                    onToggleInfinityFocus: widget.onToggleInfinityFocus,
                    onChangeOverlayMode: widget.onChangeOverlayMode,
                    onClose: () => setState(() => _showOpticsSheet = false),
                  ),
                ),

              // Expanded Options Popup for CABIN HUB (Clip & Galleria)
              if (_showCabinSheet)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _CabinControlsSheet(
                    loopRecordingMinutes: widget.loopRecordingMinutes,
                    onChangeLoopRecording: widget.onChangeLoopRecording,
                    onOpenGallery: widget.onOpenGallery,
                    onClose: () => setState(() => _showCabinSheet = false),
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
// FLOATING HOTSPOT CARD WIDGET (MATCHING USER REFERENCE IMAGE EXACTLY!)
// ----------------------------------------------------------------------------

class _FloatingHotspotCard extends StatelessWidget {
  const _FloatingHotspotCard({
    required this.title,
    required this.pillText,
    required this.subtitle,
    required this.accentColor,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String pillText;
  final String subtitle;
  final Color accentColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
          decoration: BoxDecoration(
            color: const Color(0xEB0A121A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? accentColor : accentColor.withValues(alpha: 0.35),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Title + Pill Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      pillText,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2.5),
              // Row 2: Subtitle
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// EXPANDED QUICK CONTROL SHEETS FOR THE TWO CARDS
// ----------------------------------------------------------------------------

class _OpticsControlsSheet extends StatelessWidget {
  const _OpticsControlsSheet({
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xF5080E15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x7700E5FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'FRONT OPTICS & FOCUS CONTROLS',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
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
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: isFrontCamera ? Icons.camera_front_rounded : Icons.camera_rear_rounded,
                  label: 'Lens',
                  value: isFrontCamera ? 'Front Lens' : 'Rear Lens',
                  active: true,
                  onTap: isRecording ? null : onSwitchLens,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.all_inclusive_rounded,
                  label: 'Road Focus',
                  value: infinityFocus ? 'Infinity Lock' : 'Auto Focus',
                  active: infinityFocus,
                  onTap: () => onToggleInfinityFocus(!infinityFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.layers_rounded,
                  label: 'Overlay',
                  value: videoOverlayMode == 'subtitles'
                      ? 'Subtitles'
                      : videoOverlayMode == 'burnin'
                          ? 'Burn-in'
                          : 'Off',
                  active: videoOverlayMode != 'none',
                  onTap: onChangeOverlayMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CabinControlsSheet extends StatelessWidget {
  const _CabinControlsSheet({
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xF5080E15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x7700E676), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'CABIN HUB & CLIP MANAGEMENT',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
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
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.video_library_rounded,
                  label: 'Galleria',
                  value: 'Apri Clip Video',
                  active: true,
                  onTap: onOpenGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.loop_rounded,
                  label: 'Loop Retention',
                  value: loopRecordingMinutes == 0 ? 'Save All' : '${loopRecordingMinutes}m Loop',
                  active: loopRecordingMinutes > 0,
                  onTap: onChangeLoopRecording,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: active ? const Color(0x1F00E5FF) : const Color(0xFF131A21),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0x6600E5FF) : const Color(0x28FFFFFF),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? (active ? const Color(0xFF00E5FF) : Colors.white70)
                    : Colors.white24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 9.5,
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
