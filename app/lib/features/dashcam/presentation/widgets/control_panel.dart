import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _safeLock() {
    HapticFeedback.heavyImpact();
    onLock();
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return Column(
        children: [
          // Primary driver emergency/lock button: big, high-contrast, safe to hit while driving
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: busy ? null : _safeLock,
              icon: const Icon(Icons.shield_rounded, size: 24),
              label: const Text(
                'LOCK INCIDENT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onToggleRecording,
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onTogglePause,
                  icon: Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 20,
                  ),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onQuickActions,
              icon: const Icon(Icons.menu_rounded, size: 18),
              label: const Text('Quick Actions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Idle state: big start button
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onToggleRecording,
            icon: const Icon(Icons.fiber_manual_record, size: 22),
            label: const Text(
              'START RECORDING',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onQuickActions,
            icon: const Icon(Icons.menu_rounded, size: 18),
            label: const Text('Quick Actions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
