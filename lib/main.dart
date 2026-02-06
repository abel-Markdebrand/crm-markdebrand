import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'widgets/voip/call_overlay.dart';
import 'services/voip_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos las fuentes base aquí para reutilizarlas
    // Century Gothic -> Questrial (Geométrica, limpia)
    // Nexa -> Montserrat (Moderna, pesos variados)
    final textTheme = GoogleFonts.montserratTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      title: 'Markdebrand CRM',
      scaffoldMessengerKey: VoipService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,

      // --- CONFIGURACIÓN DE TEMA GLOBAL ---
      theme: ThemeData(
        useMaterial3: true,

        // 1. PALETA DE COLORES (Negro Corporativo)
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black, // Color principal de la app
          secondary: const Color(0xFF1E293B), // Gris azulado para detalles
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,

        // 2. CONFIGURACIÓN DE TIPOGRAFÍA (Google Fonts)
        // Aplicamos Montserrat como base para todo el texto de la app
        textTheme: textTheme.copyWith(
          // Títulos Grandes (Headers) -> Usan Questrial (Simula Century Gothic)
          displayLarge: GoogleFonts.questrial(
            fontSize: 57,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          displayMedium: GoogleFonts.questrial(
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          headlineMedium: GoogleFonts.questrial(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          headlineSmall: GoogleFonts.questrial(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),

          // Cuerpo de texto (Body) -> Montserrat (Simula Nexa)
          bodyLarge: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w400, // Nexa Light equivalent
            color: const Color(0xFF1E293B),
          ),
          bodyMedium: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w400, // Nexa Light equivalent
            color: const Color(0xFF1E293B),
          ),
        ),

        // 4. ESTILO GLOBAL DE INPUTS (Cajas de texto)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
          hintStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w400,
            color: Colors.grey[400],
          ),
          // Borde cuando no estás escribiendo
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          // Borde cuando haces clic para escribir (Se pone negro)
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          // Borde de error
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
        ),

        // 5. ESTILO GLOBAL DE BOTONES
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),

      builder: (context, child) {
        // Initialize Call Manager (Lazy or here)
        // Note: Ideally CallManager.instance.init() is called after login,
        // but we can ensure it's built here.

        return CallOverlay(child: child!);
      },
      home: const LoginScreen(),
    );
  }
}
