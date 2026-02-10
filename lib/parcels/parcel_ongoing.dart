import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../maps/screens/map_screen.dart';
import 'parcel_ongoing_information.dart';

class ParcelOngoingPage extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const ParcelOngoingPage({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<ParcelOngoingPage> createState() => _ParcelOngoingPageState();
}

class _ParcelOngoingPageState extends State<ParcelOngoingPage> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  static const int _itemsPerPage = 10;

  bool isLoadingOngoing = true;
  List<Map<String, dynamic>> ongoingParcels = [];
  List<Map<String, dynamic>> filteredParcels = []; // bago

  int attempt1Pending = 0;
  int attempt2Pending = 0;
  int _currentPage = 0;
  LatLng _mapCenter = const LatLng(14.5995, 120.9842);
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _recipientMapPoints = [];
  int? _selectedDestinationLimit = 1;
  List<Map<String, dynamic>> _routeCandidates = [];

    String dropdownValue = "All"; // ✅ bago
  final TextEditingController searchController = TextEditingController(); // ✅ bago

  @override
  void initState() {
    super.initState();
    if (widget.liveLat != null && widget.liveLng != null) {
      _mapCenter = LatLng(widget.liveLat!, widget.liveLng!);
      _currentLocation = _mapCenter;
    }
    fetchOngoingParcels();
    _loadCurrentLocation();
  }

  Future<void> fetchOngoingParcels() async {
    try {
      final response = await supabase.from('parcels').select('*');
      final List data = response as List;

      List<Map<String, dynamic>> ongoing = [];
      List<Map<String, dynamic>> mapPoints = [];
      List<Map<String, dynamic>> routeCandidates = [];
      int a1 = 0;
      int a2 = 0;

      for (var item in data) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);

        final status = (row['status'] ?? '').toString().toLowerCase();
        if (status != 'on-going') continue;
        if (!_isAssignedToCurrentRider(row)) continue;

        String attempt1Status =
            (row['attempt1_status'] ?? '').toString().toLowerCase();
        String attempt2Status =
            (row['attempt2_status'] ?? '').toString().toLowerCase();

        String attempt = "";
        if (attempt1Status == "pending") {
          attempt = "Attempt 1";
          a1++;
        } else if (attempt2Status == "pending") {
          attempt = "Attempt 2";
          a2++;
        }

        if (attempt.isNotEmpty) {
          ongoing.add({
            "parcel_id": row['parcel_id'],
            "name": row['recipient_name'] ?? "Unknown",
            "address": row['address'] ?? "",
            "attempt": attempt,
          });

          final lat = _toDouble(row['r_lat']);
          final lng = _toDouble(row['r_lng'] ?? row['r_long'] ?? row['lng']);
          if (lat != null && lng != null) {
            mapPoints.add({
              'parcel_id': row['parcel_id'],
              'point': LatLng(lat, lng),
            });
            routeCandidates.add({
              'parcel_id': row['parcel_id'],
              'address': (row['address'] ?? '').toString(),
              'lat': lat,
              'lng': lng,
            });
          }
        }
      }

      setState(() {
        ongoingParcels = ongoing;
        filteredParcels = ongoing; // bago
        _recipientMapPoints = mapPoints;
        _routeCandidates = routeCandidates;
        _currentPage = 0;
        attempt1Pending = a1;
        attempt2Pending = a2;
        isLoadingOngoing = false;
      });
    } catch (e) {
      debugPrint("Error fetching ongoing parcels: $e");
      setState(() => isLoadingOngoing = false);
    }
  }

   /// ✅ Apply filters for dropdown + search
  void applyFilters() {
    setState(() {
      final searchText = searchController.text.toLowerCase();

      filteredParcels = ongoingParcels.where((parcel) {
        final parcelId = (parcel['parcel_id'] ?? '').toString().toLowerCase();
        final attempt = (parcel['attempt'] ?? '');

        final matchesAttempt = dropdownValue == "All" || attempt == dropdownValue;

        final matchesSearch = parcelId.contains(searchText);

        return matchesAttempt && matchesSearch;
      }).toList();
      _currentPage = 0;
    });
  }

  bool _isAssignedToCurrentRider(Map<String, dynamic> item) {
    final riderId = widget.userId.trim();
    final candidates = [
      item['user_id'],
      item['assigned_rider'],
      item['assigned_rider_id'],
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.toString().trim() == riderId) {
        return true;
      }
    }
    return false;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _showStartDeliveryDialog() async {
    int tempSelection = _selectedDestinationLimit ?? 1;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Delivery',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose Number of destination',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Note: This is based from the nearest destination from current location',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<int>(
                      value: 1,
                      groupValue: tempSelection,
                      activeColor: const Color(0xFFD40000),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('1 destination (highly recommended)'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => tempSelection = value);
                      },
                    ),
                    RadioListTile<int>(
                      value: 5,
                      groupValue: tempSelection,
                      activeColor: const Color(0xFFD40000),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('5 destinations'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => tempSelection = value);
                      },
                    ),
                    RadioListTile<int>(
                      value: 10,
                      groupValue: tempSelection,
                      activeColor: const Color(0xFFD40000),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('10 destinations'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => tempSelection = value);
                      },
                    ),
                    RadioListTile<int>(
                      value: 0,
                      groupValue: tempSelection,
                      activeColor: const Color(0xFFD40000),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All destinations'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => tempSelection = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDestinationLimit = tempSelection;
                            });
                            Navigator.pop(context);
                            _startDeliveryFromSelection(tempSelection);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD40000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startDeliveryFromSelection(int selectedLimit) {
    if (_routeCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parcel destinations with coordinates found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final from = _currentLocation ?? _mapCenter;
    const distance = Distance();
    final sorted = List<Map<String, dynamic>>.from(_routeCandidates)
      ..sort((a, b) {
        final aPoint = LatLng(a['lat'] as double, a['lng'] as double);
        final bPoint = LatLng(b['lat'] as double, b['lng'] as double);
        final aMeters = distance.as(LengthUnit.Meter, from, aPoint);
        final bMeters = distance.as(LengthUnit.Meter, from, bPoint);
        return aMeters.compareTo(bMeters);
      });

    final count = selectedLimit == 0
        ? sorted.length
        : math.min(selectedLimit, sorted.length);
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available destinations for routing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final selected = sorted.take(count).toList();

    final parcelDestinations = selected.map((entry) {
      final parcelId = entry['parcel_id'].toString();
      final address = (entry['address'] ?? '').toString().trim();
      final label = address.isEmpty ? 'Parcel #$parcelId' : 'Parcel #$parcelId - $address';
      return <String, dynamic>{
        'name': label,
        'parcel_id': entry['parcel_id'],
        'lat': entry['lat'],
        'lng': entry['lng'],
      };
    }).toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          userId: widget.userId,
          liveLat: _currentLocation?.latitude ?? widget.liveLat,
          liveLng: _currentLocation?.longitude ?? widget.liveLng,
          initialDestinations: parcelDestinations,
        ),
      ),
    );
  }

  Future<void> _loadCurrentLocation() async {
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
      final nextCenter = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _mapCenter = nextCenter;
        _currentLocation = nextCenter;
      });
      _mapController.move(nextCenter, 15.0);
    } catch (e) {
      debugPrint('Error loading current location: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3E3E3), Color(0xFFD40000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // 🔴 Top header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF800000), Color(0xFFFF0000)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "On-going Parcels",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 📦 Page content
            Padding(
              padding: const EdgeInsets.only(top: 100.0),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _attemptSummaryCard(),
                  const SizedBox(height: 20),
                  _NavigationOnGoingParcelCard(), // 🗺️ Map Card
                  const SizedBox(height: 20),
                  _ongoingListCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Summary Card
  Widget _attemptSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Delivery Attempt",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text("Attempt 1 Pending",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(attempt1Pending.toString(),
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
              Column(
                children: [
                  const Text("Attempt 2 Pending",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(attempt2Pending.toString(),
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🗺️ Map Card (same setup as maps1.dart)
  Widget _NavigationOnGoingParcelCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Ongoing Parcels Maps",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: _showStartDeliveryDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD40000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Start Delivery",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 15.0,
                  minZoom: 10.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.avoid_app',
                    maxZoom: 18,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation ?? _mapCenter,
                        width: 44,
                        height: 44,
                        child: _buildGoogleStyleLocationDot(),
                      ),
                      ..._recipientMapPoints.map(
                        (entry) => Marker(
                          point: entry['point'] as LatLng,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 32,
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
  }

  /// ✅ List of ongoing parcels
/// ✅ List of ongoing parcels (with search + filter)
Widget _ongoingListCard() {
    final totalItems = filteredParcels.length;
    final totalPages =
        totalItems == 0 ? 1 : ((totalItems - 1) ~/ _itemsPerPage) + 1;
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final pageItems = totalItems == 0
        ? <Map<String, dynamic>>[]
        : filteredParcels.sublist(startIndex, endIndex);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "On-going Parcels",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 🔍 Search Bar
          TextField(
            controller: searchController,
            onChanged: (_) => applyFilters(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Search by Parcel ID...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ⬇️ Dropdown for filtering attempts
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Sort by: ",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: dropdownValue,
                items: const [
                  DropdownMenuItem(value: "All", child: Text("All")),
                  DropdownMenuItem(value: "Attempt 1", child: Text("Attempt 1")),
                  DropdownMenuItem(value: "Attempt 2", child: Text("Attempt 2")),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      dropdownValue = newValue;
                      _currentPage = 0;
                    });
                    applyFilters();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (isLoadingOngoing)
            const Center(child: CircularProgressIndicator())
          else if (pageItems.isEmpty)
            const Center(child: Text("No on-going parcels found"))
          else
            Column(
              children: pageItems
                  .map((parcel) => InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ParcelOngoingInformationPage(
                                parcelId: parcel['parcel_id'],
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        child: _onGoingRow(
                          parcel['parcel_id'].toString(),
                          parcel['name'],
                          parcel['attempt'],
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 10),
          if (!isLoadingOngoing && totalItems > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: safePage > 0
                      ? () => setState(() => _currentPage = safePage - 1)
                      : null,
                  child: const Text("Previous"),
                ),
                Text(
                  "Page ${safePage + 1} of $totalPages",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: safePage < totalPages - 1
                      ? () => setState(() => _currentPage = safePage + 1)
                      : null,
                  child: const Text("Next"),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _onGoingRow(String id, String customer, String attempt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: Colors.orange),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(customer,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          Text(
            attempt,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleStyleLocationDot() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ],
      ),
    );
  }
}
