import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/errors/failures.dart';
import '../domain/entities/alerta_seguridad.dart';
import '../domain/entities/cliente.dart';
import '../domain/entities/usuario_globo.dart';
import '../domain/entities/viaje.dart';
import '../domain/repositories/i_cliente_repository.dart';
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
import '../presentation/features/torre_control/providers/dashboard_provider.dart';
import '../presentation/features/torre_control/providers/unidades_provider.dart';
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
