import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../demo/demo_providers.dart' show appModeProvider;
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';
import '../../../../injection_container.dart';
import '../../../app/router.dart';
import '../../operador/providers/clientes_provider.dart';

/// Cartera de clientes: directorio, búsqueda, alta y edición.
class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final clientesSP = ref.watch(clientesStreamProvider);

    return clientesSP.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('No se pudieron cargar los clientes\n$e',
            textAlign: TextAlign.center, style: GloboTypography.caption),
      ),
      data: (clientes) {
        final filtrados = _busqueda.isEmpty
            ? clientes
            : clientes.where((c) {
                final q = _busqueda.toLowerCase();
                return c.nombre.toLowerCase().contains(q) ||
                    c.direccion.toLowerCase().contains(q) ||
                    (c.rfc ?? '').toLowerCase().contains(q);
              }).toList();

        final geocodificados =
            clientes.where((c) => c.posicion != null).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPIs ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
              child: Row(children: [
                _KpiChip(
                  icon: Icons.business_outlined,
                  label: 'Clientes activos',
                  value: '${clientes.length}',
                  color: GloboColors.primary,
                ),
                _KpiChip(
                  icon: Icons.location_on_outlined,
                  label: 'Con coordenadas (geofencing)',
                  value: '$geocodificados',
                  color: GloboColors.success,
                ),
                _KpiChip(
                  icon: Icons.location_off_outlined,
                  label: 'Sin geocodificar',
                  value: '${clientes.length - geocodificados}',
                  color: clientes.length - geocodificados > 0
                      ? GloboColors.warning
                      : GloboColors.textTertiary,
                ),
              ]),
            ),

            // ── Búsqueda + alta ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(GloboSpacing.md),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, dirección o RFC…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: GloboRadius.buttonRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GloboSpacing.md),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('Nuevo cliente'),
                  onPressed: () => context.push(AppRoutes.altaCliente),
                ),
              ]),
            ),

            // ── Lista ────────────────────────────────────────────────────
            Expanded(
              child: filtrados.isEmpty
                  ? _EmptyClientes(hayBusqueda: _busqueda.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          GloboSpacing.md, 0, GloboSpacing.md, GloboSpacing.md),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GloboSpacing.sm),
                      itemBuilder: (_, i) => _ClienteCard(
                        cliente: filtrados[i],
                        onEditar: () => _editar(context, filtrados[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _editar(BuildContext context, Cliente cliente) {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La edición de clientes se realiza en modo producción'),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _ClienteDialog(cliente: cliente),
    );
  }
}

// ── KPI ───────────────────────────────────────────────────────────────────────

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: GloboSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
        decoration: BoxDecoration(
          color: GloboColors.surface,
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: GloboTypography.headlineMedium
                        .copyWith(color: color)),
                Text(label,
                    style: GloboTypography.caption,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tarjeta de cliente ────────────────────────────────────────────────────────

class _ClienteCard extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onEditar;

  const _ClienteCard({required this.cliente, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final geocodificado = cliente.posicion != null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onEditar,
        borderRadius: GloboRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: GloboColors.primary.withAlpha(14),
                borderRadius: GloboRadius.buttonRadius,
              ),
              child: Center(
                child: Text(
                  cliente.nombre.isNotEmpty
                      ? cliente.nombre.characters.first.toUpperCase()
                      : '?',
                  style: GloboTypography.titleMedium
                      .copyWith(color: GloboColors.primary),
                ),
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(cliente.nombre,
                          style: GloboTypography.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (cliente.rfc != null &&
                        cliente.rfc!.isNotEmpty) ...[
                      const SizedBox(width: GloboSpacing.sm),
                      Text(cliente.rfc!,
                          style: GloboTypography.caption
                              .copyWith(letterSpacing: 0.5)),
                    ],
                  ]),
                  Text(cliente.direccion,
                      style: GloboTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: GloboSpacing.sm),
            if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: GloboSpacing.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_outlined,
                      size: 13, color: GloboColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(cliente.telefono!, style: GloboTypography.caption),
                ]),
              ),
            Tooltip(
              message: geocodificado
                  ? 'Geocodificado — listo para geofencing'
                  : 'Sin coordenadas — el cierre automático de viajes no aplica',
              child: Icon(
                geocodificado
                    ? Icons.location_on
                    : Icons.location_off_outlined,
                size: 16,
                color: geocodificado
                    ? GloboColors.success
                    : GloboColors.warning,
              ),
            ),
            const SizedBox(width: GloboSpacing.sm),
            const Icon(Icons.edit_outlined,
                size: 15, color: GloboColors.textTertiary),
          ]),
        ),
      ),
    );
  }
}

// ── Diálogo de edición ────────────────────────────────────────────────────────

class _ClienteDialog extends ConsumerStatefulWidget {
  final Cliente cliente;
  const _ClienteDialog({required this.cliente});

  @override
  ConsumerState<_ClienteDialog> createState() => _ClienteDialogState();
}

class _ClienteDialogState extends ConsumerState<_ClienteDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _rfcCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _contactoCtrl;
  late final TextEditingController _notasCtrl;

  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombreCtrl    = TextEditingController(text: c.nombre);
    _direccionCtrl = TextEditingController(text: c.direccion);
    _rfcCtrl       = TextEditingController(text: c.rfc ?? '');
    _telefonoCtrl  = TextEditingController(text: c.telefono ?? '');
    _contactoCtrl  = TextEditingController(text: c.contacto ?? '');
    _notasCtrl     = TextEditingController(text: c.notas ?? '');
    _activo        = c.activo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _rfcCtrl.dispose();
    _telefonoCtrl.dispose();
    _contactoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = <String, dynamic>{
      'nombre':    _nombreCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'rfc':       _rfcCtrl.text.trim().toUpperCase(),
      'telefono':  _telefonoCtrl.text.trim(),
      'contacto':  _contactoCtrl.text.trim(),
      'notas':     _notasCtrl.text.trim(),
      'activo':    _activo,
    };

    // Si cambió la dirección, re-geocodificar con Nominatim (gratis)
    final direccionCambio =
        _direccionCtrl.text.trim() != widget.cliente.direccion;
    if (direccionCambio) {
      try {
        final resultados = await sl<GeocodingService>()
            .buscarDireccion(_direccionCtrl.text.trim());
        if (resultados.isNotEmpty) {
          data['posicion'] = {
            'lat': resultados.first.lat,
            'lng': resultados.first.lng,
          };
        }
      } catch (_) {
        // Sin coordenadas nuevas — se conservan las anteriores
      }
    }

    try {
      final result = await sl<IClienteRepository>()
          .actualizarCliente(widget.cliente.id, data);
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _guardando = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${failure.message}'),
            backgroundColor: GloboColors.error,
          ));
        },
        (_) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cliente ${_nombreCtrl.text.trim()} actualizado'),
            backgroundColor: GloboColors.success,
          ));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: GloboColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.edit_outlined,
            size: 20, color: GloboColors.primary),
        const SizedBox(width: GloboSpacing.sm),
        Expanded(
          child: Text('Editar ${widget.cliente.nombre}',
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre / Razón social *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: GloboSpacing.sm),
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección *',
                    helperText:
                        'Si cambia, se geocodifica de nuevo automáticamente',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: GloboSpacing.sm),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rfcCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'RFC'),
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Teléfono'),
                    ),
                  ),
                ]),
                const SizedBox(height: GloboSpacing.sm),
                TextFormField(
                  controller: _contactoCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Persona de contacto'),
                ),
                const SizedBox(height: GloboSpacing.sm),
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: GloboSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cliente activo'),
                  subtitle: Text(
                    _activo
                        ? 'Visible en despacho y selector de viajes'
                        : 'Oculto — no aparecerá al crear viajes',
                    style: GloboTypography.caption,
                  ),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 16),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

// ── Vista vacía ───────────────────────────────────────────────────────────────

class _EmptyClientes extends StatelessWidget {
  final bool hayBusqueda;
  const _EmptyClientes({required this.hayBusqueda});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hayBusqueda ? Icons.search_off_outlined : Icons.business_outlined,
            size: 48,
            color: GloboColors.textTertiary,
          ),
          const SizedBox(height: GloboSpacing.md),
          Text(
            hayBusqueda
                ? 'Sin resultados para la búsqueda'
                : 'Aún no hay clientes registrados',
            style: GloboTypography.titleMedium
                .copyWith(color: GloboColors.textSecondary),
          ),
          if (!hayBusqueda) ...[
            const SizedBox(height: GloboSpacing.xs),
            Text(
              'Registra el primero con "Nuevo cliente" — la dirección se '
              'geocodifica sola',
              style: GloboTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}
