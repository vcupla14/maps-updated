import 'alert_type.dart';

class NavigationAlertContext {
  final bool isNavigating;
  final int? speedKmh;
  final bool inPedestrianZone;
  final String? pedestrianZoneType;
  final bool inNoOvertakingZone;

  const NavigationAlertContext({
    required this.isNavigating,
    required this.speedKmh,
    required this.inPedestrianZone,
    required this.pedestrianZoneType,
    required this.inNoOvertakingZone,
  });
}

class NavigationTypeLogic {
  static const int overspeedThresholdKmh = 20;

  static AlertType? resolveAlert(NavigationAlertContext context) {
    if (!context.isNavigating) return null;

    if ((context.speedKmh ?? 0) >= overspeedThresholdKmh) {
      return AlertType.overspeeding;
    }
    if (context.inPedestrianZone) {
      final zoneType = (context.pedestrianZoneType ?? 'pedestrians')
          .trim()
          .toLowerCase();
      switch (zoneType) {
        case 'church':
          return AlertType.churchZone;
        case 'school':
          return AlertType.schoolZone;
        case 'hospital':
          return AlertType.hospitalZone;
        case 'pedestrians':
        default:
          return AlertType.pedestrianCrossingZone;
      }
    }
    if (context.inNoOvertakingZone) {
      return AlertType.noOvertakingZone;
    }
    return null;
  }
}
