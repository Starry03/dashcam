import 'package:flutter/material.dart';

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x2CC9A45A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66C9A45A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          if (onDismiss != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
