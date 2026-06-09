import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/errors/failures.dart';
import '../domain/entities/activo_fijo.dart';
import '../domain/entities/alerta_seguridad.dart';
import '../domain/entities/cliente.dart';
import '../domain/entities/factura_cliente.dart';
import '../domain/entities/factura_proveedor.dart';
import '../domain/entities/item_inventario.dart';
import '../domain/entities/movimiento_inventario.dart';
import '../domain/entities/poliza_seguro.dart';
import '../domain/entities/usuario_globo.dart';
import '../domain/entities/viaje.dart';
import '../domain/repositories/i_activo_fijo_repository.dart';
import '../domain/repositories/i_cliente_repository.dart';
import '../domain/repositories/i_factura_cliente_repository.dart';
import '../domain/repositories/i_factura_proveedor_repository.dart';
import '../domain/repositories/i_inventario_repository.dart';
import '../domain/repositories/i_poliza_seguro_repository.dart';
import '../domain/repositories/i_seguridad_repository.dart';
import '../domain/repositories/i_viaje_repository.dart';
import '../domain/usecases/seguridad/trigger_sos_usecase.dart';
import '../presentation/app/router.dart' show AppRoutes, rootNavigatorKey, routerProvider;
import '../presentation/features/auth/providers/auth_provider.dart';
import '../presentation/features/operador/providers/clientes_provider.dart';
import '../presentation/features/operador/providers/iniciar_viaje_provider.dart';
import '../presentation/features/operador/providers/operador_provider.dart';
import '../presentation/features/operador/providers/sos_provider.dart';
import '../presentation/app/app.dart';
import '../presentation/features/torre_control/providers/activo_fijo_provider.dart';
import '../presentation/features/torre_control/providers/dashboard_provider.dart';
import '../presentation/features/torre_control/providers/factura_cliente_provider.dart';
import '../presentation/features/torre_control/providers/factura_proveedor_provider.dart';
import '../presentation/features/torre_control/providers/inventario_provider.dart';
import '../presentation/features/torre_control/providers/poliza_seguro_provider.dart';
import '../presentation/features/torre_control/providers/unidades_provider.dart';
import '../presentation/features/torre_control/providers/documentos_provider.dart';
import '../domain/entities/documento_vencimiento.dart';
import '../presentation/features/torre_control/widgets/alerta_panel_widget.dart';
import '../presentation/features/torre_control/pages/dashboard_page.dart';
import '../presentation/features/torre_control/pages/auditoria_page.dart';
import '../presentation/features/operador/pages/iniciar_viaje_page.dart';
import '../presentation/features/operador/pages/operador_home_page.dart';
import '../presentation/features/operador/pages/sos_page.dart';
import '../presentation/features/auth/pages/demo_login_page.dart';
import 'demo_data.dart';

// ── Estado Mutable de la Demo ───────────────────────────────────────────────

final _viajesStreamController = StreamController<List<Viaje>>.broadcast();
final _alertasStreamController = StreamController<List<AlertaSeguridad>>.broadcast();

List<Viaje> _viajesActivosLocal = List.from(DemoData.viajes);
List<AlertaSeguridad> _alertasActivasLocal = List.from(DemoData.alertas);

void _emitViajes() => _viajesStreamController.add(List.unmodifiable(_viajesActivosLocal));
void _emitAlertas() => _alertasStreamController.add(List.unmodifiable(_alertasActivasLocal));

// ── Stub del repositorio para demo (Reactivo) ─────────────────────────────

class _DemoViajeRepository implements IViajeRepository {
  
  _DemoViajeRepository() {
    Future.microtask(() => _emitViajes());
  }

  @override
  Stream<List<Viaje>> watchViajesActivos() => _viajesStreamController.stream;

  @override
  Stream<List<Viaje>> watchViajesPorOperador(String operadorId) {
    return _viajesStreamController.stream.map(
        (viajes) => viajes.where((v) => v.operadorId == operadorId).toList());
  }

  @override
  Stream<List<Viaje>> watchViajesCompletados() {
    return _viajesStreamController.stream.map(
        (viajes) => viajes.where((v) => v.estado == EstadoViaje.completado).toList());
  }

  @override
  Future<Either<Failure, Viaje>> getViaje(String id) async =>
      Right(_viajesActivosLocal.firstWhere(
        (v) => v.id == id,
        orElse: () => _viajesActivosLocal.first,
      ));

  @override
  Future<Either<Failure, String>> crearViaje(Viaje viaje) async {
    _viajesActivosLocal.add(viaje);
    _emitViajes();
    return Right(viaje.id);
  }

  @override
  Future<Either<Failure, Unit>> actualizarEstado(
          String viajeId, EstadoViaje nuevoEstado) async {
    final i = _viajesActivosLocal.indexWhere((v) => v.id == viajeId);
    if (i >= 0) {
      _viajesActivosLocal[i] = _viajesActivosLocal[i].copyWith(estado: nuevoEstado);
      _emitViajes();
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> asignarViaje(
          String viajeId, String operadorId, String unidadId) async {
    final i = _viajesActivosLocal.indexWhere((v) => v.id == viajeId);
    if (i >= 0) {
      // Create a copy replacing operator and unit
      final v = _viajesActivosLocal[i];
      _viajesActivosLocal[i] = Viaje(
        id: v.id,
        unidadId: unidadId,
        operadorId: operadorId,
        origenDescripcion: v.origenDescripcion,
        destinoDescripcion: v.destinoDescripcion,
        destinos: v.destinos,
        estado: v.estado,
        fechaInicio: v.fechaInicio,
        createdAt: v.createdAt,
        updatedAt: DateTime.now(),
      );
      _emitViajes();
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> justificarVarianza(
          String viajeId, String motivo) async {
    final i = _viajesActivosLocal.indexWhere((v) => v.id == viajeId);
    if (i >= 0) {
      _viajesActivosLocal[i] = _viajesActivosLocal[i].copyWith(justificacionVarianza: motivo);
      _emitViajes();
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> actualizarTco(
          String viajeId, TcoViaje tco) async {
    final i = _viajesActivosLocal.indexWhere((v) => v.id == viajeId);
    if (i >= 0) {
      _viajesActivosLocal[i] = _viajesActivosLocal[i].copyWith(tco: tco);
      _emitViajes();
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> marcarBanderaRoja(
          String viajeId, double varianza) async {
    final i = _viajesActivosLocal.indexWhere((v) => v.id == viajeId);
    if (i >= 0) {
      _viajesActivosLocal[i] = _viajesActivosLocal[i].copyWith(
        nivelAlerta: NivelAlertaViaje.bandajaRoja,
        varianzaCombustible: varianza,
      );
      _emitViajes();
    }
    return const Right(unit);
  }
}

final _demoViajeRepo = _DemoViajeRepository();

// ── Stub de seguridad para demo (Reactivo) ─────────────────────

class _DemoSeguridadRepository implements ISeguridadRepository {
  
  _DemoSeguridadRepository() {
    Future.microtask(() => _emitAlertas());
  }

  @override
  Future<Either<Failure, String>> triggerSOS(
          String viajeId, String operadorId, String unidadId,
          GeoPoint posicion) async {
    
    final nuevaAlerta = AlertaSeguridad(
      id: 'alerta-${DateTime.now().millisecondsSinceEpoch}',
      viajeId: viajeId,
      operadorId: operadorId,
      unidadId: unidadId,
      timestamp: DateTime.now(),
      tipo: TipoAlerta.sos,
      estado: EstadoAlerta.activa,
      posicion: posicion,
    );
    
    _alertasActivasLocal.insert(0, nuevaAlerta);
    _emitAlertas();
    return Right(nuevaAlerta.id);
  }

  @override
  Future<Either<Failure, Unit>> enviarPosicionSOS(
          String alertaId, GeoPoint posicion) async =>
      const Right(unit);

  @override
  Stream<List<AlertaSeguridad>> watchAlertasActivas() {
    return _alertasStreamController.stream;
  }

  @override
  Future<Either<Failure, Unit>> atenderAlerta(
          String alertaId, String atendidaPor, String notas) async {
    final i = _alertasActivasLocal.indexWhere((a) => a.id == alertaId);
    if (i >= 0) {
      final a = _alertasActivasLocal[i];
      _alertasActivasLocal[i] = AlertaSeguridad(
        id: a.id,
        viajeId: a.viajeId,
        operadorId: a.operadorId,
        unidadId: a.unidadId,
        timestamp: a.timestamp,
        tipo: a.tipo,
        estado: EstadoAlerta.atendida,
        posicion: a.posicion,
        atendidaPor: atendidaPor,
        notas: notas,
      );
      _emitAlertas();
    }
    return const Right(unit);
  }
}

final _demoSosUsecase = TriggerSosUsecase(_DemoSeguridadRepository());

// ── Stub de clientes para demo ─────────────────────────────────

class _DemoClienteRepository implements IClienteRepository {
  @override
  Stream<List<Cliente>> watchClientes() =>
      Stream.value(DemoData.clientes);

  @override
  Future<Either<Failure, List<Cliente>>> buscarClientes(String query) async {
    final norm = query.toLowerCase().trim();
    final results = DemoData.clientes
        .where((c) =>
            c.nombre.toLowerCase().contains(norm) ||
            c.direccion.toLowerCase().contains(norm))
        .toList();
    return Right(results);
  }
}

final _demoClienteRepo = _DemoClienteRepository();

// ── Stub de activos fijos para demo ───────────────────────────────────────────

class _DemoActivoFijoRepository implements IActivoFijoRepository {
  @override
  Stream<List<ActivoFijo>> watchActivosFijos() =>
      Stream.value(DemoData.activosFijos);

  @override
  Future<Either<Failure, String>> crearActivo(ActivoFijo activo) async =>
      Right(activo.id);

  @override
  Future<Either<Failure, Unit>> actualizarActivo(ActivoFijo activo) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> eliminarActivo(String id) async =>
      const Right(unit);
}

// ── Stub de facturas de clientes para demo ────────────────────────────────────

class _DemoFacturaClienteRepository implements IFacturaClienteRepository {
  @override
  Stream<List<FacturaCliente>> watchFacturas() =>
      Stream.value(DemoData.facturas);

  @override
  Future<Either<Failure, String>> crearFactura(FacturaCliente factura) async =>
      Right(factura.id);

  @override
  Future<Either<Failure, Unit>> registrarCobro(
          String facturaId, double monto, DateTime fecha) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> cancelarFactura(String facturaId) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> registrarCartaPorte(
          String facturaId, String cartaPorteUuid) async =>
      const Right(unit);
}

// ── Stub de facturas de proveedores para demo ─────────────────────────────────

final _demoFacturaProveedorRepo = _DemoFacturaProveedorRepository();

class _DemoFacturaProveedorRepository implements IFacturaProveedorRepository {
  final _controller = StreamController<List<FacturaProveedor>>.broadcast();
  List<FacturaProveedor> _facturas = List.of(DemoData.facturasProveedor);

  _DemoFacturaProveedorRepository() {
    Future.microtask(() => _controller.add(_facturas));
  }

  @override
  Stream<List<FacturaProveedor>> watchFacturas() => _controller.stream;

  @override
  Future<Either<Failure, String>> crearFactura(FacturaProveedor factura) async {
    _facturas = [factura, ..._facturas];
    _controller.add(_facturas);
    return Right(factura.id);
  }

  @override
  Future<Either<Failure, Unit>> registrarPago(
          String facturaId, double monto, DateTime fecha) async {
    _facturas = _facturas.map((f) {
      if (f.id == facturaId) {
        return FacturaProveedor(
          id: f.id,
          proveedorId: f.proveedorId,
          proveedorNombre: f.proveedorNombre,
          tipoProveedor: f.tipoProveedor,
          numeroFactura: f.numeroFactura,
          fechaEmision: f.fechaEmision,
          fechaVencimiento: f.fechaVencimiento,
          monto: f.monto,
          montoPagado: monto,
          estatus: EstatusFacturaProveedor.pagada,
          fechaPago: fecha,
          viajeId: f.viajeId,
          unidadId: f.unidadId,
        );
      }
      return f;
    }).toList();
    _controller.add(_facturas);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> cancelarFactura(String facturaId) async =>
      const Right(unit);
}

// ── Stub de inventario para demo ──────────────────────────────────────────────

class _DemoInventarioRepository implements IInventarioRepository {
  @override
  Stream<List<ItemInventario>> watchItems() =>
      Stream.value(DemoData.itemsInventario);

  @override
  Future<Either<Failure, Unit>> actualizarStock(
          String itemId, double nuevoStock) async =>
      const Right(unit);

  @override
  Future<Either<Failure, String>> registrarMovimiento(
          MovimientoInventario movimiento) async =>
      Right(movimiento.id);
}

// ── Stub de pólizas de seguro para demo ───────────────────────────────────────

class _DemoPolizaSeguroRepository implements IPolizaSeguroRepository {
  @override
  Stream<List<PolizaSeguro>> watchPolizas() =>
      Stream.value(DemoData.polizas);

  @override
  Future<Either<Failure, String>> crearPoliza(PolizaSeguro poliza) async =>
      Right(poliza.id);

  @override
  Future<Either<Failure, Unit>> actualizarPoliza(PolizaSeguro poliza) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> eliminarPoliza(String id) async =>
      const Right(unit);
}

// ── Usuarios mock y Provider de Sesión ──────────────────────────────────────

const supervisorDemo = UsuarioGlobo(
  uid:    'demo-supervisor',
  email:  'supervisor@el-globo.mx',
  nombre: 'Ana García (Supervisor)',
  rol:    RolUsuario.supervisor,
);

const adminDemo = UsuarioGlobo(
  uid:    'demo-admin',
  email:  'admin@el-globo.mx',
  nombre: 'Carlos Ruiz (Admin)',
  rol:    RolUsuario.administrador,
);

const operadorDemo = UsuarioGlobo(
  uid:              'demo-op',
  email:            'operador@el-globo.mx',
  nombre:           'Carlos M. (Operador)',
  rol:              RolUsuario.operador,
  unidadAsignadaId: 'u001',
);

final demoUserProvider = StateProvider<UsuarioGlobo?>((ref) => null);

// ── Overrides ─────────────────────────────────────────────────────────────────

List<Override> get demoOverrides => [
      routerProvider.overrideWith((ref) => _demoRouter(ref)),
      authStatusProvider.overrideWith((ref) {
        final currentDemoUser = ref.watch(demoUserProvider);
        if (currentDemoUser == null) {
          return const AuthState(status: AuthStatus.unauthenticated);
        }
        return AuthState(
          status: currentDemoUser.rol == RolUsuario.operador
              ? AuthStatus.operador
              : AuthStatus.torreControl,
          usuario: currentDemoUser,
        );
      }),
      operadorProvider.overrideWith(
        (_) => OperadorNotifier(_demoViajeRepo),
      ),
      sosProvider.overrideWith(
        (_) => SosNotifier(_demoSosUsecase),
      ),
      viajesActivosProvider.overrideWith(
        (_) => _demoViajeRepo.watchViajesActivos(),
      ),
      unidadesActivasProvider.overrideWith(
        (_) => Stream.value(DemoData.unidades),
      ),
      fcmForegroundProvider.overrideWith(
        (_) => const Stream.empty(),
      ),
      alertasStreamProvider.overrideWith(
        (_) => _DemoSeguridadRepository().watchAlertasActivas().map(
          (alertas) => alertas.map((a) => {
            'id': a.id,
            'tipo': a.tipo.name,
            'estado': a.estado.name,
            'viaje_id': a.viajeId,
            'operador_id': a.operadorId,
            'posicion': {'lat': a.posicion.lat, 'lng': a.posicion.lng},
          }).toList(),
        ),
      ),
      viajeActivoStreamProvider(operadorDemo.uid).overrideWith(
        (_) => _demoViajeRepo.watchViajesPorOperador('op001'),
      ),
      clientesStreamProvider.overrideWith(
        (_) => Stream.value(DemoData.clientes),
      ),
      clientesBusquedaProvider.overrideWith(
        (_) => ClientesBusquedaNotifier(_demoClienteRepo),
      ),
      iniciarViajeProvider.overrideWith(
        (_) => IniciarViajeNotifier(_demoViajeRepo),
      ),
      activosFijosProvider.overrideWith(
        (_) => _DemoActivoFijoRepository().watchActivosFijos(),
      ),
      polizasProvider.overrideWith(
        (_) => _DemoPolizaSeguroRepository().watchPolizas(),
      ),
      facturasProvider.overrideWith(
        (_) => _DemoFacturaClienteRepository().watchFacturas(),
      ),
      registrarCartaPorteProvider.overrideWithValue(
        (_, __) async => const Right(unit),
      ),
      facturasProveedorProvider.overrideWith(
        (_) => _demoFacturaProveedorRepo.watchFacturas(),
      ),
      crearFacturaProveedorProvider.overrideWith(
        (_) => _demoFacturaProveedorRepo.crearFactura,
      ),
      inventarioProvider.overrideWith(
        (_) => _DemoInventarioRepository().watchItems(),
      ),
      viajesCompletadosProvider.overrideWith(
        (_) => _demoViajeRepo.watchViajesCompletados(),
      ),
      alertasActivasStreamProvider.overrideWith(
        (_) => _DemoSeguridadRepository().watchAlertasActivas(),
      ),
      documentosProvider.overrideWith(
        (_) => Stream.value(<DocumentoVencimiento>[]),
      ),
    ];

// ── Router de demo ───────────────────────────────────────────────

GoRouter _demoRouter(Ref ref) {
  final currentDemoUser = ref.watch(demoUserProvider);

  String initial = AppRoutes.auth;
  if (currentDemoUser != null) {
    initial = currentDemoUser.rol == RolUsuario.operador
        ? AppRoutes.operador
        : AppRoutes.dashboard;
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, __) => const DemoLoginPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const DashboardPage(),
        routes: [
          GoRoute(
            path: 'auditoria',
            builder: (_, __) => const AuditoriaPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.operador,
        builder: (_, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return OperadorHomePage(
            operadorId:     extra['operadorId']     ?? operadorDemo.uid,
            unidadId:       extra['unidadId']       ?? (operadorDemo.unidadAsignadaId ?? ''),
            nombreOperador: extra['nombreOperador'] ?? operadorDemo.nombre,
          );
        },
        routes: [
          GoRoute(
            path: 'sos',
            builder: (_, state) {
              final extra = state.extra as Map<String, String>? ?? {};
              return SosPage(
                operadorId: extra['operadorId'] ?? operadorDemo.uid,
                unidadId:   extra['unidadId']   ?? 'u001',
                viajeId:    extra['viajeId']    ?? 'v001',
              );
            },
          ),
          GoRoute(
            path: 'iniciar-viaje',
            builder: (_, state) {
              final extra = state.extra as Map<String, String>? ?? {};
              return IniciarViajePage(
                operadorId: extra['operadorId'] ?? operadorDemo.uid,
                unidadId:   extra['unidadId']   ??
                    (operadorDemo.unidadAsignadaId ?? ''),
              );
            },
          ),
        ],
      ),
    ],
  );
}

// ── Métricas demo (calculadas desde el stream) ───────────────────────────────

final demoMetricsProvider = Provider<DashboardMetrics>((ref) {
  final viajes = ref.watch(viajesActivosProvider).value ?? [];
  final alertas = ref.watch(alertasStreamProvider).value ?? [];
  return DashboardMetrics(
    viajesEnCurso:     viajes.where((v) => v.estado == EstadoViaje.enCurso).length,
    alertasActivas:    alertas.length,
    unidadesActivas:   viajes.length,
    tcoPromedioDia:    viajes.isEmpty ? 0 : viajes.map((v) => v.tco.total).fold(0.0, (a, b) => a + b) / viajes.length,
    viajesBanderaRoja: viajes.where((v) => v.tieneBanderaRoja).length,
  );
});
