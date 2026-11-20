import 'package:flutter/material.dart';

@immutable
class DashcamPalette extends ThemeExtension<DashcamPalette> {
  const DashcamPalette({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceStrong,
    required this.telemetry,
    required this.telemetryMuted,
    required this.text,
    required this.textMuted,
    required this.incident,
    required this.recording,
    required this.warning,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceStrong;
  final Color telemetry;
  final Color telemetryMuted;
  final Color text;
  final Color textMuted;
  final Color incident;
  final Color recording;
  final Color warning;

  static const defaults = DashcamPalette(
    surface: Color(0xFF121212),
    surfaceRaised: Color(0xFF151A20),
    surfaceStrong: Color(0xFF171B22),
    telemetry: Color(0xFF75B8CA),
    telemetryMuted: Color(0xFF87B8C6),
    text: Color(0xFFF1F3F4),
    textMuted: Color(0xFF9CABB3),
    incident: Color(0xFFE0AF57),
    recording: Color(0xFFEF5350),
    warning: Color(0xFFC9A45A),
  );

  @override
  DashcamPalette copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceStrong,
    Color? telemetry,
    Color? telemetryMuted,
    Color? text,
    Color? textMuted,
    Color? incident,
    Color? recording,
    Color? warning,
  }) {
    return DashcamPalette(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      telemetry: telemetry ?? this.telemetry,
      telemetryMuted: telemetryMuted ?? this.telemetryMuted,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      incident: incident ?? this.incident,
      recording: recording ?? this.recording,
      warning: warning ?? this.warning,
    );
  }

  @override
  DashcamPalette lerp(covariant DashcamPalette? other, double t) {
    if (other == null) return this;
    return DashcamPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      telemetry: Color.lerp(telemetry, other.telemetry, t)!,
      telemetryMuted: Color.lerp(telemetryMuted, other.telemetryMuted, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      incident: Color.lerp(incident, other.incident, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension DashcamTheme on BuildContext {
  DashcamPalette get dashcamPalette =>
      Theme.of(this).extension<DashcamPalette>() ?? DashcamPalette.defaults;
}
