import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main_screen/home_page_screen.dart';
import '../maps/screens/map_screen.dart';
import '../profile/profile_screen.dart';
import '../rules_and_violations/rules_and_violation_screen.dart';
import 'parcel_delivery_history.dart';
import 'parcel_ongoing.dart';

class ParcelsPage extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const ParcelsPage({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 3;

  List<Map<String, dynamic>> historyParcels = [];
  List<Map<String, dynamic>> ongoingParcels = [];

  bool isLoadingHistory = true;
  bool isLoadingOngoing = true;
  bool isLoadingToday = true;

  // ✅ Today summary counts
  int deliveredToday = 0;
  int ongoingToday = 0;
  int cancelledToday = 0;
  int dailyQuota = 0;

  @override
  void initState() {
    super.initState();
    fetchHistoryParcels();
    fetchOngoingParcels();
    fetchTodaySummary();
  }

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

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        _navigateWithTransition(
          HomePageScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 1:
        _navigateWithTransition(
          MapScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 2:
        _navigateWithTransition(
          RulesAndViolationScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 4:
        _navigateWithTransition(
          ProfileScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
    }
  }

  // ✅ Fetch today’s parcel summary
  Future<void> fetchTodaySummary() async {
    try {
      final response = await supabase.from('parcels').select('*');
      final List data = response as List;

      int delivered = 0;
      int ongoing = 0;
      int cancelled = 0;
      int quota = 0;

      String today =
          DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd

      for (var item in data) {
        String status = (item['status'] ?? '').toString().toLowerCase();
        String attempt1Status =
            (item['attempt1_status'] ?? '').toString().toLowerCase();
        String attempt2Status =
            (item['attempt2_status'] ?? '').toString().toLowerCase();

        String attempt1Date = (item['attempt1_date'] ?? '').toString();
        String attempt2Date = (item['attempt2_date'] ?? '').toString();

        // ✅ Delivered
        if (status == "successfully delivered") {
          if (attempt1Date.startsWith(today) ||
              attempt2Date.startsWith(today)) {
            delivered++;
            quota++; // quota counts delivered only
          }
        }

        // ✅ Ongoing
        else if (status == "on-going") {
          if (attempt1Status == "pending") {
            ongoing++;
          } else if (attempt1Status == "failed" &&
              attempt2Status == "pending") {
            ongoing++;
          }
        }

        // ✅ Cancelled
        else if (status == "cancelled") {
          if (attempt1Date.startsWith(today) ||
              attempt2Date.startsWith(today)) {
            cancelled++;
          }
        }
      }

      setState(() {
        deliveredToday = delivered;
        ongoingToday = ongoing;
        cancelledToday = cancelled;
        dailyQuota = quota;
        isLoadingToday = false;
      });
    } catch (e) {
      debugPrint("Error fetching today summary: $e");
      setState(() => isLoadingToday = false);
    }
  }

  // ✅ Fetch delivery history (only delivered & cancelled)
  Future<void> fetchHistoryParcels() async {
    try {
      final response = await supabase.from('parcels').select('*');
      final List data = response as List;

      List<Map<String, dynamic>> history = [];

      for (var item in data) {
        String status = item['status'] ?? '';
        String attempt1Status = item['attempt1_status'] ?? '';
        String attempt2Status = item['attempt2_status'] ?? '';

        if (status == "successfully delivered" || status == "cancelled") {
          String timestamp = "";

          if (attempt1Status == "success" || attempt1Status == "failed") {
            timestamp = item['attempt1_date'] ?? "";
          } else if (attempt2Status == "success" ||
              attempt2Status == "failed") {
            timestamp = item['attempt2_date'] ?? "";
          }

          history.add({
            "parcel_id": item['parcel_id'],
            "status":
                status == "successfully delivered" ? "Delivered" : "Cancelled",
            "timestamp": timestamp,
          });
        }
      }

      setState(() {
        history.sort(
            (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        historyParcels = history.take(3).toList();
        isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("Error fetching history parcels: $e");
      setState(() => isLoadingHistory = false);
    }
  }

  // ✅ Fetch ongoing parcels (attempt pending)
  Future<void> fetchOngoingParcels() async {
    try {
      final response = await supabase.from('parcels').select('*');
      final List data = response as List;

      List<Map<String, dynamic>> ongoing = [];

      for (var item in data) {
        String attempt1Status = item['attempt1_status'] ?? '';
        String attempt2Status = item['attempt2_status'] ?? '';

        String attempt = "";
        if (attempt1Status == "pending") {
          attempt = "Attempt 1";
        } else if (attempt2Status == "pending") {
          attempt = "Attempt 2";
        }

        if (attempt.isNotEmpty) {
          ongoing.add({
            "parcel_id": item['parcel_id'],
            "name": item['recipient_name'] ?? "Unknown",
            "attempt": attempt,
          });
        }
      }

      setState(() {
        ongoingParcels = ongoing.take(3).toList();
        isLoadingOngoing = false;
      });
    } catch (e) {
      debugPrint("Error fetching ongoing parcels: $e");
      setState(() => isLoadingOngoing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFD40000),
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
            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 240,
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
                        const SizedBox(width: 48),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "Parcels",
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

            // Page content
            Padding(
              padding: const EdgeInsets.only(top: 100.0),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _todayParcelCard(),
                  const SizedBox(height: 20),
                  _parcelHistoryCard(),
                  const SizedBox(height: 20),
                  _onGoingParcelCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 247, 139, 150),
              blurRadius: 40,
              spreadRadius: 10,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.grey.shade200,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.red,
            unselectedItemColor: Colors.black54,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.location_on), label: "Location"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.warning), label: "Rules"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping), label: "Parcels"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Today summary card (DB)
  Widget _todayParcelCard() {
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
      child: isLoadingToday
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Today",
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
                        const Text("Delivered Parcels",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(deliveredToday.toString(),
                            style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("On-going",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(ongoingToday.toString(),
                            style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("Cancelled Parcels",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(cancelledToday.toString(),
                            style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                    ),
                  ],
                ),
                const Divider(thickness: 1, color: Colors.grey),
                Column(
                  children: [
                    const Text("Daily Quota",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Text("Total Numbers of Parcels",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    Text("$dailyQuota/70",
                        style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
              ],
            ),
    );
  }

  // ✅ Parcel Delivery History (DB, 3 items only)
  Widget _parcelHistoryCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Parcel Delivery History",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DeliveryHistoryPage()));
                },
                child: const Text("View All",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (historyParcels.isEmpty)
            const Center(child: Text("No history available"))
          else
            Column(
              children: historyParcels
                  .map((parcel) => _historyRow(parcel['parcel_id'].toString(),
                      parcel['timestamp'] ?? "", parcel['status']))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _historyRow(String id, String date, String status) {
    final isDelivered = status == "Delivered";
    final statusColor = isDelivered ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: statusColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(date,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          Text(status,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor)),
        ],
      ),
    );
  }

  // ✅ On-going Parcels (DB, 3 items only)
  Widget _onGoingParcelCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("On-going Parcels",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ParcelOngoingPage(
                                userId: widget.userId,
                                liveLat: widget.liveLat,
                                liveLng: widget.liveLng,
                              )));
                },
                child: const Text("View All",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoadingOngoing)
            const Center(child: CircularProgressIndicator())
          else if (ongoingParcels.isEmpty)
            const Center(child: Text("No on-going parcels"))
          else
            Column(
              children: ongoingParcels
                  .map((parcel) => _onGoingRow(parcel['parcel_id'].toString(),
                      parcel['name'], parcel['attempt']))
                  .toList(),
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
          Text(attempt,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
        ],
      ),
    );
  }
}
