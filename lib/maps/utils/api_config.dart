/// API Configuration for AVOID Maps Module
/// Contains all API endpoints and keys for external services
library;

class ApiConfig {
  // OpenStreetMap (OSM) - No API key required
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  
  // OSRM (Open Source Routing Machine) - Free routing service
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const String osrmRouteEndpoint = '/route/v1/driving';
  
  // OpenWeatherMap API (You need to register for free API key)
  // Sign up at: https://openweathermap.org/api
  static const String openWeatherApiKey = '792874a9880224b30b884c44090d0f05';
  static const String openWeatherBaseUrl = 'https://api.openweathermap.org/data/2.5';
  
  // Project NOAH (Philippines) - Flood Hazard Maps
  // Using publicly available GeoServer
  static const String noahGeoServerUrl = 'https://api.noah.dost.gov.ph/geoserver';
  static const String noahFloodHazardLayer = 'noah:flood_hazard_maps';
  
  // Nominatim (OSM Geocoding) - For address search
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // Google Places API (Text Search)
  static const String googlePlacesApiKey = 'AIzaSyBQGJdVhaOQZyXWg5X5l0NjvH6yc0--QEA';
  
  // Speed limits (in km/h)
  static const double maxSpeedLimit = 60.0;
  static const double schoolZoneSpeedLimit = 20.0;
  
  // Get complete OSRM route URL
  static String getOsrmRouteUrl(List<String> coordinates) {
    final coordString = coordinates.join(';');
    return '$osrmBaseUrl$osrmRouteEndpoint/$coordString?overview=full&geometries=geojson&steps=true&annotations=true';
  }
  
  // Get weather by coordinates
  static String getWeatherUrl(double lat, double lon) {
    return '$openWeatherBaseUrl/weather?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=metric';
  }
}
