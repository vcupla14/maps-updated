import 'alert_type.dart';

class NavigationAlertContext {
  final bool isNavigating;
  final int? speedKmh;
  final bool inPedestrianZone;
  final bool inNoOvertakingZone;

  const NavigationAlertContext({
    required this.isNavigating,
    required this.speedKmh,
    required this.inPedestrianZone,
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
      return AlertType.pedestrians;
    }
    if (context.inNoOvertakingZone) {
      return AlertType.noOvertakingZone;
    }
    return null;
  }
}
