import 'package:flutter/material.dart';
import '../login/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reg2_screen.dart';
import '../function/email_service.dart';

class Reg1Screen extends StatefulWidget {
  const Reg1Screen({super.key});

  @override
  State<Reg1Screen> createState() => _Reg1ScreenState();
}

class _Reg1ScreenState extends State<Reg1Screen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final EmailService emailService = EmailService();

  bool _isSending = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final email = _emailController.text.trim();

    if (username.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username)) {
      _showMessage(
          "Username must be at least 3 characters (letters, numbers, underscore only).");
      return false;
    }

    if (password.isEmpty ||
        !RegExp(
                r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_])[A-Za-z\d@$!%*?&_]{8,}$')
            .hasMatch(password)) {
      _showMessage(
          "Password must be at least 8 characters, include upper/lowercase letters, a number, and a special character.");
      return false;
    }

    if (confirmPassword != password) {
      _showMessage("Passwords do not match.");
      return false;
    }

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showMessage("Please enter a valid email address.");
      return false;
    }

    return true;
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleRegister() async {
    if (!_validateInputs()) return;

    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    setState(() => _isSending = true);

    try {
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('username')
          .eq('username', username);

      if (existingUser.isNotEmpty) {
        _showMessage("Username already in use.");
        return;
      }

      final existingEmail = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('email', email);

      if (existingEmail.isNotEmpty) {
        _showMessage("Email already in use.");
        return;
      }

      await emailService.sendAndStoreCode(email);
      _showMessage("Verification code sent to $email");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Reg2Screen(
            username: username,
            password: password,
            email: email,
          ),
        ),
      );
    } catch (e) {
      _showMessage("Failed to send verification email: $e");
    } finally {
      setState(() => _isSending = false);
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
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      "REGISTER",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildInputField(
                        _usernameController, "Username"),

                    _buildPasswordField(
                      controller: _passwordController,
                      label: "Password",
                      isVisible: _showPassword,
                      onToggle: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),

                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: "Confirm Password",
                      isVisible: _showConfirmPassword,
                      onToggle: () => setState(() =>
                          _showConfirmPassword = !_showConfirmPassword),
                    ),

                    _buildInputField(_emailController, "Email"),

                    const SizedBox(height: 20),

                    OutlinedButton(
                      onPressed: _isSending ? null : _handleRegister,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        side:
                            const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text("Register",
                              style: TextStyle(fontSize: 16)),
                    ),

                    const SizedBox(height: 60),

                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),

                    const SizedBox(height: 7),

                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        side:
                            const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child:
                          const Text("Login", style: TextStyle(fontSize: 16)),
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

  // 🔹 Normal Input
  Widget _buildInputField(
      TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.red),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  // 🔐 Password Input with Eye Icon
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.red),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.red,
            ),
            onPressed: onToggle,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }
}
