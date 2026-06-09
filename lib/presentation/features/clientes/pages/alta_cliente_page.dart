import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/geocoding_service.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';

class AltaClientePage extends ConsumerStatefulWidget {
  static const routeName = '/clientes/alta';

  const AltaClientePage({super.key});

  @override
  ConsumerState<AltaClientePage> createState() => _AltaClientePageState();
}

class _AltaClientePageState extends ConsumerState<AltaClientePage> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _rfcCtrl      = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _notasCtrl    = TextEditingController();
  final _mapController = MapController();

  GeoPoint? _posicion;
  bool _buscando = false;
  bool _guardando = false;

  final _geocodingService = GetIt.instance<GeocodingService>();
  final _repo = GetIt.instance<IClienteRepository>();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _rfcCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _contactoCtrl.dispose();
    _notasCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _buscarDireccion() async {
    final q = _direccionCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _buscando = true);
    try {
      final resultados = await _geocodingService.buscarDireccion(q);
      if (!mounted) return;
      setState(() => _buscando = false);
      if (resultados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la dirección. Agrega más detalles.'),
          ),
        );
        return;
      }
      _mostrarResultados(resultados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar: $e')),
      );
    }
  }

  void _mostrarResultados(List<GeocodingResult> resultados) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Selecciona la dirección',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                itemCount: resultados.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    resultados[i].displayName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _seleccionarResultado(resultados[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _seleccionarResultado(GeocodingResult r) {
    setState(() {
      _posicion = GeoPoint(lat: r.lat, lng: r.lng);
      _direccionCtrl.text = r.displayName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(LatLng(r.lat, r.lng), 15);
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final rfc = _rfcCtrl.text.trim().toUpperCase();
    final data = <String, dynamic>{
      'nombre': _nombreCtrl.text.trim(),
      'nombre_busqueda': _nombreCtrl.text.trim().toLowerCase(),
      'direccion': _direccionCtrl.text.trim(),
      'activo': true,
      'created_at': FieldValue.serverTimestamp(),
    };
    if (rfc.isNotEmpty) data['rfc'] = rfc;
    if (_posicion != null) {
      data['posicion'] = {'lat': _posicion!.lat, 'lng': _posicion!.lng};
    }
    if (_telefonoCtrl.text.trim().isNotEmpty) {
      data['telefono'] = _telefonoCtrl.text.trim();
    }
    if (_contactoCtrl.text.trim().isNotEmpty) {
      data['contacto'] = _contactoCtrl.text.trim();
    }
    if (_notasCtrl.text.trim().isNotEmpty) {
      data['notas'] = _notasCtrl.text.trim();
    }

    final result = await _repo.crearCliente(data);
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente registrado exitosamente')),
        );
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre / Razón Social *',
                hintText: 'Transportes del Norte S.A. de C.V.',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rfcCtrl,
              decoration: const InputDecoration(
                labelText: 'RFC (opcional)',
                hintText: 'AAA000000XXX',
                counterText: '',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 13,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9&ÑñÃ]')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección *',
                      hintText: 'Calle, colonia, ciudad, estado',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buscando
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          onPressed: _buscarDireccion,
                          icon: const Icon(Icons.search),
                          tooltip: 'Buscar en mapa',
                        ),
                ),
              ],
            ),
            if (_posicion != null) ...[
              const SizedBox(height: 12),
              _MapPreview(
                posicion: _posicion!,
                controller: _mapController,
                onTap: (pos) => setState(
                  () => _posicion = GeoPoint(lat: pos.latitude, lng: pos.longitude),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Toca el mapa para ajustar la ubicación',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+52 xxx xxx xxxx',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoCtrl,
              decoration: const InputDecoration(
                labelText: 'Persona de contacto',
                hintText: 'Nombre del encargado',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Horario de recepción, instrucciones especiales...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar Cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final GeoPoint posicion;
  final MapController controller;
  final void Function(LatLng) onTap;

  const _MapPreview({
    required this.posicion,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: LatLng(posicion.lat, posicion.lng),
            initialZoom: 15,
            onTap: (_, latlng) => onTap(latlng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.globo.logistics',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(posicion.lat, posicion.lng),
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
