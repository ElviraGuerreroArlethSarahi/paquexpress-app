// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'entrega.dart';
import 'historial.dart';
import 'login.dart';

class Home extends StatefulWidget {
  final int    idAgente;
  final String nombre;

  const Home({super.key, required this.idAgente, required this.nombre});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<dynamic> _paquetes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarPaquetes();
  }

  Future<void> _cargarPaquetes() async {
    setState(() => _loading = true);
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/paquetes/pendientes'));
      if (response.statusCode == 200) {
        setState(() => _paquetes = jsonDecode(response.body));
      }
    } catch (_) {
      _showSnack('Error al cargar paquetes');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  void _irAEntrega(Map<String, dynamic> paquete) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Entrega(
          idAgente:  widget.idAgente,
          idPaquete: paquete['id_paquete'],
          direccion: paquete['direccion_destino'],
        ),
      ),
    );
    // Si se completó la entrega, refrescar la lista
    if (resultado == true) _cargarPaquetes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.nombre.split(' ').first}'),
        backgroundColor: const Color(0xFFC0154A),
        actions: [
          // Historial
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Historial(idAgente: widget.idAgente),
              ),
            ),
          ),
          // Cerrar sesión
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Login()),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paquetes.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _cargarPaquetes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paquetes.length,
                    itemBuilder: (_, i) => _paqueteCard(_paquetes[i]),
                  ),
                ),
    );
  }

  Widget _paqueteCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE3EAF8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.inventory_2_outlined,
              color: Color(0xFFC0154A)),
        ),
        title: Text(
          'Paquete #${p['id_paquete']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(p['direccion_destino'],
              style: const TextStyle(fontSize: 13)),
        ),
        trailing: ElevatedButton(
          onPressed: () => _irAEntrega(p),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text('Entregar', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        const Text('¡Sin paquetes pendientes!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _cargarPaquetes,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar'),
        ),
      ]),
    );
  }
}