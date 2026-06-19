import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/core/errors/failures.dart';
import 'package:globo_logistics/domain/entities/auditoria_resultado.dart';
import 'package:globo_logistics/domain/entities/viaje.dart';
import 'package:globo_logistics/domain/repositories/i_viaje_repository.dart';
import 'package:globo_logistics/domain/usecases/auditoria/auditoria_diesel_usecase.dart';

/// Repositorio falso: registra si se marcó bandera roja y con qué varianza.
class _FakeViajeRepo implements IViajeRepository {
  String? banderaViajeId;
  double? banderaVarianza;

  @override
  Future<Either<Failure, Unit>> marcarBanderaRoja(
      String viajeId, double varianza) async {
    banderaViajeId = viajeId;
    banderaVarianza = varianza;
    return const Right(unit);
  }

  // ── Métodos no usados por la auditoría ─────────────────────────────────────
  @override
  Future<Either<Failure, Unit>> actualizarEstado(String v, EstadoViaje e) async =>
      const Right(unit);
  @override
  Future<Either<Failure, Unit>> actualizarTco(String v, TcoViaje t) async =>
      const Right(unit);
  @override
  Future<Either<Failure, Unit>> asignarViaje(String v, String o, String u) async =>
      const Right(unit);
  @override
  Future<Either<Failure, String>> crearViaje(Viaje v) async => const Right('x');
  @override
  Future<Either<Failure, Viaje>> getViaje(String id) async =>
      Left(ServerFailure('n/a'));
  @override
  Future<Either<Failure, Unit>> justificarVarianza(String v, String m) async =>
      const Right(unit);
  @override
  Future<Either<Failure, Unit>> actualizarSeguimiento(
          String v, SeguimientoViaje s) async =>
      const Right(unit);
  @override
  Stream<List<Viaje>> watchViajesActivos() => const Stream.empty();
  @override
  Stream<List<Viaje>> watchViajesCompletados() => const Stream.empty();
  @override
  Stream<List<Viaje>> watchViajesPorOperador(String o) => const Stream.empty();
}

void main() {
  late _FakeViajeRepo repo;
  late AuditoriaDieselUsecase usecase;

  setUp(() {
    repo = _FakeViajeRepo();
    usecase = AuditoriaDieselUsecase(repo);
  });

  // Sin medidor → la referencia son los litros por telemetría
  // (odómetro recorrido / rendimiento). 350 km / 3.5 km·L = 100 L esperados.
  AuditoriaDieselParams params(double litrosTickets) => AuditoriaDieselParams(
        viajeId: 'v1',
        odometroInicio: 1000,
        odometroFin: 1350,
        capacidadTanque: 400,
        rendimientoBaseKmL: 3.5,
        litrosTickets: litrosTickets,
        credibilidadOcrPromedio: 90,
      );

  test('carga conciliada (tickets = telemetría) → limpio, sin bandera', () async {
    final res = await usecase(params(100));
    final r = res.getOrElse(() => throw Exception('falló'));
    expect(r.nivel, NivelVarianza.limpio);
    expect(r.tieneBanderaRoja, isFalse);
    expect(r.estaDentroTolerancia, isTrue);
    expect(repo.banderaViajeId, isNull);
  });

  test('varianza leve (≈3 %) → advertencia, sin bandera roja', () async {
    final res = await usecase(params(97));
    final r = res.getOrElse(() => throw Exception('falló'));
    expect(r.nivel, NivelVarianza.advertencia);
    expect(r.tieneBanderaRoja, isFalse);
    expect(repo.banderaViajeId, isNull);
  });

  test('faltante grande (50 %) → fraude probable y marca bandera roja', () async {
    final res = await usecase(params(50));
    final r = res.getOrElse(() => throw Exception('falló'));
    expect(r.nivel, NivelVarianza.fraudeProbable);
    expect(r.tieneBanderaRoja, isTrue);
    expect(repo.banderaViajeId, 'v1');
    expect(repo.banderaVarianza, closeTo(0.50, 0.01));
  });

  test('faltante medio (≈10 %) → sospechoso y marca bandera roja', () async {
    final res = await usecase(params(90));
    final r = res.getOrElse(() => throw Exception('falló'));
    expect(r.nivel, NivelVarianza.sospechoso);
    expect(r.tieneBanderaRoja, isTrue);
    expect(repo.banderaViajeId, 'v1');
  });

  test('sin odómetro recorrido → cae a tickets (sin falso positivo)', () async {
    final res = await usecase(AuditoriaDieselParams(
      viajeId: 'v2',
      odometroInicio: 5000,
      odometroFin: 5000, // sin distancia
      capacidadTanque: 400,
      rendimientoBaseKmL: 3.5,
      litrosTickets: 120,
      credibilidadOcrPromedio: 80,
    ));
    final r = res.getOrElse(() => throw Exception('falló'));
    expect(r.nivel, NivelVarianza.limpio);
    expect(repo.banderaViajeId, isNull);
  });
}
