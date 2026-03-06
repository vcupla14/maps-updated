import 'package:flutter_tts/flutter_tts.dart';
import '../models/alert_type.dart';

/// Voice service for step-by-step navigation and safety alerts.
class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> announceNavigation(String message) async {
    await _init();
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> announceSafetyAlert(AlertType type) async {
    await _init();
    final message = switch (type) {
      AlertType.overspeeding => 'Overspeeding, slow down',
      AlertType.pedestrians => 'Pedestrian crossing, slow down',
      AlertType.noOvertakingZone => 'No overtaking zone, do not overtake',
    };
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
