import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/destination_info.dart';
import 'osrm_service.dart';

class RouteFetchResult {
  final List<LatLng> polyline;
  final List<RouteStep> steps;
  final List<RouteLeg>? legs;
  final double distanceMeters;
  final double durationSeconds;

  const RouteFetchResult({
    required this.polyline,
    required this.steps,
    this.legs,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
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
          distanceMeters: routeResult.distanceMeters,
          durationSeconds: routeResult.durationSeconds,
        );
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }

    final fallbackPolyline = [
      currentLocation,
      ...destinations.map((d) => d.location),
    ];
    final fallbackDistanceMeters =
        _estimatePolylineDistanceMeters(fallbackPolyline);

    return RouteFetchResult(
      polyline: fallbackPolyline,
      steps: const [],
      distanceMeters: fallbackDistanceMeters,
      durationSeconds: fallbackDistanceMeters / (30 * 1000 / 3600),
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
                distanceMeters: route.distanceMeters,
                durationSeconds: route.durationSeconds,
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

  static double _estimatePolylineDistanceMeters(List<LatLng> polyline) {
    if (polyline.length < 2) return 0;

    const distance = Distance();
    var total = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
    }
    return total;
  }
}
