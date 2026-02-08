import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reg_success_screen.dart';
import 'package:bcrypt/bcrypt.dart';

class Reg2Screen extends StatefulWidget {
  final String username;
  final String password;
  final String email;

  const Reg2Screen({
    super.key,
    required this.username,
    required this.password,
    required this.email,
  });

  @override
  State<Reg2Screen> createState() => _Reg2ScreenState();
}

class _Reg2ScreenState extends State<Reg2Screen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        timer.cancel();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_remainingSeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification code has expired.")),
      );
      return;
    }

    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit code.")),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('email_verification')
          .select('verification_code, created_at')
          .eq('email', widget.email)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification record not found.")),
        );
        return;
      }

      final dbCode = response['verification_code'].toString();
      final createdAt = DateTime.parse(response['created_at']);
      final expirationTime = createdAt.add(const Duration(minutes: 5));

      if (DateTime.now().isAfter(expirationTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification code has expired.")),
        );
        return;
      }

      if (code != dbCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid verification code.")),
        );
        return;
      }

      // 🔐 HASH PASSWORD
      final hashedPassword = BCrypt.hashpw(
        widget.password,
        BCrypt.gensalt(),
      );

      // ✅ INSERT USER (all required fields)
      await Supabase.instance.client.from('users').insert({
        'username': widget.username,
        'password': hashedPassword,
        'email': widget.email,
        'doj': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
        'new_user': true,
        'status': 'offline',
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegSuccessScreen(
            username: widget.username,
            password: widget.password,
            email: widget.email,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error verifying code: $e")),
      );
    }
  }

  void _resendCode() {
    setState(() {
      _remainingSeconds = 300;
    });
    _timer?.cancel();
    _startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Verification code resent to ${widget.email}")),
    );
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

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F3F3),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "EMAIL VERIFICATION",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "Enter the 6-digit code sent to ${widget.email}",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // 🔢 Code fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 40,
                            child: TextField(
                              controller: _codeControllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                              decoration: const InputDecoration(
                                counterText: "",
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 15),

                    // ⏱ Timer
                    Text(
                      _remainingSeconds > 0
                          ? "Code expires in ${_formatTime(_remainingSeconds)}"
                          : "Code expired",
                      style: TextStyle(
                        color:
                            _remainingSeconds > 0 ? Colors.black : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Verify Button
                    OutlinedButton(
                      onPressed:
                          _remainingSeconds > 0 ? _verifyCode : null,
                      child: const Text("Verify"),
                    ),

                    const SizedBox(height: 30),

                    // 🔁 Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Didn't receive the code? "),
                        GestureDetector(
                          onTap: _resendCode,
                          child: const Text(
                            "Resend it",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
