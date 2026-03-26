import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/setup_screen.dart';

void main() {
  // Ensure that plugin services are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Tracks if the initial configuration (Odoo URL, Database) is completed.
  bool _isSetupComplete = false;
  // Indicates if the app is currently checking the setup status.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  /// Checks the setup status from SharedPreferences.
  /// If the Odoo URL and Database are configured and the setup flag is true,
  /// the app will navigate to the Login screen. Otherwise, it shows the Setup screen.
  Future<void> _checkSetupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if both URL/DB exist AND explicit flag (to be safe)
    final url = prefs.getString('odoo_url');
    final db = prefs.getString('odoo_db');
    final isComplete = prefs.getBool('is_setup_completed') ?? false;

    setState(() {
      _isSetupComplete =
          isComplete &&
          (url != null && url.isNotEmpty) &&
          (db != null && db.isNotEmpty);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdebrand',
      debugShowCheckedModeBanner: false,

      // --- GLOBAL THEME CONFIGURATION ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        // 1. COLOR PALETTE (Markdebrand Blue)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          primary: const Color(0xFF007AFF),
          secondary: const Color(0xFF007AFF),
          surface: Colors.white,
          error: const Color(0xFFEF4444), // Semantic error red
        ),
        scaffoldBackgroundColor: Colors.white,

        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          const TextTheme(
            displayLarge: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            headlineMedium: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // 3. CARD STYLE (Elevated/Surface)
        cardTheme: CardThemeData(
          color: const Color(0xFFF1F5F9), // Light Gray (Slate 100)
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)), // Slate 200
          ),
        ),

        // 4. GLOBAL INPUT STYLE
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC), // Slate 50
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
          ),
        ),

        // 5. GLOBAL BUTTON STYLE
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Nexa',
            ),
          ),
        ),
      ),

      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            )
          : (_isSetupComplete ? const LoginScreen() : const SetupScreen()),
    );
  }
}
