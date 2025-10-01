// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 NUEVO
import 'package:niko_azaretto_app/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Edge-to-edge (sin colorear barras)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Opcional: solo brillo de iconos (no establezcas colores aquí)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark, // iOS
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Niko Azaretto',
      debugShowCheckedModeBanner: false,

      // 👇 Localización para que las fechas salgan en español
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'), // español
        Locale('en'), // opcional: inglés como fallback
      ],

      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          displayMedium: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          displaySmall: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          headlineMedium: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          headlineSmall: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          titleLarge: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFFEAEAEA)),
          bodyLarge: TextStyle(color: Color(0xFFEAEAEA)),
          bodyMedium: TextStyle(color: Color(0xFFEAEAEA)),
          labelLarge: TextStyle(color: Color(0xFFEAEAEA)),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64ffda),
          secondary: Color(0xFF1A1A1A),
          background: Color(0xFF101010),
          onSurface: Color(0xFFEAEAEA),
          error: Color(0xFFff8a80),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
