import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationSyncService {
  LocationSyncService._();

  static final LocationSyncService instance = LocationSyncService._();

  Timer? _timer;
  String? _activeUserId;
  bool _isSyncing = false;

  bool get isRunning => _timer?.isActive ?? false;

  Future<void> start(
    String userId, {
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_activeUserId == userId && isRunning) return;

    await stop();
    _activeUserId = userId;

    await _syncOnce();
    _timer = Timer.periodic(interval, (_) {
      _syncOnce();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _activeUserId = null;
    _isSyncing = false;
  }

  Future<void> _syncOnce() async {
    if (_isSyncing || _activeUserId == null) return;

    _isSyncing = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await Supabase.instance.client.from('users').update({
        'last_seen_lat': position.latitude,
        'last_seen_lng': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', _activeUserId!);
    } catch (_) {
      // Keep silent: periodic sync should not crash or spam UI.
    } finally {
      _isSyncing = false;
    }
  }
}
