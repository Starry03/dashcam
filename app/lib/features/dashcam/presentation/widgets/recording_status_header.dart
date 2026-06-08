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
    final label = isRecording
        ? (isPaused ? 'PAUSED' : 'RECORDING')
        : 'READY';
    final color = isRecording
        ? (isPaused ? Colors.orangeAccent : Colors.redAccent)
        : Colors.grey;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.fiber_manual_record,
          color: isRecording ? Colors.redAccent : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
