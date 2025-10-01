// lib/config.dart

class AppConfig {
  // *** ¡¡IMPORTANTE!! DEBES AJUSTAR ESTA URL ***
  // Esta debe ser la URL COMPLETA donde se encuentran tus scripts PHP (listar_eventos.php, panel.php, etc.).
  //
  // Basado en tu URL anterior: https://contenido.creawebes.com/index.php?carpeta=usuarios%2FNicolas_Azaretto%2FGaleriaBodas+v3.0
  //
  // Es MUY probable que la URL real de la carpeta raíz de tus scripts PHP sea algo como:
  // 'https://contenido.creawebes.com/usuarios/Nicolas_Azaretto/GaleriaBodas_v3.0/'
  // (Observa que he sustituido el espacio en "GaleriaBodas v3.0" por un guion bajo o una codificación segura para URL)
  //
  // Si tus archivos PHP (como listar_eventos.php) están directamente en:
  // 'https://contenido.creawebes.com/usuarios/Nicolas_Azaretto/GaleriaBodas_v3.0/listar_eventos.php'
  //
  // Entonces, tu 'baseUrl' debería ser:
  // 'https://contenido.creawebes.com/usuarios/Nicolas_Azaretto/GaleriaBodas_v3.0/'
  //
  // Asegúrate de que la URL que pongas aquí TERMINE SIEMPRE CON UN `/` (barra diagonal).
  // Es la URL de la carpeta raíz de tu aplicación PHP.
  //
  static const String baseUrl = 'https://contenido.creawebes.com/usuarios/Nicolas_Azaretto/GaleriaBodas%20v3.0/'; // <-- ¡¡AJUSTA ESTO A TU URL REAL!!
}