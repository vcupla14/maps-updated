import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum AlertType {
  overspeeding,
  pedestrians,
  noOvertakingZone,
}

extension AlertTypeX on AlertType {
  String get title {
    switch (this) {
      case AlertType.overspeeding:
        return 'Warning: Overspeeding';
      case AlertType.pedestrians:
        return 'Reminder: Pedestrians Crossings';
      case AlertType.noOvertakingZone:
        return 'Reminder: No Overtaking Zone';
    }
  }

  String get subtitle {
    switch (this) {
      case AlertType.overspeeding:
        return 'Reduce Speed';
      case AlertType.pedestrians:
        return 'Slow Down';
      case AlertType.noOvertakingZone:
        return 'Do not overtake';
    }
  }

  Color get color {
    switch (this) {
      case AlertType.overspeeding:
        return const ui.Color.fromARGB(255, 211, 14, 0);
      case AlertType.pedestrians:
        return const ui.Color.fromARGB(255, 255, 238, 83);
      case AlertType.noOvertakingZone:
        return const ui.Color.fromARGB(255, 255, 164, 28);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.overspeeding:
        return Icons.warning_rounded;
      case AlertType.pedestrians:
        return Icons.directions_walk;
      case AlertType.noOvertakingZone:
        return Icons.do_not_disturb_on;
    }
  }
}
