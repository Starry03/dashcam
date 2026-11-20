import 'package:flutter/material.dart';

Future<void> showQuickActionsSheet(
  BuildContext context, {
  required bool isFrontCamera,
  required bool isRecording,
  required bool infinityFocus,
  required String videoOverlayMode,
  required VoidCallback onSwitchLens,
  required ValueChanged<bool> onToggleInfinityFocus,
  required VoidCallback onChangeOverlayMode,
  required VoidCallback onOpenPhoneSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: const Color(0xF5080B0F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VEHICLE ARCHITECTURE',
                          style: TextStyle(
                            color: Color(0xFF87B8C6),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Dashcam controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(10),
                      side: BorderSide(color: Colors.white.withAlpha(18)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  const _ZoneTitle(
                    label: '01  FRONT OPTICS',
                    color: Color(0xFF75B8CA),
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: isFrontCamera
                        ? Icons.camera_front_rounded
                        : Icons.camera_rear_rounded,
                    title: 'Camera lens',
                    subtitle: isFrontCamera ? 'Front' : 'Rear',
                    enabled: !isRecording,
                    onTap: isRecording ? null : onSwitchLens,
                  ),
                  _SwitchCard(
                    icon: Icons.all_inclusive_rounded,
                    title: 'Road focus',
                    subtitle: 'Lock focus at infinity',
                    value: infinityFocus,
                    onChanged: onToggleInfinityFocus,
                  ),
                  _ActionCard(
                    icon: Icons.layers_rounded,
                    title: 'Video overlay',
                    subtitle: videoOverlayMode == 'subtitles'
                        ? 'Subtitles track'
                        : videoOverlayMode == 'burnin'
                        ? 'Burn-in telemetry'
                        : 'Off',
                    onTap: onChangeOverlayMode,
                  ),
                  const SizedBox(height: 22),
                  const _ZoneTitle(
                    label: '03  DEVICE',
                    color: Color(0xFFC1C7CA),
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Phone settings',
                    subtitle: 'Storage, updates and system',
                    onTap: onOpenPhoneSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showPhoneSettingsSheet(
  BuildContext context, {
  required int freeStorageMb,
  required String appVersion,
  required VoidCallback onCheckUpdates,
  required VoidCallback onOpenGallery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: const Color(0xF5080B0F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      final freeGb = freeStorageMb / 1024;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEVICE & SYSTEM',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Phone & App Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xCC151A20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOCAL STORAGE',
                          style: TextStyle(
                            color: Color(0xFF98A8AF),
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${freeGb.toStringAsFixed(1)} GB free',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.system_update_rounded,
                    title: 'Check for updates',
                    subtitle: 'Installed: $appVersion',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onCheckUpdates();
                    },
                  ),
                  _ActionCard(
                    icon: Icons.folder_open_rounded,
                    title: 'Open video folder',
                    subtitle: 'Movies / Dashcam',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onOpenGallery();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ZoneTitle extends StatelessWidget {
  const _ZoneTitle({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: enabled ? const Color(0xCC151A20) : const Color(0x7710151A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? Colors.white.withAlpha(18)
                    : Colors.white.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled ? const Color(0xFFB7C4CA) : Colors.white38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: enabled ? Colors.white54 : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: enabled ? Colors.white38 : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC151A20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF75B8CA)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
