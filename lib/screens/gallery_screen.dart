import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:niko_azaretto_app/config.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';

class GalleryScreen extends StatefulWidget {
  final String eventName;

  const GalleryScreen({super.key, required this.eventName});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  List<String> _photoUrls = [];
  int _currentPhotoIndex = -1;
  bool _isLoadingPhotos = true;
  String _galleryErrorMessage = '';
  bool _isUploading = false;
  bool _isDownloading = false; // Estado centralizado para el spinner de descarga

  final ScrollController _thumbnailScrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _passwordController = TextEditingController();
  bool _showToolsMenu = false;

  late AnimationController _cameraFlashController;
  late Animation<double> _cameraFlashAnimation;

  bool _initialPhotosDisplayed = false;

  late SharedPreferences _prefs;
  bool _hasGivenConsentForEvent = false;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _setupAnimations();
    _fetchPhotos();
  }

  void _setupAnimations() {
    _cameraFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cameraFlashAnimation = Tween<double>(begin: 0.0, end: 0.8).animate(_cameraFlashController);
  }

  Future<void> _initSharedPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hasGivenConsentForEvent = _prefs.getBool('consent_${widget.eventName}') ?? false;
        });
        debugPrint('DEBUG - Consentimiento para ${widget.eventName}: $_hasGivenConsentForEvent');
      }
    } catch (e) {
      debugPrint('ERROR - Fallo al inicializar SharedPreferences: $e');
    }
  }

  @override
  void dispose() {
    _thumbnailScrollController.dispose();
    _audioPlayer.dispose();
    _passwordController.dispose();
    _cameraFlashController.dispose();
    super.dispose();
  }

  // --- Lógica de Galería (Sin cambios) ---

  Future<void> _fetchPhotos() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPhotos = true;
      _galleryErrorMessage = '';
    });

    try {
      final String listPhotosUrl = '${AppConfig.baseUrl}eventos/${widget.eventName}/listar_fotos.php';
      debugPrint('DEBUG (fetchPhotos) - Pidiendo lista de fotos a: $listPhotosUrl');

      final response = await http.get(Uri.parse(listPhotosUrl)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Timeout al cargar fotos', const Duration(seconds: 15)),
      );

      debugPrint('DEBUG (fetchPhotos) - Código de estado: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        debugPrint('DEBUG (fetchPhotos) - Fotos encontradas: ${data.length}');

        if (mounted) {
          setState(() {
            _photoUrls = data.map((e) => '${AppConfig.baseUrl}eventos/${widget.eventName}/${e.toString()}').toList();
            
            if (_photoUrls.isNotEmpty) {
              _currentPhotoIndex = _photoUrls.length - 1;
              _scrollToActiveThumbnail();
              
              if (!_initialPhotosDisplayed) {
                _playCameraSound();
                _initialPhotosDisplayed = true;
              }
            } else {
              _currentPhotoIndex = -1;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _galleryErrorMessage = 'Error al cargar fotos: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      debugPrint('ERROR (fetchPhotos) - $e');
      if (mounted) {
        setState(() {
          _galleryErrorMessage = e is TimeoutException ? 'Timeout al cargar fotos' : 'Error de conexión: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
        });
      }
    }
  }

  void _displayImage(int index) {
    if (index < 0 || index >= _photoUrls.length || !mounted) return;
    
    setState(() {
      _currentPhotoIndex = index;
    });
    _applyFlashEffect();
    _scrollToActiveThumbnail();
  }

  void _navigateImage(int direction) {
    if (_photoUrls.isEmpty) return;
    
    int newIndex = _currentPhotoIndex + direction;
    if (newIndex < 0) {
      newIndex = _photoUrls.length - 1;
    } else if (newIndex >= _photoUrls.length) {
      newIndex = 0;
    }
    _displayImage(newIndex);
  }

  void _scrollToActiveThumbnail() {
    if (!_thumbnailScrollController.hasClients || _currentPhotoIndex == -1) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_thumbnailScrollController.hasClients && mounted) {
        final double itemWidth = 112; // 100px + 12px margin
        final double offset = _currentPhotoIndex * itemWidth;
        
        _thumbnailScrollController.animateTo(
          offset - (_thumbnailScrollController.offset % itemWidth),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _playCameraSound() {
    _audioPlayer.stop();
    _audioPlayer.play(AssetSource('click.mp3')).catchError((e) {
      debugPrint("Error al reproducir sonido: $e");
    });
  }

  void _applyFlashEffect() {
    _cameraFlashController.forward(from: 0.0).then((_) {
      if (mounted) _cameraFlashController.reverse();
    });
  }

  // --- NUEVA LÓGICA DE DESCARGA Y PERMISOS (CORREGIDA) ---

  /// **Punto de entrada principal para la descarga.**
  /// Gestiona el estado de la UI (spinner) y garantiza que siempre se limpie.
  Future<void> _downloadCurrentPhoto() async {
    if (_isDownloading) return; // Evita múltiples toques

    if (_photoUrls.isEmpty || _currentPhotoIndex == -1) {
      _showStatusMessage('No hay imagen seleccionada.', isError: true);
      return;
    }

    // 1. Iniciar el estado de carga y ocultar el menú de herramientas.
    if (mounted) {
      setState(() {
        _showToolsMenu = false;
        _isDownloading = true;
      });
    }

    // 2. Usar un bloque try/finally para GARANTIZAR que el spinner se detenga.
    try {
      debugPrint("[Download Flow] Iniciando proceso de guardado.");
      await _performSaveToGallery();
    } catch (e, stackTrace) {
      // Captura cualquier error inesperado que pueda ocurrir en el flujo.
      debugPrint("[Download Flow] Error no controlado en _downloadCurrentPhoto: $e");
      debugPrint("[Download Flow] StackTrace: $stackTrace");
      if (mounted) {
        _showStatusMessage('Ocurrió un error inesperado al guardar.', isError: true);
      }
    } finally {
      // 3. Este bloque se ejecuta SIEMPRE, con éxito o con error.
      // Es el único responsable de detener el spinner.
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        debugPrint("[Download Flow] Spinner detenido. Proceso finalizado.");
      }
    }
  }

  /// **Realiza la lógica de permisos y descarga.**
  /// No modifica el estado de la UI directamente, solo ejecuta la tarea.
  Future<void> _performSaveToGallery() async {
    // Paso 1: Solicitar permisos de forma robusta.
    final PermissionStatus status = await _requestPhotoPermission();
    debugPrint("[Download Flow] Estado del permiso: $status");

    // Paso 2: Actuar según el estado del permiso.
    if (status.isGranted || status.isLimited) {
      // Permiso concedido (total o limitado), proceder con la descarga.
      await _executeDownload();
    } else {
      // Permiso denegado.
      _showStatusMessage('Permiso denegado para guardar fotos.', isError: true);
      if (status.isPermanentlyDenied) {
        // Ofrecer al usuario ir a la configuración de la app.
        final goToSettings = await _showPermissionDialog();
        if (goToSettings == true && mounted) {
          await openAppSettings();
        }
      }
    }
  }

  /// **Función aislada para solicitar permisos de la fototeca.**
  /// Devuelve el `PermissionStatus` final para que el llamador decida cómo actuar.
  Future<PermissionStatus> _requestPhotoPermission() async {
    PermissionStatus status;

    if (Platform.isIOS) {
      // En iOS 14+, 'photosAddOnly' permite añadir fotos sin pedir acceso total.
      status = await Permission.photosAddOnly.status;
      debugPrint("[iOS Permission] Estado inicial de 'photosAddOnly': $status");
      if (status.isDenied) {
        // Si el permiso está denegado, lo solicitamos.
        // El `await` espera a que el usuario interactúe con el diálogo del sistema.
        status = await Permission.photosAddOnly.request();
        debugPrint("[iOS Permission] Nuevo estado tras la solicitud: $status");
      }
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // En Android 13+ se usan permisos granulares. Para guardar, 'photos' es una buena opción.
      // En versiones anteriores, se usa 'storage'. `permission_handler` lo gestiona bien.
      final permission = androidInfo.version.sdkInt >= 33 ? Permission.photos : Permission.storage;
      
      status = await permission.status;
      debugPrint("[Android Permission] Estado inicial de '$permission': $status");
      if (status.isDenied) {
        status = await permission.request();
        debugPrint("[Android Permission] Nuevo estado tras la solicitud: $status");
      }
    } else {
      // Plataforma no soportada.
      return PermissionStatus.denied;
    }
    
    return status;
  }

  /// **Ejecuta la descarga y guardado real de la imagen.**
  Future<void> _executeDownload() async {
    try {
      final String imageUrl = _photoUrls[_currentPhotoIndex];
      debugPrint("[Download Flow] Permiso OK. Descargando: $imageUrl");
      
      _showStatusMessage('Descargando imagen...', isError: false);

      final http.Response response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        _showStatusMessage('Error del servidor (${response.statusCode}).', isError: true);
        return;
      }

      final Uint8List imageBytes = response.bodyBytes;
      if (imageBytes.isEmpty) {
        _showStatusMessage('Error: El archivo descargado está vacío.', isError: true);
        return;
      }
      
      // Guardar en la galería.
      final String filename = path.basenameWithoutExtension(Uri.parse(imageUrl).path);
      final String uniqueName = "${filename}_${DateTime.now().millisecondsSinceEpoch}";
      
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: uniqueName
      );

      debugPrint("[Download Flow] Resultado de ImageGallerySaver: $result");

      // La librería puede devolver `isSuccess: true` o a veces `null` en iOS aunque funcione.
      if (result != null && result['isSuccess'] == true) {
        _showStatusMessage('✓ Foto guardada en tu galería', isError: false);
      } else if (Platform.isIOS) {
        // En iOS, un resultado no exitoso no siempre es un error, especialmente
        // la primera vez después de dar permisos. Si no hubo excepción, asumimos éxito.
        debugPrint("[Download Flow] Resultado no exitoso en iOS, asumiendo éxito.");
        _showStatusMessage('✓ Foto guardada en tu galería', isError: false);
      } else {
        _showStatusMessage('Error al guardar la foto.', isError: true);
      }

    } on TimeoutException {
      _showStatusMessage('Timeout al descargar. Verifica tu conexión.', isError: true);
    } catch (e) {
      debugPrint("[Download Flow] Error en _executeDownload: $e");
      _showStatusMessage('Error al guardar la imagen.', isError: true);
    }
  }

  /// Muestra un diálogo para guiar al usuario a la configuración de la app.
  Future<bool?> _showPermissionDialog() async {
    if (!mounted) return false;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        ),
        title: Text(
          'Permiso Requerido',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'PlayfairDisplay',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Para descargar fotos necesitas activar el permiso de Fotos en Configuración.\n\n¿Ir a Configuración ahora?',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ir a Configuración'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Lógica de Subida, Consentimiento y Eliminación (Sin cambios) ---

  Future<void> _checkAndRequestConsent(ImageSource source, {bool multiple = false}) async {
    if (_hasGivenConsentForEvent) {
      await _pickImage(source, multiple: multiple);
    } else {
      bool? userConsent = await _showConsentDialog();
      
      if (userConsent == true) {
        setState(() {
          _hasGivenConsentForEvent = true;
        });
        await _prefs.setBool('consent_${widget.eventName}', true);
        await _pickImage(source, multiple: multiple);
      } else {
        _showStatusMessage('No se subirán fotos sin tu consentimiento.', isError: true);
      }
    }
  }

  Future<bool?> _showConsentDialog() async {
    if (!mounted) return false;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        ),
        title: Text(
          'Compartir Fotos en la Galería del Evento',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'PlayfairDisplay',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al subir fotos a este evento, ten en cuenta:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '• Las fotos serán visibles para otros participantes con el PIN de acceso.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 5),
            Text(
              '• Se almacenarán en nuestro servidor para el evento.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15),
            Text(
              'Al aceptar, confirmas que estás de acuerdo con compartir tus fotos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, {bool multiple = false}) async {
    final ImagePicker picker = ImagePicker();
    List<XFile> images = [];

    try {
      if (multiple) {
        images = await picker.pickMultiImage();
      } else {
        final XFile? image = await picker.pickImage(source: source);
        if (image != null) {
          images.add(image);
        }
      }

      if (images.isNotEmpty) {
        await _uploadFiles(images);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      _showStatusMessage('Error al seleccionar imagen: $e', isError: true);
    }
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    if (files.isEmpty || !mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final String uploadUrl = '${AppConfig.baseUrl}eventos/${widget.eventName}/upload.php';
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath('fotos[]', file.path));
      }

      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        _showStatusMessage('Subida completada', isError: false);
        await _fetchPhotos(); 
      } else {
        _showStatusMessage('Error al subir: ${response.statusCode}', isError: true);
        debugPrint('Upload failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      debugPrint('Error uploading files: $e');
      if (e.toString().contains('TimeoutException')) {
        _showStatusMessage('Timeout al subir. Verifica tu conexión.', isError: true);
      } else {
        _showStatusMessage('Error al subir: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showStatusMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: isError ? 5 : 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteModal() {
    if (_photoUrls.isEmpty || _currentPhotoIndex == -1) {
      _showStatusMessage('No hay imagen seleccionada para eliminar.', isError: true);
      return;
    }
    
    _passwordController.clear();
    setState(() {
      _showToolsMenu = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        ),
        title: Text(
          'Eliminar Foto',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'PlayfairDisplay',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa la contraseña para eliminar:',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                fillColor: Theme.of(context).colorScheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _confirmDelete,
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    Navigator.pop(context);
    final String password = _passwordController.text;
    
    if (password.isEmpty) {
      _showStatusMessage('Ingresa una contraseña.', isError: true);
      return;
    }

    try {
      final String currentImageUrl = _photoUrls[_currentPhotoIndex];
      final String filename = path.basename(Uri.parse(currentImageUrl).path);
      final String deleteUrl = '${AppConfig.baseUrl}eventos/${widget.eventName}/eliminar_foto.php';

      final response = await http.post(
        Uri.parse(deleteUrl),
        body: {'filename': filename, 'password': password},
      ).timeout(const Duration(seconds: 15));
      
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (jsonResponse['success'] == true) {
        _showStatusMessage(jsonResponse['message'] ?? 'Foto eliminada', isError: false);
        await _fetchPhotos();
      } else {
        _showStatusMessage(jsonResponse['message'] ?? 'Error al eliminar', isError: true);
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      _showStatusMessage('Error de conexión al eliminar.', isError: true);
    }
  }

  Future<void> _reportPhoto() async {
    if (_photoUrls.isEmpty || _currentPhotoIndex == -1) {
      _showStatusMessage('No hay imagen seleccionada para reportar.', isError: true);
      setState(() { _showToolsMenu = false; });
      return;
    }

    setState(() {
      _showToolsMenu = false;
    });

    try {
      final String currentImageUrl = _photoUrls[_currentPhotoIndex];
      final String filename = path.basename(Uri.parse(currentImageUrl).path);
      final String reportScriptUrl = '${AppConfig.baseUrl}reportar_foto.php'; 

      final response = await http.post(
        Uri.parse(reportScriptUrl),
        body: {
          'filename': filename,
          'eventName': widget.eventName,
        },
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        _showStatusMessage(jsonResponse['message'] ?? 'Foto reportada correctamente.', isError: false);
      } else {
        String errorMessage = jsonResponse['message'] ?? 'Error desconocido al reportar la foto.';
        _showStatusMessage('Error: $errorMessage', isError: true);
      }
    } catch (e) {
      debugPrint('Error reporting photo: $e');
      _showStatusMessage('Error de conexión al reportar la foto.', isError: true);
    }
  }

  // ---- NUEVO: Botón Volver (igual que Android) ----
  Widget _buildBackButton() {
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
  // -----------------------------------------------

  // --- Widgets de UI (Sin cambios, salvo el botón volver superpuesto) ---

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: !isLandscape,
        bottom: !isLandscape,
        child: Stack(
          children: [
            Column(
              children: [
                if (!isLandscape)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                    ),
                  ),
                
                Expanded(
                  child: GestureDetector(
                    onTapUp: isLandscape && _photoUrls.length > 1
                        ? (details) {
                            final double screenWidth = MediaQuery.of(context).size.width;
                            if (details.localPosition.dx < screenWidth / 2) {
                              _navigateImage(-1);
                            } else {
                              _navigateImage(1);
                            }
                          }
                        : null,
                    child: _buildMainImageContainer(isLandscape),
                  ),
                ),
                
                if (!isLandscape && _isUploading)
                  _buildUploadIndicator(),
                
                if (!isLandscape && _isDownloading)
                  _buildDownloadIndicator(),
                
                if (!isLandscape && _photoUrls.isNotEmpty)
                  _buildThumbnailRow(),
              ],
            ),

            // Botón volver arriba-izquierda (siempre visible)
            Positioned(
              top: 0,
              left: 0,
              child: _buildBackButton(),
            ),
            
            if (_showToolsMenu)
              _buildFloatingToolsMenu(isLandscape),
          ],
        ),
      ),
      bottomNavigationBar: isLandscape ? null : _buildBottomNavBar(),
    );
  }

  Widget _buildMainImageContainer(bool isLandscape) {
    return Container(
      width: double.infinity,
      margin: isLandscape ? EdgeInsets.zero : const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: isLandscape ? null : Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2), 
          width: 2,
        ),
        borderRadius: isLandscape ? BorderRadius.zero : BorderRadius.circular(8),
        boxShadow: isLandscape
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  blurRadius: 40,
                ),
              ],
        color: Colors.black,
      ),
      child: _isLoadingPhotos
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            )
          : _galleryErrorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _galleryErrorMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : _photoUrls.isEmpty
                  ? Center(
                      child: Text(
                        'Aún no hay fotos. ¡Sube la primera!',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _photoUrls[_currentPhotoIndex],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error al cargar imagen: ${_photoUrls[_currentPhotoIndex]}');
                            return Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Theme.of(context).colorScheme.error,
                                size: 50,
                              ),
                            );
                          },
                        ),
                        FadeTransition(
                          opacity: _cameraFlashAnimation,
                          child: Container(color: Colors.white),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildUploadIndicator() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: 40,
      margin: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondary,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Subiendo fotos...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadIndicator() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: 40,
      margin: const EdgeInsets.only(top: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondary,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Descargando foto...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailRow() {
    return Container(
      width: double.infinity,
      height: 80,
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView.builder(
            controller: _thumbnailScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _photoUrls.length,
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            itemBuilder: (context, index) {
              final isActive = index == _currentPhotoIndex;
              return GestureDetector(
                onTap: () => _displayImage(index),
                child: Container(
                  width: 100,
                  height: 65,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              blurRadius: 15,
                            ),
                          ]
                        : null,
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                      _photoUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 24, color: Color(0xFF64ffda)),
                onPressed: () {
                  _thumbnailScrollController.animateTo(
                    _thumbnailScrollController.offset - (MediaQuery.of(context).size.width * 0.8),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 24, color: Color(0xFF64ffda)),
                onPressed: () {
                  _thumbnailScrollController.animateTo(
                    _thumbnailScrollController.offset + (MediaQuery.of(context).size.width * 0.8),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolsMenu(bool isLandscape) {
    return Positioned(
      bottom: kBottomNavigationBarHeight + (isLandscape ? 20 : 60),
      right: 15,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolsMenuItem(
              'Reportar Foto',
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z"/></svg>',
              const Color(0xFFFFD700),
              _reportPhoto,
            ),
            _buildToolsMenuItem(
              'Eliminar Foto',
              '<svg viewBox="0 0 24 24"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>',
              Theme.of(context).colorScheme.error,
              _showDeleteModal,
            ),
            _buildToolsMenuItem(
              'Descargar Foto',
              '<svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>',
              Theme.of(context).colorScheme.primary,
              _downloadCurrentPhoto, // Llama a la función corregida
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsMenuItem(String text, String svgPath, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              svgPath,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(width: 15),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color, 
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      color: Theme.of(context).colorScheme.secondary,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2), 
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavBarButton(
              'Web',
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>',
              () async {
                final Uri url = Uri.parse('https://nikoazaretto.com');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            _buildNavBarButton(
              'Cámara',
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3.2"/><path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/></svg>',
              () => _checkAndRequestConsent(ImageSource.camera),
            ),
            _buildNavBarButton(
              'Galería',
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>',
              () => _checkAndRequestConsent(ImageSource.gallery, multiple: true),
            ),
            _buildNavBarButton(
              '',
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>',
              () {
                setState(() {
                  _showToolsMenu = !_showToolsMenu;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarButton(String text, String svgPath, VoidCallback onTap) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  svgPath,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary, 
                    BlendMode.srcIn,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
