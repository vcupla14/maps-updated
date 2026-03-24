import 'package:flutter/material.dart';
import '../parcels/parcel1.dart';
import '../profile/profile_screen.dart';
import '../maps/screens/map_screen.dart';
import '../rules_and_violations/rules_and_violation_screen.dart';

class HomePageScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const HomePageScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  int _selectedIndex = 0;

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
    // Navigate to different screens based on index
    switch (index) {
      case 0: // Home - Already here
        break;
      case 1: // Location (Maps)
        _navigateWithTransition(
          MapScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 2: // Rules
        _navigateWithTransition(
          RulesAndViolationScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 3: // Fines
        _navigateToParcels();
        break;
      case 4: // Profile
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

  void _navigateToMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          userId: widget.userId,
          liveLat: widget.liveLat,
          liveLng: widget.liveLng,
        ),
      ),
    );
  }

  void _navigateToParcels() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => ParcelsPage(userId: widget.userId, liveLat: widget.liveLat, liveLng: widget.liveLng),
        transitionsBuilder: (_, animation, __, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
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

  void _navigateToRoadRules() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => RulesAndViolationScreen(
          userId: widget.userId,
          liveLat: widget.liveLat,
          liveLng: widget.liveLng,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
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

void _navigateToViolationFines() {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, animation, __) => RulesAndViolationScreen(
        userId: widget.userId,
        liveLat: widget.liveLat,
        liveLng: widget.liveLng,
        initialTab: 1,  // 👈 THIS SETS IT TO VIOLATION FINES TAB
      ),
      transitionsBuilder: (_, animation, __, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.15, 0),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Bigger Top Circle
          Positioned(
            top: -420,
            left: -100,
            right: -100,
            child: Container(
              height: 800,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF800000),
                    Color(0xFF800000),
                    Color(0xFFFF0000),
                    Color(0xFFFF0000),
                  ],
                  stops: [0.20, 0.50, 0.70, 1.0],
                ),
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 350.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image(
                        image: AssetImage('assets/images/logo2.png'),
                        width: 250,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        "Ride Safe. Ride Smart.\nAvoid Delays",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Menu Buttons (SCROLLABLE)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 200),
                    _buildMenuButton(context, "Maps", _navigateToMaps),
                    const SizedBox(height: 20),
                    _buildMenuButton(context, "Parcels", _navigateToParcels),
                    const SizedBox(height: 20),
                    _buildMenuButton(context, "Road Rules", _navigateToRoadRules),
                    const SizedBox(height: 20),
                    _buildMenuButton(context, "Violation Fines", _navigateToViolationFines),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Location"),
              BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Rules"),
              BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: "Parcels"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          side: const BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          foregroundColor: Colors.red,
          backgroundColor: Colors.white,
          shadowColor: Colors.black,
          elevation: 3,
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

