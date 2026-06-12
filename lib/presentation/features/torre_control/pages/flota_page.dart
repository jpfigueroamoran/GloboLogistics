import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../demo/demo_providers.dart' show appModeProvider;
import '../../../../domain/entities/unidad.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../injection_container.dart';
import '../providers/unidades_provider.dart';
import '../providers/usuarios_provider.dart';

/// Gestión de flota: alta, edición y estado de todas las unidades.
class FlotaPage extends ConsumerStatefulWidget {
  const FlotaPage({super.key});

  @override
  ConsumerState<FlotaPage> createState() => _FlotaPageState();
}

class _FlotaPageState extends ConsumerState<FlotaPage> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final unidadesSP = ref.watch(todasUnidadesProvider);
    final usuarios   = ref.watch(usuariosStreamProvider).valueOrNull ?? [];

    return unidadesSP.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(mensaje: e.toString()),
      data:    (unidades) {
        final filtradas = _busqueda.isEmpty
            ? unidades
            : unidades.where((u) {
                final q = _busqueda.toLowerCase();
                return u.placas.toLowerCase().contains(q) ||
                    u.modelo.toLowerCase().contains(q);
              }).toList();

        final disponibles = unidades
            .where((u) => u.estado == EstadoUnidad.activa && !u.enRuta)
            .length;
        final enRuta = unidades.where((u) => u.enRuta).length;
        final mantenimiento = unidades
            .where((u) => u.estado == EstadoUnidad.mantenimiento)
            .length;
        final servicioProximo =
            unidades.where((u) => u.requiereServicio).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPIs ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
              child: Row(children: [
                _KpiCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Flota total',
                  value: '${unidades.length}',
                  color: GloboColors.primary,
                ),
                _KpiCard(
                  icon: Icons.check_circle_outline,
                  label: 'Disponibles',
                  value: '$disponibles',
                  color: GloboColors.success,
                ),
                _KpiCard(
                  icon: Icons.route_outlined,
                  label: 'En ruta',
                  value: '$enRuta',
                  color: GloboColors.estadoTransito,
                ),
                _KpiCard(
                  icon: Icons.build_outlined,
                  label: 'En taller',
                  value: '$mantenimiento',
                  color: GloboColors.warning,
                ),
                _KpiCard(
                  icon: Icons.notification_important_outlined,
                  label: 'Servicio próximo',
                  value: '$servicioProximo',
                  color: servicioProximo > 0
                      ? GloboColors.error
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
                      hintText: 'Buscar por placas o modelo…',
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
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva unidad'),
                  onPressed: () => _abrirDialog(context, null),
                ),
              ]),
            ),

            // ── Grid de unidades ─────────────────────────────────────────
            Expanded(
              child: filtradas.isEmpty
                  ? _EmptyFlota(hayBusqueda: _busqueda.isNotEmpty)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          GloboSpacing.md, 0, GloboSpacing.md, GloboSpacing.md),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 180,
                        crossAxisSpacing: GloboSpacing.md,
                        mainAxisSpacing: GloboSpacing.md,
                      ),
                      itemCount: filtradas.length,
                      itemBuilder: (_, i) => _UnidadCard(
                        unidad: filtradas[i],
                        operadorNombre: _nombreOperador(
                            usuarios, filtradas[i].operadorAsignadoId),
                        onEditar: () =>
                            _abrirDialog(context, filtradas[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String? _nombreOperador(List<UsuarioGlobo> usuarios, String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final u in usuarios) {
      if (u.uid == uid) return u.nombre;
    }
    return uid;
  }

  void _abrirDialog(BuildContext context, Unidad? unidad) {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La gestión de flota se realiza en modo producción'),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _UnidadDialog(unidad: unidad),
    );
  }
}

// ── KPI ───────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
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

// ── Tarjeta de unidad ─────────────────────────────────────────────────────────

class _UnidadCard extends StatelessWidget {
  final Unidad unidad;
  final String? operadorNombre;
  final VoidCallback onEditar;

  const _UnidadCard({
    required this.unidad,
    required this.operadorNombre,
    required this.onEditar,
  });

  (String, Color) get _estadoChip {
    if (unidad.estado == EstadoUnidad.baja) {
      return ('BAJA', GloboColors.textTertiary);
    }
    if (unidad.estado == EstadoUnidad.mantenimiento) {
      return ('EN TALLER', GloboColors.warning);
    }
    if (unidad.enRuta) return ('EN RUTA', GloboColors.estadoTransito);
    return ('DISPONIBLE', GloboColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final (estadoLabel, estadoColor) = _estadoChip;
    final fmtNum = NumberFormat.decimalPattern('es_MX');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(color: estadoColor.withAlpha(60)),
      ),
      child: InkWell(
        onTap: onEditar,
        borderRadius: GloboRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(GloboSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: estadoColor.withAlpha(18),
                    borderRadius: GloboRadius.buttonRadius,
                  ),
                  child: Icon(Icons.local_shipping,
                      color: estadoColor, size: 22),
                ),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(unidad.placas,
                          style: GloboTypography.titleMedium),
                      Text(
                        '${unidad.modelo}${unidad.anio > 0 ? ' · ${unidad.anio}' : ''}',
                        style: GloboTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: estadoColor.withAlpha(18),
                    borderRadius: GloboRadius.chipRadius,
                    border: Border.all(color: estadoColor.withAlpha(80)),
                  ),
                  child: Text(estadoLabel,
                      style: GloboTypography.labelSmall.copyWith(
                          color: estadoColor, fontSize: 10)),
                ),
              ]),
              const SizedBox(height: GloboSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: GloboSpacing.sm),
              Row(children: [
                _DatoMini(
                  icon: Icons.speed_outlined,
                  valor: '${fmtNum.format(unidad.odometro.round())} km',
                ),
                const SizedBox(width: GloboSpacing.md),
                _DatoMini(
                  icon: Icons.local_gas_station_outlined,
                  valor:
                      '${unidad.capacidadTanqueLitros.toStringAsFixed(0)} L',
                ),
                const Spacer(),
                if (unidad.requiereServicio)
                  Tooltip(
                    message: 'Servicio a '
                        '${fmtNum.format(unidad.proximoMantenimientoOdometro!.round())} km',
                    child: const Icon(Icons.notification_important,
                        size: 16, color: GloboColors.error),
                  ),
              ]),
              const Spacer(),
              Row(children: [
                Icon(Icons.person_outline,
                    size: 14,
                    color: operadorNombre != null
                        ? GloboColors.textSecondary
                        : GloboColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    operadorNombre ?? 'Sin operador asignado',
                    style: GloboTypography.caption.copyWith(
                      color: operadorNombre != null
                          ? GloboColors.textSecondary
                          : GloboColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.edit_outlined,
                    size: 14, color: GloboColors.textTertiary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoMini extends StatelessWidget {
  final IconData icon;
  final String valor;
  const _DatoMini({required this.icon, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: GloboColors.textTertiary),
      const SizedBox(width: 4),
      Text(valor, style: GloboTypography.caption),
    ]);
  }
}

// ── Diálogo alta / edición ────────────────────────────────────────────────────

class _UnidadDialog extends ConsumerStatefulWidget {
  final Unidad? unidad;
  const _UnidadDialog({this.unidad});

  @override
  ConsumerState<_UnidadDialog> createState() => _UnidadDialogState();
}

class _UnidadDialogState extends ConsumerState<_UnidadDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _placasCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _odometroCtrl;
  late final TextEditingController _tanqueCtrl;
  late final TextEditingController _proxMantCtrl;

  late EstadoUnidad _estado;
  String? _operadorId;
  bool _guardando = false;

  bool get esEdicion => widget.unidad != null;

  @override
  void initState() {
    super.initState();
    final u = widget.unidad;
    _placasCtrl   = TextEditingController(text: u?.placas ?? '');
    _modeloCtrl   = TextEditingController(text: u?.modelo ?? '');
    _anioCtrl     = TextEditingController(
        text: (u?.anio ?? 0) > 0 ? '${u!.anio}' : '');
    _odometroCtrl = TextEditingController(
        text: u != null ? u.odometro.toStringAsFixed(0) : '');
    _tanqueCtrl   = TextEditingController(
        text: u != null ? u.capacidadTanqueLitros.toStringAsFixed(0) : '');
    _proxMantCtrl = TextEditingController(
        text: u?.proximoMantenimientoOdometro?.toStringAsFixed(0) ?? '');
    _estado     = u?.estado ?? EstadoUnidad.activa;
    _operadorId = u?.operadorAsignadoId;
  }

  @override
  void dispose() {
    _placasCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _odometroCtrl.dispose();
    _tanqueCtrl.dispose();
    _proxMantCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = <String, dynamic>{
      'placas':   _placasCtrl.text.trim().toUpperCase(),
      'modelo':   _modeloCtrl.text.trim(),
      'anio':     int.tryParse(_anioCtrl.text) ?? 0,
      'estado':   _estado.name,
      'odometro': double.tryParse(_odometroCtrl.text) ?? 0,
      'capacidad_tanque': double.tryParse(_tanqueCtrl.text) ?? 0,
      'operador_asignado_id': _operadorId,
      if (_proxMantCtrl.text.trim().isNotEmpty)
        'proximo_mantenimiento_odometro':
            double.tryParse(_proxMantCtrl.text) ?? 0,
    };

    try {
      final db = sl<FirestoreDatasource>();
      if (esEdicion) {
        await db.actualizarUnidad(widget.unidad!.id, data);
      } else {
        await db.crearUnidad(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(esEdicion
            ? 'Unidad ${_placasCtrl.text.trim().toUpperCase()} actualizada'
            : 'Unidad ${_placasCtrl.text.trim().toUpperCase()} dada de alta'),
        backgroundColor: GloboColors.success,
      ));
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
    final usuarios = ref.watch(usuariosStreamProvider).valueOrNull ?? [];
    final operadores = usuarios
        .where((u) => u.rol == RolUsuario.operador && u.activo)
        .toList();

    return AlertDialog(
      title: Row(children: [
        Icon(esEdicion ? Icons.edit_outlined : Icons.add_circle_outline,
            size: 20, color: GloboColors.primary),
        const SizedBox(width: GloboSpacing.sm),
        Text(esEdicion
            ? 'Editar unidad ${widget.unidad!.placas}'
            : 'Nueva unidad'),
      ]),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _placasCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          const InputDecoration(labelText: 'Placas *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.sm),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _anioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año'),
                    ),
                  ),
                ]),
                const SizedBox(height: GloboSpacing.sm),
                TextFormField(
                  controller: _modeloCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Modelo / Marca *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: GloboSpacing.sm),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _odometroCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Odómetro (km)'),
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _tanqueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Tanque (L)'),
                    ),
                  ),
                ]),
                const SizedBox(height: GloboSpacing.sm),
                TextFormField(
                  controller: _proxMantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Próximo servicio (odómetro km)',
                    helperText:
                        'La unidad pasará a taller al superar este odómetro',
                  ),
                ),
                const SizedBox(height: GloboSpacing.md),
                DropdownButtonFormField<EstadoUnidad>(
                  initialValue: _estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(
                        value: EstadoUnidad.activa, child: Text('Activa')),
                    DropdownMenuItem(
                        value: EstadoUnidad.mantenimiento,
                        child: Text('En mantenimiento')),
                    DropdownMenuItem(
                        value: EstadoUnidad.baja, child: Text('Baja')),
                  ],
                  onChanged: (v) => setState(() => _estado = v!),
                ),
                const SizedBox(height: GloboSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: _operadorId,
                  decoration: const InputDecoration(
                      labelText: 'Operador asignado'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('— Sin asignar —')),
                    ...operadores.map((o) => DropdownMenuItem<String?>(
                          value: o.uid,
                          child: Text(o.nombre,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _operadorId = v),
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
          label: Text(esEdicion ? 'Guardar cambios' : 'Dar de alta'),
        ),
      ],
    );
  }
}

// ── Vistas vacías / error ─────────────────────────────────────────────────────

class _EmptyFlota extends StatelessWidget {
  final bool hayBusqueda;
  const _EmptyFlota({required this.hayBusqueda});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hayBusqueda
                ? Icons.search_off_outlined
                : Icons.local_shipping_outlined,
            size: 48,
            color: GloboColors.textTertiary,
          ),
          const SizedBox(height: GloboSpacing.md),
          Text(
            hayBusqueda
                ? 'Sin resultados para la búsqueda'
                : 'Aún no hay unidades registradas',
            style: GloboTypography.titleMedium
                .copyWith(color: GloboColors.textSecondary),
          ),
          if (!hayBusqueda) ...[
            const SizedBox(height: GloboSpacing.xs),
            Text(
              'Da de alta tu primera unidad con el botón "Nueva unidad"',
              style: GloboTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String mensaje;
  const _ErrorView({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 48, color: GloboColors.textTertiary),
          const SizedBox(height: GloboSpacing.md),
          Text('No se pudo cargar la flota',
              style: GloboTypography.titleMedium),
          const SizedBox(height: GloboSpacing.xs),
          Text(mensaje,
              style: GloboTypography.caption,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
