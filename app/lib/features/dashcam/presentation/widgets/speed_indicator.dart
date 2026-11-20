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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xCC151A20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.speed_rounded,
                color: Color(0xFF75B8CA),
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                '${speedKmh.toStringAsFixed(1)} km/h',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: style.color.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: style.color.withAlpha(45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 13, color: style.color),
              const SizedBox(width: 5),
              Text(
                style.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
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
