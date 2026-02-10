import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'parcel_information.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  static const int _itemsPerPage = 10;
  bool isLoadingHistory = true;
  List<Map<String, dynamic>> historyParcels = [];

  int deliveredCount = 0;
  int cancelledCount = 0;

  @override
  void initState() {
    super.initState();
    fetchHistoryParcels();
  }

  Future<void> fetchHistoryParcels() async {
    try {
      final response =
          await Supabase.instance.client.from('parcels').select('*');
      final List data = response as List;

      List<Map<String, dynamic>> history = [];
      int delivered = 0;
      int cancelled = 0;

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

          // ✅ Count totals
          if (status == "successfully delivered") {
            delivered++;
          } else if (status == "cancelled") {
            cancelled++;
          }
        }
      }

      // ✅ Update state so UI refreshes
      setState(() {
        history.sort(
            (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        historyParcels = history;
        deliveredCount = delivered;
        cancelledCount = cancelled;
        isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("Error fetching history parcels: $e");
      setState(() => isLoadingHistory = false);
    }
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
            // 🔴 Top gradient header
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
                              "Delivery History",
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
                  _historyParcelCard(),
                  const SizedBox(height: 20),
                  _parcelHistoryCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ TOTAL SUMMARY CARD (Dynamic from DB)
  Widget _historyParcelCard() {
    final total = deliveredCount + cancelledCount;

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
            "Total History of Parcel",
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
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(deliveredCount.toString(),
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ],
              ),
              Column(
                children: [
                  const Text("Total",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(total.toString(),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              Column(
                children: [
                  const Text("Cancelled Parcels",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(cancelledCount.toString(),
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

  /// ✅ HISTORY LIST CARD
  Widget _parcelHistoryCard() {
    String searchQuery = '';
    String sortFilter = 'All';
    int currentPage = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        final visibleParcels = historyParcels
            .where((parcel) =>
                parcel['parcel_id']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) &&
                (sortFilter == 'All' ||
                    parcel['status'].toString().toLowerCase() ==
                        sortFilter.toLowerCase()))
            .toList();

        final totalItems = visibleParcels.length;
        final totalPages =
            totalItems == 0 ? 1 : ((totalItems - 1) ~/ _itemsPerPage) + 1;
        final safePage = currentPage.clamp(0, totalPages - 1);
        final startIndex = safePage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
        final pageItems = totalItems == 0
            ? <Map<String, dynamic>>[]
            : visibleParcels.sublist(startIndex, endIndex);

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
                "Parcel Delivery History",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                          currentPage = 0;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search by Parcel ID...',
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: sortFilter,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['All', 'Delivered', 'Cancelled']
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            sortFilter = value;
                            currentPage = 0;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (pageItems.isEmpty)
                const Center(child: Text("No matching parcels found"))
              else
                Column(
                  children: pageItems
                      .map((parcel) => _historyRow(
                            parcel['parcel_id'].toString(),
                            parcel['timestamp'] ?? "",
                            parcel['status'],
                          ))
                      .toList(),
                ),
              const SizedBox(height: 10),
              if (!isLoadingHistory && totalItems > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: safePage > 0
                          ? () => setState(() => currentPage = safePage - 1)
                          : null,
                      child: const Text("Previous"),
                    ),
                    Text(
                      "Page ${safePage + 1} of $totalPages",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: safePage < totalPages - 1
                          ? () => setState(() => currentPage = safePage + 1)
                          : null,
                      child: const Text("Next"),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyRow(String id, String date, String status) {
    final isDelivered = status == "Delivered";
    final statusColor = isDelivered ? Colors.green : Colors.red;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ParcelInformationPage(parcelId: int.parse(id)),
          ),
        );
      },
      child: Padding(
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
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
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
      ),
    );
  }
}

