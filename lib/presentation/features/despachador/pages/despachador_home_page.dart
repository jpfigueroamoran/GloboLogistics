import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../demo/demo_providers.dart' show appModeProvider;
import '../../../../domain/entities/solicitud_transporte.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../injection_container.dart';
import '../../auth/widgets/rol_home_scaffold.dart';
import '../../solicitante/providers/solicitudes_provider.dart';
import '../../torre_control/pages/despacho_page.dart';
import '../../torre_control/pages/entregas_page.dart';
import '../../torre_control/providers/dashboard_provider.dart'
    show viajeRepositoryProvider;

/// Pantalla del Despachador: convierte la demanda (solicitudes) en oferta
/// (viajes asignados) y vigila las entregas. Tres pestañas, una misión.
class DespachadorHomePage extends ConsumerStatefulWidget {
  const DespachadorHomePage({super.key});

  @override
  ConsumerState<DespachadorHomePage> createState() =>
      _DespachadorHomePageState();
}

class _DespachadorHomePageState extends ConsumerState<DespachadorHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = ref.watch(solicitudesPendientesCountProvider);

    return RolHomeScaffold(
      titulo: 'Centro de Despacho',
      subtitulo: 'Solicitudes → viajes → entregas',
      bottom: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: GloboColors.textOnDarkSecondary,
        indicatorColor: GloboColors.accentGlow,
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: pendientes > 0,
              label: Text('$pendientes'),
              child: const Icon(Icons.inbox_outlined, size: 20),
            ),
            text: 'Solicitudes',
          ),
          const Tab(
              icon: Icon(Icons.assignment_outlined, size: 20),
              text: 'Asignar'),
          const Tab(
              icon: Icon(Icons.route_outlined, size: 20), text: 'Entregas'),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ColaSolicitudes(),
          DespachoPag(),
          EntregasPage(),
        ],
      ),
    );
  }
}

// ── Cola de solicitudes ───────────────────────────────────────────────────────

class _ColaSolicitudes extends ConsumerWidget {
  const _ColaSolicitudes();

  Color _color(EstadoSolicitud e) => switch (e) {
        EstadoSolicitud.pendiente => GloboColors.warning,
        EstadoSolicitud.asignada  => GloboColors.info,
        EstadoSolicitud.enRuta    => GloboColors.estadoTransito,
        EstadoSolicitud.entregada => GloboColors.success,
        EstadoSolicitud.rechazada => GloboColors.error,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaSP = ref.watch(colaSolicitudesProvider);
    return colaSP.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inbox_outlined,
                  size: 48, color: GloboColors.textTertiary),
              const SizedBox(height: GloboSpacing.md),
              Text('No hay solicitudes',
                  style: GloboTypography.titleMedium
                      .copyWith(color: GloboColors.textSecondary)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(GloboSpacing.md),
          itemCount: solicitudes.length,
          separatorBuilder: (_, __) => const SizedBox(height: GloboSpacing.sm),
          itemBuilder: (_, i) => _SolicitudQueueCard(
            solicitud: solicitudes[i],
            color: _color(solicitudes[i].estado),
          ),
        );
      },
    );
  }
}

class _SolicitudQueueCard extends ConsumerWidget {
  final SolicitudTransporte solicitud;
  final Color color;
  const _SolicitudQueueCard({required this.solicitud, required this.color});

  Future<void> _avanzar(
      BuildContext context, WidgetRef ref, EstadoSolicitud nuevo) async {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La gestión de solicitudes es en modo producción'),
      ));
      return;
    }
    await sl<FirestoreDatasource>()
        .actualizarEstadoSolicitud(solicitud.id, nuevo);
  }

  /// Convierte la solicitud en un viaje programado y las enlaza. El viaje
  /// aparece en la pestaña "Asignar" para ponerle unidad y operador; al
  /// arrancar, el motor mueve la solicitud a "en ruta" y luego "entregada".
  Future<void> _crearViaje(BuildContext context, WidgetRef ref) async {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La creación de viajes es en modo producción'),
      ));
      return;
    }
    final ahora = DateTime.now();
    final viaje = Viaje(
      id: '',
      unidadId: '',
      operadorId: '',
      origenDescripcion: solicitud.origen,
      destinoDescripcion: solicitud.destino,
      estado: EstadoViaje.programado,
      solicitudId: solicitud.id,
      observaciones: 'Material: ${solicitud.material}'
          '${solicitud.notas != null ? ' · ${solicitud.notas}' : ''}',
      createdAt: ahora,
      updatedAt: ahora,
    );
    final result = await ref.read(viajeRepositoryProvider).crearViaje(viaje);
    if (!context.mounted) return;
    await result.fold(
      (f) async => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${f.message}')),
      ),
      (viajeId) async {
        await sl<FirestoreDatasource>().actualizarEstadoSolicitud(
          solicitud.id,
          EstadoSolicitud.asignada,
          viajeId: viajeId,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Viaje creado — asígnale unidad y operador en la pestaña "Asignar"'),
          backgroundColor: GloboColors.success,
        ));
      },
    );
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Motivo'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: GloboColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null) return;
    if (ref.read(appModeProvider)) return;
    await sl<FirestoreDatasource>().actualizarEstadoSolicitud(
      solicitud.id,
      EstadoSolicitud.rechazada,
      motivoRechazo: motivo.isEmpty ? 'Sin especificar' : motivo,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM, HH:mm', 'es_MX');
    final esUrgente = solicitud.prioridad == PrioridadSolicitud.urgente ||
        solicitud.prioridad == PrioridadSolicitud.alta;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(
            color: esUrgente && solicitud.esActiva
                ? GloboColors.error.withAlpha(80)
                : GloboColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(solicitud.material,
                    style: GloboTypography.titleMedium,
                    overflow: TextOverflow.ellipsis),
              ),
              if (esUrgente && solicitud.esActiva)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(solicitud.prioridad.label.toUpperCase(),
                      style: GloboTypography.labelSmall.copyWith(
                          color: GloboColors.error, fontSize: 9)),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: GloboRadius.chipRadius,
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(solicitud.estado.label,
                    style: GloboTypography.labelSmall
                        .copyWith(color: color, fontSize: 10)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${solicitud.origen}  →  ${solicitud.destino}',
                style: GloboTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Row(children: [
              Icon(Icons.person_outline,
                  size: 12, color: GloboColors.textTertiary),
              const SizedBox(width: 4),
              Text(solicitud.solicitanteNombre,
                  style: GloboTypography.caption),
              const Spacer(),
              Text(fmt.format(solicitud.createdAt),
                  style: GloboTypography.caption),
            ]),
            if (solicitud.esActiva) ...[
              const SizedBox(height: GloboSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: GloboSpacing.sm),
              Row(children: _acciones(context, ref)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _acciones(BuildContext context, WidgetRef ref) {
    switch (solicitud.estado) {
      case EstadoSolicitud.pendiente:
        return [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 15),
              label: const Text('Rechazar'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: GloboColors.error),
              onPressed: () => _rechazar(context, ref),
            ),
          ),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_road, size: 15),
              label: const Text('Crear viaje'),
              onPressed: () => _crearViaje(context, ref),
            ),
          ),
        ];
      case EstadoSolicitud.asignada:
        return [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping_outlined, size: 15),
              label: const Text('Marcar en ruta'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: GloboColors.estadoTransito),
              onPressed: () => _avanzar(context, ref, EstadoSolicitud.enRuta),
            ),
          ),
        ];
      case EstadoSolicitud.enRuta:
        return [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.flag_outlined, size: 15),
              label: const Text('Marcar entregada'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: GloboColors.success),
              onPressed: () =>
                  _avanzar(context, ref, EstadoSolicitud.entregada),
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}
