import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place.dart';
import '../utils/api_config.dart';

class GooglePlacesService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';

  // Rough bounding box for the Philippines
  static const double _minLat = 4.5;
  static const double _maxLat = 21.5;
  static const double _minLon = 116.9;
  static const double _maxLon = 126.6;

  static Future<List<Place>> searchPlaces(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'key': ApiConfig.googlePlacesApiKey,
      'region': 'ph',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to search places: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;

    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') {
      final message = data['error_message'] ?? status ?? 'Unknown error';
      throw Exception('Places API error: $message');
    }

    final results = (data['results'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final places = results.map(_placeFromGoogleJson).where(_isInPhilippines);
    return places.take(limit).toList();
  }

  static Place _placeFromGoogleJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? '';
    final address = (json['formatted_address'] as String?) ?? '';
    final displayName = address.isNotEmpty && !address.contains(name)
        ? '$name, $address'
        : (address.isNotEmpty ? address : name);

    final location = (json['geometry']?['location'] as Map<String, dynamic>?);
    final lat = (location?['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (location?['lng'] as num?)?.toDouble() ?? 0.0;
    final types = (json['types'] as List<dynamic>?)?.cast<String>();

    return Place(
      displayName: displayName,
      latitude: lat,
      longitude: lng,
      type: types != null && types.isNotEmpty ? types.first : null,
      placeClass: null,
    );
  }

  static bool _isInPhilippines(Place place) {
    return place.latitude >= _minLat &&
        place.latitude <= _maxLat &&
        place.longitude >= _minLon &&
        place.longitude <= _maxLon;
  }
}
