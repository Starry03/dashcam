import 'package:flutter/material.dart';

import '../../domain/gps_status.dart';

class SpeedIndicator extends StatelessWidget {
  const SpeedIndicator({
    super.key,
    required this.speedKmh,
    required this.gpsStatus,
  });

  final double speedKmh;
  final GpsUiStatus gpsStatus;

  ({String label, Color color, IconData icon}) _gpsStyle() {
    switch (gpsStatus) {
      case GpsUiStatus.active:
        return (
          label: 'GPS',
          color: Colors.white60,
          icon: Icons.gps_fixed_rounded,
        );
      case GpsUiStatus.weakSignal:
        return (
          label: 'Weak GPS',
          color: Colors.orange.shade200,
          icon: Icons.gps_not_fixed_rounded,
        );
      case GpsUiStatus.permissionDenied:
        return (
          label: 'GPS not allowed',
          color: Colors.red.shade200,
          icon: Icons.location_disabled_rounded,
        );
      case GpsUiStatus.gpsDisabled:
        return (
          label: 'GPS off',
          color: Colors.red.shade200,
          icon: Icons.gps_off_rounded,
        );
      case GpsUiStatus.checking:
        return (
          label: 'GPS...',
          color: Colors.white54,
          icon: Icons.gps_not_fixed_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _gpsStyle();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed_rounded, color: Colors.white70, size: 22),
              const SizedBox(width: 10),
              Text(
                '${speedKmh.toStringAsFixed(1)} km/h',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: gpsStatus == GpsUiStatus.active ? 0.72 : 0.9,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 12, color: style.color),
              const SizedBox(width: 4),
              Text(
                style.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: style.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
