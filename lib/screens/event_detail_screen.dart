// lib/screens/event_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:niko_azaretto_app/config.dart'; // Importa tu archivo de configuración para la URL base
import 'package:niko_azaretto_app/models/event.dart'; // Importa el modelo Event
import 'package:niko_azaretto_app/screens/gallery_screen.dart'; // Importa la pantalla de la galería de fotos
import 'package:url_launcher/url_launcher.dart'; // Importa para abrir URLs externas (Google Maps)

class EventDetailScreen extends StatelessWidget {
  final Event event; // Esta pantalla recibe un objeto Event completo con todos los datos

  const EventDetailScreen({super.key, required this.event});

  // Botón "Volver" idéntico al de GalleryScreen (círculo semitransparente + flecha)
  Widget _buildBackButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.55),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background, // Establece el color de fondo (primary-bg)
      body: CustomScrollView(
        // CustomScrollView permite un scroll combinado, ideal para AppBar grandes y contenido
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent, // AppBar transparente
            expandedHeight: 250, // Altura cuando la AppBar está completamente expandida
            pinned: false, // La AppBar no se queda fija en la parte superior al hacer scroll
            automaticallyImplyLeading: false, // Usamos nuestro botón custom
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true, // Centra el contenido del FlexibleSpaceBar
              titlePadding: EdgeInsets.zero, // Elimina el padding por defecto del título para un control total
              background: Stack(
                children: [
                  // RELLENA y centra el contenido (logo + título) para que NO se desplace al poner el botón
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/logo.png', // Ruta a tu archivo de logo
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16), // Espacio entre el logo y el título
                          Text(
                            event.name, // Muestra el nombre del evento
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontFamily: 'PlayfairDisplay', // Usa la fuente para títulos
                                  fontSize: 40, // Tamaño de fuente grande para el título
                                  color: Colors.white,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Botón volver superpuesto arriba-izquierda (idéntico al de Galería)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildBackButton(context),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            // SliverList muestra una lista de widgets en el CustomScrollView
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding horizontal para el contenido principal
                  child: Column(
                    children: [
                      // Contenedor de la imagen de portada del evento
                      // CORRECCIÓN: Se envuelve el Container con un widget AspectRatio
                      AspectRatio(
                        aspectRatio: 16 / 9, // La relación de aspecto ahora se define aquí
                        child: Container(
                          width: double.infinity, // Ocupa todo el ancho disponible
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8), // Bordes redondeados
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              width: 1,
                            ), // Borde (border-color)
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5), // Sombra (box-shadow)
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8), // Recorta la imagen con bordes redondeados
                            child: Image.network(
                              // Construye la URL completa de la imagen de portada
                              '${AppConfig.baseUrl}${event.imageUrl}',
                              fit: BoxFit.cover, // La imagen cubrirá el área, recortando si es necesario
                              loadingBuilder: (context, child, loadingProgress) {
                                // Muestra un indicador de progreso mientras la imagen se carga
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                // Muestra un icono de error si la imagen no se puede cargar
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Theme.of(context).colorScheme.error,
                                      size: 50,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40), // Espacio después de la imagen (2.5rem)

                      // Contenedor de los detalles del evento (descripción, fecha, hora, lugar, ubicación)
                      Container(
                        padding: const EdgeInsets.all(32.0), // Padding interno (2rem)
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary, // Fondo (secondary-bg)
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ), // Borde (border-color)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda
                          children: [
                            Text(
                              event.description, // Descripción del evento
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 18, // 1.1rem
                                    height: 1.7, // Altura de línea
                                  ),
                            ),
                            const SizedBox(height: 18), // Espacio entre elementos (1.2rem)

                            // Filas de detalles (fecha, hora, lugar)
                            _buildDetailRow(context, 'Fecha:', event.date),
                            _buildDetailRow(context, 'Hora:', event.time),
                            _buildDetailRow(context, 'Lugar:', event.place),

                            // Fila para la ubicación con enlace a Google Maps
                            _buildDetailRow(
                              context,
                              'Ubicación:',
                              'Ver en Google Maps',
                              isLink: true, // Indica que es un enlace
                              linkUrl: event.locationUrl, // URL de Google Maps
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40), // Espacio después de los detalles (2.5rem)

                      // Botón de Llamada a la Acción (CTA) para ir a la galería
                      ElevatedButton(
                        onPressed: () {
                          // Navega a la pantalla de la galería, pasando el slug del evento
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GalleryScreen(eventName: event.slug),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary, // Fondo del botón (accent-color)
                          foregroundColor: Theme.of(context).colorScheme.background, // Color del texto (primary-bg)
                          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontSize: 18, // 1.1rem
                                fontWeight: FontWeight.bold, // 700
                              ),
                          elevation: 0, // Sin sombra por defecto
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Carga tus fotos del día de la fiesta'),
                      ),
                      const SizedBox(height: 60), // Padding inferior (4rem)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para construir cada fila de detalle (ej. "Fecha: 2025-10-11")
  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isLink = false, String? linkUrl}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0), // Espacio entre cada fila (1.2rem)
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido al inicio de la línea
        children: [
          Text(
            label, // El texto de la etiqueta (ej. "Fecha:")
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary, // Color (accent-color)
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
          ),
          const SizedBox(width: 8), // Espacio entre la etiqueta y el valor (0.5em)
          Expanded(
            // Expanded hace que el texto ocupe el resto del ancho disponible
            child: isLink
                ? GestureDetector(
                    // Si es un enlace, el GestureDetector permite que sea clickeable
                    onTap: () async {
                      if (linkUrl != null && linkUrl.isNotEmpty) {
                        final Uri url = Uri.parse(linkUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication); // Abre la URL en una aplicación externa (ej. navegador, Google Maps)
                        } else {
                          // Muestra un SnackBar si no se puede abrir la URL
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('No se pudo abrir la ubicación.'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      value, // El texto del enlace (ej. "Ver en Google Maps")
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary, // Color del enlace (accent-color)
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline, // Subrayado para indicar que es un enlace
                          ),
                    ),
                  )
                : Text(
                    value, // El valor del detalle (ej. "2025-10-11")
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}
