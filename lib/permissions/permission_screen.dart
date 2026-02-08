import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_screen/get_started_screen.dart';

class PermissionsScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const PermissionsScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _termsAccepted = false;
  bool _locationGranted = false;
  bool _loading = false;

  final SupabaseClient supabase = Supabase.instance.client;

  /// REQUEST LOCATION PERMISSION
  Future<void> _requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      setState(() => _locationGranted = true);
    }
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  /// CONTINUE FLOW
  Future<void> _continue() async {
    if (!_termsAccepted || !_locationGranted) return;

    setState(() => _loading = true);

    try {
      // ✅ Update terms, location, and mark user as not new
      await supabase.from('users').update({
        'terms_accepted': true,
        'location_granted': true,
        'new_user': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', widget.userId);

      if (!mounted) return;

      // 🔹 Navigate to GetStartedScreen with userId
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GetStartedScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving permissions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF800000), Color(0xFFFF0000)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          title: const Text(
            'Permissions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // 🔹 Policy Box scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'J&T Rider Policy & Privacy',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Welcome J&T rider! Please follow the guidelines below:\n\n'
                        '- Always wear proper safety gear.\n'
                        '- Follow traffic rules.\n'
                        '- Handle parcels with care.\n'
                        '- Deliver on time and maintain professionalism.\n'
                        '- Keep your location on for real-time tracking.\n\n'
                        'Privacy: All important information about you and the deliveries '
                        'is handled strictly within the company. Your personal information '
                        'is safe and protected under company policies.\n\n'
                        'By accepting, you agree to follow all the above rules.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16), // Small spacing before bottom

            // 🔹 Bottom Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (value) {
                    setState(() => _termsAccepted = value ?? false);
                  },
                  title: const Text(
                    'I agree to the Legal & Policy Terms',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _locationGranted,
                  onChanged: (_) => _requestLocation(),
                  title: const Text(
                    'Allow Location Access',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_termsAccepted && _locationGranted && !_loading)
                        ? _continue
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CONTINUE',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

    );
  }
}
