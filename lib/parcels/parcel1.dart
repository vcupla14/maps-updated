import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool isLoadingUser = true;
  String riderFirstName = 'Rider';

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
    fetchRiderName();
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

      for (var item in data) {
        if (!_isAssignedToCurrentRider(item)) continue;
        final status = (item['status'] ?? '').toString().toLowerCase();
        final attempt1Status =
            (item['attempt1_status'] ?? '').toString().toLowerCase();
        final attempt2Status =
            (item['attempt2_status'] ?? '').toString().toLowerCase();

        final attempt1Date = (item['attempt1_date'] ?? '').toString();
        final attempt2Date = (item['attempt2_date'] ?? '').toString();

        final deliveredTodayByAttempt1 =
            attempt1Status == 'success' && isSameDay(attempt1Date);
        final deliveredTodayByAttempt2 =
            attempt2Status == 'success' && isSameDay(attempt2Date);

        final cancelledTodayByAttempt1 =
            attempt1Status == 'failed' && isSameDay(attempt1Date);
        final cancelledTodayByAttempt2 =
            attempt2Status == 'failed' && isSameDay(attempt2Date);

        if (status == 'successfully delivered') {
          if (deliveredTodayByAttempt1 || deliveredTodayByAttempt2) {
            delivered++;
            quota++;
          }
        } else if (status == 'on-going') {
          if (attempt1Status == 'pending' ||
              (attempt1Status == 'failed' && attempt2Status == 'pending')) {
            ongoing++;
          }
        } else if (status == 'cancelled') {
          if (cancelledTodayByAttempt1 || cancelledTodayByAttempt2) {
            cancelled++;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        deliveredToday = delivered;
        ongoingToday = ongoing;
        cancelledToday = cancelled;
        dailyQuota = quota;
        isLoadingToday = false;
      });
    } catch (e) {
      debugPrint('Error fetching today summary: $e');
      if (!mounted) return;
      setState(() => isLoadingToday = false);
    }
  }

  Future<void> fetchRiderName() async {
    try {
      final response = await supabase
          .from('users')
          .select('fname')
          .eq('user_id', widget.userId)
          .maybeSingle();
      if (!mounted) return;
      final fname = (response?['fname'] ?? '').toString().trim();
      setState(() {
        riderFirstName = fname.isNotEmpty ? fname : 'Rider';
        isLoadingUser = false;
      });
    } catch (e) {
      debugPrint("Error fetching rider name: $e");
      if (!mounted) return;
      setState(() => isLoadingUser = false);
    }
  }

  String _timeGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    if ((hour >= 5 && hour < 12) || (hour == 12 && minute == 0)) {
      return 'Good Morning';
    }
    if ((hour == 12 && minute > 0) || (hour > 12 && hour < 18)) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  bool isSameDay(String rawDate) {
    if (rawDate.isEmpty) return false;
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;

    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  bool _isAssignedToCurrentRider(Map<String, dynamic> item) {
    final riderId = widget.userId.trim().toLowerCase();
    final candidates = [
      item['user_id'],
      item['assigned_rider'],
      item['assigned_rider_id'],
    ];
    for (final candidate in candidates) {
      if (candidate != null &&
          candidate.toString().trim().toLowerCase() == riderId) {
        return true;
      }
    }
    return false;
  }

  // ✅ Fetch delivery history (only delivered & cancelled)
  Future<void> fetchHistoryParcels() async {
    try {
      final response = await supabase
          .from('parcels')
          .select('*')
          .eq('assigned_rider_id', widget.userId)
          .inFilter('status', ['successfully delivered', 'cancelled']);
      final List data = response as List;

      List<Map<String, dynamic>> history = [];

      for (var item in data) {
        String timestamp = "";
        if (item['attempt2_date'] != null) {
          timestamp = item['attempt2_date'].toString();
        } else if (item['attempt1_date'] != null) {
          timestamp = item['attempt1_date'].toString();
        }

        history.add({
          "parcel_id": item['parcel_id'],
          "status":
              item['status'] == "successfully delivered" ? "Delivered" : "Cancelled",
          "timestamp": timestamp,
        });
      }

      if (!mounted) return;
      setState(() {
        history.sort((a, b) {
          final aTime = DateTime.tryParse((a['timestamp'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse((b['timestamp'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        historyParcels = history.take(3).toList();
        isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("Error fetching history parcels: $e");
      if (!mounted) return;
      setState(() => isLoadingHistory = false);
    }
  }

  // ✅ Fetch ongoing parcels (attempt pending)
  Future<void> fetchOngoingParcels() async {
    try {
      final response = await supabase
          .from('parcels')
          .select('*')
          .order('created_at', ascending: false);
      final List data = response as List;

      List<Map<String, dynamic>> ongoing = [];

      for (var item in data) {
        if (!_isAssignedToCurrentRider(item)) continue;
        final status = (item['status'] ?? '').toString().toLowerCase();
        if (status != 'on-going') continue;

        final attempt1Status =
            (item['attempt1_status'] ?? '').toString().toLowerCase();
        final attempt2Status =
            (item['attempt2_status'] ?? '').toString().toLowerCase();

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

      if (!mounted) return;
      setState(() {
        ongoingParcels = ongoing.take(3).toList();
        isLoadingOngoing = false;
      });
    } catch (e) {
      debugPrint("Error fetching ongoing parcels: $e");
      if (!mounted) return;
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
                                fontSize: 20,
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
                  _onGoingParcelCard(),
                  const SizedBox(height: 20),
                  _parcelHistoryCard(),
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
    final greetingName = isLoadingUser ? '...' : riderFirstName;
    final dateLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final totalForStatus = deliveredToday + ongoingToday + cancelledToday;
    final deliveredFlex = totalForStatus == 0
        ? 0
        : ((deliveredToday / totalForStatus) * 1000).round();
    final ongoingFlex = totalForStatus == 0
        ? 0
        : ((ongoingToday / totalForStatus) * 1000).round();
    final notDeliveredFlex = totalForStatus == 0
        ? 0
        : ((cancelledToday / totalForStatus) * 1000).round();
    final quotaProgress = (dailyQuota / 70).clamp(0.0, 1.0);

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
                Text(
                  '${_timeGreeting()}, $greetingName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Today ",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 14,
                    child: totalForStatus == 0
                        ? Container(color: Colors.black12)
                        : Row(
                            children: [
                              Expanded(
                                flex: deliveredFlex > 0 ? deliveredFlex : 1,
                                child: Container(color: Colors.green),
                              ),
                              Expanded(
                                flex: ongoingFlex > 0 ? ongoingFlex : 1,
                                child: Container(color: Colors.orange),
                              ),
                              Expanded(
                                flex:
                                    notDeliveredFlex > 0 ? notDeliveredFlex : 1,
                                child: Container(color: Colors.red),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusLegendItem(color: Colors.green, label: "Delivered"),
                    _statusLegendItem(color: Colors.orange, label: "On-going"),
                    _statusLegendItem(color: Colors.red, label: "Not Delivered"),
                  ],
                ),
                const SizedBox(height: 12),
                _dailyQuotaSemiCircle(quotaProgress),
              ],
            ),
    );
  }

  // ✅ Parcel Delivery History (DB, 3 items only)
  Widget _statusLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _dailyQuotaSemiCircle(double progress) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 64),
            painter: _SemiCircleProgressPainter(
              progress: progress,
              trackColor: const Color(0xFFD9D9D9),
              progressColor: Colors.green,
              strokeWidth: 6,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Text(
              "Quota\n${dailyQuota.toString().padLeft(2, '0')}/70",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              DeliveryHistoryPage(userId: widget.userId)));
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
    final statusLabel = isDelivered ? "Delivered" : "Not Delivered";
    final parsed = DateTime.tryParse(date);
    final displayDate = parsed != null
        ? DateFormat('MMM d • h:mm a').format(parsed.toLocal())
        : date;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, size: 18, color: statusColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Parcel #$id",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(displayDate,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          Text(statusLabel,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ParcelOngoingPage(
                                userId: widget.userId,
                                liveLat: widget.liveLat,
                                liveLng: widget.liveLng,
                              )));
                  if (!mounted) return;
                  fetchTodaySummary();
                  fetchOngoingParcels();
                  fetchHistoryParcels();
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
              const Icon(Icons.inventory_2, size: 18, color: Colors.orange),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Parcel #$id",
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

class _SemiCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _SemiCircleProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    if (p > 0) {
      canvas.drawArc(rect, math.pi, math.pi * p, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SemiCircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
