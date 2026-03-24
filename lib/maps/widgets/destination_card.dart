import 'package:flutter/material.dart';

/// Simple destination item showing just the destination name with remove button
class DestinationCard extends StatelessWidget {
  final String destinationName;
  final VoidCallback onRemove;
  final int destinationNumber;

  const DestinationCard({
    super.key,
    required this.destinationName,
    required this.onRemove,
    required this.destinationNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 2),
      child: Row(
        children: [
          // Destination number badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$destinationNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Destination name
          Expanded(
            child: Text(
              destinationName.split(',')[0], // Show only first part
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: Colors.white,
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
