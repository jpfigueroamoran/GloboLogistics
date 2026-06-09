import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/entities/unidad.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';
import '../../../../injection_container.dart';
import '../../../features/clientes/widgets/cliente_selector_widget.dart';
import '../providers/dashboard_provider.dart';
import '../providers/unidades_provider.dart';

import '../providers/usuarios_provider.dart';
import '../../../../domain/entities/usuario_globo.dart';

class DespachoPag extends ConsumerStatefulWidget {
  const DespachoPag({super.key});

  @override
  ConsumerState<DespachoPag> createState() => _DespachoPagState();
}

class _DespachoPagState extends ConsumerState<DespachoPag> {
  String? _selectedUnidadId;
  String? _selectedViajeId;
  String? _selectedOperadorId;

  @override
  Widget build(BuildContext context) {
    final unidadesSP = ref.watch(unidadesActivasProvider);
    final viajesSP   = ref.watch(viajesActivosProvider);
    final usuariosSP = ref.watch(usuariosStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna unidades
                Expanded(
                  child: _UnidadesColumn(
                    unidadesSP: unidadesSP,
                    selectedId: _selectedUnidadId,
                    onSelect: (id) => setState(() => _selectedUnidadId = id),
                  ),
                ),
                const SizedBox(width: GloboSpacing.md),
                // Columna viajes pendientes
                Expanded(
                  child: _ViajesColumn(
                    viajesSP: viajesSP,
                    selectedId: _selectedViajeId,
                    onSelect: (id) => setState(() => _selectedViajeId = id),
                  ),
                ),
                const SizedBox(width: GloboSpacing.md),
                // Panel de asignación
                SizedBox(
                  width: 300,
                  child: _AsignacionPanel(
                    unidadesSP: unidadesSP,
                    viajesSP: viajesSP,
                    usuariosSP: usuariosSP,
                    selectedUnidadId: _selectedUnidadId,
                    selectedViajeId: _selectedViajeId,
                    selectedOperadorId: _selectedOperadorId,
                    onAsignar: _asignar,
                    onLimpiar: () => setState(() {
                      _selectedUnidadId = null;
                      _selectedViajeId = null;
                      _selectedOperadorId = null;
                    }),
                    onOperadorChanged: (id) => setState(() => _selectedOperadorId = id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _asignar() async {
    if (_selectedUnidadId == null || _selectedViajeId == null || _selectedOperadorId == null) return;
    
    final opId = _selectedOperadorId!;

    final result = await sl<IViajeRepository>().asignarViaje(
      _selectedViajeId!,
      opId,
      _selectedUnidadId!,
    );

    result.fold(
      (f) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al asignar: ${f.message}')),
        );
      },
      (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje asignado correctamente.'),
            backgroundColor: GloboColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedUnidadId = null;
          _selectedViajeId  = null;
          _selectedOperadorId = null;
        });
      },
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  void _mostrarNuevoViajeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _NuevoViajeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Centro de Despacho', style: GloboTypography.headlineMedium),
              Text('Asigna operadores, unidades y viajes pendientes',
                  style: GloboTypography.bodyMedium),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Nuevo Viaje'),
          onPressed: () => _mostrarNuevoViajeDialog(context),
        ),
      ],
    );
  }
}

// ── Diálogo Nuevo Viaje ───────────────────────────────────────────────────────

class _NuevoViajeDialog extends ConsumerStatefulWidget {
  const _NuevoViajeDialog();

  @override
  ConsumerState<_NuevoViajeDialog> createState() => _NuevoViajeDialogState();
}

class _NuevoViajeDialogState extends ConsumerState<_NuevoViajeDialog> {
  final _origenCtrl  = TextEditingController();
  final _notasCtrl   = TextEditingController();

  Cliente? _clienteDestino;
  bool _guardando = false;

  @override
  void dispose() {
    _origenCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_origenCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el origen del viaje')),
      );
      return;
    }
    if (_clienteDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el cliente destino')),
      );
      return;
    }

    setState(() => _guardando = true);
    final ahora = DateTime.now();

    final viaje = Viaje(
      id: '',
      unidadId: '',
      operadorId: '',
      origenDescripcion: _origenCtrl.text.trim(),
      destinoDescripcion: _clienteDestino!.nombre,
      destinoGeo: _clienteDestino!.posicion,
      estado: EstadoViaje.programado,
      createdAt: ahora,
      updatedAt: ahora,
      observaciones: _notasCtrl.text.trim().isEmpty
          ? null
          : _notasCtrl.text.trim(),
    );

    final result = await sl<IViajeRepository>().crearViaje(viaje);
    if (!mounted) return;

    result.fold(
      (f) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${f.message}')),
        );
      },
      (_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje creado — pendiente de asignación'),
            backgroundColor: GloboColors.success,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_road, size: 20),
          SizedBox(width: 8),
          Text('Nuevo Viaje'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _origenCtrl,
              decoration: const InputDecoration(
                labelText: 'Origen (bodega de carga) *',
                hintText: 'Centro de Distribución Norte',
                prefixIcon: Icon(Icons.circle_outlined, size: 16),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            ClienteSelectorWidget(
              label: 'Cliente / Destino de descarga *',
              onSelected: (c) => setState(() => _clienteDestino = c),
            ),
            if (_clienteDestino?.posicion == null &&
                _clienteDestino != null) ...[
              const SizedBox(height: 4),
              Text(
                'Este cliente no tiene coordenadas GPS — el geofence no estará disponible.',
                style: GloboTypography.caption
                    .copyWith(color: GloboColors.warning),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas de despacho (opcional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _crear,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Crear Viaje'),
        ),
      ],
    );
  }
}

// ── Columna de unidades ───────────────────────────────────────────────────────

class _UnidadesColumn extends StatelessWidget {
  final AsyncValue<List<Unidad>> unidadesSP;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _UnidadesColumn({
    required this.unidadesSP,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 18, color: GloboColors.primary),
                const SizedBox(width: GloboSpacing.sm),
                Text('Unidades', style: GloboTypography.titleMedium),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: unidadesSP.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (unidades) => ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: unidades.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) => _UnidadTile(
                  unidad: unidades[i],
                  isSelected: unidades[i].id == selectedId,
                  onTap: () => onSelect(unidades[i].id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnidadTile extends StatelessWidget {
  final Unidad unidad;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnidadTile({
    required this.unidad,
    required this.isSelected,
    required this.onTap,
  });

  Color get _estadoColor => switch (unidad.estado) {
        EstadoUnidad.activa       => GloboColors.successAccent,
        EstadoUnidad.mantenimiento => GloboColors.warningAccent,
        EstadoUnidad.baja          => GloboColors.error,
      };

  String get _estadoLabel => switch (unidad.estado) {
        EstadoUnidad.activa       => 'Activa',
        EstadoUnidad.mantenimiento => 'Mantto.',
        EstadoUnidad.baja          => 'Baja',
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: isSelected
          ? GloboColors.primary.withAlpha(12)
          : null,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _estadoColor,
        ),
      ),
      title: Text(unidad.placas, style: GloboTypography.titleMedium),
      subtitle: Text(unidad.modelo, style: GloboTypography.caption),
      trailing: Text(
        _estadoLabel,
        style: GloboTypography.labelSmall.copyWith(color: _estadoColor),
      ),
      onTap: onTap,
    );
  }
}

// ── Columna de viajes ─────────────────────────────────────────────────────────

class _ViajesColumn extends StatelessWidget {
  final AsyncValue<List<Viaje>> viajesSP;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ViajesColumn({
    required this.viajesSP,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.route_outlined,
                    size: 18, color: GloboColors.primary),
                const SizedBox(width: GloboSpacing.sm),
                Text('Viajes Pendientes',
                    style: GloboTypography.titleMedium),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: viajesSP.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (viajes) {
                final pendientes = viajes
                    .where((v) => v.estado == EstadoViaje.programado)
                    .toList();
                if (pendientes.isEmpty) {
                  return const Center(
                      child: Text('Sin viajes pendientes'));
                }
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: pendientes.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) => _ViajeTile(
                    viaje: pendientes[i],
                    isSelected: pendientes[i].id == selectedId,
                    onTap: () => onSelect(pendientes[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ViajeTile extends StatelessWidget {
  final Viaje viaje;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViajeTile({
    required this.viaje,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: isSelected
          ? GloboColors.primary.withAlpha(12)
          : null,
      leading: const Icon(
        Icons.flag_outlined,
        size: 20,
        color: GloboColors.steelGray,
      ),
      title: Text(
        viaje.origenDescripcion,
        style: GloboTypography.titleMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '→ ${viaje.destinoDescripcion}',
        style: GloboTypography.caption,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

// ── Panel de asignación ───────────────────────────────────────────────────────

class _AsignacionPanel extends StatelessWidget {
  final AsyncValue<List<Unidad>> unidadesSP;
  final AsyncValue<List<Viaje>> viajesSP;
  final AsyncValue<List<UsuarioGlobo>> usuariosSP;
  final String? selectedUnidadId;
  final String? selectedViajeId;
  final String? selectedOperadorId;
  final VoidCallback onAsignar;
  final VoidCallback onLimpiar;
  final ValueChanged<String?> onOperadorChanged;

  const _AsignacionPanel({
    required this.unidadesSP,
    required this.viajesSP,
    required this.usuariosSP,
    required this.selectedUnidadId,
    required this.selectedViajeId,
    required this.selectedOperadorId,
    required this.onAsignar,
    required this.onLimpiar,
    required this.onOperadorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unidades = unidadesSP.valueOrNull ?? [];
    final viajes   = viajesSP.valueOrNull ?? [];
    final usuarios = usuariosSP.valueOrNull ?? [];
    final operadores = usuarios.where((u) => u.esOperador).toList();

    final unidad = selectedUnidadId != null
        ? unidades.where((u) => u.id == selectedUnidadId).firstOrNull
        : null;
    final viaje = selectedViajeId != null
        ? viajes.where((v) => v.id == selectedViajeId).firstOrNull
        : null;

    final canAsignar = unidad != null && viaje != null && selectedOperadorId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 18, color: GloboColors.primary),
                const SizedBox(width: GloboSpacing.sm),
                Text('Asignación', style: GloboTypography.titleMedium),
              ],
            ),
            const SizedBox(height: GloboSpacing.md),
            // Operator Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: GloboRadius.buttonRadius,
                border: Border.all(color: GloboColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('Seleccionar Operador', style: GloboTypography.bodyMedium),
                  value: selectedOperadorId,
                  items: operadores.map((op) {
                    return DropdownMenuItem<String>(
                      value: op.uid,
                      child: Text(op.nombre, style: GloboTypography.bodyMedium),
                    );
                  }).toList(),
                  onChanged: onOperadorChanged,
                ),
              ),
            ),
            const SizedBox(height: GloboSpacing.md),
            _AsignacionSlot(
              label: 'Unidad seleccionada',
              value: unidad != null
                  ? '${unidad.placas}\n${unidad.modelo}'
                  : null,
              icon: Icons.local_shipping_outlined,
            ),
            const SizedBox(height: GloboSpacing.sm),
            _AsignacionSlot(
              label: 'Viaje seleccionado',
              value: viaje != null
                  ? '${viaje.origenDescripcion}\n→ ${viaje.destinoDescripcion}'
                  : null,
              icon: Icons.route_outlined,
            ),
            const Spacer(),
            if (!canAsignar)
              Text(
                'Selecciona operador, unidad y viaje para asignar',
                style: GloboTypography.caption,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: GloboSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAsignar ? onAsignar : null,
                child: const Text('Confirmar Asignación'),
              ),
            ),
            const SizedBox(height: GloboSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onLimpiar,
                child: const Text('Limpiar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsignacionSlot extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const _AsignacionSlot({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GloboSpacing.sm),
      decoration: BoxDecoration(
        color: hasValue
            ? GloboColors.primary.withAlpha(12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(
          color: hasValue
              ? GloboColors.primary.withAlpha(60)
              : GloboColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: hasValue
                  ? GloboColors.primary
                  : GloboColors.steelGrayLight),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            child: hasValue
                ? Text(value!, style: GloboTypography.bodyMedium)
                : Text(label,
                    style: GloboTypography.caption
                        .copyWith(color: GloboColors.steelGrayLight)),
          ),
        ],
      ),
    );
  }
}
