// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Importa la librería para reproducir audio
import 'package:niko_azaretto_app/screens/events_screen.dart'; // Importa la siguiente pantalla a la que navegará

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// Para usar animaciones, el State debe extender con SingleTickerProviderStateMixin
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoAnimationController; // Controlador para la animación del logo
  late Animation<double> _logoAnimation; // La animación de opacidad y escala del logo
  final AudioPlayer _audioPlayer = AudioPlayer(); // Instancia del reproductor de audio

  @override
  void initState() {
    super.initState();

    // Inicializa el controlador de la animación del logo.
    // Duración de 2 segundos para el "fade-in" y "scale-in" del logo, como en tu CSS.
    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this, // 'this' actúa como TickerProvider debido a SingleTickerProviderStateMixin
    );
    // Define la curva de la animación, similar a 'ease-out'.
    _logoAnimation = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOut,
    );

    // Lógica para el efecto de "flash" inicial, el sonido y la navegación.
    // Retraso de 400ms antes de que comience la animación del logo y el sonido.
    Future.delayed(const Duration(milliseconds: 400), () {
      _logoAnimationController.forward(); // Inicia la animación del logo (hacia adelante)

      // Intenta reproducir el sonido de la cámara desde los assets.
      _audioPlayer.play(AssetSource('click.mp3')).catchError((e) {
        // Captura y registra cualquier error si la reproducción falla (ej. si el archivo no existe o no hay permisos).
        debugPrint("Error al reproducir el sonido: $e");
      });
    });

    // Configura un temporizador para navegar a la siguiente pantalla (EventsScreen).
    // Después de 3 segundos, reemplaza la pantalla actual (SplashScreen) con EventsScreen.
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const EventsScreen()),
      );
    });
  }

  @override
  void dispose() {
    // Es crucial liberar los recursos de los controladores y reproductores cuando el widget ya no se usa.
    _logoAnimationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Establece el color de fondo de la pantalla, que corresponde a tu --primary-bg.
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        // Stack permite superponer widgets, útil para el efecto de flash sobre el logo.
        children: [
          // Efecto de flash blanco inicial.
          // Esto simula el comportamiento de tu #intro-flash CSS.
          // TweenAnimationBuilder anima un valor (opacidad en este caso) y lo usa en el builder.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0), // Anima la opacidad de 1.0 (visible) a 0.0 (transparente).
            duration: const Duration(milliseconds: 300), // La animación dura 300ms, como tu @keyframes flashIntro.
            builder: (context, value, child) {
              return Opacity(
                opacity: value, // Aplica la opacidad animada.
                child: Container(color: Colors.white), // El widget blanco que simula el flash.
              );
            },
            curve: Curves.easeOut, // Usa la curva de animación 'easeOut'.
          ),
          
          // Logo de Niko Azaretto centrado en la pantalla.
          Center(
            child: FadeTransition(
              opacity: _logoAnimation, // La opacidad del logo es controlada por _logoAnimation.
              child: ScaleTransition(
                // La escala del logo también es controlada, simulando el 'transform: scale(0.9)' a 'scale(1)'.
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(_logoAnimation),
                child: Image.asset(
                  'assets/logo.png', // Ruta de tu archivo de logo en la carpeta assets.
                  width: 150, // Ancho fijo del logo.
                  height: 150, // Alto fijo del logo.
                  fit: BoxFit.contain, // La imagen se ajusta dentro de su caja sin recortarse.
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}