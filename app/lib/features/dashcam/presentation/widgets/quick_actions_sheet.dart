import 'package:flutter/material.dart';

/// Presents the quick-actions bottom sheet. Each action pops the sheet and then
/// invokes its callback; all business logic lives in the caller.
Future<void> showQuickActionsSheet(
  BuildContext context, {
  required bool isFrontCamera,
  required bool isRecording,
  required int loopRecordingMinutes,
  required bool infinityFocus,
  required String videoOverlayMode,
  required VoidCallback onSwitchLens,
  required VoidCallback onLock,
  required VoidCallback onOpenGallery,
  required VoidCallback onChangeLoopRecording,
  required ValueChanged<bool> onToggleInfinityFocus,
  required VoidCallback onChangeOverlayMode,
  required VoidCallback onCheckUpdates,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1D1D1D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isFrontCamera
                      ? Icons.camera_front_rounded
                      : Icons.camera_rear_rounded,
                  color: isRecording ? Colors.white38 : Colors.white,
                ),
                title: const Text('Switch Lens'),
                subtitle: Text(
                  isFrontCamera ? 'Front' : 'Rear',
                  style: const TextStyle(color: Colors.white54),
                ),
                enabled: !isRecording,
                onTap: isRecording
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        onSwitchLens();
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.lock_rounded,
                  color: isRecording ? Colors.white : Colors.white38,
                ),
                title: const Text('Lock Current Clip'),
                subtitle: Text(
                  isRecording
                      ? 'Protects the active segment'
                      : 'Available only while recording',
                  style: const TextStyle(color: Colors.white54),
                ),
                enabled: isRecording,
                onTap: isRecording
                    ? () {
                        Navigator.of(sheetContext).pop();
                        onLock();
                      }
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                ),
                title: const Text('Open Gallery'),
                subtitle: const Text(
                  'Saved clips',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onOpenGallery();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.loop_rounded,
                  color: Colors.white,
                ),
                title: const Text('Loop Recording'),
                subtitle: Text(
                  loopRecordingMinutes == 0 ? 'Off (Save All)' : 'Last $loopRecordingMinutes Minutes',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChangeLoopRecording();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.all_inclusive_rounded,
                  color: Colors.white,
                ),
                title: const Text('Road Focus (Infinity)'),
                subtitle: const Text(
                  'Locks focus to the road, ignoring windshield & reflections',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: infinityFocus,
                onChanged: (val) {
                  onToggleInfinityFocus(val);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.layers_rounded,
                  color: Colors.white,
                ),
                title: const Text('Video Overlay'),
                subtitle: Text(
                  videoOverlayMode == 'subtitles'
                      ? 'Subtitles Track (No Heat)'
                      : (videoOverlayMode == 'burnin'
                          ? 'Burn-in on Video (High CPU)'
                          : 'Off (Disabled)'),
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChangeOverlayMode();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                ),
                title: const Text('Check for Updates'),
                subtitle: const Text(
                  'Check and install latest version from GitHub',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onCheckUpdates();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
