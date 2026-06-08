import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.busy,
    required this.onToggleRecording,
    required this.onTogglePause,
    required this.onLock,
    required this.onQuickActions,
  });

  final bool isRecording;
  final bool isPaused;
  final bool busy;
  final VoidCallback onToggleRecording;
  final VoidCallback onTogglePause;
  final VoidCallback onLock;
  final VoidCallback onQuickActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : onToggleRecording,
                icon: Icon(
                  isRecording
                      ? Icons.stop_rounded
                      : Icons.fiber_manual_record,
                ),
                label: Text(isRecording ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording
                      ? Colors.redAccent
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy || !isRecording ? null : onTogglePause,
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(isPaused ? 'Resume' : 'Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onLock,
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Lock Clip'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onQuickActions,
            icon: const Icon(Icons.menu_rounded),
            label: const Text('Quick Actions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
