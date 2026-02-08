import 'package:latlong2/latlong.dart';

class DestinationInfo {
  final LatLng location;
  final String name;
  double distanceKm;
  int durationMinutes;

  DestinationInfo({
    required this.location,
    required this.name,
    this.distanceKm = 0.0,
    this.durationMinutes = 0,
  });

  /// Calculate straight-line distance from another location (in kilometers)
  /// This is a simple haversine distance calculation
  void calculateDistanceFrom(LatLng from) {
    const Distance distance = Distance();
    distanceKm = distance.as(LengthUnit.Kilometer, from, location);
    
    // Rough estimate: average speed 30 km/h in city
    durationMinutes = (distanceKm / 30 * 60).round();
  }

  @override
  String toString() => name;
}
