import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// SCREENS
import 'splashscreen/splash_screen.dart';
import '../login/login_screen.dart';
import '../login/login2_screen.dart';
import 'register/reg1_screen.dart';
import 'main_screen/get_started_screen.dart';
import 'main_screen/home_page_screen.dart';
import '../permissions/permission_screen.dart'; // make sure this path is correct

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jyoumapskekkstkuzeai.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp5b3VtYXBza2Vra3N0a3V6ZWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDQ4MzIsImV4cCI6MjA4NDkyMDgzMn0.RifNU_FVnNITZemArvBKCi6AN5k2rkAzZ6nebno9xms',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AVOID',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),

      // START SCREEN
      initialRoute: '/splash',

      // STATIC ROUTES
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const Reg1Screen(),
      },

      // DYNAMIC ROUTES WITH ARGUMENTS
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login-otp':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => Login2Screen(
                username: args['username'],
                userId: args['userId'],
              ),
            );

          case '/permissions':
            final userId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PermissionsScreen(userId: userId),
            );

          case '/get-started':
            final userId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => GetStartedScreen(userId: userId),
            );

          case '/home':
            final userId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => HomePageScreen(userId: userId),
            );

          default:
            return null;
        }
      },
    );
  }
}
