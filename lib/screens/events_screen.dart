// lib/screens/events_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:niko_azaretto_app/config.dart';
import 'package:niko_azaretto_app/models/event.dart';
import 'package:niko_azaretto_app/screens/event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

enum EventsTab { upcoming, past }

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _events = [];
  List<Event> _upcoming = [];
  List<Event> _past = [];
  bool _isLoading = true;
  String _errorMessage = '';
  EventsTab _activeTab = EventsTab.upcoming;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  // ---- FECHAS / FORMATO ----
  DateTime _sod(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _parseDate(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    try {
      return _sod(DateTime.parse(v).toLocal());
    } catch (_) {
      return null;
    }
  }

  int _daysDiff(DateTime a, DateTime b) => _sod(a).difference(_sod(b)).inDays;

  String _fmtDate(DateTime d) {
    return MaterialLocalizations.of(context).formatFullDate(d);
  }

  // ---- CARGA DE EVENTOS ----
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String url = '${AppConfig.baseUrl}listar_eventos.php';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final events = data.map((j) => Event.fromJson(j)).toList();
        _splitAndSort(events);
      } else {
        setState(() {
          _errorMessage =
              'Error del servidor: ${response.statusCode}. Inténtalo más tarde.';
        });
      }
    } on SocketException {
      setState(() {
        _errorMessage =
            'No hay conexión a Internet. Por favor, revisa tu conexión.';
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Tiempo de espera agotado. Intenta nuevamente.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---- SEPARAR Y ORDENAR (FIX) ----
  void _splitAndSort(List<Event> events) {
    final today = _sod(DateTime.now());

    final pairs = events
        .map((e) => MapEntry(e, _parseDate(e.date)))
        .where((p) => p.value != null)
        .toList();

    final upcomingPairs = pairs
        .where((p) => !p.value!.isBefore(today))
        .toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));

    final pastPairs = pairs
        .where((p) => p.value!.isBefore(today))
        .toList()
      ..sort((a, b) => b.value!.compareTo(a.value!));

    setState(() {
      _events = events;
      _upcoming = upcomingPairs.map((p) => p.key).toList();
      _past = pastPairs.map((p) => p.key).toList();
    });
  }

  // ---- MODAL PIN ----
  void _showPasswordModal(Event event) {
    final TextEditingController pinController = TextEditingController();
    final ValueNotifier<bool> showError = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          title: Text(
            'Acceso Privado',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'PlayfairDisplay',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: showError,
                  builder: (context, hasError, _) {
                    return TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontSize: 20),
                      decoration: InputDecoration(
                        hintText: 'PIN de Acceso',
                        hintStyle: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                        fillColor: Theme.of(context).colorScheme.background,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: hasError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: hasError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        counterText: "",
                      ),
                      onChanged: (_) {
                        if (hasError) showError.value = false;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {
                      if (pinController.text == event.pin) {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                EventDetailScreen(event: event),
                          ),
                        );
                      } else {
                        showError.value = true;
                        pinController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('PIN incorrecto.'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            duration: const Duration(milliseconds: 900),
                          ),
                        );
                      }
                    },
                    child: const Text('Entrar'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ---- UI PARTES ----
  Widget _dateChip(Event e) {
    final d = _parseDate(e.date);
    if (d == null) return const SizedBox.shrink();
    final today = _sod(DateTime.now());
    final diff = _daysDiff(d, today);

    Color textColor;
    String text;

    if (diff == 0) {
      textColor = const Color(0xFF00E676);
      text = 'Hoy · ${_fmtDate(d)}';
    } else if (diff > 0) {
      textColor = Colors.white;
      if (diff == 1) {
        text = 'Mañana · ${_fmtDate(d)}';
      } else if (diff <= 7) {
        text = 'En $diff días · ${_fmtDate(d)}';
      } else {
        text = _fmtDate(d);
      }
    } else {
      textColor = Colors.white;
      text = _fmtDate(d);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Widget _eventCard(Event event) {
    return GestureDetector(
      onTap: () => _showPasswordModal(event),
      child: Card(
        color: Theme.of(context).colorScheme.secondary,
        elevation: 10,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(.08)),
                ),
              ),
              child: Center(
                child: Text(
                  event.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    '${AppConfig.baseUrl}${event.imageUrl}',
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, lp) {
                      if (lp == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.broken_image,
                        color: Theme.of(context).colorScheme.error,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: Center(child: _dateChip(event)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabsBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C212B),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segBtn(
            label: 'Próximos',
            active: _activeTab == EventsTab.upcoming,
            onTap: () => setState(() => _activeTab = EventsTab.upcoming),
          ),
          const SizedBox(width: 6),
          _segBtn(
            label: 'Pasados',
            active: _activeTab == EventsTab.past,
            onTap: () => setState(() => _activeTab = EventsTab.past),
          ),
        ],
      ),
    );
  }

  Widget _segBtn({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:
              active ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Theme.of(context).colorScheme.background
                : const Color(0xFFB7C0CD),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Event> get _visibleList =>
      _activeTab == EventsTab.upcoming ? _upcoming : _past;

  // ---- LISTA (iPhone) ----
  SliverList _buildPhoneList() {
    return SliverList.builder(
      itemCount: _visibleList.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14.0),
        child: _eventCard(_visibleList[i]),
      ),
    );
  }

  // ---- GRID (iPad) con alto fijo por ítem -> sin overflow ----
  SliverGrid _buildTabletGrid(BoxConstraints c) {
    final width = c.maxWidth;
    final horizontalPadding = 16.0;
    const spacing = 14.0;

    // columnas según ancho
    final int columns = width >= 1100 ? 3 : 2;

    // ancho real de cada celda
    final tileWidth =
        (width - horizontalPadding * 2 - spacing * (columns - 1)) / columns;

    // Imagen 16:9
    final imageHeight = tileWidth * 9 / 16;

    // Alturas adicionales (título, separadores, paddings, chip) + margen seguridad
    const extraHeights = 128.0; // margen suficiente para evitar overflow

    final mainExtent = imageHeight + extraHeights;

    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: mainExtent, // <- clave para no “cortar” la tarjeta
      ),
      itemCount: _visibleList.length,
      itemBuilder: (context, i) => _eventCard(_visibleList[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                expandedHeight: isTablet ? 220 : 200,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: EdgeInsets.zero,
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: 24),
                      Image.asset('assets/logo.png', width: 90, height: 90),
                      const SizedBox(height: 6),
                      Text(
                        'Eventos 2025 – 2026',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: isTablet ? 40 : 36,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 10),
                  child: Center(child: _tabsBar()),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + (isTablet ? 8 : bottomSafe),
                ),
                sliver: _isLoading
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                            backgroundColor: Colors.white.withOpacity(.08),
                          ),
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_errorMessage ==
                                      'No hay conexión a Internet. Por favor, revisa tu conexión.')
                                    Icon(Icons.signal_wifi_off_outlined,
                                        size: 80,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                  if (_errorMessage ==
                                      'No hay conexión a Internet. Por favor, revisa tu conexión.')
                                    const SizedBox(height: 12),
                                  Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_errorMessage ==
                                      'No hay conexión a Internet. Por favor, revisa tu conexión.')
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 18.0),
                                      child: ElevatedButton.icon(
                                        onPressed: _fetchEvents,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .background,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 22, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Reintentar'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : _visibleList.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'No hay eventos.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.75),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            : isTablet
                                ? _buildTabletGrid(constraints)
                                : _buildPhoneList(),
              ),

              SliverToBoxAdapter(
                child: SizedBox(height: 8 + (isTablet ? 8 : bottomSafe)),
              ),
            ],
          );
        },
      ),
    );
  }
}
