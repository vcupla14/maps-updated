import 'package:flutter/material.dart';

import '../models/alert_type.dart';

class AlertCard extends StatelessWidget {
  final AlertType type;
  final VoidCallback? onClose;
  final double height;

  const AlertCard({
    super.key,
    required this.type,
    this.onClose,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type.color;

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent,
          width: 3,
        ),
      ),
      child: Row(
        children: [
          Icon(
            type.icon,
            color: accent,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type.subtitle,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: accent,
              size: 18,
            ),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
