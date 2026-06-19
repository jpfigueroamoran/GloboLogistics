import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/automatizacion_service.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../injection_container.dart';
import '../../../app/sos_overlay.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/mantenimiento_provider.dart';
import '../providers/documentos_provider.dart';
import '../widgets/tco_panel_widget.dart';
import '../widgets/alerta_panel_widget.dart';
import '../widgets/fleet_map_widget.dart';
import '../widgets/notification_center_widget.dart';
import 'score_operadores_page.dart';
import 'despacho_page.dart';
import 'entregas_page.dart';
import 'flota_page.dart';
import 'clientes_page.dart';
import 'alertas_reglas_page.dart';
import 'mantenimiento_page.dart';
import 'documentos_page.dart';
import 'auditoria_page.dart';
import 'usuarios_page.dart';
import 'historial_viajes_page.dart';
import 'finanzas_page.dart';
import 'facturacion_page.dart';
import 'proveedores_page.dart';
import 'resumen_financiero_page.dart';
import 'cierre_mensual_page.dart';
import 'reportes_page.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../demo/demo_providers.dart' show demoUserProvider, appModeProvider;

// ── Índices de sección ────────────────────────────────────────────────────────

enum _Seccion {
  overview,
  entregas,
  despacho,
  flota,
  clientes,
  scoreOperadores,
  mantenimiento,
  documentos,
  resumen,
  finanzas,
  proveedores,
  alertas,
  auditoria,
  historialViajes,
  usuarios,
  facturacion,
  cierreMensual,
  reportes,
}

// ── Shell principal ───────────────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  _Seccion _seccion = _Seccion.overview;
  bool _sidebarExpanded = false;

  // SOS ya vistos — para disparar el overlay solo con alertas nuevas
  final Set<String> _sosVistos = {};
  bool _sosInicializado = false;

  @override
  void initState() {
    super.initState();
    // Motor de automatización (reemplazo costo-cero de las Cloud Functions):
    // corre mientras Torre de Control esté abierta, solo en producción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(appModeProvider)) {
        sl<AutomatizacionService>().iniciar();
      }
    });
  }

  @override
  void dispose() {
    sl<AutomatizacionService>().detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics    = ref.watch(dashboardMetricsProvider);
    final criticos   = ref.watch(mantenimientosCriticosProvider);
    final vencidos   = ref.watch(documentosVencidosCountProvider);
    final authState  = ref.watch(authStatusProvider);
    final esAdmin    = authState.usuario?.rol == RolUsuario.administrador;

    // Overlay SOS en tiempo real desde el stream de Firestore — reemplazo
    // costo-cero del push FCM (que requiere Cloud Functions / plan Blaze).
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(alertasStreamProvider,
        (_, next) {
      final alertas = next.valueOrNull;
      if (alertas == null) return;
      final sosActivos = alertas.where((a) => a['tipo'] == 'sos');
      if (!_sosInicializado) {
        // Las alertas que ya existían al abrir el dashboard no disparan overlay
        _sosInicializado = true;
        _sosVistos.addAll(
            sosActivos.map((a) => a['id'] as String? ?? '').where((id) => id.isNotEmpty));
        return;
      }
      for (final a in sosActivos) {
        final id = a['id'] as String? ?? '';
        if (id.isEmpty || _sosVistos.contains(id)) continue;
        _sosVistos.add(id);
        SosOverlay.show(
          context,
          titulo:     '🚨 PROTOCOLO SOS ACTIVADO',
          cuerpo:     'Un operador necesita asistencia inmediata.',
          operadorId: a['operador_id'] as String? ?? '—',
          unidadId:   a['unidad_id'] as String? ?? '—',
          onAtender:  () => setState(() => _seccion = _Seccion.overview),
        );
      }
    });

    final esCompacto = MediaQuery.sizeOf(context).width < 800;

    final contenido = Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey(_seccion),
          child: _buildContent(),
        ),
      ),
    );

    // ── Teléfonos / ventanas angostas: navegación en Drawer ─────────────
    if (esCompacto) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: GloboColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'TORRE DE CONTROL',
                style: GloboTypography.labelSmall.copyWith(
                  color: GloboColors.textOnDarkSecondary,
                  letterSpacing: 2,
                  fontSize: 9,
                ),
              ),
              Text(
                _seccionLabel(_seccion),
                style: GloboTypography.titleMedium
                    .copyWith(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            const NotificationCenterWidget(),
            _ThemeModeToggle(),
            const SizedBox(width: 4),
          ],
        ),
        drawer: Drawer(
          width: 230,
          child: _Sidebar(
            selected: _seccion,
            alertasCount: metrics.alertasActivas,
            entregasEnRuta: metrics.viajesEnCurso,
            mantenimientoCriticos: criticos,
            documentosVencidos: vencidos,
            esAdmin: esAdmin,
            expanded: true,
            onSelect: (s) {
              setState(() => _seccion = s);
              Navigator.of(context).pop(); // cerrar drawer al navegar
            },
            onToggleExpanded: () {},
          ),
        ),
        body: Column(children: [contenido]),
      );
    }

    // ── Escritorio / tablet horizontal: sidebar fijo ─────────────────────
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: _seccion,
            alertasCount: metrics.alertasActivas,
            entregasEnRuta: metrics.viajesEnCurso,
            mantenimientoCriticos: criticos,
            documentosVencidos: vencidos,
            esAdmin: esAdmin,
            expanded: _sidebarExpanded,
            onSelect: (s) => setState(() => _seccion = s),
            onToggleExpanded: () =>
                setState(() => _sidebarExpanded = !_sidebarExpanded),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  metrics: metrics,
                  seccionLabel: _seccionLabel(_seccion),
                ),
                contenido,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _seccionLabel(_Seccion s) => switch (s) {
        _Seccion.overview        => 'Dashboard Ejecutivo',
        _Seccion.entregas        => 'Entregas en Curso',
        _Seccion.despacho        => 'Centro de Despacho',
        _Seccion.flota           => 'Gestión de Flota',
        _Seccion.clientes        => 'Cartera de Clientes',
        _Seccion.scoreOperadores => 'Score de Operadores',
        _Seccion.mantenimiento   => 'Mantenimiento Predictivo',
        _Seccion.documentos      => 'Documentos y Vencimientos',
        _Seccion.resumen         => 'Resumen Financiero',
        _Seccion.finanzas        => 'Finanzas — Activos y Pólizas',
        _Seccion.proveedores     => 'Proveedores, CxP e Inventario',
        _Seccion.alertas         => 'Reglas de Alerta',
        _Seccion.auditoria       => 'Auditoría',
        _Seccion.historialViajes => 'Historial y TCO',
        _Seccion.usuarios        => 'Gestión de Usuarios',
        _Seccion.facturacion     => 'Facturación / CxC',
        _Seccion.cierreMensual   => 'Cierre Mensual',
        _Seccion.reportes        => 'Analítica y Reportes',
      };

  Widget _buildContent() => switch (_seccion) {
        _Seccion.overview        => _OverviewContent(
            viajesSP: ref.watch(viajesActivosProvider),
            metrics: ref.watch(dashboardMetricsProvider),
            onNavigate: (s) => setState(() => _seccion = s),
          ),
        _Seccion.entregas        => const EntregasPage(),
        _Seccion.despacho        => const DespachoPag(),
        _Seccion.flota           => const FlotaPage(),
        _Seccion.clientes        => const ClientesPage(),
        _Seccion.scoreOperadores => const ScoreOperadoresPage(),
        _Seccion.mantenimiento   => const MantenimientoPage(),
        _Seccion.documentos      => const DocumentosPage(),
        _Seccion.resumen         => const ResumenFinancieroPage(),
        _Seccion.finanzas        => const FinanzasPage(),
        _Seccion.proveedores     => const ProveedoresPage(),
        _Seccion.alertas         => const AlertasReglasPage(),
        _Seccion.auditoria       => const AuditoriaPage(),
        _Seccion.historialViajes => const HistorialViajesPage(),
        _Seccion.usuarios        => const UsuariosPage(),
        _Seccion.facturacion     => const FacturacionPage(),
        _Seccion.cierreMensual   => const CierreMensualPage(),
        _Seccion.reportes        => const ReportesPage(),
      };
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _Seccion selected;
  final int alertasCount;
  final int entregasEnRuta;
  final int mantenimientoCriticos;
  final int documentosVencidos;
  final bool esAdmin;
  final bool expanded;
  final ValueChanged<_Seccion> onSelect;
  final VoidCallback onToggleExpanded;

  const _Sidebar({
    required this.selected,
    required this.alertasCount,
    required this.entregasEnRuta,
    required this.mantenimientoCriticos,
    required this.documentosVencidos,
    required this.esAdmin,
    required this.expanded,
    required this.onSelect,
    required this.onToggleExpanded,
  });

  void _logout(WidgetRef ref) {
    if (ref.read(appModeProvider)) {
      ref.read(demoUserProvider.notifier).state = null;
    } else {
      signOut(ref.read(firebaseAuthProvider));
    }
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
            'La automatización y las alertas en tiempo real se pausarán '
            'hasta el siguiente acceso.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) _logout(ref);
  }

  @override
  Widget build(BuildContext context) {
    final e = expanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: e ? 200 : 72,
      color: GloboColors.primary,
      child: Column(
        children: [
          const SizedBox(height: GloboSpacing.md),
          // ── Logo + toggle ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: e ? 12 : 0),
            child: Row(
              mainAxisAlignment:
                  e ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                _LogoIcon(),
                if (e)
                  const Text(
                    'GLOBO',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    e ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white38,
                    size: 18,
                  ),
                  tooltip: e ? 'Contraer' : 'Expandir',
                  onPressed: onToggleExpanded,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 16),

          // ── Items de navegación (scrollable para evitar overflow) ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── OPERACIONES ──────────────────────────────────────
                  _GroupLabel('OPS', expanded: e),
                  _NavItem(icon: Icons.dashboard_outlined,   label: 'Overview',  expanded: e, isSelected: selected == _Seccion.overview,        onTap: () => onSelect(_Seccion.overview)),
                  _NavItem(icon: Icons.route_outlined,       label: 'Entregas',  expanded: e, isSelected: selected == _Seccion.entregas,         badge: entregasEnRuta > 0 ? entregasEnRuta : null, onTap: () => onSelect(_Seccion.entregas)),
                  _NavItem(icon: Icons.assignment_outlined,  label: 'Despacho',  expanded: e, isSelected: selected == _Seccion.despacho,         onTap: () => onSelect(_Seccion.despacho)),
                  _NavItem(icon: Icons.local_shipping_outlined, label: 'Flota',  expanded: e, isSelected: selected == _Seccion.flota,            onTap: () => onSelect(_Seccion.flota)),
                  _NavItem(icon: Icons.business_outlined,    label: 'Clientes',  expanded: e, isSelected: selected == _Seccion.clientes,         onTap: () => onSelect(_Seccion.clientes)),
                  _NavItem(icon: Icons.people_outline,       label: 'Score Op.', expanded: e, isSelected: selected == _Seccion.scoreOperadores,  onTap: () => onSelect(_Seccion.scoreOperadores)),
                  _NavItem(icon: Icons.build_outlined,       label: 'Mantto.',   expanded: e, isSelected: selected == _Seccion.mantenimiento,    badge: mantenimientoCriticos > 0 ? mantenimientoCriticos : null, onTap: () => onSelect(_Seccion.mantenimiento)),
                  _NavItem(icon: Icons.description_outlined, label: 'Docs.',     expanded: e, isSelected: selected == _Seccion.documentos,       badge: documentosVencidos > 0 ? documentosVencidos : null,       onTap: () => onSelect(_Seccion.documentos)),

                  // ── FINANZAS ─────────────────────────────────────────
                  // Supervisor: solo consulta (Resumen, Facturación, Reportes).
                  // Finanzas/activos, Proveedores y Cierre → solo admin.
                  const SizedBox(height: 4),
                  _GroupLabel('FIN', expanded: e),
                  _NavItem(icon: Icons.bar_chart_outlined,       label: 'Resumen',     expanded: e, isSelected: selected == _Seccion.resumen,       onTap: () => onSelect(_Seccion.resumen)),
                  _NavItem(icon: Icons.receipt_long_outlined,    label: 'Facturación', expanded: e, isSelected: selected == _Seccion.facturacion,   onTap: () => onSelect(_Seccion.facturacion)),
                  if (esAdmin) ...[
                    _NavItem(icon: Icons.account_balance_outlined, label: 'Finanzas',    expanded: e, isSelected: selected == _Seccion.finanzas,      onTap: () => onSelect(_Seccion.finanzas)),
                    _NavItem(icon: Icons.inventory_2_outlined,     label: 'Prov. & Inv.', expanded: e, isSelected: selected == _Seccion.proveedores, onTap: () => onSelect(_Seccion.proveedores)),
                    _NavItem(icon: Icons.check_box_outlined,       label: 'Cierre Mes',  expanded: e, isSelected: selected == _Seccion.cierreMensual, onTap: () => onSelect(_Seccion.cierreMensual)),
                  ],
                  _NavItem(icon: Icons.analytics_outlined,       label: 'Reportes',    expanded: e, isSelected: selected == _Seccion.reportes,      onTap: () => onSelect(_Seccion.reportes)),

                  // ── CONTROL ──────────────────────────────────────────
                  const SizedBox(height: 4),
                  _GroupLabel('CTRL', expanded: e),
                  _NavItem(icon: Icons.warning_amber_outlined, label: 'Alertas',   expanded: e, isSelected: selected == _Seccion.alertas,        badge: alertasCount > 0 ? alertasCount : null, onTap: () => onSelect(_Seccion.alertas)),
                  if (esAdmin)
                    _NavItem(icon: Icons.fact_check_outlined,    label: 'Auditoría', expanded: e, isSelected: selected == _Seccion.auditoria,      onTap: () => onSelect(_Seccion.auditoria)),
                  _NavItem(icon: Icons.history_outlined,       label: 'Historial', expanded: e, isSelected: selected == _Seccion.historialViajes, onTap: () => onSelect(_Seccion.historialViajes)),

                  // ── ADMIN ────────────────────────────────────────────
                  if (esAdmin) ...[
                    const SizedBox(height: 4),
                    _GroupLabel('ADM', expanded: e),
                    _NavItem(icon: Icons.manage_accounts_outlined, label: 'Usuarios', expanded: e, isSelected: selected == _Seccion.usuarios, onTap: () => onSelect(_Seccion.usuarios)),
                  ],
                ],
              ),
            ),
          ),

          // ── Footer fijo — siempre visible ──────────────────────────
          const Divider(color: Colors.white24, height: GloboSpacing.md),
          Consumer(
            builder: (context, ref, _) {
              return _NavItem(
                icon: Icons.logout,
                label: 'Salir',
                expanded: e,
                onTap: () => _confirmarLogout(context, ref),
              );
            },
          ),
          const SizedBox(height: GloboSpacing.sm),
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
  final bool expanded;
  final int? badge;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.expanded = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: isSelected ? Colors.white.withAlpha(20) : Colors.transparent,
      border: isSelected
          ? const Border(left: BorderSide(color: GloboColors.accentGlow, width: 3))
          : null,
    );
    final iconWidget = Icon(
      icon,
      color: isSelected ? Colors.white : Colors.white54,
      size: 22,
    );

    if (expanded) {
      return Tooltip(
        message: '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: decoration,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    iconWidget,
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: _BadgeWidget(badge!),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 52,
          decoration: decoration,
          child: Stack(
            alignment: Alignment.center,
            children: [
              iconWidget,
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 10,
                  child: _BadgeWidget(badge!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeWidget extends StatelessWidget {
  final int count;
  const _BadgeWidget(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: GloboColors.error,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final DashboardMetrics metrics;
  final String seccionLabel;

  const _TopBar({required this.metrics, required this.seccionLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(width: GloboSpacing.sm),
          const NotificationCenterWidget(),
          if (metrics.viajesBanderaRoja > 0) ...[
            const SizedBox(width: GloboSpacing.sm),
            _MetricChip(
              icon: Icons.flag,
              label: '${metrics.viajesBanderaRoja} banderas',
              color: GloboColors.error,
            ),
          ],
          const SizedBox(width: GloboSpacing.sm),
          _ThemeModeToggle(),
          const SizedBox(width: GloboSpacing.lg),
          const _DateTimeDisplay(),
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
  const _DateTimeDisplay();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (_, snap) {
        final now = snap.data!;
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
      },
    );
  }
}

// ── Etiqueta de grupo para el sidebar ────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String label;
  final bool expanded;
  const _GroupLabel(this.label, {this.expanded = false});

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(child: Divider(color: Colors.white12, height: 1)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: GloboSpacing.xs,
        horizontal: GloboSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white12, height: 1)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 5),
          const Expanded(child: Divider(color: Colors.white12, height: 1)),
        ],
      ),
    );
  }
}

// ── Toggle modo oscuro / claro ────────────────────────────────────────────────

class _ThemeModeToggle extends ConsumerWidget {
  const _ThemeModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 20,
        color: GloboColors.steelGray,
      ),
      tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
      onPressed: () => ref.read(themeModeProvider.notifier).state =
          isDark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

// ── Vista Overview ────────────────────────────────────────────────────────────

class _OverviewContent extends StatelessWidget {
  final AsyncValue<List<Viaje>> viajesSP;
  final DashboardMetrics metrics;
  final ValueChanged<_Seccion> onNavigate;

  const _OverviewContent({
    required this.viajesSP,
    required this.metrics,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final esCompacto = MediaQuery.sizeOf(context).width < 800;

    // ── Teléfono: todo apilado y scrolleable ─────────────────────────────
    if (esCompacto) {
      return ListView(
        padding: const EdgeInsets.only(bottom: GloboSpacing.lg),
        children: [
          _QuickActionsBar(onNavigate: onNavigate, compacto: true),
          const SizedBox(height: GloboSpacing.sm),
          const SizedBox(height: 240, child: FleetMapWidget()),
          const SizedBox(height: GloboSpacing.sm),
          SizedBox(height: 300, child: _ViajesTable(viajesSP: viajesSP)),
          const SizedBox(height: 320, child: AlertaPanelWidget()),
          const Divider(height: 0),
          const SizedBox(height: 300, child: TcoPanelWidget()),
        ],
      );
    }

    // ── Escritorio: mapa + tabla con panel lateral ───────────────────────
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _QuickActionsBar(onNavigate: onNavigate),
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

// ── Accesos rápidos del Overview ──────────────────────────────────────────────

class _QuickActionsBar extends StatelessWidget {
  final ValueChanged<_Seccion> onNavigate;
  final bool compacto;
  const _QuickActionsBar({required this.onNavigate, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final acciones = [
      _QuickAction(
        icon: Icons.add_road_outlined,
        label: 'Nuevo viaje',
        color: GloboColors.primary,
        onTap: () => onNavigate(_Seccion.despacho),
      ),
      _QuickAction(
        icon: Icons.local_shipping_outlined,
        label: 'Flota',
        color: GloboColors.estadoTransito,
        onTap: () => onNavigate(_Seccion.flota),
      ),
      _QuickAction(
        icon: Icons.add_business_outlined,
        label: 'Clientes',
        color: GloboColors.success,
        onTap: () => onNavigate(_Seccion.clientes),
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'Facturación',
        color: GloboColors.info,
        onTap: () => onNavigate(_Seccion.facturacion),
      ),
      _QuickAction(
        icon: Icons.analytics_outlined,
        label: 'Reportes',
        color: GloboColors.accentBright,
        onTap: () => onNavigate(_Seccion.reportes),
      ),
    ];

    // En teléfono: dos columnas con alto táctil cómodo
    if (compacto) {
      final ancho =
          (MediaQuery.sizeOf(context).width - GloboSpacing.md * 2 - 8) / 2;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: acciones
              .map((a) => SizedBox(width: ancho, child: a))
              .toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
      child: Row(
        children: acciones
            .map((a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: GloboSpacing.sm),
                    child: a,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(14),
      borderRadius: GloboRadius.buttonRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: GloboRadius.buttonRadius,
        child: Container(
          // Altura mínima táctil de 44 px (Material accesible)
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: GloboRadius.buttonRadius,
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GloboTypography.labelSmall.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FiltroViaje { todos, enCurso, programados, banderaRoja }

class _ViajesTable extends StatefulWidget {
  final AsyncValue<List<Viaje>> viajesSP;
  const _ViajesTable({required this.viajesSP});

  @override
  State<_ViajesTable> createState() => _ViajesTableState();
}

class _ViajesTableState extends State<_ViajesTable> {
  _FiltroViaje _filtro = _FiltroViaje.todos;

  String _label(_FiltroViaje f) => switch (f) {
        _FiltroViaje.todos       => 'Todos',
        _FiltroViaje.enCurso     => 'En curso',
        _FiltroViaje.programados => 'Programados',
        _FiltroViaje.banderaRoja => 'Bandera roja',
      };

  List<Viaje> _aplicar(List<Viaje> viajes) => switch (_filtro) {
        _FiltroViaje.todos       => viajes,
        _FiltroViaje.enCurso     =>
          viajes.where((v) => v.estado == EstadoViaje.enCurso).toList(),
        _FiltroViaje.programados =>
          viajes.where((v) => v.estado == EstadoViaje.programado).toList(),
        _FiltroViaje.banderaRoja =>
          viajes.where((v) => v.tieneBanderaRoja).toList(),
      };

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
                PopupMenuButton<_FiltroViaje>(
                  tooltip: 'Filtrar viajes',
                  initialValue: _filtro,
                  onSelected: (f) => setState(() => _filtro = f),
                  itemBuilder: (_) => _FiltroViaje.values
                      .map((f) => PopupMenuItem(
                            value: f,
                            child: Row(children: [
                              if (f == _filtro)
                                const Icon(Icons.check,
                                    size: 16, color: GloboColors.primary)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(_label(f)),
                            ]),
                          ))
                      .toList(),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.filter_list,
                        size: 16, color: GloboColors.primary),
                    const SizedBox(width: 4),
                    Text(_label(_filtro),
                        style: GloboTypography.labelSmall
                            .copyWith(color: GloboColors.primary)),
                  ]),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: widget.viajesSP.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (todos) {
                final viajes = _aplicar(todos);
                if (viajes.isEmpty) {
                  return Center(
                    child: Text(
                      _filtro == _FiltroViaje.todos
                          ? 'No hay viajes activos'
                          : 'Sin viajes en "${_label(_filtro)}"',
                      style: GloboTypography.caption,
                    ),
                  );
                }
                return ListView.separated(
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
                );
              },
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
