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
        fontSize: 44,
        fontWeight: FontWeight.w300,
        fontFamily: 'monospace',
        letterSpacing: -1.5,
        color: Color(0xFFF2F5F6),
      ),
      textAlign: TextAlign.center,
    );
  }
}
