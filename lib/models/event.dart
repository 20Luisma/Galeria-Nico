// lib/models/event.dart

// Define la clase Event para representar un evento con sus propiedades.
class Event {
  final String name; // Nombre del evento (ej. "Isabela & Elías")
  final String slug; // Nombre "limpio" del evento, usado en URLs (ej. "isabela-elias")
  final String description; // Descripción detallada del evento
  final String date; // Fecha del evento (ej. "2025-09-14")
  final String time; // Hora del evento (ej. "16:00")
  final String place; // Lugar o salón del evento (ej. "Finca El Roble")
  final String locationUrl; // URL a la ubicación en Google Maps
  final String pin; // PIN de acceso al evento
  final String imageUrl; // URL relativa de la imagen de portada del evento (ej. "eventos/mi-evento/fotos/cover_xyz.jpg")
  final String eventPageUrl; // URL relativa a la página HTML individual del evento (ej. "eventos/mi-evento/index.html")

  // Constructor de la clase Event. Todas las propiedades son requeridas.
  Event({
    required this.name,
    required this.slug,
    required this.description,
    required this.date,
    required this.time,
    required this.place,
    required this.locationUrl,
    required this.pin,
    required this.imageUrl,
    required this.eventPageUrl,
  });

  // Un "factory constructor" para crear una instancia de Event desde un Map (que es lo que obtenemos de JSON).
  // Esto facilita la conversión de la respuesta de tu API PHP a un objeto Dart.
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      // Se utiliza el operador '?? ''' (null-aware operator) para asegurar
      // que si una propiedad no existe en el JSON o es null, se use una cadena vacía
      // en su lugar, evitando errores de tipo null.
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      place: json['place'] ?? '',
      locationUrl: json['location_url'] ?? '', // Asegúrate de que este nombre coincide con la clave en tu JSON PHP
      pin: json['pin'] ?? '',
      imageUrl: json['image'] ?? '', // Asegúrate de que este nombre coincide con la clave en tu JSON PHP
      eventPageUrl: json['url'] ?? '', // Asegúrate de que este nombre coincide con la clave en tu JSON PHP
    );
  }
}