import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.busy,
    required this.onToggleRecording,
    required this.onTogglePause,
    required this.onLock,
  });

  final bool isRecording;
  final bool isPaused;
  final bool busy;
  final VoidCallback onToggleRecording;
  final VoidCallback onTogglePause;
  final VoidCallback onLock;

  void _safeLock() {
    HapticFeedback.heavyImpact();
    onLock();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.dashcamPalette;

    if (isRecording) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: busy ? null : _safeLock,
                icon: const Icon(Icons.lock_rounded, size: 21),
                label: const Text(
                  'LOCK CLIP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE0AF57),
                  foregroundColor: const Color(0xFF17130C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onToggleRecording,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('STOP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF1F3F4),
                      backgroundColor: const Color(0x22EF5350),
                      side: const BorderSide(color: Color(0x99EF5350)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onTogglePause,
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 18,
                    ),
                    label: Text(isPaused ? 'RESUME' : 'PAUSE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE7ECEE),
                      backgroundColor: const Color(0xFF20272D),
                      side: const BorderSide(color: Color(0x5538BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onToggleRecording,
              icon: Icon(
                Icons.fiber_manual_record,
                color: palette.recording,
                size: 18,
              ),
              label: const Text(
                'START RECORDING',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.surfaceStrong,
                foregroundColor: palette.text,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: palette.telemetry.withAlpha(180),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
