class Place {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? type;
  final String? placeClass;

  Place({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type,
    this.placeClass,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      displayName: json['display_name'] ?? '',
      latitude: double.parse(json['lat'] ?? '0'),
      longitude: double.parse(json['lon'] ?? '0'),
      type: json['type'],
      placeClass: json['class'],
    );
  }

  @override
  String toString() => displayName;
}