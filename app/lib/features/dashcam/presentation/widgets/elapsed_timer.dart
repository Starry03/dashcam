import 'package:flutter/material.dart';

class ElapsedTimer extends StatelessWidget {
  const ElapsedTimer({super.key, required this.elapsedSeconds});

  final int elapsedSeconds;

  static String format(int seconds) {
    if (seconds == 0) return '00:00:00';
    final d = Duration(seconds: seconds);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      format(elapsedSeconds),
      style: const TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w200,
        fontFamily: 'monospace',
      ),
    );
  }
}
