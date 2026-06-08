import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/mantenimiento_provider.dart';
import '../providers/documentos_provider.dart';
import '../widgets/tco_panel_widget.dart';
import '../widgets/alerta_panel_widget.dart';
import '../widgets/fleet_map_widget.dart';
import 'score_operadores_page.dart';
import 'despacho_page.dart';
import 'alertas_reglas_page.dart';
import 'mantenimiento_page.dart';
import 'documentos_page.dart';
import 'auditoria_page.dart';
import 'usuarios_page.dart';
import 'historial_viajes_page.dart';
import '../../../../demo/demo_providers.dart' show demoUserProvider;

// ── Índices de sección ────────────────────────────────────────────────────────

enum _Seccion {
  overview,
  despacho,
  scoreOperadores,
  mantenimiento,
  documentos,
  alertas,
  auditoria,
  historialViajes,
  usuarios,
}

// ── Shell principal ───────────────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  _Seccion _seccion = _Seccion.overview;

  @override
  Widget build(BuildContext context) {
    final metrics    = ref.watch(dashboardMetricsProvider);
    final criticos   = ref.watch(mantenimientosCriticosProvider);
    final vencidos   = ref.watch(documentosVencidosCountProvider);
    final authState  = ref.watch(authStatusProvider);
    final esAdmin    = authState.usuario?.rol == RolUsuario.administrador;

    return Scaffold(
      backgroundColor: GloboColors.backgroundSecondary,
      body: Row(
        children: [
          _Sidebar(
            selected: _seccion,
            alertasCount: metrics.alertasActivas,
            mantenimientoCriticos: criticos,
            documentosVencidos: vencidos,
            esAdmin: esAdmin,
            onSelect: (s) => setState(() => _seccion = s),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  metrics: metrics,
                  seccionLabel: _seccionLabel(_seccion),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _seccionLabel(_Seccion s) => switch (s) {
        _Seccion.overview        => 'Dashboard Ejecutivo',
        _Seccion.despacho        => 'Centro de Despacho',
        _Seccion.scoreOperadores => 'Score de Operadores',
        _Seccion.mantenimiento   => 'Mantenimiento Predictivo',
        _Seccion.documentos      => 'Documentos y Vencimientos',
        _Seccion.alertas         => 'Reglas de Alerta',
        _Seccion.auditoria       => 'Auditoría',
        _Seccion.historialViajes => 'Historial y TCO',
        _Seccion.usuarios        => 'Gestión de Usuarios',
      };

  Widget _buildContent() => switch (_seccion) {
        _Seccion.overview        => _OverviewContent(
            viajesSP: ref.watch(viajesActivosProvider),
            metrics: ref.watch(dashboardMetricsProvider),
          ),
        _Seccion.despacho        => const DespachoPag(),
        _Seccion.scoreOperadores => const ScoreOperadoresPage(),
        _Seccion.mantenimiento   => const MantenimientoPage(),
        _Seccion.documentos      => const DocumentosPage(),
        _Seccion.alertas         => const AlertasReglasPage(),
        _Seccion.auditoria       => const AuditoriaPage(),
        _Seccion.historialViajes => const HistorialViajesPage(),
        _Seccion.usuarios        => const UsuariosPage(),
      };
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _Seccion selected;
  final int alertasCount;
  final int mantenimientoCriticos;
  final int documentosVencidos;
  final bool esAdmin;
  final ValueChanged<_Seccion> onSelect;

  const _Sidebar({
    required this.selected,
    required this.alertasCount,
    required this.mantenimientoCriticos,
    required this.documentosVencidos,
    required this.esAdmin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: GloboColors.primary,
      child: Column(
        children: [
          const SizedBox(height: GloboSpacing.lg),
          _LogoIcon(),
          const Divider(color: Colors.white24, height: GloboSpacing.xl),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Overview',
            isSelected: selected == _Seccion.overview,
            onTap: () => onSelect(_Seccion.overview),
          ),
          _NavItem(
            icon: Icons.assignment_outlined,
            label: 'Despacho',
            isSelected: selected == _Seccion.despacho,
            onTap: () => onSelect(_Seccion.despacho),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Score',
            isSelected: selected == _Seccion.scoreOperadores,
            onTap: () => onSelect(_Seccion.scoreOperadores),
          ),
          _NavItem(
            icon: Icons.build_outlined,
            label: 'Mantto.',
            badge: mantenimientoCriticos > 0
                ? mantenimientoCriticos
                : null,
            isSelected: selected == _Seccion.mantenimiento,
            onTap: () => onSelect(_Seccion.mantenimiento),
          ),
          _NavItem(
            icon: Icons.description_outlined,
            label: 'Docs.',
            badge:
                documentosVencidos > 0 ? documentosVencidos : null,
            isSelected: selected == _Seccion.documentos,
            onTap: () => onSelect(_Seccion.documentos),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.warning_amber_outlined,
            label: 'Alertas',
            badge: alertasCount > 0 ? alertasCount : null,
            isSelected: selected == _Seccion.alertas,
            onTap: () => onSelect(_Seccion.alertas),
          ),
          _NavItem(
            icon: Icons.fact_check_outlined,
            label: 'Auditoría',
            isSelected: selected == _Seccion.auditoria,
            onTap: () => onSelect(_Seccion.auditoria),
          ),
          _NavItem(
            icon: Icons.history_outlined,
            label: 'Historial',
            isSelected: selected == _Seccion.historialViajes,
            onTap: () => onSelect(_Seccion.historialViajes),
          ),
          const Spacer(),
          if (esAdmin) ...[
            const Divider(color: Colors.white24, height: GloboSpacing.md),
            _NavItem(
              icon: Icons.manage_accounts_outlined,
              label: 'Usuarios',
              isSelected: selected == _Seccion.usuarios,
              onTap: () => onSelect(_Seccion.usuarios),
            ),
          ],
          const SizedBox(height: GloboSpacing.lg),
          const Divider(color: Colors.white24, height: GloboSpacing.md),
          Consumer(
            builder: (context, ref, _) {
              return _NavItem(
                icon: Icons.logout,
                label: 'Cerrar Sesión',
                onTap: () {
                  ref.read(demoUserProvider.notifier).state = null;
                },
              );
            },
          ),
          const SizedBox(height: GloboSpacing.lg),
        ],
      ),
    );
  }
}

class _LogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: GloboColors.accentBright,
        borderRadius: GloboRadius.buttonRadius,
      ),
      child: const Center(
        child: Text(
          'GL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int? badge;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 56,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withAlpha(20)
                : Colors.transparent,
            border: isSelected
                ? const Border(
                    left: BorderSide(
                        color: GloboColors.accentGlow, width: 3))
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
                size: 22,
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: GloboColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final DashboardMetrics metrics;
  final String seccionLabel;

  const _TopBar({required this.metrics, required this.seccionLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.xl),
      color: GloboColors.surface,
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TORRE DE CONTROL',
                style: GloboTypography.labelSmall.copyWith(
                  letterSpacing: 2.5,
                  color: GloboColors.textTertiary,
                ),
              ),
              Text(seccionLabel, style: GloboTypography.headlineMedium),
            ],
          ),
          const Spacer(),
          _MetricChip(
            icon: Icons.local_shipping,
            label: '${metrics.viajesEnCurso} en ruta',
            color: GloboColors.estadoTransito,
          ),
          const SizedBox(width: GloboSpacing.sm),
          if (metrics.alertasActivas > 0)
            _MetricChip(
              icon: Icons.warning_amber,
              label: '${metrics.alertasActivas} alertas',
              color: GloboColors.error,
            ),
          if (metrics.viajesBanderaRoja > 0) ...[
            const SizedBox(width: GloboSpacing.sm),
            _MetricChip(
              icon: Icons.flag,
              label: '${metrics.viajesBanderaRoja} banderas',
              color: GloboColors.error,
            ),
          ],
          const SizedBox(width: GloboSpacing.lg),
          _DateTimeDisplay(),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.sm, vertical: GloboSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GloboTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _DateTimeDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.year}',
          style: GloboTypography.monoData.copyWith(fontSize: 12),
        ),
        Text(
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}',
          style: GloboTypography.titleMedium.copyWith(letterSpacing: 1),
        ),
      ],
    );
  }
}

// ── Vista Overview ────────────────────────────────────────────────────────────

class _OverviewContent extends StatelessWidget {
  final AsyncValue<List<Viaje>> viajesSP;
  final DashboardMetrics metrics;

  const _OverviewContent({
    required this.viajesSP,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const Expanded(flex: 3, child: FleetMapWidget()),
              Expanded(flex: 2, child: _ViajesTable(viajesSP: viajesSP)),
            ],
          ),
        ),
        SizedBox(
          width: 340,
          child: Container(
            color: GloboColors.surface,
            child: const Column(
              children: [
                Expanded(child: AlertaPanelWidget()),
                Divider(height: 0),
                Expanded(child: TcoPanelWidget()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ViajesTable extends StatelessWidget {
  final AsyncValue<List<Viaje>> viajesSP;
  const _ViajesTable({required this.viajesSP});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(
          GloboSpacing.md, 0, GloboSpacing.md, GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              children: [
                Text('Viajes Activos',
                    style: GloboTypography.titleMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filtrar'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: viajesSP.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (viajes) => viajes.isEmpty
                  ? const Center(child: Text('No hay viajes activos'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: viajes.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (ctx, i) {
                        final v = viajes[i];
                        return ListTile(
                          leading: _EstadoIndicator(estado: v.estado),
                          title: Text(
                            '${v.origenDescripcion} → ${v.destinoDescripcion}',
                            style: GloboTypography.titleMedium,
                          ),
                          subtitle: Text(
                            'TCO: \$${v.tco.total.toStringAsFixed(0)} MXN  |  '
                            'Litros: ${v.litrosCargados.toStringAsFixed(0)} L',
                            style: GloboTypography.caption,
                          ),
                          trailing: v.tieneBanderaRoja
                              ? const Icon(Icons.flag,
                                  color: GloboColors.error, size: 20)
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoIndicator extends StatelessWidget {
  final EstadoViaje estado;
  const _EstadoIndicator({required this.estado});

  Color get _color => switch (estado) {
        EstadoViaje.programado => GloboColors.steelGray,
        EstadoViaje.enCurso   => GloboColors.estadoTransito,
        EstadoViaje.completado => GloboColors.success,
        EstadoViaje.cancelado  => GloboColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}
