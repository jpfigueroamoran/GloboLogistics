import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../demo/demo_providers.dart' show demoUserProvider, appModeProvider;
import '../../../../domain/entities/solicitud_transporte.dart';
import '../../../../injection_container.dart';
import '../../auth/providers/auth_provider.dart'
    show signOut, firebaseAuthProvider;
import '../../operador/widgets/offline_banner.dart';
import '../providers/solicitudes_provider.dart';

/// Pantalla de inicio del Solicitante. Un solo verbo: pedir transporte.
/// Debajo, sus solicitudes con estado en vivo (no tiene que llamar a nadie).
class SolicitanteHomePage extends ConsumerWidget {
  final String solicitanteUid;
  final String nombre;

  const SolicitanteHomePage({
    super.key,
    required this.solicitanteUid,
    required this.nombre,
  });

  Color _estadoColor(EstadoSolicitud e) => switch (e) {
        EstadoSolicitud.pendiente => GloboColors.warning,
        EstadoSolicitud.asignada  => GloboColors.info,
        EstadoSolicitud.enRuta    => GloboColors.estadoTransito,
        EstadoSolicitud.entregada => GloboColors.success,
        EstadoSolicitud.rechazada => GloboColors.error,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesSP = ref.watch(misSolicitudesProvider(solicitanteUid));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GloboColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('GLOBO LOGISTICS',
                style: GloboTypography.labelSmall.copyWith(
                    color: GloboColors.textOnDarkSecondary,
                    letterSpacing: 2,
                    fontSize: 9)),
            Text(nombre,
                style: GloboTypography.titleMedium
                    .copyWith(color: GloboColors.textOnDark),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GloboColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Pedir transporte'),
        onPressed: () => _nuevaSolicitud(context, ref),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: solicitudesSP.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('No se pudieron cargar tus solicitudes\n$e',
                    textAlign: TextAlign.center,
                    style: GloboTypography.caption),
              ),
              data: (solicitudes) => solicitudes.isEmpty
                  ? const _SinSolicitudes()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 96),
                      itemCount: solicitudes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GloboSpacing.sm),
                      itemBuilder: (_, i) => _SolicitudCard(
                        solicitud: solicitudes[i],
                        color: _estadoColor(solicitudes[i].estado),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    if (ref.read(appModeProvider)) {
      ref.read(demoUserProvider.notifier).state = null;
    } else {
      signOut(ref.read(firebaseAuthProvider));
    }
  }

  void _nuevaSolicitud(BuildContext context, WidgetRef ref) {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Las solicitudes se registran en modo producción'),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NuevaSolicitudSheet(
        solicitanteUid: solicitanteUid,
        solicitanteNombre: nombre,
      ),
    );
  }
}

// ── Tarjeta de solicitud ──────────────────────────────────────────────────────

class _SolicitudCard extends StatelessWidget {
  final SolicitudTransporte solicitud;
  final Color color;
  const _SolicitudCard({required this.solicitud, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, HH:mm', 'es_MX');
    return Card(
      margin: EdgeInsets.zero,
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
            const SizedBox(height: GloboSpacing.sm),
            Row(children: [
              const Icon(Icons.circle, size: 9, color: GloboColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(solicitud.origen,
                    style: GloboTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            Row(children: [
              const Icon(Icons.location_on,
                  size: 13, color: GloboColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(solicitud.destino,
                    style: GloboTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.flag_outlined,
                  size: 12, color: GloboColors.textTertiary),
              const SizedBox(width: 4),
              Text('Prioridad ${solicitud.prioridad.label.toLowerCase()}',
                  style: GloboTypography.caption),
              const Spacer(),
              Text(fmt.format(solicitud.createdAt),
                  style: GloboTypography.caption),
            ]),
            if (solicitud.estado == EstadoSolicitud.rechazada &&
                solicitud.motivoRechazo != null) ...[
              const SizedBox(height: 6),
              Text('Motivo: ${solicitud.motivoRechazo}',
                  style: GloboTypography.caption
                      .copyWith(color: GloboColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Hoja de nueva solicitud ───────────────────────────────────────────────────

class _NuevaSolicitudSheet extends ConsumerStatefulWidget {
  final String solicitanteUid;
  final String solicitanteNombre;
  const _NuevaSolicitudSheet({
    required this.solicitanteUid,
    required this.solicitanteNombre,
  });

  @override
  ConsumerState<_NuevaSolicitudSheet> createState() =>
      _NuevaSolicitudSheetState();
}

class _NuevaSolicitudSheetState extends ConsumerState<_NuevaSolicitudSheet> {
  final _formKey = GlobalKey<FormState>();
  final _materialCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  PrioridadSolicitud _prioridad = PrioridadSolicitud.normal;
  bool _guardando = false;

  @override
  void dispose() {
    _materialCtrl.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await sl<FirestoreDatasource>().crearSolicitudTransporte({
        'solicitante_uid': widget.solicitanteUid,
        'solicitante_nombre': widget.solicitanteNombre,
        'material': _materialCtrl.text.trim(),
        'origen': _origenCtrl.text.trim(),
        'destino': _destinoCtrl.text.trim(),
        'prioridad': _prioridad.name,
        if (_notasCtrl.text.trim().isNotEmpty) 'notas': _notasCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solicitud enviada — Despacho la verá de inmediato'),
        backgroundColor: GloboColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: GloboColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GloboSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: GloboSpacing.md),
                  decoration: BoxDecoration(
                    color: GloboColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Nueva solicitud de transporte',
                  style: GloboTypography.titleMedium),
              const SizedBox(height: GloboSpacing.md),
              TextFormField(
                controller: _materialCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué material necesitas mover? *',
                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _origenCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Origen (dónde se recoge) *',
                  prefixIcon: Icon(Icons.circle_outlined, size: 16),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _destinoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Destino (dónde se entrega) *',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              DropdownButtonFormField<PrioridadSolicitud>(
                initialValue: _prioridad,
                decoration: const InputDecoration(
                  labelText: 'Prioridad',
                  prefixIcon: Icon(Icons.flag_outlined, size: 18),
                ),
                items: PrioridadSolicitud.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _prioridad = v!),
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              const SizedBox(height: GloboSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _enviar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Enviar solicitud'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vacío ─────────────────────────────────────────────────────────────────────

class _SinSolicitudes extends StatelessWidget {
  const _SinSolicitudes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 56, color: GloboColors.textTertiary),
            const SizedBox(height: GloboSpacing.md),
            Text('Aún no has pedido transporte',
                style: GloboTypography.titleMedium
                    .copyWith(color: GloboColors.textSecondary)),
            const SizedBox(height: GloboSpacing.xs),
            Text(
              'Toca "Pedir transporte" y sigue aquí el estado de tu material '
              'en todo momento.',
              style: GloboTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
