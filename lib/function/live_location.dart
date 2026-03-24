import 'package:geolocator/geolocator.dart';

class LiveLocation {
  final double latitude;
  final double longitude;

  const LiveLocation({
    required this.latitude,
    required this.longitude,
  });
}

class LiveLocationService {
  static Future<LiveLocation?> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LiveLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
