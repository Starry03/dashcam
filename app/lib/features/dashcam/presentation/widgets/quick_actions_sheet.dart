import 'package:flutter/material.dart';

/// Presents the quick-actions bottom sheet. Each action pops the sheet and then
/// invokes its callback; all business logic lives in the caller.
Future<void> showQuickActionsSheet(
  BuildContext context, {
  required bool isFrontCamera,
  required bool isRecording,
  required VoidCallback onSwitchLens,
  required VoidCallback onLock,
  required VoidCallback onOpenGallery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1D1D1D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            ],
          ),
        ),
      );
    },
  );
}
