// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants.dart';

class Entrega extends StatefulWidget {
  final int idAgente;
  final int idPaquete;
  final String direccion;

  const Entrega({
    super.key,
    required this.idAgente,
    required this.idPaquete,
    required this.direccion,
  });

  @override
  State<Entrega> createState() => _EntregaState();
}

class _EntregaState extends State<Entrega> {
  Uint8List? _fotoBytes;
  XFile? _fotoFile;
  double? _lat;
  double? _lng;
  bool _loadingGps = false;
  bool _loadingEntrega = false;

  final _picker = ImagePicker();

  // ── FOTO ─────────────────────────────────────────────────────────
  // En web: image_picker abre el selector de archivos del navegador.
  // Si el usuario tiene cámara/webcam, Chrome puede ofrecer esa opción.

  Future<void> _seleccionarFoto() async {
    final foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (foto != null) {
      final bytes = await foto.readAsBytes();
      setState(() {
        _fotoBytes = bytes;
        _fotoFile = foto;
      });
    }
  }

  // ── GPS ──────────────────────────────────────────────────────────
  // geolocator ^12 tiene soporte web completo.
  // Usa navigator.geolocation del navegador internamente.
  // Chrome mostrará popup pidiendo permiso de ubicación.

  Future<void> _obtenerUbicacion() async {
    setState(() => _loadingGps = true);
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        _showSnack(
          'Permiso de ubicación denegado. Actívalo en la configuración del navegador.',
          isError: true,
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _showSnack('No se pudo obtener la ubicación', isError: true);
    } finally {
      setState(() => _loadingGps = false);
    }
  }

  // ── REGISTRAR ENTREGA ─────────────────────────────────────────────

  Future<void> _registrarEntrega() async {
    if (_fotoFile == null || _fotoBytes == null) {
      _showSnack('Selecciona una foto de evidencia primero', isError: true);
      return;
    }
    if (_lat == null || _lng == null) {
      _showSnack('Obtén tu ubicación GPS primero', isError: true);
      return;
    }

    setState(() => _loadingEntrega = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/entregas/'),
      );

      request.fields['id_agente'] = widget.idAgente.toString();
      request.fields['id_paquete'] = widget.idPaquete.toString();
      request.fields['latitud'] = _lat.toString();
      request.fields['longitud'] = _lng.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _fotoBytes!,
          filename: _fotoFile!.name,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      if (response.statusCode == 200) {
        _showSnack('¡Paquete entregado correctamente!');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);
      } else {
        _showSnack(data['detail'] ?? 'Error al registrar', isError: true);
      }
    } catch (e) {
      _showSnack('Error de conexión con el servidor', isError: true);
    } finally {
      setState(() => _loadingEntrega = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Paquete #${widget.idPaquete}',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFC0154A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: Colors.grey[200]),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dirección arriba, sin card
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC0154A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.direccion,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            _paso(1, 'Foto de evidencia', _seccionFoto()),
            const SizedBox(height: 20),
            _paso(2, 'Ubicación GPS', _seccionGps()),
            const SizedBox(height: 28),

            // Botón paso 3
            _paso(
              3,
              '',
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        (_loadingEntrega || _fotoFile == null || _lat == null)
                        ? null
                        : _registrarEntrega,
                    icon: _loadingEntrega
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Paquete entregado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0154A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (_fotoFile == null || _lat == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Completa los pasos anteriores',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget genérico de paso numerado
  Widget _paso(int numero, String titulo, Widget contenido) {
    final activo =
        numero == 1 || (numero == 2 && _fotoFile != null) || (numero == 3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: activo ? const Color(0xFFC0154A) : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$numero',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: activo ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo.isNotEmpty) ...[
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              contenido,
              const SizedBox(height: 4),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionFoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fotoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _fotoBytes!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 32, color: Colors.grey),
                SizedBox(height: 6),
                Text(
                  'Sin foto',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _seleccionarFoto,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC0154A),
            side: const BorderSide(color: Color(0xFFC0154A)),
            minimumSize: const Size(double.infinity, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            _fotoBytes == null ? 'Tomar foto' : 'Cambiar foto',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _seccionGps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lat != null && _lng != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_lat!, _lng!),
                  initialZoom: 16,
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
                        point: LatLng(_lat!, _lng!),
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFC0154A),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ] else
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 28, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  'Sin ubicación',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _loadingGps ? null : _obtenerUbicacion,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC0154A),
            side: const BorderSide(color: Color(0xFFC0154A)),
            minimumSize: const Size(double.infinity, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: _loadingGps
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFC0154A),
                  ),
                )
              : Text(
                  _lat == null ? 'Obtener ubicación' : 'Actualizar',
                  style: const TextStyle(fontSize: 13),
                ),
        ),
      ],
    );
  }
}
