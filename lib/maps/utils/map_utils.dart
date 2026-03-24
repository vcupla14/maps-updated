import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

gmaps.LatLngBounds computeBounds(List<LatLng> points) {
  double? minLat, maxLat, minLng, maxLng;
  for (final p in points) {
    minLat = minLat == null ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
    maxLat = maxLat == null ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
    minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
    maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
  }
  return gmaps.LatLngBounds(
    southwest: gmaps.LatLng(minLat!, minLng!),
    northeast: gmaps.LatLng(maxLat!, maxLng!),
  );
}

String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.toStringAsFixed(0)} m';
}
