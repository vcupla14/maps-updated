import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';

import '../register/reg1_screen.dart';
import '../main_screen/home_page_screen.dart';
import 'login2_screen.dart';
import '../permissions/permission_screen.dart';
import '../function/live_location.dart';
import '../function/location_sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;

  Future<void> _login() async {
    // 🔹 FORCE lowercase (DB-safe)
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter username and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, password, new_user, last_active')
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
        return;
      }

      final String userId = response['user_id'].toString();
      final String hashedPassword = response['password'];
      final bool newUser = response['new_user'] ?? true;
      final String? lastActiveStr = response['last_active'];
      final liveLocation = await LiveLocationService.getCurrent();
      final double? liveLat = liveLocation?.latitude;
      final double? liveLng = liveLocation?.longitude;

      final isPasswordCorrect = BCrypt.checkpw(password, hashedPassword);

      if (!isPasswordCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incorrect password")),
        );
        return;
      }

      // 🔹 NEW USER
      if (newUser) {
        await Supabase.instance.client.from('users').update({
          'status': 'online',
          'last_active': DateTime.now().toIso8601String(),
          'last_seen_lat': liveLat,
          'last_seen_lng': liveLng,
        }).eq('user_id', userId);
        await LocationSyncService.instance.start(userId);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PermissionsScreen(
              userId: userId,
              liveLat: liveLat,
              liveLng: liveLng,
            ),
          ),
        );
        return;
      }

      // 🔹 CHECK LAST ACTIVE (24H RULE)
      bool requireOtp = false;

      if (lastActiveStr == null) {
        requireOtp = true;
      } else {
        final lastActive = DateTime.parse(lastActiveStr);
        if (DateTime.now().difference(lastActive).inHours >= 24) {
          requireOtp = true;
        }
      }

      if (requireOtp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Login2Screen(
              username: username,
              userId: userId,
              liveLat: liveLat,
              liveLng: liveLng,
            ),
          ),
        );
        return;
      }

      // 🔹 NORMAL LOGIN
      await Supabase.instance.client.from('users').update({
        'status': 'online',
        'new_user': false,
        'last_active': DateTime.now().toIso8601String(),
        'last_seen_lat': liveLat,
        'last_seen_lng': liveLng,
      }).eq('user_id', userId);
      await LocationSyncService.instance.start(userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePageScreen(
            userId: userId,
            liveLat: liveLat,
            liveLng: liveLng,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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

          // ⚪ Login Box
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
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🧍 Username (FORCED LOWERCASE)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: TextField(
                          controller: _usernameController,
                          onChanged: (value) {
                            final lower = value.toLowerCase();
                            if (value != lower) {
                              _usernameController.value =
                                  _usernameController.value.copyWith(
                                text: lower,
                                selection: TextSelection.collapsed(
                                  offset: lower.length,
                                ),
                              );
                            }
                          },
                          decoration: InputDecoration(
                            labelText: "Username",
                            labelStyle: const TextStyle(color: Colors.red),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🔒 Password
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: const TextStyle(color: Colors.red),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // 🔘 Login
                      OutlinedButton(
                        onPressed: _isLoading ? null : _login,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 30),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text("Login"),
                      ),

                      const SizedBox(height: 60),

                      const Text(
                        "Don't have an account?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🧾 Register
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Reg1Screen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text("Register"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
