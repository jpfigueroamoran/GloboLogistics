import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/errors/failures.dart';
import '../core/services/fcm_service.dart';
import '../data/datasources/remote/firestore_datasource.dart';
import '../data/models/usuario_globo_model.dart';
import '../injection_container.dart';
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
import '../presentation/features/torre_control/providers/usuarios_provider.dart';
import '../presentation/features/torre_control/providers/documentos_provider.dart';
import '../domain/entities/documento_vencimiento.dart';
import '../presentation/features/torre_control/widgets/alerta_panel_widget.dart';
import '../presentation/features/torre_control/pages/dashboard_page.dart';
import '../presentation/features/torre_control/pages/auditoria_page.dart';
import '../presentation/features/operador/pages/iniciar_viaje_page.dart';
import '../presentation/features/operador/pages/operador_home_page.dart';
import '../presentation/features/operador/pages/sos_page.dart';
import '../presentation/features/auth/pages/auth_landing_page.dart';
import '../presentation/features/auth/pages/demo_login_page.dart';
import '../presentation/features/clientes/pages/alta_cliente_page.dart';
import '../presentation/features/onboarding/pages/onboarding_wizard_page.dart';
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
  Stream<List<Viaje>> watchViajesActivos() {
    return _viajesStreamController.stream.map((viajes) => viajes
        .where((v) =>
            v.estado == EstadoViaje.enCurso ||
            v.estado == EstadoViaje.programado)
        .toList());
  }

  @override
  Stream<List<Viaje>> watchViajesPorOperador(String operadorId) {
    return _viajesStreamController.stream.map((viajes) => viajes
        .where((v) =>
            v.operadorId == operadorId &&
            (v.estado == EstadoViaje.enCurso ||
             v.estado == EstadoViaje.programado))
        .toList());
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
    final id = viaje.id.isEmpty
        ? 'demo-${DateTime.now().millisecondsSinceEpoch}'
        : viaje.id;
    final nuevo = Viaje(
      id: id,
      unidadId: viaje.unidadId,
      operadorId: viaje.operadorId,
      operadorNombre: viaje.operadorNombre,
      origenDescripcion: viaje.origenDescripcion,
      destinoDescripcion: viaje.destinoDescripcion,
      origenGeo: viaje.origenGeo,
      destinoGeo: viaje.destinoGeo,
      destinos: viaje.destinos,
      estado: viaje.estado,
      litrosCargados: viaje.litrosCargados,
      tco: viaje.tco,
      observaciones: viaje.observaciones,
      createdAt: viaje.createdAt,
      updatedAt: viaje.updatedAt,
    );
    _viajesActivosLocal.add(nuevo);
    _emitViajes();
    return Right(id);
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
      final v = _viajesActivosLocal[i];
      _viajesActivosLocal[i] = Viaje(
        id:                  v.id,
        unidadId:            unidadId,
        operadorId:          operadorId,
        operadorNombre:      v.operadorNombre,
        origenDescripcion:   v.origenDescripcion,
        destinoDescripcion:  v.destinoDescripcion,
        origenGeo:           v.origenGeo,
        destinoGeo:          v.destinoGeo,
        destinos:            v.destinos,
        estado:              v.estado,
        fechaInicio:         v.fechaInicio,
        fechaFin:            v.fechaFin,
        litrosCargados:      v.litrosCargados,
        litrosConsumiidosTelemetria: v.litrosConsumiidosTelemetria,
        litrosConsumiidosTickets:    v.litrosConsumiidosTickets,
        varianzaCombustible: v.varianzaCombustible,
        nivelAlerta:         v.nivelAlerta,
        tco:                 v.tco,
        observaciones:       v.observaciones,
        createdAt:           v.createdAt,
        updatedAt:           DateTime.now(),
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

  @override
  Future<Either<Failure, Unit>> cancelarAlerta(String alertaId) async {
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
        estado: EstadoAlerta.falsaAlarma,
        posicion: a.posicion,
        notas: 'Cancelada por el operador desde la app.',
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

  @override
  Future<Either<Failure, String>> crearCliente(
          Map<String, dynamic> data) async =>
      const Right('demo-cliente-id');

  @override
  Future<Either<Failure, void>> actualizarCliente(
          String id, Map<String, dynamic> data) async =>
      const Right(null);
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

/// true = modo demo (datos de ejemplo), false = modo producción con Firebase.
/// La app arranca en producción; el demo se activa con el botón del login.
final appModeProvider = StateProvider<bool>((ref) => false);

// ── Overrides ─────────────────────────────────────────────────────────────────

List<Override> get demoOverrides => [
      routerProvider.overrideWith((ref) => _demoRouter(ref)),
      authStatusProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        if (isDemo) {
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
        }
        // Modo producción: delegar a Firebase Auth real
        final authAsync = ref.watch(authUserProvider);
        final profileAsync = ref.watch(userProfileProvider);
        if (authAsync.isLoading) return const AuthState.loading();
        if (authAsync.hasError) {
          return AuthState(
              status: AuthStatus.error,
              errorMessage: authAsync.error.toString());
        }
        final user = authAsync.valueOrNull;
        if (user == null) return const AuthState.unauthenticated();
        if (profileAsync.isLoading) {
          return const AuthState(status: AuthStatus.loadingProfile);
        }
        final perfil = profileAsync.valueOrNull;
        if (perfil == null) return const AuthState(status: AuthStatus.sinPerfil);
        if (!perfil.activo) return const AuthState(status: AuthStatus.desactivado);
        if (perfil.esOperador) return AuthState(status: AuthStatus.operador, usuario: perfil);
        return AuthState(status: AuthStatus.torreControl, usuario: perfil);
      }),
      viajeRepositoryProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo ? _demoViajeRepo : sl<IViajeRepository>();
      }),
      operadorProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? OperadorNotifier(_demoViajeRepo)
            : OperadorNotifier(sl<IViajeRepository>());
      }),
      sosProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? SosNotifier(_demoSosUsecase)
            : SosNotifier(sl<TriggerSosUsecase>());
      }),
      viajesActivosProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _demoViajeRepo.watchViajesActivos()
            : sl<IViajeRepository>().watchViajesActivos();
      }),
      unidadesActivasProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? Stream.value(DemoData.unidades)
            : sl<FirestoreDatasource>().watchUnidades();
      }),
      todasUnidadesProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? Stream.value(DemoData.unidades)
            : sl<FirestoreDatasource>().watchTodasUnidades();
      }),
      fcmForegroundProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? const Stream.empty()
            : FcmService.foregroundMessages.map((m) => m);
      }),
      alertasStreamProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        if (isDemo) {
          return _DemoSeguridadRepository().watchAlertasActivas().map(
            (alertas) => alertas.map((a) => {
              'id': a.id,
              'tipo': a.tipo.name,
              'estado': a.estado.name,
              'viaje_id': a.viajeId,
              'operador_id': a.operadorId,
              'posicion': {'lat': a.posicion.lat, 'lng': a.posicion.lng},
            }).toList(),
          );
        }
        return sl<FirestoreDatasource>().watchAlertasActivas();
      }),
      viajeActivoStreamProvider(operadorDemo.uid).overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _demoViajeRepo.watchViajesPorOperador('op001')
            : sl<IViajeRepository>().watchViajesPorOperador(operadorDemo.uid);
      }),
      clientesStreamProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? Stream.value(DemoData.clientes)
            : sl<IClienteRepository>().watchClientes();
      }),
      clientesBusquedaProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? ClientesBusquedaNotifier(_demoClienteRepo)
            : ClientesBusquedaNotifier(sl<IClienteRepository>());
      }),
      iniciarViajeProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? IniciarViajeNotifier(_demoViajeRepo)
            : IniciarViajeNotifier(sl<IViajeRepository>());
      }),
      activosFijosProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _DemoActivoFijoRepository().watchActivosFijos()
            : sl<IActivoFijoRepository>().watchActivosFijos();
      }),
      polizasProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _DemoPolizaSeguroRepository().watchPolizas()
            : sl<IPolizaSeguroRepository>().watchPolizas();
      }),
      facturasProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _DemoFacturaClienteRepository().watchFacturas()
            : sl<IFacturaClienteRepository>().watchFacturas();
      }),
      registrarCartaPorteProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        if (isDemo) return (_, __) async => const Right(unit);
        return sl<IFacturaClienteRepository>().registrarCartaPorte;
      }),
      facturasProveedorProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _demoFacturaProveedorRepo.watchFacturas()
            : sl<IFacturaProveedorRepository>().watchFacturas();
      }),
      crearFacturaProveedorProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _demoFacturaProveedorRepo.crearFactura
            : sl<IFacturaProveedorRepository>().crearFactura;
      }),
      inventarioProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _DemoInventarioRepository().watchItems()
            : sl<IInventarioRepository>().watchItems();
      }),
      viajesCompletadosProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _demoViajeRepo.watchViajesCompletados()
            : sl<IViajeRepository>().watchViajesCompletados();
      }),
      alertasActivasStreamProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        return isDemo
            ? _DemoSeguridadRepository().watchAlertasActivas()
            : sl<ISeguridadRepository>().watchAlertasActivas();
      }),
      documentosProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        if (isDemo) return Stream.value(<DocumentoVencimiento>[]);
        return sl<FirestoreDatasource>()
            .watchDocumentos()
            .map((list) => list.map(docFromSnapshot).toList());
      }),
      usuariosStreamProvider.overrideWith((ref) {
        final isDemo = ref.watch(appModeProvider);
        if (isDemo) return Stream.value(DemoData.usuarios);
        return cf.FirebaseFirestore.instance
            .collection('usuarios')
            .snapshots()
            .map((snap) => snap.docs
                .map((d) => UsuarioGloboModel.fromFirestore(d))
                .toList()
              ..sort((a, b) => a.nombre.compareTo(b.nombre)));
      }),
    ];

// ── Router de demo ───────────────────────────────────────────────

GoRouter _demoRouter(Ref ref) {
  final isDemo = ref.watch(appModeProvider);
  final currentDemoUser = ref.watch(demoUserProvider);

  String initial = AppRoutes.auth;
  if (isDemo && currentDemoUser != null) {
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
        builder: (_, __) =>
            isDemo ? const DemoLoginPage() : const AuthLandingPage(),
      ),
      GoRoute(
        path: AppRoutes.altaCliente,
        builder: (_, __) => const AltaClientePage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingWizardPage(),
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
