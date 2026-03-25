import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'constants.dart';

class Historial extends StatefulWidget {
  final int idAgente;
  const Historial({super.key, required this.idAgente});

  @override
  State<Historial> createState() => _HistorialState();
}

class _HistorialState extends State<Historial> {
  List<dynamic> _entregas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _loading = true);
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/entregas/${widget.idAgente}'));

      if (response.statusCode == 200) {
        setState(() => _entregas = jsonDecode(response.body));
      }
    } catch (_) {
      // puedes mostrar un snackbar si quieres
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mis entregas', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFC0154A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: Colors.grey[200]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistorial,
          )
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC0154A)),
            )
          : _entregas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Sin entregas registradas',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _entregas.length,
                  itemBuilder: (_, i) => _entregaItem(_entregas[i]),
                ),
    );
  }

  Widget _entregaItem(Map<String, dynamic> e) {
    final lat = double.tryParse(e['latitud'].toString());
    final lng = double.tryParse(e['longitud'].toString());

    final String? rutaFoto = e['ruta_foto'];
    final String? fotoUrl = (rutaFoto != null && rutaFoto.isNotEmpty)
        ? '$baseUrl/$rutaFoto'
        : null;

    final String fecha = e['fecha'] != null
        ? e['fecha'].toString().substring(0, 16).replaceFirst('T', '  ')
        : '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC0154A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paquete #${e['id_paquete']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ]),
                Text(
                  fecha,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color.fromARGB(255, 52, 48, 48)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Foto
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: fotoUrl != null
                  ? Image.network(
                      fotoUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _sinFotoPlaceholder(),
                    )
                  : _sinFotoPlaceholder(),
            ),

            const SizedBox(height: 10),

            // Dirección
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFFC0154A), size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    e['direccion'] ?? 'Sin dirección',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Mapa
            if (lat != null && lng != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 130,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.paquexpress.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFC0154A),
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (lat != null && lng != null) ...[
              const SizedBox(height: 5),
              Text(
                '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color.fromARGB(255, 91, 82, 82),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sinFotoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 100,
      color: Colors.grey[100],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 28, color: Colors.grey),
          SizedBox(height: 4),
          Text(
            'Foto no disponible',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}