import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ParcelOngoingInformationPage extends StatefulWidget {
  final int parcelId;
  final String userId;

  const ParcelOngoingInformationPage({
    super.key,
    required this.parcelId,
    required this.userId,
  });

  @override
  State<ParcelOngoingInformationPage> createState() =>
      _ParcelOngoingInformationPageState();
}

class _ParcelOngoingInformationPageState
    extends State<ParcelOngoingInformationPage> {
  bool isLoading = true;
  Map<String, dynamic>? parcelDetails;
  final ImagePicker _picker = ImagePicker();
  String? _proofImageUrl;
  bool _isUploadingImage = false;
  bool _isSubmittingStatus = false;

  bool get _canSubmitActions =>
      _proofImageUrl != null && !_isUploadingImage && !_isSubmittingStatus;

  bool get _showMoveToAttempt2Button {
    if (parcelDetails == null) return false;
    final attempt1 =
        (parcelDetails!['attempt1_status'] ?? '').toString().toLowerCase();
    final attempt2 =
        (parcelDetails!['attempt2_status'] ?? '').toString().toLowerCase();
    return attempt1 == 'pending' && attempt2 != 'pending';
  }

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

      if (!mounted) return;
      if (response != null) {
        setState(() {
          parcelDetails = response;
          _proofImageUrl = (response['parcel_image_proof'] ?? '').toString().trim().isEmpty
              ? null
              : (response['parcel_image_proof'] ?? '').toString().trim();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching parcel details: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
      body: Container(
        height: double.infinity, // ⬅️ ensure background covers full screen
        width: double.infinity,
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

            // Content
            Padding(
              padding: const EdgeInsets.only(top: 120.0),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : parcelDetails == null
                      ? const Center(child: Text("No details found"))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(15),
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
                                _parcelIdSection(parcelDetails!['parcel_id']),
                                _divider(),
                                _infoSection(
                                    "Ship to:",
                                    "Name: ${parcelDetails!['recipient_name']}\n"
                                        "Address: ${parcelDetails!['address']}\n"
                                        "Phone: ${parcelDetails!['recipient_phone']}"),
                                _divider(),
                                _infoSection(
                                    "From sender:",
                                    "Name: ${parcelDetails!['sender_name']}\n"
                                        "Phone: ${parcelDetails!['sender_phone']}"),
                                _divider(),
                                _attemptSection(parcelDetails!),
                                _divider(),
                                const Text(
                                  "Proof of Delivery:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _isUploadingImage ? null : _showImageSourcePicker,
                                  child: Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildProofImageContent(),
                                  ),
                                )),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            _canSubmitActions ? () => _updateParcelStatus(delivered: false) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text(
                                          "Cancel Parcel",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            _canSubmitActions ? () => _updateParcelStatus(delivered: true) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text(
                                          "Deliver Parcel",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_showMoveToAttempt2Button) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _isSubmittingStatus
                                          ? null
                                          : _pickDateAndMoveToAttempt2,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                          width: 1.6,
                                        ),
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        "Mark as Delay (Move to Attempt 2)",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildProofImageContent() {
    if (_isUploadingImage) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_proofImageUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _proofImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Failed to load image'),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              color: Colors.black54,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Change',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 36),
          SizedBox(height: 4),
          Text("Add Image"),
        ],
      ),
    );
  }

  Future<void> _showImageSourcePicker() async {
    if (_isUploadingImage) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Use Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Upload Image'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (!mounted) return;
      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName =
          'proof_${widget.parcelId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '${widget.userId}/${widget.parcelId}/$fileName';

      String contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'webp') contentType = 'image/webp';

      await Supabase.instance.client.storage
          .from('parcel_proof')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('parcel_proof')
          .getPublicUrl(storagePath);

      await Supabase.instance.client.from('parcels').update({
        'parcel_image_proof': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('parcel_id', widget.parcelId);

      if (!mounted) return;
      setState(() {
        _proofImageUrl = publicUrl;
      });
    } catch (e) {
      debugPrint('Image upload failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _updateParcelStatus({required bool delivered}) async {
    if (!_canSubmitActions || parcelDetails == null) return;

    final attempt1 = (parcelDetails!['attempt1_status'] ?? '').toString().toLowerCase();
    final attempt2 = (parcelDetails!['attempt2_status'] ?? '').toString().toLowerCase();
    final now = DateTime.now().toIso8601String();

    final updates = <String, dynamic>{
      'status': delivered ? 'successfully delivered' : 'cancelled',
      'parcel_image_proof': _proofImageUrl,
      'updated_at': now,
    };

    if (attempt1 == 'pending') {
      updates['attempt1_status'] = delivered ? 'success' : 'failed';
      updates['attempt1_date'] = now;
    } else if (attempt2 == 'pending') {
      updates['attempt2_status'] = delivered ? 'success' : 'failed';
      updates['attempt2_date'] = now;
    }

    try {
      setState(() => _isSubmittingStatus = true);

      await Supabase.instance.client
          .from('parcels')
          .update(updates)
          .eq('parcel_id', widget.parcelId);

      if (!mounted) return;
      await fetchParcelDetails();
      if (!mounted) return;
      await _showStatusModal(
        title: delivered ? 'Parcel delivered' : 'Parcel cancelled',
        icon: delivered ? Icons.check_circle_outline : Icons.cancel_outlined,
        iconColor: delivered ? Colors.green : Colors.red,
        buttonColor: delivered ? Colors.green : Colors.red,
      );
    } catch (e) {
      debugPrint('Update failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmittingStatus = false);
    }
  }

  Future<void> _moveToAttempt2() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Pick date for attempt 2',
    );
    if (pickedDate == null) return;

    await _moveToAttempt2WithDate(pickedDate);
  }

  Future<void> _pickDateAndMoveToAttempt2() async {
    await _moveToAttempt2();
  }

  Future<void> _moveToAttempt2WithDate(DateTime attempt2Date) async {
    if (parcelDetails == null || !_showMoveToAttempt2Button) return;

    final now = DateTime.now().toIso8601String();
    try {
      setState(() => _isSubmittingStatus = true);

      await Supabase.instance.client.from('parcels').update({
        'attempt1_status': 'failed',
        'attempt1_date': now,
        'attempt2_status': 'pending',
        'attempt2_date': attempt2Date.toIso8601String(),
        'updated_at': now,
      }).eq('parcel_id', widget.parcelId);

      if (!mounted) return;
      await fetchParcelDetails();
      if (!mounted) return;
      await _showStatusModal(
        title: 'Attempt 2 scheduled',
        icon: Icons.event_available_outlined,
        iconColor: Colors.green,
        buttonColor: Colors.green,
      );
    } catch (e) {
      debugPrint('Update failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmittingStatus = false);
    }
  }

  Future<void> _showStatusModal({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color buttonColor,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 60),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop(true);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: buttonColor,
                      side: BorderSide(color: buttonColor, width: 1.6),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Go back to Parcel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Parcel ID section (Big + Bold number)
  Widget _parcelIdSection(dynamic parcelId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Parcel ID:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            parcelId.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _attemptSection(Map<String, dynamic> data) {
    String attemptText = "Pending";
    Color attemptColor = Colors.orange;
    IconData attemptIcon = Icons.hourglass_empty; // ⏳ default for pending

    final attempt1 = (data['attempt1_status'] ?? '').toString().toLowerCase();
    final attempt2 = (data['attempt2_status'] ?? '').toString().toLowerCase();

    if (attempt1 == "success" || attempt1 == "delivered") {
      attemptText = "Attempt 1 (Delivered)";
      attemptColor = Colors.green;
      attemptIcon = Icons.check_circle_outline;
    } else if (attempt2 == "success" || attempt2 == "delivered") {
      attemptText = "Attempt 2 (Delivered)";
      attemptColor = Colors.green;
      attemptIcon = Icons.check_circle_outline;
    } else if (attempt1 == "pending") {
      attemptText = "Attempt 1 (Pending)";
      attemptColor = Colors.orange;
      attemptIcon = Icons.hourglass_empty;
    } else if ((attempt1 == "failed" || attempt1 == "cancel") &&
        attempt2 == "pending") {
      attemptText = "Attempt 2 (Pending)";
      attemptColor = Colors.orange;
      attemptIcon = Icons.hourglass_empty;
    } else if ((attempt1 == "failed" || attempt1 == "cancel") &&
        (attempt2 == "failed" || attempt2 == "cancel")) {
      attemptText = "Both Attempts Failed";
      attemptColor = Colors.red;
      attemptIcon = Icons.cancel;
    }

    return Row(
      children: [
        Icon(attemptIcon, color: attemptColor),
        const SizedBox(width: 8),
        Text(
          attemptText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: attemptColor,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Divider(color: Colors.grey, height: 4),
    );
  }
}
