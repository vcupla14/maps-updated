import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_screen/home_page_screen.dart';
import '../function/email_service.dart';
import '../function/location_sync_service.dart';

class Login2Screen extends StatefulWidget {
  final String username;
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const Login2Screen({
    super.key,
    required this.username,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<Login2Screen> createState() => _Login2ScreenState();
}

class _Login2ScreenState extends State<Login2Screen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 300;

  bool _verified = false;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _showSuccess = false;

  String? _email;

  @override
  void initState() {
    super.initState();
    _initVerification();
  }

  // 🔁 Initialize OTP
  Future<void> _initVerification() async {
    setState(() => _isSending = true);

    try {
      final user = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('username', widget.username)
          .maybeSingle();

      if (user == null) {
        _showSnack("User not found");
        return;
      }

      _email = user['email'];

      final emailService = EmailService();
      await emailService.sendAndStoreCode(_email!);

      _startTimer();
    } catch (e) {
      _showSnack("Error sending code: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  // ⏱ Timer
  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = 300;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ✅ Verify Code
  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showSnack("Enter a valid 6-digit code");
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final record = await Supabase.instance.client
          .from('email_verification')
          .select('verification_code, expiration_time')
          .eq('email', _email!)
          .order('verification_id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (record == null) {
        _showSnack("Verification record not found");
        return;
      }

      final expiration =
          DateTime.parse(record['expiration_time']);

      if (DateTime.now().isAfter(expiration)) {
        _showSnack("Verification code has expired");
        return;
      }

      if (record['verification_code'].toString() != code) {
        _showSnack("Invalid verification code");
        return;
      }

      // ⏳ Loading delay
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _verified = true;
        _showSuccess = true;
      });

      _timer?.cancel();
    } catch (e) {
      _showSnack("Verification error: $e");
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  // 🚀 Proceed
  Future<void> _proceedToHome() async {
    await Supabase.instance.client.from('users').update({
      'status': 'online',
      'last_active': DateTime.now().toIso8601String(),
      'last_seen_lat': widget.liveLat,
      'last_seen_lng': widget.liveLng,
    }).eq('user_id', widget.userId);
    await LocationSyncService.instance.start(widget.userId);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePageScreen(
          userId: widget.userId,
          liveLat: widget.liveLat,
          liveLng: widget.liveLng,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _codeControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔴 Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFF800000),
                  Colors.black,
                  Color(0xFF800000),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),

          // 🔴 Logo
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Image.asset(
                'assets/images/logo2.png',
                width: 270,
                height: 100,
              ),
            ),
          ),

          // ⚪ Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F3F3),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "EMAIL VERIFICATION",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _email != null
                        ? "Enter the 6-digit code sent to $_email"
                        : "Sending verification code...",
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // 🔢 OTP Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: 40,
                          child: TextField(
                            controller: _codeControllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                counterText: ""),
                            onChanged: (v) {
                              if (v.isNotEmpty && i < 5) {
                                _focusNodes[i + 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 15),

                  // ⏱ Timer OR Success Text
                  if (_showSuccess)
                    const Text(
                      "Verification successful",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    )
                  else
                    Text(
                      _remainingSeconds > 0
                          ? "Code expires in ${_formatTime(_remainingSeconds)}"
                          : "Code expired",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds > 0
                            ? Colors.black
                            : Colors.red,
                      ),
                    ),

                  const SizedBox(height: 25),

                  // 🔘 Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isSending || _isVerifying)
                          ? null
                          : (_verified
                              ? _proceedToHome
                              : _verifyCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _verified ? Colors.red : null,
                        foregroundColor:
                            _verified ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _verified
                                  ? "PROCEED TO HOME PAGE"
                                  : "VERIFY",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
