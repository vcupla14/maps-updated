import 'package:latlong2/latlong.dart';

import '../models/destination_info.dart';
import 'osrm_service.dart';

class DestinationOrderingService {
  static Future<List<DestinationInfo>> reorderDestinations({
    required LatLng currentLocation,
    required List<DestinationInfo> destinations,
  }) async {
    if (destinations.isEmpty) return [];

    if (destinations.length == 1) {
      destinations[0].calculateDistanceFrom(currentLocation);
      return List<DestinationInfo>.from(destinations);
    }

    final points = [currentLocation, ...destinations.map((d) => d.location)];
    final matrix = await OSRMService.getDistanceMatrix(points);

    if (matrix == null) {
      return _sortByStraightLine(currentLocation, destinations);
    }

    final List<int> remainingIdx =
        List<int>.generate(destinations.length, (i) => i);
    final List<DestinationInfo> sorted = [];
    int currentIdx = 0; // index in matrix (0 = current location)

    while (remainingIdx.isNotEmpty) {
      int? bestDestIdx;
      double bestDistance = double.infinity;

      for (final destIdx in remainingIdx) {
        final matrixIdx = destIdx + 1;
        final dist = matrix.distances[currentIdx][matrixIdx];
        if (dist != null && dist < bestDistance) {
          bestDistance = dist;
          bestDestIdx = destIdx;
        }
      }

      if (bestDestIdx == null) break;
      final dest = destinations[bestDestIdx];
      final matrixIdx = bestDestIdx + 1;
      final duration = matrix.durations[currentIdx][matrixIdx];

      dest.distanceKm = (bestDistance / 1000);
      if (duration != null) {
        dest.durationMinutes = (duration / 60).round();
      }

      sorted.add(dest);
      remainingIdx.remove(bestDestIdx);
      currentIdx = matrixIdx;
    }

    return sorted;
  }

  static List<DestinationInfo> _sortByStraightLine(
    LatLng currentLocation,
    List<DestinationInfo> destinations,
  ) {
    final List<DestinationInfo> remaining = List.from(destinations);
    final List<DestinationInfo> sorted = [];
    LatLng fromPoint = currentLocation;

    while (remaining.isNotEmpty) {
      DestinationInfo? nearest;
      double minDistance = double.infinity;

      for (var dest in remaining) {
        const Distance distance = Distance();
        final dist =
            distance.as(LengthUnit.Kilometer, fromPoint, dest.location);
        if (dist < minDistance) {
          minDistance = dist;
          nearest = dest;
        }
      }

      if (nearest != null) {
        nearest.calculateDistanceFrom(fromPoint);
        sorted.add(nearest);
        remaining.remove(nearest);
        fromPoint = nearest.location;
      }
    }

    return sorted;
  }
}
