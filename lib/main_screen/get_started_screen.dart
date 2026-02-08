import 'package:flutter/material.dart';
import '../profile/personal_information_screen.dart'; // <-- import personal info screen

class GetStartedScreen extends StatefulWidget {
  final String userId; // <-- receive userId
  final double? liveLat;
  final double? liveLng;

  const GetStartedScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo2.png',
                        width: 300,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Ride Safe, Ride Smart,\nAvoid Delays",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Image.asset(
                          'assets/images/motor_logo.png',
                          height: MediaQuery.of(context).size.height * 0.4,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 50),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () {
                          // Navigate to PersonalInformationScreen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalInformationScreen(
                                userId: widget.userId,
                                liveLat: widget.liveLat,
                                liveLng: widget.liveLng,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "Get Started",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
