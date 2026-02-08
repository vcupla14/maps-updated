import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/api_config.dart';

/// OSRM (Open Source Routing Machine) service for getting actual road routes
/// Uses the public OSRM demo server: https://router.project-osrm.org/
class OSRMService {
  static const String _baseUrl = ApiConfig.osrmBaseUrl;
  static const String _profile = 'driving';

  /// Get route between two points
  /// 
  /// Returns a RouteResult containing:
  /// - List of LatLng points for the polyline
  /// - Distance in meters
  /// - Duration in seconds
  /// 
  /// Example:
  /// ```dart
  /// final route = await OSRMService.getRoute(
  ///   start: LatLng(14.5995, 120.9842), // Manila
  ///   end: LatLng(13.4127, 121.1794),   // Calapan
  /// );
  /// print('Distance: ${route.distanceKm} km');
  /// print('Duration: ${route.durationMinutes} minutes');
  /// ```
  static Future<RouteResult?> getRoute({
    required LatLng start,
    required LatLng end,
    String profile = _profile, // driving, walking, cycling
    bool includeSteps = false,
  }) async {
    try {
      // Build OSRM route URL
      // Format: /route/v1/{profile}/{lon},{lat};{lon},{lat}
      final url = '$_baseUrl/route/v1/$profile/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson'
          '${includeSteps ? '&steps=true&annotations=true' : ''}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Extract geometry (polyline points)
          final coordinates = route['geometry']['coordinates'] as List;
          final polyline = coordinates
              .map((coord) => LatLng(
                    coord[1] as double, // lat
                    coord[0] as double, // lon
                  ))
              .toList();

          // Extract distance and duration
          final distanceMeters = route['distance'] as num;
          final durationSeconds = route['duration'] as num;

          final steps = includeSteps ? _parseRouteSteps(route) : null;

          return RouteResult(
            polyline: polyline,
            distanceMeters: distanceMeters.toDouble(),
            durationSeconds: durationSeconds.toDouble(),
            steps: steps,
          );
        }
      }

      return null;
    } catch (e) {
      print('OSRM Error: $e');
      return null;
    }
  }

  /// Snap a point to the nearest road using OSRM nearest service.
  /// Returns null if no road match is found.
  static Future<LatLng?> getNearestRoadPoint(
    LatLng point, {
    String profile = _profile,
  }) async {
    try {
      final url = '$_baseUrl/nearest/v1/$profile/'
          '${point.longitude},${point.latitude}'
          '?number=1';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['code'] != 'Ok') return null;
      final waypoints = data['waypoints'] as List<dynamic>? ?? [];
      if (waypoints.isEmpty) return null;

      final location = waypoints.first['location'] as List<dynamic>?;
      if (location == null || location.length < 2) return null;
      return LatLng(location[1] as double, location[0] as double);
    } catch (e) {
      print('OSRM Nearest Error: $e');
      return null;
    }
  }

  /// Get route passing through multiple waypoints
  /// 
  /// This is useful for multi-stop deliveries
  /// 
  /// Example:
  /// ```dart
  /// final route = await OSRMService.getMultiStopRoute([
  ///   LatLng(14.5995, 120.9842), // Manila
  ///   LatLng(14.6760, 121.0437), // Quezon City
  ///   LatLng(13.4127, 121.1794), // Calapan
  /// ]);
  /// ```
  static Future<RouteResult?> getMultiStopRoute(
    List<LatLng> waypoints, {
    String profile = _profile,
    bool includeSteps = false,
  }) async {
    if (waypoints.length < 2) {
      return null;
    }

    try {
      // Build coordinates string
      final coords = waypoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      final url = '$_baseUrl/route/v1/$profile/$coords'
          '?overview=full&geometries=geojson'
          '${includeSteps ? '&steps=true&annotations=true' : ''}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Extract geometry (polyline points)
          final coordinates = route['geometry']['coordinates'] as List;
          final polyline = coordinates
              .map((coord) => LatLng(
                    coord[1] as double, // lat
                    coord[0] as double, // lon
                  ))
              .toList();

          // Extract distance and duration
          final distanceMeters = route['distance'] as num;
          final durationSeconds = route['duration'] as num;

          // Extract leg information (distance/duration per segment)
          final legs = route['legs'] as List;
          final legDetails = legs.map((leg) {
            return RouteLeg(
              distanceMeters: (leg['distance'] as num).toDouble(),
              durationSeconds: (leg['duration'] as num).toDouble(),
            );
          }).toList();

          final steps = includeSteps ? _parseRouteSteps(route) : null;

          return RouteResult(
            polyline: polyline,
            distanceMeters: distanceMeters.toDouble(),
            durationSeconds: durationSeconds.toDouble(),
            legs: legDetails,
            steps: steps,
          );
        }
      }

      return null;
    } catch (e) {
      print('OSRM Multi-stop Error: $e');
      return null;
    }
  }

  /// Get multiple candidate routes for the same multi-stop trip.
  /// Uses OSRM alternatives and returns parsed candidates (best-first by OSRM).
  static Future<List<RouteResult>> getMultiStopRouteAlternatives(
    List<LatLng> waypoints, {
    String profile = _profile,
    bool includeSteps = false,
  }) async {
    if (waypoints.length < 2) {
      return const [];
    }

    try {
      final coords = waypoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      final url = '$_baseUrl/route/v1/$profile/$coords'
          '?overview=full&geometries=geojson&alternatives=true'
          '${includeSteps ? '&steps=true&annotations=true' : ''}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body);
      if (data['code'] != 'Ok' || data['routes'].isEmpty) return const [];

      final routes = data['routes'] as List<dynamic>;
      final results = <RouteResult>[];

      for (final routeEntry in routes) {
        final route = routeEntry as Map<String, dynamic>;
        final coordinates = route['geometry']['coordinates'] as List;
        final polyline = coordinates
            .map((coord) => LatLng(
                  coord[1] as double,
                  coord[0] as double,
                ))
            .toList();

        final distanceMeters = route['distance'] as num;
        final durationSeconds = route['duration'] as num;

        final legs = route['legs'] as List<dynamic>? ?? const [];
        final legDetails = legs.map((leg) {
          final legMap = leg as Map<String, dynamic>;
          return RouteLeg(
            distanceMeters: (legMap['distance'] as num).toDouble(),
            durationSeconds: (legMap['duration'] as num).toDouble(),
          );
        }).toList();

        final steps = includeSteps ? _parseRouteSteps(route) : null;

        results.add(
          RouteResult(
            polyline: polyline,
            distanceMeters: distanceMeters.toDouble(),
            durationSeconds: durationSeconds.toDouble(),
            legs: legDetails,
            steps: steps,
          ),
        );
      }

      return results;
    } catch (e) {
      print('OSRM Multi-stop Alternatives Error: $e');
      return const [];
    }
  }

  /// Get optimized route (TSP - Traveling Salesman Problem)
  /// 
  /// This reorders waypoints to find the shortest route
  /// Useful when you don't care about the order of stops
  /// 
  /// Example:
  /// ```dart
  /// final optimized = await OSRMService.getOptimizedRoute(
  ///   start: LatLng(14.5995, 120.9842),
  ///   waypoints: [
  ///     LatLng(14.6760, 121.0437),
  ///     LatLng(14.5547, 121.0244),
  ///   ],
  ///   end: LatLng(13.4127, 121.1794),
  /// );
  /// // Returns optimized order and route
  /// ```
  static Future<OptimizedRouteResult?> getOptimizedRoute({
    required LatLng start,
    required List<LatLng> waypoints,
    LatLng? end,
  }) async {
    if (waypoints.isEmpty) return null;

    try {
      // Build coordinates: start;waypoint1;waypoint2;...;end
      List<LatLng> allPoints = [start, ...waypoints];
      if (end != null) {
        allPoints.add(end);
      }

      final coords = allPoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      // Use OSRM trip service for optimization
      final url = '$_baseUrl/trip/v1/$_profile/$coords'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['trips'].isNotEmpty) {
          final trip = data['trips'][0];
          
          // Extract optimized waypoint order
          final waypointOrder = (trip['waypoint_order'] as List)
              .map((i) => i as int)
              .toList();

          // Extract geometry
          final coordinates = trip['geometry']['coordinates'] as List;
          final polyline = coordinates
              .map((coord) => LatLng(
                    coord[1] as double,
                    coord[0] as double,
                  ))
              .toList();

          final distanceMeters = trip['distance'] as num;
          final durationSeconds = trip['duration'] as num;

          return OptimizedRouteResult(
            polyline: polyline,
            distanceMeters: distanceMeters.toDouble(),
            durationSeconds: durationSeconds.toDouble(),
            optimizedOrder: waypointOrder,
          );
        }
      }

      return null;
    } catch (e) {
      print('OSRM Optimization Error: $e');
      return null;
    }
  }

  static List<RouteStep> _parseRouteSteps(Map<String, dynamic> route) {
    final steps = <RouteStep>[];
    final legs = route['legs'] as List<dynamic>? ?? [];

    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final legSteps = legMap['steps'] as List<dynamic>? ?? [];
      for (final step in legSteps) {
        final stepMap = step as Map<String, dynamic>;
        final maneuver = stepMap['maneuver'] as Map<String, dynamic>;
        final loc = maneuver['location'] as List<dynamic>;
        final name = (stepMap['name'] as String?)?.trim() ?? '';
        final instruction = _buildInstruction(
          maneuver['type'] as String?,
          maneuver['modifier'] as String?,
          name,
          maneuver['exit'] as int?,
        );

        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMeters: (stepMap['distance'] as num).toDouble(),
            location: LatLng(loc[1] as double, loc[0] as double),
            name: name,
            type: maneuver['type'] as String?,
            modifier: maneuver['modifier'] as String?,
          ),
        );
      }
    }

    return steps;
  }

  static String _buildInstruction(
    String? type,
    String? modifier,
    String name,
    int? exit,
  ) {
    final mod = (modifier ?? '').replaceAll('_', ' ').trim();
    switch (type) {
      case 'depart':
        if (name.isNotEmpty) return 'Head ${mod.isEmpty ? '' : '$mod '}on $name';
        return 'Head ${mod.isNotEmpty ? mod : 'straight'}';
      case 'turn':
        if (name.isNotEmpty) return 'Turn ${mod.isEmpty ? '' : '$mod '}onto $name';
        return 'Turn ${mod.isNotEmpty ? mod : ''}'.trim();
      case 'merge':
        if (name.isNotEmpty) return 'Merge ${mod.isEmpty ? '' : '$mod '}onto $name';
        return 'Merge ${mod.isNotEmpty ? mod : ''}'.trim();
      case 'roundabout':
        if (exit != null) return 'Enter roundabout, take exit $exit';
        return 'Enter roundabout';
      case 'continue':
        if (name.isNotEmpty) return 'Continue on $name';
        return 'Continue ${mod.isNotEmpty ? mod : 'straight'}';
      case 'arrive':
        return 'Arrive at your destination';
      default:
        if (name.isNotEmpty) return 'Continue on $name';
        return 'Continue';
    }
  }

  /// Distance & duration matrix (meters/seconds) for all points
  /// Returns null if OSRM table fails
  static Future<RouteMatrix?> getDistanceMatrix(
    List<LatLng> points, {
    String profile = _profile,
  }) async {
    if (points.length < 2) return null;

    try {
      final coords = points
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      final url = '$_baseUrl/table/v1/$profile/$coords'
          '?annotations=distance,duration';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['code'] != 'Ok') return null;

      final distances = (data['distances'] as List)
          .map((row) => (row as List).map((v) => (v as num?)?.toDouble()).toList())
          .toList();
      final durations = (data['durations'] as List)
          .map((row) => (row as List).map((v) => (v as num?)?.toDouble()).toList())
          .toList();

      return RouteMatrix(distances: distances, durations: durations);
    } catch (e) {
      print('OSRM Matrix Error: $e');
      return null;
    }
  }
}

/// Result from OSRM route query
class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteLeg>? legs;
  final List<RouteStep>? steps;

  RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.legs,
    this.steps,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
  
  @override
  String toString() => 
      'Route: ${distanceKm.toStringAsFixed(1)} km, $durationMinutes min';
}

/// Information about a leg (segment) of the route
class RouteLeg {
  final double distanceMeters;
  final double durationSeconds;

  RouteLeg({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
}

/// Turn-by-turn step info
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final LatLng location;
  final String name;
  final String? type;
  final String? modifier;

  RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.location,
    required this.name,
    required this.type,
    required this.modifier,
  });
}

/// Result from optimized route (TSP)
class OptimizedRouteResult extends RouteResult {
  final List<int> optimizedOrder;

  OptimizedRouteResult({
    required super.polyline,
    required super.distanceMeters,
    required super.durationSeconds,
    required this.optimizedOrder,
  });
}

class RouteMatrix {
  final List<List<double?>> distances;
  final List<List<double?>> durations;

  RouteMatrix({
    required this.distances,
    required this.durations,
  });
}
