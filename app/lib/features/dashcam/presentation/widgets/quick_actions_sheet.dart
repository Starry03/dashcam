import 'package:flutter/material.dart';

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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xCC151A20),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(18)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFFB7C4CA)),
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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
