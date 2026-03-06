import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/destination_info.dart';
import 'osrm_service.dart';

class RouteFetchResult {
  final List<LatLng> polyline;
  final List<RouteStep> steps;
  final List<RouteLeg>? legs;

  const RouteFetchResult({
    required this.polyline,
    required this.steps,
    this.legs,
  });
}

class RouteFetchService {
  static Future<RouteFetchResult> fetchMultiStopRoute({
    required LatLng currentLocation,
    required List<DestinationInfo> destinations,
  }) async {
    try {
      final waypoints = [currentLocation, ...destinations.map((d) => d.location)];
      final routeResult = await OSRMService.getMultiStopRoute(
        waypoints,
        includeSteps: true,
      );

      if (routeResult != null) {
        return RouteFetchResult(
          polyline: routeResult.polyline,
          steps: routeResult.steps ?? [],
          legs: routeResult.legs,
        );
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }

    return RouteFetchResult(
      polyline: [currentLocation, ...destinations.map((d) => d.location)],
      steps: const [],
    );
  }

  static Future<List<RouteFetchResult>> fetchMultiStopRouteCandidates({
    required LatLng currentLocation,
    required List<DestinationInfo> destinations,
  }) async {
    try {
      final waypoints = [currentLocation, ...destinations.map((d) => d.location)];
      final routeResults = await OSRMService.getMultiStopRouteAlternatives(
        waypoints,
        includeSteps: true,
      );

      if (routeResults.isNotEmpty) {
        return routeResults
            .map(
              (route) => RouteFetchResult(
                polyline: route.polyline,
                steps: route.steps ?? [],
                legs: route.legs,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching route candidates: $e');
    }

    return const [];
  }

  static void applyLegsToDestinations({
    required List<RouteLeg> legs,
    required List<DestinationInfo> destinations,
  }) {
    for (int i = 0; i < legs.length && i < destinations.length; i++) {
      destinations[i].distanceKm = legs[i].distanceKm;
      destinations[i].durationMinutes = legs[i].durationMinutes;
    }
  }
}
