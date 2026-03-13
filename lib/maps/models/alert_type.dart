import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum AlertType {
  overspeeding,
  pedestrianCrossingZone,
  churchZone,
  schoolZone,
  hospitalZone,
  noOvertakingZone,
}

extension AlertTypeX on AlertType {
  String get title {
    switch (this) {
      case AlertType.overspeeding:
        return 'Warning: Overspeeding';
      case AlertType.pedestrianCrossingZone:
        return 'Slow Down : Pedestrian Crossings';
      case AlertType.churchZone:
        return 'Slow Down : Church Zone';
      case AlertType.schoolZone:
        return 'Slow Down : School Zone';
      case AlertType.hospitalZone:
        return 'Slow Down : Hospital Zone';
      case AlertType.noOvertakingZone:
        return 'Reminder: No Overtaking Zone';
    }
  }

  String get subtitle {
    switch (this) {
      case AlertType.overspeeding:
        return 'Reduce Speed';
      case AlertType.pedestrianCrossingZone:
        return '';
      case AlertType.churchZone:
        return '';
      case AlertType.schoolZone:
        return '';
      case AlertType.hospitalZone:
        return '';
      case AlertType.noOvertakingZone:
        return 'Do not overtake';
    }
  }

  Color get color {
    switch (this) {
      case AlertType.overspeeding:
        return const ui.Color.fromARGB(255, 211, 14, 0);
      case AlertType.pedestrianCrossingZone:
      case AlertType.churchZone:
      case AlertType.schoolZone:
      case AlertType.hospitalZone:
        return const ui.Color.fromARGB(255, 193, 116, 0);
      case AlertType.noOvertakingZone:
        return const ui.Color.fromARGB(255, 193, 116, 0);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.overspeeding:
        return Icons.warning_rounded;
      case AlertType.pedestrianCrossingZone:
        return Icons.directions_walk;
      case AlertType.churchZone:
        return Icons.account_balance;
      case AlertType.schoolZone:
        return Icons.school;
      case AlertType.hospitalZone:
        return Icons.local_hospital;
      case AlertType.noOvertakingZone:
        return Icons.do_not_disturb_on;
    }
  }
}
