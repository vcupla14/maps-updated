import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login/login_screen.dart';
import '../main_screen/home_page_screen.dart';
import '../maps/screens/map_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 4;

  String username = "";
  String fname = "";
  String mname = "";
  String lname = "";
  String email = "";
  String gender = "";
  String age = "";
  String birthDate = "";
  String profileUrl = "";

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final response = await Supabase.instance.client
        .from('users')
        .select(
            'username, fname, mname, lname, email, gender, age, birth_date, profile_url')
        .eq('user_id', widget.userId)
        .maybeSingle();

    if (response != null) {
      setState(() {
        username = response['username'] ?? "";
        fname = response['fname'] ?? "";
        mname = response['mname'] ?? "";
        lname = response['lname'] ?? "";
        email = response['email'] ?? "";
        gender = response['gender'] ?? "";
        age = response['age']?.toString() ?? "";
        birthDate = response['birth_date'] ?? "";
        profileUrl = response['profile_url'] ?? "";
      });
    }
  }

  /// ✅ SMOOTH SLIDE + FADE TRANSITION
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Road Rules - Coming Soon')),
      );
      return;
    }
    if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Violation Fines - Coming Soon')),
      );
      return;
    }

    final bool slideLeft = index < _selectedIndex;
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, animation, __) =>
                HomePageScreen(
                  userId: widget.userId,
                  liveLat: widget.liveLat,
                  liveLng: widget.liveLng,
                ),
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
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, animation, __) =>
                MapScreen(
                  userId: widget.userId,
                  liveLat: widget.liveLat,
                  liveLng: widget.liveLng,
                ),
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
        break;
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client
        .from('users')
        .update({'status': 'offline'})
        .eq('user_id', widget.userId);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String getInitials() {
    String initials = "";
    if (fname.isNotEmpty) initials += fname[0];
    if (mname.isNotEmpty) initials += mname[0];
    if (lname.isNotEmpty) initials += lname[0];
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// 🔴 GRADIENT APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            "Profile",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF800000), Color(0xFFFF0000)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 🔴 PROFILE IMAGE WITH 1PX RED BORDER
            Container(
              padding: const EdgeInsets.all(1),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.red, width: 1),
                ),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: Colors.red.shade400,
                backgroundImage:
                    profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                child: profileUrl.isEmpty
                    ? Text(
                        getInitials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              username,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Personal Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            infoRow("Name", "$fname $mname $lname"),
            infoRow("Email", email),
            infoRow("Gender", gender),
            infoRow("Age", age),
            infoRow("Birthday", birthDate),

            const Spacer(),

            /// 🔴 LOGOUT BUTTON
            OutlinedButton(
              onPressed: logout,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                foregroundColor: Colors.red,
              ),
              child: const Text("Logout", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),

      /// 🔻 BOTTOM NAV
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
                  icon: Icon(Icons.attach_money), label: "Fines"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
