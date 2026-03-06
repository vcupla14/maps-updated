import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/profile_screen.dart';
import '../../main_screen/home_page_screen.dart';
import '../../parcels/parcel1.dart';
import '../../parcels/parcel_ongoing.dart';
import '../../parcels/parcel_ongoing_information.dart';
import '../../rules_and_violations/rules_and_violation_screen.dart';
import '../widgets/search_destination_sheet.dart';
import '../widgets/destination_card.dart';
import '../widgets/route_segment_card.dart';
import '../widgets/alert_card.dart';
import '../models/destination_info.dart';
import '../models/alert_type.dart';
import '../models/navigation_type.dart';
import '../services/destination_ordering_service.dart';
import '../services/osrm_service.dart';
import '../services/route_fetch_service.dart';
import '../services/voice_alert_service.dart';
import '../utils/map_styles.dart';
import '../utils/map_utils.dart';
import '../utils/api_config.dart';
import '../../function/live_location.dart';

class MapScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;
  final List<Map<String, dynamic>>? initialDestinations;
  final bool autoStartNavigation;

  const MapScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
    this.initialDestinations,
    this.autoStartNavigation = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<gmaps.GoogleMapController> _gmapsController = Completer();
  final VoiceAlertService _voiceAlertService = VoiceAlertService();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _recenterTimer;
  Timer? _programmaticMoveTimer;
  Timer? _weatherRefreshTimer;
  Timer? _alertAutoCloseTimer;
  Timer? _rawRenderTimer;

  int _selectedIndex = 1;

  bool _isNavigating = false;
  bool _hasDestination = false;
  bool _followUser = true;
  double _currentHeading = 0;
  bool _hasCompassHeading = false;
  bool _pendingResort = false;
  bool _programmaticMove = false;
  bool _suppressUserInteraction = false;
  double? _visualBearing;
  bool _snapInFlight = false;
  bool _isComputingRoute = false;
  bool _arrivalModalVisible = false;
  bool _arrivalHandlingInProgress = false;
  DateTime? _lastSnapAt;
  DateTime? _lastFollowCameraAt;
  double? _lastFollowCameraZoomCommand;
  bool _isRecenteringToFollow = false;
  DateTime? _lastProgressAt;
  gmaps.GoogleMapController? _mapController;
  gmaps.BitmapDescriptor? _navArrowIcon;
  bool _navArrowLoaded = false;
  bool _avoidFloodedAreas = false;
  String? _mapTypeSelection;
  double? _cameraZoom;
  static const double _navigationZoom = 19.2;
  static const Duration _followCameraMinInterval =
      Duration(milliseconds: 80);

  static const int _utmZoneNumber = 51;
  static const bool _utmNorthernHemisphere = true;
  static const double _floodInnerCircleRadiusMeters = 24;
  static const double _floodOuterCircleRadiusMeters = 52;
  static const int _maxVisibleFloodCircles = 600;

  List<LatLng> _floodPoints = [];
  List<gmaps.Circle> _floodCircles = [];
  bool _floodsLoaded = false;
  bool _floodsLoading = false;
  List<LatLng> _pedestrianZonePoints = [];
  bool _pedestrianZonesLoaded = false;
  bool _pedestrianZonesLoading = false;
  static const double _pedestrianAlertRadiusMeters = 120;
  List<LatLng> _noOvertakingZonePoints = [];
  bool _noOvertakingZonesLoaded = false;
  bool _noOvertakingZonesLoading = false;
  static const double _noOvertakingSamplingStepMeters = 35;
  static const double _noOvertakingAlertRadiusMeters = 90;
  final Set<gmaps.Marker> _weatherMarkers = {};
  final Map<String, gmaps.BitmapDescriptor> _weatherIconCache = {};
  final Map<String, String> _weatherConditionByPlace = {};
  bool _weatherLoading = false;
  DateTime? _weatherLastLoadedAt;
  static const Duration _weatherCacheTtl = Duration(minutes: 10);
  static const Duration _weatherRefreshInterval = Duration(minutes: 5);
  bool _rerouteInProgress = false;

  static const int _routeSampleStride = 6;
  static const double _floodHitDistanceMeters = 40;
  static const double _routeWeatherLinkMeters = 3500;

  /// Snapped location (for route progress)
  LatLng? _currentLocation;

  /// Raw GPS location (for arrow marker so it won't jump)
  LatLng? _rawLocation;
  LatLng? _displayRawLocation;
  LatLng? _rawRenderTarget;

  String _currentLocationName = "Your Location";

  final List<DestinationInfo> _destinations = [];
  List<LatLng> _routePolyline = [];
  List<RouteStep> _routeSteps = [];
  bool _initialDestinationsApplied = false;
  int _currentStepIndex = 0;
  double _distanceToNextStepMeters = 0;
  static const double _destinationArrivalThresholdMeters = 25.0;
  double? _currentSpeedMps;
  bool _inPedestrianZone = false;
  bool _inNoOvertakingZone = false;
  AlertType? _dismissedAlertType;
  AlertType? _autoCloseScheduledFor;
  AlertType? _lastSpokenAlertType;
  static const Duration _alertAutoCloseDelay = Duration(seconds: 4);
  static const Duration _overspeedLogCooldown = Duration(seconds: 3);
  DateTime? _lastOverspeedLogAt;
  bool _overspeedLogInFlight = false;
  String _riderFullName = '';

  // --- New: stable trimming/progress helpers ---
  int _lastTrimIdx = 0;
  int _routeTrimStartIdx = 0;
  static const int _trimSearchWindow = 60;
  static const double _trimDistanceThreshold = 25;

  double? _prevStepDistance;
  int _distanceIncreasingCount = 0;
  Position? _lastAcceptedGpsSample;
  double? _smoothedLat;
  double? _smoothedLng;
  bool _locationUpdateInFlight = false;
  Position? _queuedLocationSample;
  int _routeProgressIdx = 0;
  static const double _gpsSmoothingAlpha = 0.30;
  static const double _maxAcceptedGpsAccuracyMeters = 20.0;
  static const double _maxAcceptedSpeedMps = 45.0;
  static const Duration _maxAcceptedGpsAge = Duration(seconds: 4);
  static const int _routeMatchForwardWindow = 40;
  static const double _routeMatchMaxDistanceMeters = 35.0;
  static const double _navigationTrimLeadMeters = 12.0;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    if (widget.liveLat != null && widget.liveLng != null) {
      final seedLocation = LatLng(widget.liveLat!, widget.liveLng!);
      _rawLocation = seedLocation;
      _currentLocation = seedLocation;
    }
    _loadPedestrianZones();
    _loadNoOvertakingZones();
    _loadRiderFullName();
    _startWeatherAutoRefresh();
    unawaited(_applyInitialDestinationsIfAny());
    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_navArrowLoaded) {
      _navArrowLoaded = true;
      _loadNavArrowIcon();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _recenterTimer?.cancel();
    _programmaticMoveTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    _alertAutoCloseTimer?.cancel();
    _rawRenderTimer?.cancel();
    _voiceAlertService.stop();
    super.dispose();
  }

  void _startWeatherAutoRefresh() {
    _weatherRefreshTimer?.cancel();
    _weatherRefreshTimer = Timer.periodic(_weatherRefreshInterval, (_) {
      if (!mounted) return;
      if (_mapTypeSelection == 'weather' || _avoidFloodedAreas) {
        _loadWeatherMarkers(force: true).then((_) {
          _maybeApplyFloodWeatherReroute(force: true);
        });
      }
    });
  }

  Future<void> _loadNavArrowIcon() async {
    const targetSize = 140;
    final data =
        await DefaultAssetBundle.of(context).load('assets/images/nav_arrow.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 90,
      targetHeight: 90,
    );
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble()),
    );

    // White70 circle background
    final circlePaint = ui.Paint()
      ..color = const ui.Color(0xB3FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(
      ui.Offset(targetSize / 2, targetSize / 2),
      targetSize / 2,
      circlePaint,
    );

    // Draw arrow image centered
    final arrow = frame.image;
    final dx = (targetSize - arrow.width) / 2;
    final dy = (targetSize - arrow.height) / 2;
    canvas.drawImage(arrow, ui.Offset(dx, dy), ui.Paint());

    final image = await recorder
        .endRecording()
        .toImage(targetSize, targetSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final icon = gmaps.BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    if (!mounted) return;
    setState(() => _navArrowIcon = icon);
  }

  // ================= LOCATION =================

  Future<void> _getCurrentLocation() async {
    final position = await LiveLocationService.getCurrent();
    if (position == null) return;

    if (!mounted) return;

    final raw = LatLng(position.latitude, position.longitude);
    _rawLocation = raw;
    _smoothedLat = raw.latitude;
    _smoothedLng = raw.longitude;

    final snapped = await _snapToRoad(raw) ?? raw;

    if (!mounted) return;

    setState(() {
      _currentLocation = snapped;
      _displayRawLocation = snapped;
    });
    _rawRenderTarget = snapped;
    _startRawRenderLoop();
    unawaited(_applyInitialDestinationsIfAny());

    _animateCameraTo(_currentLocation!, 15);

    _positionSub?.cancel();
    final LocationSettings locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
            intervalDuration: const Duration(seconds: 1),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
          );
    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((pos) {
      if (!mounted) return;

      if (!_hasCompassHeading) {
        final heading = pos.heading;
        if (!heading.isNaN && heading >= 0) {
          _currentHeading = heading;
        }
      }
      _currentSpeedMps = (pos.speed.isNaN || pos.speed < 0) ? null : pos.speed;

      final rawNow = LatLng(pos.latitude, pos.longitude);
      _rawLocation = rawNow;
      if (!_isNavigating && _currentLocation == null) {
        _currentLocation = rawNow;
      }
      _enqueueLocationSample(pos);
    });

    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading == null || heading.isNaN) return;
      _hasCompassHeading = true;
      _currentHeading = heading;
      if (_isNavigating && _followUser) {
        _applyFollowCamera();
      }
    });
  }

  void _setRawLocationAnimated(LatLng target) {
    _rawRenderTarget = target;
    _startRawRenderLoop();

    if (_displayRawLocation == null) {
      if (!mounted) return;
      setState(() => _displayRawLocation = target);
      if (_isNavigating && _followUser) _applyFollowCamera();
      return;
    }
  }

  void _enqueueLocationSample(Position sample) {
    _queuedLocationSample = sample;
    if (_locationUpdateInFlight) return;
    unawaited(_drainLocationSamples());
  }

  Future<void> _drainLocationSamples() async {
    _locationUpdateInFlight = true;
    try {
      while (mounted && _queuedLocationSample != null) {
        final next = _queuedLocationSample!;
        _queuedLocationSample = null;
        final raw = LatLng(next.latitude, next.longitude);
        await _processSnappedLocationUpdate(raw, sample: next);
      }
    } finally {
      _locationUpdateInFlight = false;
    }
  }

  void _startRawRenderLoop() {
    if (_rawRenderTimer?.isActive == true) return;
    _rawRenderTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      final target = _rawRenderTarget;
      if (target == null) return;

      final current = _displayRawLocation;
      if (current == null) {
        setState(() => _displayRawLocation = target);
        return;
      }

      final gapMeters = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );

      // Snap when already very close; otherwise smoothly approach target.
      if (gapMeters < 0.35) {
        if ((current.latitude - target.latitude).abs() > 1e-7 ||
            (current.longitude - target.longitude).abs() > 1e-7) {
          setState(() => _displayRawLocation = target);
        }
      } else {
        final alpha = gapMeters > 12
            ? 0.55
            : gapMeters > 5
                ? 0.35
                : 0.22;
        final blended = LatLng(
          current.latitude + (target.latitude - current.latitude) * alpha,
          current.longitude + (target.longitude - current.longitude) * alpha,
        );
        setState(() => _displayRawLocation = blended);
      }

      if (_isNavigating && _followUser) _applyFollowCamera();
    });
  }

  Future<void> _processSnappedLocationUpdate(
    LatLng rawNow, {
    Position? sample,
  }) async {
    if (sample != null && !_isGoodGpsSample(sample, _lastAcceptedGpsSample)) {
      return;
    }
    if (sample != null) {
      _lastAcceptedGpsSample = sample;
    }

    final filteredRaw = _smoothRawPoint(rawNow);
    LatLng nextLocation = filteredRaw;

    if (_isNavigating && _routePolyline.length >= 2) {
      final projection = _projectToForwardRouteSegment(
        filteredRaw,
        startIdx: _routeProgressIdx,
        forwardWindow: _routeMatchForwardWindow,
      );
      if (projection != null &&
          projection.distanceMeters <= _routeMatchMaxDistanceMeters) {
        nextLocation = projection.point;
        _routeProgressIdx = math.max(_routeProgressIdx, projection.segmentIndex);
      } else {
        nextLocation = await _snapToRoad(filteredRaw) ?? filteredRaw;
      }
    } else {
      nextLocation = await _snapToRoad(filteredRaw) ?? filteredRaw;
    }

    if (!mounted) return;
    setState(() => _currentLocation = nextLocation);
    _setRawLocationAnimated(nextLocation);

    if (_isNavigating) {
      _trimRoutePolyline();
      _updateNavigationProgress();
      if (_followUser) _applyFollowCamera();
    } else {
      unawaited(_applyInitialDestinationsIfAny());
    }

    if (_pendingResort && !_isNavigating) {
      _pendingResort = false;
      _rebuildDestinationOrder();
      _fetchRoute();
    }

    _updateNavigationZoneFlags();
    _syncAlertDismissState();
    _syncVoiceSafetyAlert();
  }

  // ================= NAV =================

  double? get _activeLat => _rawLocation?.latitude ?? widget.liveLat;
  double? get _activeLng => _rawLocation?.longitude ?? widget.liveLng;

  void _navigateWithTransition(Widget page, int index) {
    if (index == _selectedIndex) return;
    final bool slideLeft = index < _selectedIndex;
    setState(() => _selectedIndex = index);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) {
          final slideAnimation = Tween<Offset>(
            begin: Offset(slideLeft ? -0.15 : 0.15, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
          );

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openParcelsWithTransition() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => ParcelsPage(userId: widget.userId, liveLat: _activeLat, liveLng: _activeLng),
        transitionsBuilder: (_, animation, __, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
          );

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_isNavigating) {
      return;
    }

    switch (index) {
      case 0:
        _navigateWithTransition(
          HomePageScreen(
            userId: widget.userId,
            liveLat: _activeLat,
            liveLng: _activeLng,
          ),
          index,
        );
        break;
      case 4:
        _navigateWithTransition(
          ProfileScreen(
            userId: widget.userId,
            liveLat: _activeLat,
            liveLng: _activeLng,
          ),
          index,
        );
        break;
      case 2:
        _navigateWithTransition(
          RulesAndViolationScreen(
            userId: widget.userId,
            liveLat: _activeLat,
            liveLng: _activeLng,
          ),
          index,
        );
        break;
      case 3:
        _openParcelsWithTransition();
        break;
    }
  }

  void _startNavigation() {
    if (_routeSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No step-by-step route available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _currentStepIndex = 0;
    _distanceToNextStepMeters = 0;

    // reset trim/progress trackers
    _lastTrimIdx = 0;
    _routeTrimStartIdx = 0;
    _routeProgressIdx = 0;
    _prevStepDistance = null;
    _distanceIncreasingCount = 0;
    final seed = _currentLocation ?? _displayRawLocation ?? _rawLocation;
    if (seed != null && _routePolyline.length >= 2) {
      final seedProjection = _projectToForwardRouteSegment(
        seed,
        startIdx: 0,
        forwardWindow: _routePolyline.length - 2,
      );
      if (seedProjection != null) {
        _routeProgressIdx = seedProjection.segmentIndex;
      }
    }

    setState(() {
      _isNavigating = true;
      _dismissedAlertType = null;
      _lastSpokenAlertType = null;
      _visualBearing = null;
    });
    _updateNavigationZoneFlags();
    _syncVoiceSafetyAlert();
    _followUser = true;
    _cameraZoom = _navigationZoom;
    _applyMapStyle(navigation: true);

    _voiceAlertService.announceNavigation(_routeSteps.first.instruction);
    if (_rawLocation != null) {
      setState(() {
        _currentLocation = _displayRawLocation ?? _rawLocation;
      });
      _applyFollowCamera(zoomOverride: _navigationZoom, force: true);
      _updateNavigationProgress();
    } else if (_currentLocation != null) {
      _applyFollowCamera(zoomOverride: _navigationZoom, force: true);
      _updateNavigationProgress();
    }

    
  }

  void _endNavigation() {
    setState(() {
      _isNavigating = false;
      _dismissedAlertType = null;
      _lastSpokenAlertType = null;
      _arrivalModalVisible = false;
      _arrivalHandlingInProgress = false;
      _visualBearing = null;
    });
    _cancelAlertAutoClose();
    _followUser = false;
    _applyMapStyle(navigation: false);
    _voiceAlertService.stop();

    // reset trackers
    _lastTrimIdx = 0;
    _routeTrimStartIdx = 0;
    _routeProgressIdx = 0;
    _prevStepDistance = null;
    _distanceIncreasingCount = 0;

    if (_currentLocation != null) {
      if (_destinations.isNotEmpty) {
        final points = <LatLng>[
          _currentLocation!,
          ..._destinations.map((d) => d.location),
        ];
        _fitBounds(points);
      } else {
        _animateCameraTo(_currentLocation!, _cameraZoom ?? 17,
            tilt: 0, bearing: 0);
      }
    }

    
  }

  int? _extractParcelId(DestinationInfo destination) {
    if (destination.parcelId != null) return destination.parcelId;
    final match = RegExp(r'Parcel\s*#(\d+)', caseSensitive: false)
        .firstMatch(destination.name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _handleReachedDestination() async {
    final navPosition = _displayRawLocation ?? _currentLocation ?? _rawLocation;
    if (!_isNavigating ||
        navPosition == null ||
        _destinations.isEmpty ||
        _arrivalModalVisible ||
        _arrivalHandlingInProgress) {
      return;
    }

    final target = _destinations.first;
    final distance = Geolocator.distanceBetween(
      navPosition.latitude,
      navPosition.longitude,
      target.location.latitude,
      target.location.longitude,
    );
    if (distance > _destinationArrivalThresholdMeters) return;

    _arrivalHandlingInProgress = true;
    final completedParcelId = _extractParcelId(target);

    if (mounted) {
      setState(() {
        _destinations.removeAt(0);
        _routePolyline = [];
        _routeTrimStartIdx = 0;
        _routeProgressIdx = 0;
        _routeSteps = [];
        _currentStepIndex = 0;
        _distanceToNextStepMeters = 0;
      });
    }

    final hasNextDestination = _destinations.isNotEmpty;
    if (hasNextDestination) {
      if (mounted) setState(() => _isComputingRoute = true);
      try {
        await _rebuildDestinationOrder();
        await _fetchRoute();
      } finally {
        if (mounted) setState(() => _isComputingRoute = false);
      }
      if (mounted && _routeSteps.isNotEmpty) {
        _voiceAlertService.announceNavigation(_routeSteps.first.instruction);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _hasDestination = false;
        });
      }
      _followUser = false;
      _applyMapStyle(navigation: false);
      _voiceAlertService.stop();
    }

    _arrivalModalVisible = true;
    await _showRideCompletedModal(
      completedParcelId: completedParcelId,
      showContinue: hasNextDestination,
    );
    _arrivalModalVisible = false;
    _arrivalHandlingInProgress = false;
  }

  Future<void> _showRideCompletedModal({
    required int? completedParcelId,
    required bool showContinue,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFF0000),
                Color(0xFF800000),
              ],
              stops: [0.0, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ride completed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _endNavigation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 8,
                  shadowColor: Colors.black45,
                ),
                child: const Text(
                  'Go back to Maps',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showContinue) const SizedBox(height: 8),
              if (showContinue)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _followUser = true;
                    if (_routeSteps.isNotEmpty) {
                      _voiceAlertService
                          .announceNavigation(_routeSteps.first.instruction);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 8,
                    shadowColor: Colors.black45,
                  ),
                  child: const Text(
                    'Continue to the next Destination',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (completedParcelId == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParcelOngoingPage(
                          userId: widget.userId,
                          liveLat: _activeLat,
                          liveLng: _activeLng,
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParcelOngoingInformationPage(
                        parcelId: completedParcelId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 8,
                  shadowColor: Colors.black45,
                ),
                child: const Text(
                  'Deliver Parcel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMapTypeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final height = MediaQuery.of(context).size.height * (1 / 4);
            return Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFF800000),
                  ],
                  stops: [0.0, 1.0],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: 16, left: 16, right: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Map Function',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              InkWell(
                                onTap: () {
                                  String? nextSelection;
                                  setModalState(() {
                                    nextSelection = _mapTypeSelection == 'floods'
                                        ? null
                                        : 'floods';
                                    _mapTypeSelection = nextSelection;
                                  });
                                  setState(() => _mapTypeSelection = nextSelection);
                                  if (nextSelection == 'floods' &&
                                      _floodCircles.isEmpty) {
                                    _loadFloodProneAreas();
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                          _mapTypeSelection == 'floods'
                                              ? 1
                                              : 0.5),
                                      width:
                                          _mapTypeSelection == 'floods'
                                              ? 2
                                              : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Image.asset(
                                      'assets/images/floods_icon.png',
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Floods',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  String? nextSelection;
                                  setModalState(() {
                                    nextSelection = _mapTypeSelection == 'weather'
                                        ? null
                                        : 'weather';
                                    _mapTypeSelection = nextSelection;
                                  });
                                  setState(() => _mapTypeSelection = nextSelection);
                                  if (nextSelection == 'weather') {
                                    _loadWeatherMarkers();
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                          _mapTypeSelection == 'weather'
                                              ? 1
                                              : 0.5),
                                      width:
                                          _mapTypeSelection == 'weather'
                                              ? 2
                                              : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Image.asset(
                                      'assets/images/weather_icon.png',
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Weather',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Avoid Real-Time Flooded Areas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  final nextValue = !_avoidFloodedAreas;
                                  setModalState(() {
                                    _avoidFloodedAreas = nextValue;
                                  });
                                  setState(() => _avoidFloodedAreas = nextValue);
                                  if (nextValue) {
                                    _maybeApplyFloodWeatherReroute(force: true);
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeInOut,
                                  width: 48,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _avoidFloodedAreas
                                        ? const ui.Color.fromARGB(255, 75, 0, 0)
                                        : Colors.white70,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeInOut,
                                    alignment: _avoidFloodedAreas
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadFloodProneAreas() async {
    if (_floodsLoaded || _floodsLoading) return;
    _floodsLoading = true;
    try {
      final csv = await rootBundle.loadString(
        'floods_datasets/rizal_floodprone_areas.csv',
      );
      final lines = csv.split(RegExp(r'\r?\n'));
      final points = <LatLng>[];
      int idx = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (idx == 0 && trimmed.toLowerCase().startsWith('x,')) {
          idx++;
          continue;
        }
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final easting = double.tryParse(parts[0]);
        final northing = double.tryParse(parts[1]);
        if (easting == null || northing == null) continue;

        final latLng = _utmToLatLng(
          easting,
          northing,
          _utmZoneNumber,
          _utmNorthernHemisphere,
        );

        points.add(latLng);
        idx++;
      }

      if (!mounted) return;
      setState(() {
        _floodPoints = points;
        _floodsLoaded = true;
        _floodsLoading = false;
      });
      _refreshVisibleFloodCircles();
    } catch (_) {
      _floodsLoading = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load flood data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshVisibleFloodCircles() async {
    if (_mapController == null) return;
    if (!_floodsLoaded || _floodPoints.isEmpty) return;
    if (_mapTypeSelection != 'floods') return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoom = _cameraZoom ?? 14.0;
    final config = _floodRenderConfig(zoom);
    if (config.maxPoints <= 0) {
      if (!mounted) return;
      if (_floodCircles.isNotEmpty) {
        setState(() => _floodCircles = []);
      }
      return;
    }

    final visibleCircles = <gmaps.Circle>[];
    final usedCells = <String>{};
    int idx = 0;
    int selectedPoints = 0;

    for (final point in _floodPoints) {
      if (!_isWithinBounds(point, bounds)) {
        idx++;
        continue;
      }

      final cellKey = _floodCellKey(point, config.cellSizeDeg);
      if (!usedCells.add(cellKey)) {
        idx++;
        continue;
      }

      visibleCircles.add(
        gmaps.Circle(
          circleId: gmaps.CircleId('flood_outer_$idx'),
          center: gmaps.LatLng(point.latitude, point.longitude),
          radius: _floodOuterCircleRadiusMeters,
          fillColor: Colors.red.withOpacity(0.25),
          strokeColor: Colors.transparent,
          strokeWidth: 0,
        ),
      );
      if (config.showInnerCircle) {
        visibleCircles.add(
          gmaps.Circle(
            circleId: gmaps.CircleId('flood_inner_$idx'),
            center: gmaps.LatLng(point.latitude, point.longitude),
            radius: _floodInnerCircleRadiusMeters,
            fillColor: Colors.red,
            strokeColor: Colors.transparent,
            strokeWidth: 0,
          ),
        );
      }

      idx++;
      selectedPoints++;
      if (selectedPoints >= config.maxPoints ||
          visibleCircles.length >= _maxVisibleFloodCircles) {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _floodCircles = visibleCircles;
    });
  }

  _FloodRenderConfig _floodRenderConfig(double zoom) {
    if (zoom < 12.0) {
      return const _FloodRenderConfig(
        maxPoints: 0,
        cellSizeDeg: 0.0,
        showInnerCircle: false,
      );
    }
    if (zoom < 13.0) {
      return const _FloodRenderConfig(
        maxPoints: 60,
        cellSizeDeg: 0.0045,
        showInnerCircle: false,
      );
    }
    if (zoom < 14.0) {
      return const _FloodRenderConfig(
        maxPoints: 100,
        cellSizeDeg: 0.0030,
        showInnerCircle: false,
      );
    }
    if (zoom < 15.0) {
      return const _FloodRenderConfig(
        maxPoints: 150,
        cellSizeDeg: 0.0020,
        showInnerCircle: false,
      );
    }
    if (zoom < 16.0) {
      return const _FloodRenderConfig(
        maxPoints: 220,
        cellSizeDeg: 0.0015,
        showInnerCircle: true,
      );
    }
    if (zoom < 17.0) {
      return const _FloodRenderConfig(
        maxPoints: 300,
        cellSizeDeg: 0.0010,
        showInnerCircle: true,
      );
    }
    return const _FloodRenderConfig(
      maxPoints: 420,
      cellSizeDeg: 0.0007,
      showInnerCircle: true,
    );
  }

  String _floodCellKey(LatLng point, double cellSizeDeg) {
    final x = (point.latitude / cellSizeDeg).floor();
    final y = (point.longitude / cellSizeDeg).floor();
    return '$x:$y';
  }

  bool _isWithinBounds(LatLng point, gmaps.LatLngBounds bounds) {
    final lat = point.latitude;
    final lng = point.longitude;
    final south = bounds.southwest.latitude;
    final north = bounds.northeast.latitude;
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;

    final withinLat = lat >= south && lat <= north;
    if (west <= east) {
      return withinLat && lng >= west && lng <= east;
    }
    return withinLat && (lng >= west || lng <= east);
  }

  Future<void> _loadWeatherMarkers({bool force = false}) async {
    if (_weatherLoading) return;
    if (!force &&
        _weatherLastLoadedAt != null &&
        DateTime.now().difference(_weatherLastLoadedAt!) < _weatherCacheTtl &&
        _weatherMarkers.isNotEmpty) {
      return;
    }

    _weatherLoading = true;
    final markers = <gmaps.Marker>{};
    final conditions = <String, String>{};

    try {
      for (final place in _priorityBarangayWeatherPlaces) {
        final weather = await _fetchWeatherAt(place.latitude, place.longitude);
        if (weather == null) continue;
        conditions[place.name] = weather.condition;

        final iconDescriptor = await _resolveWeatherIcon(weather.iconCode);
        for (int i = 0; i < _weatherDisplayOffsetsMeters.length; i++) {
          final offset = _weatherDisplayOffsetsMeters[i];
          final position = _offsetByMeters(
            place,
            northMeters: offset.dy,
            eastMeters: offset.dx,
          );
          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('weather_${place.name}_$i'),
              position: gmaps.LatLng(position.latitude, position.longitude),
              icon: iconDescriptor,
              infoWindow: gmaps.InfoWindow(
                title: place.name,
                snippet: weather.condition,
              ),
              zIndex: 3,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _weatherMarkers
          ..clear()
          ..addAll(markers);
        _weatherConditionByPlace
          ..clear()
          ..addAll(conditions);
        _weatherLastLoadedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load weather data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _weatherLoading = false;
    }
  }

  Future<_WeatherInfo?> _fetchWeatherAt(double lat, double lon) async {
    final uri = Uri.parse(ApiConfig.getWeatherUrl(lat, lon));
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final weatherList = data['weather'];
    if (weatherList is! List || weatherList.isEmpty) return null;
    final weather = weatherList.first as Map<String, dynamic>;
    final iconCode = (weather['icon'] ?? '').toString().trim();
    final condition = (weather['description'] ?? '').toString().trim();
    if (iconCode.isEmpty) return null;

    return _WeatherInfo(
      iconCode: iconCode,
      condition: condition.isEmpty ? 'No status' : condition,
    );
  }

  Future<gmaps.BitmapDescriptor> _resolveWeatherIcon(String iconCode) async {
    final cached = _weatherIconCache[iconCode];
    if (cached != null) return cached;

    try {
      final url = Uri.parse('https://openweathermap.org/img/wn/$iconCode@2x.png');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isNotEmpty) {
          final icon = await _bitmapDescriptorFromPng(bytes, 86);
          _weatherIconCache[iconCode] = icon;
          return icon;
        }
      }
    } catch (_) {}

    return gmaps.BitmapDescriptor.defaultMarkerWithHue(
      gmaps.BitmapDescriptor.hueAzure,
    );
  }

  Future<gmaps.BitmapDescriptor> _bitmapDescriptorFromPng(
    Uint8List bytes,
    int targetPx,
  ) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (targetPx * 0.74).round(),
      targetHeight: (targetPx * 0.74).round(),
    );
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetPx.toDouble(), targetPx.toDouble()),
    );

    final bgPaint = ui.Paint()
      ..color = const ui.Color(0x66FF6B6B)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(
      ui.Offset(targetPx / 2, targetPx / 2),
      targetPx / 2,
      bgPaint,
    );

    final iconImage = frame.image;
    final dx = (targetPx - iconImage.width) / 2;
    final dy = (targetPx - iconImage.height) / 2;
    canvas.drawImage(iconImage, ui.Offset(dx, dy), ui.Paint());

    final image = await recorder.endRecording().toImage(targetPx, targetPx);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return gmaps.BitmapDescriptor.defaultMarkerWithHue(
        gmaps.BitmapDescriptor.hueAzure,
      );
    }
    return gmaps.BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }

  _WeatherPlace _offsetByMeters(
    _WeatherPlace base, {
    required double northMeters,
    required double eastMeters,
  }) {
    const metersPerDegreeLat = 111320.0;
    final latRad = base.latitude * math.pi / 180.0;
    final metersPerDegreeLon = metersPerDegreeLat * math.cos(latRad);
    final lat = base.latitude + (northMeters / metersPerDegreeLat);
    final lon = base.longitude + (eastMeters / metersPerDegreeLon);
    return _WeatherPlace(name: base.name, latitude: lat, longitude: lon);
  }

  LatLng _utmToLatLng(
    double easting,
    double northing,
    int zoneNumber,
    bool isNorthernHemisphere,
  ) {
    const double a = 6378137.0;
    const double eccSquared = 0.00669438;
    const double k0 = 0.9996;

    double x = easting - 500000.0;
    double y = northing;
    if (!isNorthernHemisphere) {
      y -= 10000000.0;
    }

    final double eccPrimeSquared = eccSquared / (1 - eccSquared);
    final double m = y / k0;
    final double mu = m /
        (a *
            (1 -
                eccSquared / 4 -
                3 * eccSquared * eccSquared / 64 -
                5 * eccSquared * eccSquared * eccSquared / 256));

    final double e1 = (1 - math.sqrt(1 - eccSquared)) /
        (1 + math.sqrt(1 - eccSquared));

    final double phi1Rad = mu +
        (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) *
            math.sin(4 * mu) +
        (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
        (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);

    final double n1 = a / math.sqrt(1 - eccSquared * math.sin(phi1Rad) * math.sin(phi1Rad));
    final double t1 = math.tan(phi1Rad) * math.tan(phi1Rad);
    final double c1 = eccPrimeSquared * math.cos(phi1Rad) * math.cos(phi1Rad);
    final double r1 = a *
        (1 - eccSquared) /
        math.pow(1 - eccSquared * math.sin(phi1Rad) * math.sin(phi1Rad), 1.5);
    final double d = x / (n1 * k0);

    double lat = phi1Rad -
        (n1 * math.tan(phi1Rad) / r1) *
            (d * d / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * eccPrimeSquared) *
                    math.pow(d, 4) /
                    24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * eccPrimeSquared -
                        3 * c1 * c1) *
                    math.pow(d, 6) /
                    720);

    double lon = (d -
            (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
            (5 -
                    2 * c1 +
                    28 * t1 -
                    3 * c1 * c1 +
                    8 * eccPrimeSquared +
                    24 * t1 * t1) *
                math.pow(d, 5) /
                120) /
        math.cos(phi1Rad);

    final double longOrigin = (zoneNumber - 1) * 6 - 180 + 3;
    lon = _degreesToRadians(longOrigin) + lon;

    return LatLng(_radiansToDegrees(lat), _radiansToDegrees(lon));
  }

  double _degreesToRadians(double deg) => deg * (math.pi / 180.0);
  double _radiansToDegrees(double rad) => rad * (180.0 / math.pi);

  // ================= DESTINATION HANDLING =================

  Future<void> _applyInitialDestinationsIfAny() async {
    if (_initialDestinationsApplied) return;
    final raw = widget.initialDestinations;
    if (raw == null || raw.isEmpty) return;
    if (_currentLocation == null) return;

    final seeded = <DestinationInfo>[];
    for (final item in raw) {
      final lat = (item['lat'] is num)
          ? (item['lat'] as num).toDouble()
          : double.tryParse(item['lat']?.toString() ?? '');
      final lng = (item['lng'] is num)
          ? (item['lng'] as num).toDouble()
          : double.tryParse(item['lng']?.toString() ?? '');
      final name = (item['name'] ?? '').toString().trim();
      final parcelId = (item['parcel_id'] is num)
          ? (item['parcel_id'] as num).toInt()
          : int.tryParse(item['parcel_id']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      seeded.add(
        DestinationInfo(
          location: LatLng(lat, lng),
          name: name.isEmpty ? 'Destination' : name,
          parcelId: parcelId,
        ),
      );
    }

    _initialDestinationsApplied = true;
    if (seeded.isEmpty) return;

    setState(() {
      _destinations
        ..clear()
        ..addAll(seeded);
      _hasDestination = true;
    });

    if (mounted) {
      setState(() => _isComputingRoute = true);
    }
    try {
      await _rebuildDestinationOrder();
      await _fetchRoute();
    } finally {
      if (mounted) {
        setState(() => _isComputingRoute = false);
      }
    }

    if (!mounted) return;
    if (widget.autoStartNavigation && _routeSteps.isNotEmpty) {
      _startNavigation();
    }
  }

  void _showSearchDestination() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchDestinationSheet(
        onDestinationSelected: _addDestination,
      ),
    );
  }


  Future<void> _addDestination(LatLng location, String name) async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    final newDestination = DestinationInfo(
      location: location,
      name: name,
    );

    _destinations.add(newDestination);
    if (_isNavigating) {
      setState(() {
        _hasDestination = true;
      });
    } else if (_currentLocation == null) {
      _pendingResort = true;
      _getCurrentLocation();
      setState(() {
        _hasDestination = true;
      });
    } else {
      await _rebuildDestinationOrder();
    }

    if (!_isNavigating) {
      await _fetchRoute();
    }

    if (_currentLocation != null) {
      final points = <LatLng>[
        _currentLocation!,
        ..._destinations.map((d) => d.location),
      ];
      _fitBounds(points);
    } else {
      _animateCameraTo(location, 15);
    }

    
  }

  Future<void> _rebuildDestinationOrder() async {
    if (_currentLocation == null || _destinations.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasDestination = _destinations.isNotEmpty;
      });
      return;
    }

    final sorted = await DestinationOrderingService.reorderDestinations(
      currentLocation: _currentLocation!,
      destinations: _destinations,
    );

    if (!mounted) return;
    setState(() {
      _destinations
        ..clear()
        ..addAll(sorted);
      _hasDestination = true;
    });
  }

  Future<void> _fetchRoute() async {
    if (_destinations.isEmpty || _currentLocation == null) {
      setState(() {
        _routePolyline = [];
        _routeTrimStartIdx = 0;
        _routeProgressIdx = 0;
        _routeSteps = [];
      });
      return;
    }

    final result = await RouteFetchService.fetchMultiStopRoute(
      currentLocation: _currentLocation!,
      destinations: _destinations,
    );

    if (!mounted) return;

    setState(() {
      _routePolyline = result.polyline;
      _routeSteps = result.steps;
      _currentStepIndex = 0;
      _distanceToNextStepMeters = 0;

      // reset trim/progress trackers whenever route updates
      _lastTrimIdx = 0;
      _routeTrimStartIdx = 0;
      _routeProgressIdx = 0;
      _prevStepDistance = null;
      _distanceIncreasingCount = 0;
    });

    _fitRouteBounds();

    if (result.legs != null) {
      RouteFetchService.applyLegsToDestinations(
        legs: result.legs!,
        destinations: _destinations,
      );
    }

    await _maybeApplyFloodWeatherReroute();
  }

  Future<void> _maybeApplyFloodWeatherReroute({bool force = false}) async {
    if (!_avoidFloodedAreas || _rerouteInProgress) return;
    if (_destinations.isEmpty || _currentLocation == null) return;
    if (_routePolyline.isEmpty) return;

    if (!_floodsLoaded) {
      await _loadFloodProneAreas();
    }
    if (_weatherConditionByPlace.isEmpty || force) {
      await _loadWeatherMarkers(force: force);
    }
    if (!mounted || _floodPoints.isEmpty) return;

    final currentFloodHits = _countFloodHits(_routePolyline);
    if (currentFloodHits <= 0) return;

    final rainingOnRoute = _isRainingNearRoute(_routePolyline);
    if (!rainingOnRoute) return;

    _rerouteInProgress = true;
    try {
      final candidates = await RouteFetchService.fetchMultiStopRouteCandidates(
        currentLocation: _currentLocation!,
        destinations: _destinations,
      );
      if (!mounted || candidates.isEmpty) return;

      RouteFetchResult? best;
      var bestFloodHits = currentFloodHits;

      for (final candidate in candidates) {
        final hits = _countFloodHits(candidate.polyline);
        if (hits < bestFloodHits) {
          bestFloodHits = hits;
          best = candidate;
        }
      }

      if (best == null) {
        return;
      }

      setState(() {
        _routePolyline = best!.polyline;
        _routeSteps = best.steps;
        _currentStepIndex = 0;
        _distanceToNextStepMeters = 0;
        _lastTrimIdx = 0;
        _routeTrimStartIdx = 0;
        _routeProgressIdx = 0;
        _prevStepDistance = null;
        _distanceIncreasingCount = 0;
      });

      if (best.legs != null) {
        RouteFetchService.applyLegsToDestinations(
          legs: best.legs!,
          destinations: _destinations,
        );
      }

      _fitRouteBounds();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route updated: avoiding flooded road due to rain'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _rerouteInProgress = false;
    }
  }

  bool _isRainingNearRoute(List<LatLng> route) {
    for (final place in _priorityBarangayWeatherPlaces) {
      final condition = _weatherConditionByPlace[place.name];
      if (condition == null || !_isRainCondition(condition)) continue;

      for (int i = 0; i < route.length; i += _routeSampleStride) {
        final p = route[i];
        final distance = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          place.latitude,
          place.longitude,
        );
        if (distance <= _routeWeatherLinkMeters) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isRainCondition(String condition) {
    final text = condition.toLowerCase();
    return text.contains('rain') ||
        text.contains('drizzle') ||
        text.contains('thunderstorm') ||
        text.contains('shower');
  }

  int _countFloodHits(List<LatLng> route) {
    if (_floodPoints.isEmpty || route.isEmpty) return 0;

    var minLat = route.first.latitude;
    var maxLat = route.first.latitude;
    var minLng = route.first.longitude;
    var maxLng = route.first.longitude;

    for (int i = 0; i < route.length; i += _routeSampleStride) {
      final p = route[i];
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    const pad = 0.004;
    final candidateFloodPoints = _floodPoints.where((f) {
      return f.latitude >= minLat - pad &&
          f.latitude <= maxLat + pad &&
          f.longitude >= minLng - pad &&
          f.longitude <= maxLng + pad;
    }).toList(growable: false);

    if (candidateFloodPoints.isEmpty) return 0;

    var hits = 0;
    for (int i = 0; i < route.length; i += _routeSampleStride) {
      final p = route[i];
      for (final flood in candidateFloodPoints) {
        final d = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          flood.latitude,
          flood.longitude,
        );
        if (d <= _floodHitDistanceMeters) {
          hits++;
          break;
        }
      }
    }
    return hits;
  }

  Future<void> _loadPedestrianZones() async {
    if (_pedestrianZonesLoaded || _pedestrianZonesLoading) return;
    _pedestrianZonesLoading = true;
    try {
      final raw = await rootBundle.loadString(
        'alert_dataset/rizal_pedestrian_zones_merged.geojson',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];
      final points = <LatLng>[];

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null) continue;
        final type = (geometry['type'] ?? '').toString();
        final coords = geometry['coordinates'];

        if (type == 'Point' && coords is List && coords.length >= 2) {
          final lon = (coords[0] as num?)?.toDouble();
          final lat = (coords[1] as num?)?.toDouble();
          if (lat != null && lon != null) {
            points.add(LatLng(lat, lon));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pedestrianZonePoints = points;
        _pedestrianZonesLoaded = true;
      });
    } catch (_) {
      // Keep silent; navigation can still run without this alert source.
    } finally {
      _pedestrianZonesLoading = false;
    }
  }

  void _updateNavigationZoneFlags() {
    if (!_isNavigating || _currentLocation == null) {
      if (_inPedestrianZone || _inNoOvertakingZone) {
        setState(() {
          _inPedestrianZone = false;
          _inNoOvertakingZone = false;
        });
      }
      return;
    }

    final current = _currentLocation!;
    final inPedestrian = _isNearAnyZonePoint(
      current,
      _pedestrianZonePoints,
      _pedestrianAlertRadiusMeters,
    );
    final inNoOvertaking = _isNearAnyZonePoint(
      current,
      _noOvertakingZonePoints,
      _noOvertakingAlertRadiusMeters,
    );

    if (inPedestrian != _inPedestrianZone ||
        inNoOvertaking != _inNoOvertakingZone) {
      setState(() {
        _inPedestrianZone = inPedestrian;
        _inNoOvertakingZone = inNoOvertaking;
      });
    }
  }

  bool _isNearAnyZonePoint(
    LatLng current,
    List<LatLng> zonePoints,
    double thresholdMeters,
  ) {
    if (zonePoints.isEmpty) return false;

    final latPad = thresholdMeters / 111320.0;
    final lonPad =
        thresholdMeters / (111320.0 * math.cos(current.latitude * math.pi / 180));

    for (final zone in zonePoints) {
      if ((zone.latitude - current.latitude).abs() > latPad) continue;
      if ((zone.longitude - current.longitude).abs() > lonPad) continue;

      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        zone.latitude,
        zone.longitude,
      );
      if (d <= thresholdMeters) return true;
    }
    return false;
  }

  Future<void> _loadNoOvertakingZones() async {
    if (_noOvertakingZonesLoaded || _noOvertakingZonesLoading) return;
    _noOvertakingZonesLoading = true;
    try {
      final raw = await rootBundle.loadString(
        'alert_dataset/rizal_no_overtaking_zone.geojson',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];
      final points = <LatLng>[];

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null) continue;

        final type = (geometry['type'] ?? '').toString();
        final coords = geometry['coordinates'];

        if (type == 'Point' && coords is List && coords.length >= 2) {
          final lon = (coords[0] as num?)?.toDouble();
          final lat = (coords[1] as num?)?.toDouble();
          if (lat != null && lon != null) {
            points.add(LatLng(lat, lon));
          }
          continue;
        }

        if (type == 'LineString' && coords is List && coords.length >= 2) {
          LatLng? lastKept;
          for (final item in coords) {
            if (item is! List || item.length < 2) continue;
            final lon = (item[0] as num?)?.toDouble();
            final lat = (item[1] as num?)?.toDouble();
            if (lat == null || lon == null) continue;
            final current = LatLng(lat, lon);
            if (lastKept == null) {
              points.add(current);
              lastKept = current;
              continue;
            }
            final dist = Geolocator.distanceBetween(
              lastKept.latitude,
              lastKept.longitude,
              current.latitude,
              current.longitude,
            );
            if (dist >= _noOvertakingSamplingStepMeters) {
              points.add(current);
              lastKept = current;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _noOvertakingZonePoints = points;
        _noOvertakingZonesLoaded = true;
      });
    } catch (_) {
      // Keep silent for now; this preview layer is optional.
    } finally {
      _noOvertakingZonesLoading = false;
    }
  }

  Future<void> _removeDestination(int index) async {
    _destinations.removeAt(index);

    if (_destinations.isEmpty) {
      setState(() {
        _isNavigating = false;
        _hasDestination = false;
        _routePolyline = [];
        _routeTrimStartIdx = 0;
        _routeProgressIdx = 0;
        _routeSteps = [];
        _currentStepIndex = 0;
        _distanceToNextStepMeters = 0;
        _dismissedAlertType = null;
        _lastSpokenAlertType = null;
      });
      _cancelAlertAutoClose();
      _followUser = false;
      _applyMapStyle(navigation: false);
      _voiceAlertService.stop();
    } else {
      if (mounted) {
        setState(() => _isComputingRoute = true);
      }
      try {
        await _rebuildDestinationOrder();
        await _fetchRoute();
      } finally {
        if (mounted) {
          setState(() => _isComputingRoute = false);
        }
      }
    }

    
  }

  // ================= NAVIGATION PROGRESS =================

  void _updateNavigationProgress() {
    final now = DateTime.now();
    if (_lastProgressAt != null &&
        now.difference(_lastProgressAt!) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastProgressAt = now;

    unawaited(_handleReachedDestination());
    if (_currentLocation == null) return;
    if (_routeSteps.isEmpty) return;
    if (_currentStepIndex >= _routeSteps.length) return;

    if (_currentStepIndex < 0 || _currentStepIndex >= _routeSteps.length) {
      _currentStepIndex = _routeSteps.isEmpty ? 0 : (_routeSteps.length - 1);
      if (_routeSteps.isEmpty) return;
    }
    final step = _routeSteps[_currentStepIndex];
    final distance = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      step.location.latitude,
      step.location.longitude,
    );

    if ((_distanceToNextStepMeters - distance).abs() > 0.5) {
      setState(() => _distanceToNextStepMeters = distance);
    }

    // "passed step" detection:
    // If the distance keeps increasing, assume step already passed (common in fast movement / GPS jitter)
    if (_prevStepDistance != null && distance > _prevStepDistance! + 5) {
      _distanceIncreasingCount++;
    } else {
      _distanceIncreasingCount = 0;
    }
    _prevStepDistance = distance;

    final reached = distance <= 30;
    final likelyPassed = _distanceIncreasingCount >= 3;

    if ((reached || likelyPassed) && _currentStepIndex < _routeSteps.length - 1) {
      _currentStepIndex += 1;
      _distanceIncreasingCount = 0;
      _prevStepDistance = null;

      _voiceAlertService.announceNavigation(
        _routeSteps[_currentStepIndex].instruction,
      );
    }
  }

  bool _isGoodGpsSample(Position sample, Position? last) {
    if (sample.accuracy.isFinite &&
        sample.accuracy > _maxAcceptedGpsAccuracyMeters) {
      return false;
    }

    final now = DateTime.now();
    final timestamp = sample.timestamp;
    if (timestamp != null && now.difference(timestamp).abs() > _maxAcceptedGpsAge) {
      return false;
    }

    if (last != null) {
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        sample.latitude,
        sample.longitude,
      );
      final prevTs = last.timestamp;
      final currTs = sample.timestamp;
      if (prevTs != null && currTs != null) {
        final dtMs = currTs.millisecondsSinceEpoch - prevTs.millisecondsSinceEpoch;
        if (dtMs > 0) {
          final speedMps = meters / (dtMs / 1000.0);
          if (speedMps > _maxAcceptedSpeedMps) return false;
        }
      }
    }

    return true;
  }

  LatLng _smoothRawPoint(LatLng raw) {
    _smoothedLat ??= raw.latitude;
    _smoothedLng ??= raw.longitude;
    _smoothedLat =
        _gpsSmoothingAlpha * raw.latitude + (1 - _gpsSmoothingAlpha) * _smoothedLat!;
    _smoothedLng =
        _gpsSmoothingAlpha * raw.longitude + (1 - _gpsSmoothingAlpha) * _smoothedLng!;
    return LatLng(_smoothedLat!, _smoothedLng!);
  }

  _RouteProjection? _projectToForwardRouteSegment(
    LatLng point, {
    required int startIdx,
    required int forwardWindow,
  }) {
    if (_routePolyline.length < 2) return null;
    final from = startIdx.clamp(0, _routePolyline.length - 2).toInt();
    final to = math.min(from + forwardWindow, _routePolyline.length - 2);

    _RouteProjection? best;
    for (int i = from; i <= to; i++) {
      final a = _routePolyline[i];
      final b = _routePolyline[i + 1];
      final projection = _projectPointOnSegment(point, a, b);
      if (best == null || projection.distanceMeters < best.distanceMeters) {
        best = _RouteProjection(
          segmentIndex: i,
          point: projection.point,
          distanceMeters: projection.distanceMeters,
        );
      }
    }
    return best;
  }

  _SegmentProjection _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    const latMeters = 111320.0;
    final refLat = ((p.latitude + a.latitude + b.latitude) / 3.0) *
        (math.pi / 180.0);
    final lngMeters = latMeters * math.cos(refLat).abs();

    final px = p.longitude * lngMeters;
    final py = p.latitude * latMeters;
    final ax = a.longitude * lngMeters;
    final ay = a.latitude * latMeters;
    final bx = b.longitude * lngMeters;
    final by = b.latitude * latMeters;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final denom = (abx * abx) + (aby * aby);

    double t = 0.0;
    if (denom > 0) {
      t = ((apx * abx + apy * aby) / denom).clamp(0.0, 1.0);
    }

    final projX = ax + (abx * t);
    final projY = ay + (aby * t);
    final dX = px - projX;
    final dY = py - projY;
    final distanceMeters = math.sqrt((dX * dX) + (dY * dY));

    final point = LatLng(
      projY / latMeters,
      lngMeters > 0 ? (projX / lngMeters) : p.longitude,
    );

    return _SegmentProjection(
      point: point,
      distanceMeters: distanceMeters,
    );
  }

  int _advanceRouteIndexByMeters(int startIdx, double aheadMeters) {
    if (_routePolyline.length < 2) return 0;
    var idx = startIdx.clamp(0, _routePolyline.length - 2).toInt();
    var acc = 0.0;
    while (idx < _routePolyline.length - 2 && acc < aheadMeters) {
      final a = _routePolyline[idx];
      final b = _routePolyline[idx + 1];
      acc += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      idx++;
    }
    return idx;
  }

  /// New stable trim:
  /// - only search nearest within a window ahead of last known trim position
  /// - only trim forward
  void _trimRoutePolyline() {
    final trimSource = _displayRawLocation ?? _rawLocation ?? _currentLocation;
    if (_routePolyline.length < 2 || trimSource == null) return;

    if (_isNavigating) {
      final baseIdx =
          _routeProgressIdx.clamp(0, _routePolyline.length - 2).toInt();
      final trimIdx =
          _advanceRouteIndexByMeters(baseIdx, _navigationTrimLeadMeters);
      if (trimIdx > _routeTrimStartIdx &&
          _routePolyline.length - trimIdx >= 2) {
        setState(() {
          _routeTrimStartIdx = trimIdx;
        });
      }
      _lastTrimIdx = baseIdx;
      return;
    }

    final start = _lastTrimIdx.clamp(0, _routePolyline.length - 1).toInt();
    final end = math.min(start + _trimSearchWindow, _routePolyline.length);

    int bestIdx = start;
    double bestDist = double.infinity;

    for (int i = start; i < end; i++) {
      final p = _routePolyline[i];
      final d = Geolocator.distanceBetween(
        trimSource.latitude,
        trimSource.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    // Non-navigation mode keeps conservative trim behavior.
    if (bestDist <= _trimDistanceThreshold && bestIdx > _lastTrimIdx) {
      _lastTrimIdx = bestIdx;
      final nextTrimStart = math.max(0, bestIdx - 1);
      if (nextTrimStart != _routeTrimStartIdx &&
          _routePolyline.length - nextTrimStart >= 2) {
        setState(() {
          _routeTrimStartIdx = nextTrimStart;
        });
      }
    } else {
      _lastTrimIdx = bestIdx;
    }
  }

  // ================= CAMERA & SNAP =================

  void _applyFollowCamera({double? zoomOverride, bool force = false}) {
    if (!force && _isRecenteringToFollow) return;
    final followTarget = _isNavigating
        ? (_displayRawLocation ?? _currentLocation ?? _rawLocation)
        : (_currentLocation ?? _displayRawLocation ?? _rawLocation);
    if (followTarget == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastFollowCameraAt != null &&
        now.difference(_lastFollowCameraAt!) < _followCameraMinInterval) {
      return;
    }
    _lastFollowCameraAt = now;
    final baseZoom = zoomOverride ?? _cameraZoom ?? 18.5;
    final zoom = (_isNavigating && _followUser && baseZoom < _navigationZoom)
        ? _navigationZoom
        : baseZoom;
    final routeBearing = _isNavigating ? _routeBearingOrHeading() : 0.0;
    if (_isNavigating) {
      _lastFollowCameraZoomCommand = zoom;
    }
    if (_isNavigating) {
      unawaited(
        _moveCameraTo(
          followTarget,
          zoom,
          tilt: 60,
          bearing: routeBearing,
        ),
      );
    } else {
      unawaited(
        _animateCameraTo(
          followTarget,
          zoom,
          tilt: 0,
          bearing: routeBearing,
        ),
      );
    }
  }

  Future<void> _moveCameraTo(
    LatLng target,
    double? zoom, {
    double? bearing,
    double? tilt,
  }) async {
    if (!_gmapsController.isCompleted) return;
    _programmaticMove = true;
    _suppressUserInteraction = true;
    _programmaticMoveTimer?.cancel();
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 250), () {
      _programmaticMove = false;
    });

    final controller = await _gmapsController.future;
    _mapController ??= controller;
    final cameraPosition = gmaps.CameraPosition(
      target: gmaps.LatLng(target.latitude, target.longitude),
      zoom: zoom ?? 18,
      tilt: tilt ?? (_isNavigating ? 60 : 0),
      bearing: bearing ?? 0,
    );
    await controller.moveCamera(
      gmaps.CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

  Future<LatLng?> _snapToRoad(LatLng raw, {bool force = false}) async {
    final now = DateTime.now();
    if (_snapInFlight) return null;

    // Faster snap refresh while navigating for smoother progression.
    final minInterval = _isNavigating
        ? const Duration(milliseconds: 100)
        : const Duration(seconds: 3);

    if (!force &&
        _lastSnapAt != null &&
        now.difference(_lastSnapAt!) < minInterval) {
      return null;
    }

    _snapInFlight = true;
    try {
      final snapped = await OSRMService.getNearestRoadPoint(raw);
      _lastSnapAt = DateTime.now();
      return snapped;
    } finally {
      _snapInFlight = false;
    }
  }

  double _routeBearingOrHeading() {
    final currentForBearing = _isNavigating
        ? (_displayRawLocation ?? _currentLocation ?? _rawLocation)
        : (_currentLocation ?? _displayRawLocation ?? _rawLocation);
    if (currentForBearing == null) return _currentHeading;

    final speedMps = _currentSpeedMps ?? 0;
    final headingBearing = _normalizeBearing(_currentHeading);
    final stableHeading =
        (speedMps < 2.0 && _visualBearing != null) ? _visualBearing! : headingBearing;

    double targetBearing = stableHeading;

    // Prefer route direction only near maneuver; otherwise keep forward heading.
    if (_routePolyline.length >= 2) {
      final polyBearing = _bearingAlongPolyline(currentForBearing);
      if (polyBearing != null) {
        if (_isNavigating && _distanceToNextStepMeters > 0) {
          final d = _distanceToNextStepMeters;
          // Turn bias only when close to maneuver to avoid early map/icon turns.
          if (d <= 8) {
            targetBearing = polyBearing;
          } else if (d <= 22) {
            final t = ((22 - d) / (22 - 8)).clamp(0.0, 1.0);
            targetBearing = _lerpAngle(stableHeading, polyBearing, t);
          } else {
            targetBearing = stableHeading;
          }
        } else if (_isNavigating) {
          targetBearing = stableHeading;
        } else {
          targetBearing = polyBearing;
        }
      }
    } else if (_routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length) {
      targetBearing = _bearingBetween(
        currentForBearing,
        _routeSteps[_currentStepIndex].location,
      );
    }

    // Smooth rotation to avoid abrupt/early camera-icon turning.
    final currentVisual = _visualBearing ?? targetBearing;
    double maxTurnPerUpdate = _isNavigating ? 3.0 : 12.0;
    if (_isNavigating && _distanceToNextStepMeters <= 22) maxTurnPerUpdate = 5.0;
    if (_isNavigating && _distanceToNextStepMeters <= 10) maxTurnPerUpdate = 7.0;
    if (_isNavigating && speedMps < 1.5) maxTurnPerUpdate = 2.0;
    final delta = _shortestAngleDelta(currentVisual, targetBearing);
    final appliedDelta = delta.clamp(-maxTurnPerUpdate, maxTurnPerUpdate);
    _visualBearing = _normalizeBearing(currentVisual + appliedDelta);
    return _visualBearing!;
  }

  double? _bearingAlongPolyline(LatLng current) {
    if (_routePolyline.length < 2) return null;

    final start = (_isNavigating ? _routeProgressIdx : _lastTrimIdx)
        .clamp(0, _routePolyline.length - 1)
        .toInt();
    final searchWindow = _isNavigating ? 24 : _trimSearchWindow;
    var end = math.min(start + searchWindow, _routePolyline.length);
    if (end - start < 2) {
      end = math.min(searchWindow, _routePolyline.length);
    }

    int bestIdx = start;
    double bestDist = double.infinity;

    for (int i = start; i < end; i++) {
      final p = _routePolyline[i];
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    // Keep look-ahead short so turning starts near actual turn point.
    final speedMps = _currentSpeedMps ?? 0;
    final lookAheadMeters = speedMps >= 7
        ? 6.0
        : speedMps >= 4
            ? 4.0
            : 3.0;
    double acc = 0;
    int j = bestIdx;
    while (j < _routePolyline.length - 1 && acc < lookAheadMeters) {
      final a = _routePolyline[j];
      final b = _routePolyline[j + 1];
      acc += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      j++;
    }

    if (j == bestIdx) {
      j = math.min(bestIdx + 1, _routePolyline.length - 1);
    }

    return _bearingBetween(_routePolyline[bestIdx], _routePolyline[j]);
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lat2 = _degToRad(to.latitude);
    final dLon = _degToRad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final computedBearing = math.atan2(y, x);
    return (_radToDeg(computedBearing) + 360) % 360;
  }

  double _normalizeBearing(double bearing) {
    var b = bearing % 360;
    if (b < 0) b += 360;
    return b;
  }

  double _shortestAngleDelta(double from, double to) {
    var diff = (to - from + 540) % 360 - 180;
    if (diff < -180) diff += 360;
    return diff;
  }

  double _lerpAngle(double from, double to, double t) {
    final delta = _shortestAngleDelta(from, to);
    return _normalizeBearing(from + delta * t);
  }

  double _degToRad(double deg) => deg * (math.pi / 180);
  double _radToDeg(double rad) => rad * (180 / math.pi);

  void _registerUserCameraInteraction() {
    if (!_isNavigating) return;
    if (_followUser) {
      setState(() => _followUser = false);
    } else {
      _followUser = false;
    }
  }

  Future<void> _animateCameraTo(
    LatLng target,
    double? zoom, {
    double? bearing,
    double? tilt,
  }) async {
    if (!_gmapsController.isCompleted) return;
    _programmaticMove = true;
    _suppressUserInteraction = true;
    _programmaticMoveTimer?.cancel();
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 600), () {
      _programmaticMove = false;
    });

    final controller = await _gmapsController.future;
    _mapController ??= controller;
    final cameraPosition = gmaps.CameraPosition(
      target: gmaps.LatLng(target.latitude, target.longitude),
      zoom: zoom ?? 18,
      tilt: tilt ?? (_isNavigating ? 60 : 0),
      bearing: bearing ?? 0,
    );
    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

  Future<void> _fitRouteBounds() async {
    if (!_gmapsController.isCompleted) return;
    if (_currentLocation == null) return;
    final points = <LatLng>[
      _currentLocation!,
      ..._destinations.map((d) => d.location),
      ..._routePolyline,
    ];
    if (points.length < 2) return;
    if (!_isNavigating) {
      _fitBounds(points);
    }
  }

  Future<void> _fitBounds(List<LatLng> points) async {
    if (!_gmapsController.isCompleted || points.isEmpty) return;
    final bounds = computeBounds(points);
    _programmaticMove = true;
    _suppressUserInteraction = true;
    _programmaticMoveTimer?.cancel();
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 600), () {
      _programmaticMove = false;
    });
    final controller = await _gmapsController.future;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final hasOverlays = _hasDestination && !_isNavigating;
    final topOverlay = hasOverlays ? 220.0 : 0.0;
    final bottomOverlay = hasOverlays ? 220.0 : 0.0;
    final padding = (topInset + topOverlay + bottomOverlay) / 2;
    final padded = padding < 110 ? 110.0 : padding;
    await controller.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, padded),
    );
  }

  void _applyMapStyle({required bool navigation}) {
    final controller = _mapController;
    if (controller == null) return;
    if (navigation) {
      controller.setMapStyle(darkMapStyle);
    } else {
      controller.setMapStyle(null);
    }
  }

  void _recenterOnUser() {
    if (_currentLocation == null) return;
    if (_isNavigating) {
      if (_cameraZoom == null || _cameraZoom! < _navigationZoom) {
        _cameraZoom = _navigationZoom;
      }
      _applyFollowCamera();
    } else {
      _animateCameraTo(_currentLocation!, 17, bearing: 0, tilt: 0);
    }
  }

  Future<void> _resumeFollowWithAnimation() async {
    if (_currentLocation == null) return;
    if (_isNavigating) {
      if (_isRecenteringToFollow) return;
      _isRecenteringToFollow = true;
      try {
        final target = _displayRawLocation ?? _currentLocation ?? _rawLocation;
        if (target == null) return;
        final zoom = (_cameraZoom == null || _cameraZoom! < _navigationZoom)
            ? _navigationZoom
            : _cameraZoom!;
        if (mounted && _followUser) {
          setState(() => _followUser = false);
        } else {
          _followUser = false;
        }
        await _animateCameraTo(
          target,
          zoom,
          tilt: 60,
          bearing: _routeBearingOrHeading(),
        );
        if (!mounted) return;
        setState(() => _followUser = true);
        // Give the recenter animation a short handoff window so follow mode
        // does not immediately issue a hard moveCamera jump.
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        final catchupTarget = _displayRawLocation ?? _currentLocation ?? _rawLocation;
        if (catchupTarget != null) {
          await _animateCameraTo(
            catchupTarget,
            _cameraZoom ?? _navigationZoom,
            tilt: 60,
            bearing: _routeBearingOrHeading(),
          );
        }
      } finally {
        _isRecenteringToFollow = false;
      }
      return;
    }
    _recenterOnUser();
  }

  AlertType? _currentNavigationAlertType() {
    final speedKmh =
        _currentSpeedMps != null ? (_currentSpeedMps! * 3.6).round() : null;
    return NavigationTypeLogic.resolveAlert(
      NavigationAlertContext(
        isNavigating: _isNavigating,
        speedKmh: speedKmh,
        inPedestrianZone: _inPedestrianZone,
        inNoOvertakingZone: _inNoOvertakingZone,
      ),
    );
  }

  void _syncAlertDismissState() {
    if (_dismissedAlertType == null) return;
    final currentType = _currentNavigationAlertType();
    if (_dismissedAlertType == AlertType.overspeeding &&
        currentType == AlertType.overspeeding) {
      setState(() => _dismissedAlertType = null);
      return;
    }
    if (currentType == null || currentType != _dismissedAlertType) {
      setState(() => _dismissedAlertType = null);
    }
  }

  void _dismissAlert(AlertType type) {
    if (type == AlertType.overspeeding) return;
    _cancelAlertAutoClose();
    setState(() {
      _dismissedAlertType = type;
      _lastSpokenAlertType = null;
    });
  }

  void _scheduleAlertAutoClose(AlertType type) {
    if (type == AlertType.overspeeding) {
      _cancelAlertAutoClose();
      return;
    }
    if (_dismissedAlertType == type) return;
    if (_autoCloseScheduledFor == type && _alertAutoCloseTimer?.isActive == true) {
      return;
    }

    _alertAutoCloseTimer?.cancel();
    _autoCloseScheduledFor = type;
    _alertAutoCloseTimer = Timer(_alertAutoCloseDelay, () {
      if (!mounted) return;
      final currentType = _currentNavigationAlertType();
      if (currentType == type && _dismissedAlertType != type) {
        setState(() => _dismissedAlertType = type);
      }
      _autoCloseScheduledFor = null;
    });
  }

  void _cancelAlertAutoClose() {
    _alertAutoCloseTimer?.cancel();
    _autoCloseScheduledFor = null;
  }

  void _syncVoiceSafetyAlert() {
    final currentType = _currentNavigationAlertType();
    unawaited(_maybeLogOverspeedingViolation(currentType));
    final shouldSpeak =
        currentType != null && currentType != _dismissedAlertType;

    if (!shouldSpeak) {
      _lastSpokenAlertType = null;
      return;
    }

    if (_lastSpokenAlertType == currentType) return;
    _lastSpokenAlertType = currentType;
    _voiceAlertService.announceSafetyAlert(currentType!);
  }

  Future<void> _loadRiderFullName() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('fname, mname, lname')
          .eq('user_id', widget.userId)
          .maybeSingle();
      if (!mounted || response == null) return;

      final fname = (response['fname'] ?? '').toString().trim();
      final mname = (response['mname'] ?? '').toString().trim();
      final lname = (response['lname'] ?? '').toString().trim();
      final parts = [fname, mname, lname].where((p) => p.isNotEmpty).toList();
      _riderFullName = parts.join(' ');
    } catch (_) {
      // Keep silent; violation log can still proceed without name.
    }
  }

  Future<void> _maybeLogOverspeedingViolation(AlertType? currentType) async {
    if (!_isNavigating) return;
    if (currentType != AlertType.overspeeding) return;
    if (_currentLocation == null) return;
    if (_overspeedLogInFlight) return;

    final now = DateTime.now();
    if (_lastOverspeedLogAt != null &&
        now.difference(_lastOverspeedLogAt!) < _overspeedLogCooldown) {
      return;
    }

    _overspeedLogInFlight = true;
    try {
      await Supabase.instance.client.from('violation_logs').insert({
        'user_id': widget.userId,
        'violation': 'overspeeding',
        'name': _riderFullName.isEmpty ? null : _riderFullName,
        'lat': _currentLocation!.latitude,
        'lng': _currentLocation!.longitude,
        'date': now.toIso8601String(),
      });
      _lastOverspeedLogAt = now;
    } catch (_) {
      // Keep silent to avoid UI noise while driving.
    } finally {
      _overspeedLogInFlight = false;
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final hasSteps =
        _routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length;
    final currentStep = hasSteps ? _routeSteps[_currentStepIndex] : null;
    final distanceToFirstDestinationMeters =
        (_currentLocation != null && _destinations.isNotEmpty)
            ? Geolocator.distanceBetween(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
                _destinations.first.location.latitude,
                _destinations.first.location.longitude,
              )
            : null;
    final etaMinutes = (distanceToFirstDestinationMeters != null &&
            _currentSpeedMps != null &&
            _currentSpeedMps! > 1.0)
        ? (distanceToFirstDestinationMeters / _currentSpeedMps! / 60).round()
        : (_destinations.isNotEmpty
            ? _destinations.first.durationMinutes
            : null);
    final speedKmh = _currentSpeedMps != null
        ? (_currentSpeedMps! * 3.6).round()
        : null;
    final displaySpeedKmh =
        (speedKmh != null && speedKmh >= 8) ? speedKmh : null;
    final activeAlertType = _currentNavigationAlertType();
    final shouldShowAlert = activeAlertType != null &&
        activeAlertType != _dismissedAlertType;
    if (shouldShowAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || activeAlertType == null) return;
        _scheduleAlertAutoClose(activeAlertType);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cancelAlertAutoClose();
      });
    }
    final arrivalTime = etaMinutes != null
        ? DateTime.now().add(Duration(minutes: etaMinutes))
        : null;

    final markers = <gmaps.Marker>{
      for (final entry in _destinations.asMap().entries)
        gmaps.Marker(
          markerId: gmaps.MarkerId('dest_${entry.key}'),
          position: gmaps.LatLng(
            entry.value.location.latitude,
            entry.value.location.longitude,
          ),
          infoWindow: gmaps.InfoWindow(
            title: 'Destination ${entry.key + 1}',
            snippet: entry.value.name,
          ),
        ),

      // Use animated, snapped navigation point for stable road-locked UI.
      if (_isNavigating &&
          (_displayRawLocation ?? _currentLocation) != null)
        gmaps.Marker(
          markerId: const gmaps.MarkerId('nav_arrow'),
          position: gmaps.LatLng(
            (_displayRawLocation ?? _currentLocation)!.latitude,
            (_displayRawLocation ?? _currentLocation)!.longitude,
          ),
          icon: _navArrowIcon ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueRed,
              ),
          flat: true,
          rotation: _routeBearingOrHeading(),
          anchor: const Offset(0.5, 0.5),
          zIndex: 5,
        ),
      if (_mapTypeSelection == 'weather') ..._weatherMarkers,
    };

    final visibleRoute = _routeTrimStartIdx > 0 &&
            _routeTrimStartIdx < _routePolyline.length - 1
        ? _routePolyline.sublist(_routeTrimStartIdx)
        : _routePolyline;
    var routePoints = visibleRoute
        .map((p) => gmaps.LatLng(p.latitude, p.longitude))
        .toList();
    // Keep trim visually locked to the navigator arrow position.
    final navHead = _isNavigating
        ? (_displayRawLocation ?? _currentLocation)
        : null;
    if (navHead != null) {
      routePoints = [
        gmaps.LatLng(navHead.latitude, navHead.longitude),
        ...routePoints,
      ];
    }
    final polylines = <gmaps.Polyline>{
      if (routePoints.isNotEmpty)
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route_outline'),
          points: routePoints,
          color: Colors.white70,
          width: 12,
        ),
      if (routePoints.isNotEmpty)
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: routePoints,
          color: Colors.blue,
          width: 8,
        ),
    };
    final circles = <gmaps.Circle>{};
    if (_mapTypeSelection == 'floods') {
      circles.addAll(_floodCircles);
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// MAP
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _currentLocation != null
                  ? gmaps.LatLng(
                      _currentLocation!.latitude,
                      _currentLocation!.longitude,
                    )
                  : const gmaps.LatLng(13.4127, 121.1794),
              zoom: 18,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_gmapsController.isCompleted) {
                _gmapsController.complete(controller);
              }
              _applyMapStyle(navigation: _isNavigating);
            },
            markers: markers,
            polylines: polylines,
            circles: circles,
            myLocationEnabled: !_isNavigating,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            onCameraMoveStarted: () {
              if (_programmaticMove) return;
              if (_suppressUserInteraction) {
                _suppressUserInteraction = false;
                return;
              }
              _registerUserCameraInteraction();
            },
            onCameraMove: (position) {
              final manualZoomBreakFollow = _isNavigating &&
                  _followUser &&
                  _lastFollowCameraZoomCommand != null &&
                  (position.zoom - _lastFollowCameraZoomCommand!).abs() > 0.12;
              _cameraZoom = position.zoom;
              if (manualZoomBreakFollow) {
                _registerUserCameraInteraction();
                _programmaticMove = false;
                _suppressUserInteraction = false;
                return;
              }
              if (_programmaticMove) return;
              if (_suppressUserInteraction) {
                _suppressUserInteraction = false;
                return;
              }
              _registerUserCameraInteraction();
            },
            onCameraIdle: () {
              if (_mapTypeSelection == 'floods') {
                _refreshVisibleFloodCircles();
              }
            },
          ),

          /// SEARCH BAR (when no destinations)
          if (!_isNavigating && !_hasDestination)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _showSearchDestination,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Search destination...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          /// TURN-BY-TURN CARD (during navigation)
          if (_isNavigating && currentStep != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, color: Colors.white, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            currentStep.instruction,
                            minFontSize: 16,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatDistance(_distanceToNextStepMeters)} to next step',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          /// RECENTER BUTTON (during navigation)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 107,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'recenter_nav',
                  onPressed: () {
                    if (_currentLocation == null) return;
                    _recenterTimer?.cancel();
                    unawaited(_resumeFollowWithAnimation());
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          /// MAP TYPE BUTTON (during navigation)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 172,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'map_type_nav',
                  onPressed: _showMapTypeSheet,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: const Icon(
                    Icons.layers,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          /// SPEED INDICATOR (during navigation)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 237,
              right: 16,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displaySpeedKmh != null ? '$displaySpeedKmh' : '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'km/h',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          /// RECENTER BUTTON (idle, no destinations)
          if (!_isNavigating && !_hasDestination)
            Positioned(
              top: MediaQuery.of(context).padding.top + 81,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'recenter_idle',
                  onPressed: () {
                    if (_currentLocation == null) return;
                    _recenterTimer?.cancel();
                    unawaited(_resumeFollowWithAnimation());
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          /// MAP TYPE BUTTON (idle, no destinations)
          if (!_isNavigating && !_hasDestination)
            Positioned(
              top: MediaQuery.of(context).padding.top + 145,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFF800000),
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'map_type_idle',
                  onPressed: _showMapTypeSheet,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: const Icon(
                    Icons.layers,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          /// TOP DESTINATION BOXES (when has destinations, not navigating)
          if (_hasDestination && !_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFF800000),
                        ],
                        stops: [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentLocationName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.25),
                        ),
                        SizedBox(
                          height: _destinations.length > 2
                              ? 104
                              : _destinations.length * 52,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: _destinations.length > 2
                                ? const BouncingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            itemCount: _destinations.length,
                            itemBuilder: (context, index) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DestinationCard(
                                      destinationName: _destinations[index].name,
                                      destinationNumber: index + 1,
                                      onRemove: () => _removeDestination(index),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _showSearchDestination,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFF800000),
                            ],
                            stops: [0.0, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.35),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFF800000),
                          ],
                          stops: [0.0, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'recenter',
                        onPressed: () {
                          if (_currentLocation == null) return;
                          _recenterTimer?.cancel();
                          unawaited(_resumeFollowWithAnimation());
                        },
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFF800000),
                          ],
                          stops: [0.0, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'map_type_has_dest',
                        onPressed: _showMapTypeSheet,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: const Icon(
                          Icons.layers,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          /// BOTTOM ROUTE INFO + START BUTTON (when has destinations, not navigating)
          if (_hasDestination && !_isNavigating)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: RouteSegmentCard(
                            destinations: _destinations,
                            currentLocationName: _currentLocationName,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                              child: ElevatedButton(
                                onPressed: _startNavigation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 8,
                                ),
                                child: Ink(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFF0000),
                                        Color(0xFF800000),
                                      ],
                                      stops: [0.0, 1.0],
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30)),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.navigation,
                                            color: Colors.white, size: 24),
                                        SizedBox(width: 12),
                                        Text(
                                          'START NAVIGATION',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (shouldShowAlert)
            Positioned(
              left: 10,
              right: 10,
              bottom: 80,
              child: AlertCard(
                type: activeAlertType!,
                onClose: activeAlertType == AlertType.overspeeding
                    ? null
                    : () => _dismissAlert(activeAlertType!),
              ),
            ),
          if (_isComputingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          color: Color(0xFFD40000),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Computing the distance and route',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Please wait.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      /// BOTTOM NAV BAR
      bottomNavigationBar: _isNavigating
          ? Container(
              height: 72,
              decoration: BoxDecoration(
                boxShadow: [],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFF800000),
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _endNavigation,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        etaMinutes != null ? '${etaMinutes} min' : '--',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.motorcycle,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    distanceToFirstDestinationMeters != null &&
                                            arrivalTime != null
                                        ? '${formatDistance(distanceToFirstDestinationMeters)} • ${DateFormat('h:mm a').format(arrivalTime)}'
                                        : '--',
                                    style: const TextStyle(
                                      color: ui.Color.fromARGB(190, 255, 255, 255),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              if (_currentLocation == null ||
                                  _destinations.isEmpty) {
                                return;
                              }
                              if (_isNavigating) {
                                setState(() => _followUser = false);
                              }
                              _fitBounds([
                                _currentLocation!,
                                _destinations.first.location,
                              ]);
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.alt_route,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ),
              ),
            )
          : !_hasDestination
              ? Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromARGB(255, 247, 139, 150),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
                    child: BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.grey.shade200,
                      currentIndex: _selectedIndex,
                      selectedItemColor: Colors.red,
                      unselectedItemColor: Colors.black54,
                      onTap: _onItemTapped,
                      items: const [
                        BottomNavigationBarItem(
                            icon: Icon(Icons.home), label: 'Home'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.location_on), label: 'Location'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.warning), label: 'Rules'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.local_shipping), label: 'Parcels'),
                        BottomNavigationBarItem(
                            icon: Icon(Icons.person), label: 'Profile'),
                      ],
                        ),
                  ),
                )
              : null,
    );
  }

}

class _RouteProjection {
  final int segmentIndex;
  final LatLng point;
  final double distanceMeters;

  const _RouteProjection({
    required this.segmentIndex,
    required this.point,
    required this.distanceMeters,
  });
}

class _SegmentProjection {
  final LatLng point;
  final double distanceMeters;

  const _SegmentProjection({
    required this.point,
    required this.distanceMeters,
  });
}

class _FloodRenderConfig {
  final int maxPoints;
  final double cellSizeDeg;
  final bool showInnerCircle;

  const _FloodRenderConfig({
    required this.maxPoints,
    required this.cellSizeDeg,
    required this.showInnerCircle,
  });
}

class _WeatherPlace {
  final String name;
  final double latitude;
  final double longitude;

  const _WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class _WeatherInfo {
  final String iconCode;
  final String condition;

  const _WeatherInfo({
    required this.iconCode,
    required this.condition,
  });
}

const List<_WeatherPlace> _priorityBarangayWeatherPlaces = [
  _WeatherPlace(name: 'Brgy Mayamot', latitude: 14.6206, longitude: 121.1160),
  _WeatherPlace(name: 'Brgy Cupang', latitude: 14.5897, longitude: 121.1012),
  _WeatherPlace(name: 'Brgy Mambugan', latitude: 14.5878, longitude: 121.1337),
];

const List<Offset> _weatherDisplayOffsetsMeters = [
  Offset(0, 0),
  Offset(500, 0),
  Offset(-500, 0),
  Offset(0, 500),
  Offset(0, -500),
  Offset(500, 500),
  Offset(500, -500),
  Offset(-500, 500),
  Offset(-500, -500),
  Offset(1000, 0),
  Offset(-1000, 0),
  Offset(0, 1000),
  Offset(0, -1000),
];
