import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login/login_screen.dart';
import '../main_screen/home_page_screen.dart';
import '../maps/screens/map_screen.dart';
import '../parcels/parcel1.dart';
import '../rules_and_violations/rules_and_violation_screen.dart';

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

    if (!mounted) return;
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
  void _openParcelsWithTransition(bool slideLeft) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => ParcelsPage(userId: widget.userId, liveLat: widget.liveLat, liveLng: widget.liveLng),
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

    if (index == 2) {
      final bool slideLeft = index < _selectedIndex;
      setState(() => _selectedIndex = index);
      Navigator.pushReplacement(
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
      return;
    }
    if (index == 3) {
      final bool slideLeft = index < _selectedIndex;
      _openParcelsWithTransition(slideLeft);
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

  Future<void> _showChangePasswordCard() async {
    final passwordRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_])[A-Za-z\d@$!%*?&_]{8,}$');
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    String? oldPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    bool isUpdating = false;
    bool updateSuccess = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            Future<void> submitChangePassword() async {
              setModalState(() {
                oldPasswordError = null;
                newPasswordError = null;
                confirmPasswordError = null;
              });

              final oldValue = oldPasswordController.text.trim();
              final newValue = newPasswordController.text.trim();
              final confirmValue = confirmPasswordController.text.trim();

              bool hasError = false;
              if (oldValue.isEmpty) {
                oldPasswordError = 'This field is required.';
                hasError = true;
              }
              if (newValue.isEmpty) {
                newPasswordError = 'This field is required.';
                hasError = true;
              }
              if (confirmValue.isEmpty) {
                confirmPasswordError = 'This field is required.';
                hasError = true;
              }

              if (!hasError && !passwordRegex.hasMatch(newValue)) {
                newPasswordError =
                    'Must be 8+ chars with upper/lower, number, special.';
                hasError = true;
              }
              if (!hasError && confirmValue != newValue) {
                confirmPasswordError = 'Passwords do not match.';
                hasError = true;
              }

              if (hasError) {
                setModalState(() {});
                return;
              }

              setModalState(() => isUpdating = true);
              try {
                final response = await Supabase.instance.client
                    .from('users')
                    .select('password')
                    .eq('user_id', widget.userId)
                    .maybeSingle();

                if (response == null || response['password'] == null) {
                  setModalState(() {
                    oldPasswordError = 'Unable to verify old password.';
                    isUpdating = false;
                  });
                  return;
                }

                final hashedPassword = response['password'].toString();
                final isOldPasswordCorrect =
                    BCrypt.checkpw(oldValue, hashedPassword);

                if (!isOldPasswordCorrect) {
                  setModalState(() {
                    oldPasswordError = 'Old password is incorrect.';
                    isUpdating = false;
                  });
                  return;
                }

                final newHashedPassword =
                    BCrypt.hashpw(newValue, BCrypt.gensalt());

                await Supabase.instance.client
                    .from('users')
                    .update({'password': newHashedPassword})
                    .eq('user_id', widget.userId);

                if (!mounted) return;
                setModalState(() {
                  isUpdating = false;
                  updateSuccess = true;
                  oldPasswordController.clear();
                  newPasswordController.clear();
                  confirmPasswordController.clear();
                });
              } catch (e) {
                if (!mounted) return;
                setModalState(() {
                  isUpdating = false;
                });
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Failed to update password: $e')),
                );
              } finally {
                if (mounted && !updateSuccess) {
                  setModalState(() => isUpdating = false);
                }
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (updateSuccess) ...[
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Center(
                            child: Icon(
                              Icons.check_circle_outline,
                              color: Colors.red,
                              size: 100,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Password updated successfully',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Enter your old and new password.',
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: oldPasswordController,
                            obscureText: !showOldPassword,
                            onChanged: (_) {
                              if (oldPasswordError != null) {
                                setModalState(() => oldPasswordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Old Password',
                              labelStyle: const TextStyle(color: Colors.red),
                              errorText: oldPasswordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showOldPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    showOldPassword = !showOldPassword;
                                  });
                                },
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide:
                                    BorderSide(color: Colors.red, width: 1.5),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            style: const TextStyle(color: Colors.red),
                            cursorColor: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: newPasswordController,
                            obscureText: !showNewPassword,
                            onChanged: (_) {
                              if (newPasswordError != null) {
                                setModalState(() => newPasswordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              labelStyle: const TextStyle(color: Colors.red),
                              errorText: newPasswordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showNewPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    showNewPassword = !showNewPassword;
                                  });
                                },
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide:
                                    BorderSide(color: Colors.red, width: 1.5),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            style: const TextStyle(color: Colors.red),
                            cursorColor: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: !showConfirmPassword,
                            onChanged: (_) {
                              if (confirmPasswordError != null) {
                                setModalState(() => confirmPasswordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              labelStyle: const TextStyle(color: Colors.red),
                              errorText: confirmPasswordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    showConfirmPassword = !showConfirmPassword;
                                  });
                                },
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide:
                                    BorderSide(color: Colors.red, width: 1.5),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            style: const TextStyle(color: Colors.red),
                            cursorColor: Colors.red,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed:
                                    isUpdating ? null : () => Navigator.pop(context),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: isUpdating ? null : submitChangePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: isUpdating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Update'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
      resizeToAvoidBottomInset: false,
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
          Container(
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
          ),
          const SafeArea(
            child: SizedBox(
              height: 70,
              child: Center(
                child: Text(
                  "Profile",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 104, 20, 20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 670,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(80, 255, 0, 0),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.red, width: 1),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 70,
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
                        "$fname $mname $lname",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      infoRow("Username", username),
                      infoRow("Email", email),
                      infoRow("Gender", gender),
                      infoRow("Age", age),
                      infoRow("Birthday", birthDate),
                      const SizedBox(height: 80),
                      SizedBox(
                        width: 300,
                        child: OutlinedButton(
                          onPressed: _showChangePasswordCard,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text(
                            "Change Password",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 300,
                        child: OutlinedButton(
                          onPressed: logout,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text(
                            "Logout",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
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
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}



