import 'package:flutter/material.dart';

class RecordingStatusHeader extends StatelessWidget {
  const RecordingStatusHeader({
    super.key,
    required this.isRecording,
    required this.isPaused,
  });

  final bool isRecording;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final label = isRecording ? (isPaused ? 'PAUSED' : 'RECORDING') : 'READY';
    final color = isRecording
        ? (isPaused ? Colors.orangeAccent : Colors.redAccent)
        : Colors.grey;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC151A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecording ? color.withAlpha(90) : Colors.white.withAlpha(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isRecording
                  ? [
                      BoxShadow(
                        color: color.withAlpha(120),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: isRecording ? Colors.white : const Color(0xFF9CABB3),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
