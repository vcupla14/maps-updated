import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelInformationPage extends StatefulWidget {
  final int parcelId;

  const ParcelInformationPage({super.key, required this.parcelId});

  @override
  State<ParcelInformationPage> createState() => _ParcelInformationPageState();
}

class _ParcelInformationPageState extends State<ParcelInformationPage> {
  bool isLoading = true;
  Map<String, dynamic>? parcelDetails;

  @override
  void initState() {
    super.initState();
    fetchParcelDetails();
  }

  Future<void> fetchParcelDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('parcels')
          .select()
          .eq('parcel_id', widget.parcelId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          parcelDetails = response;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching parcel details: $e");
      setState(() => isLoading = false);
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
                              "Parcel Information",
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

            // 📦 Page Content
            Padding(
              padding: const EdgeInsets.only(top: 120.0),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : parcelDetails == null
                      ? const Center(child: Text("No details found"))
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildParcelInfoCard(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📦 Main Parcel Information Card
  Widget _buildParcelInfoCard() {
    final attempt1 = parcelDetails!['attempt1_status'];
    final attempt2 = parcelDetails!['attempt2_status'];
    final updatedAt = parcelDetails!['updated_at'] ?? "N/A";

    String attemptLabel = "No successful attempt";
    IconData attemptIcon = Icons.cancel_outlined;
    Color attemptColor = const Color.fromARGB(255, 248, 0, 0);

    if (attempt1 == "success") {
      attemptLabel = "Attempt 1 Success";
      attemptIcon = Icons.check_circle_outline;
      attemptColor = Colors.green;
    } else if (attempt2 == "success") {
      attemptLabel = "Attempt 2 Success";
      attemptIcon = Icons.check_circle_outline;
      attemptColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Parcel ID
          _sectionTitle("Parcel ID:"),
          Text(
            parcelDetails!['parcel_id'].toString(),
            style: const TextStyle(
              fontSize: 24, // 🔥 Increased from 18 → 24
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(),

          // Ship To
          _sectionTitle("Ship To:"),
          Text("Name: ${parcelDetails!['recipient_name'] ?? "N/A"}"),
          Text("Address: ${parcelDetails!['address'] ?? "N/A"}"),
          Text("Phone Number: ${parcelDetails!['recipient_phone'] ?? "N/A"}"),
          const Divider(),

          // From Sender
          _sectionTitle("From Sender:"),
          Text("Name: ${parcelDetails!['sender_name'] ?? "N/A"}"),
          Text("Phone Number: ${parcelDetails!['sender_phone'] ?? "N/A"}"),
          const Divider(),

          // Attempt & Delivered Date
          _sectionTitle("Attempt:"),
          Row(
            children: [
              Icon(attemptIcon, color: attemptColor),
              const SizedBox(width: 8),
              Text(attemptLabel,
                  style: TextStyle(
                      color: attemptColor, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text("Delivered Date: $updatedAt"),
          const Divider(),

          // Proof of Delivery
          _sectionTitle("Proof of Delivery"),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: const Center(
              child: Text("Proof of Delivery (Static Placeholder)"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
    );
  }
}
