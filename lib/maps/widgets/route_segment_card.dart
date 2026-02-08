import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math' as math;
import '../models/destination_info.dart';

class RouteSegmentCard extends StatelessWidget {
  final List<DestinationInfo> destinations;
  final String currentLocationName;

  const RouteSegmentCard({
    super.key,
    required this.destinations,
    required this.currentLocationName,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Container(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = math.max(200.0, constraints.maxWidth - 48);
          return MediaQuery.removePadding(
            context: context,
            child: destinations.length == 1
                ? Center(
                    child: _buildRouteCard(
                      context,
                      destination: destinations.first,
                      index: 0,
                      fromLabel: 'Your location',
                      toLabel: 'Search destination 1',
                      fromName: currentLocationName,
                      cardWidth: cardWidth,
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    itemCount: destinations.length,
                    separatorBuilder: (context, index) => _buildConnector(),
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      final fromLabel = index == 0
                          ? 'Your location'
                          : 'Search destination $index';
                      final toLabel = 'Search destination ${index + 1}';
                      final fromName = index == 0
                          ? currentLocationName
                          : destinations[index - 1].name;

                      return _buildRouteCard(
                        context,
                        destination: destination,
                        index: index,
                        fromLabel: fromLabel,
                        toLabel: toLabel,
                        fromName: fromName,
                        cardWidth: cardWidth,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildConnector() {
    return Center(
      child: Container(
        width: 47,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.red.shade300,
              Colors.red.shade500,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context, {
    required DestinationInfo destination,
    required int index,
    required String fromLabel,
    required String toLabel,
    required String fromName,
    required double cardWidth,
  }) {
    return Container(
      width: cardWidth,
      height: 64,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 216, 14, 14).withOpacity(0.65),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Destination number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Destination info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  '${fromName.split(',')[0]} \u2192 ${destination.name.split(',')[0]}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  minFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${destination.distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${destination.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
