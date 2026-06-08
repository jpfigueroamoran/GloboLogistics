import 'package:dartz/dartz.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/viaje.dart';
import '../../domain/repositories/i_viaje_repository.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/viaje_model.dart';

class ViajeRepositoryImpl implements IViajeRepository {
  final FirestoreDatasource _remote;

  const ViajeRepositoryImpl(this._remote);

  @override
  Stream<List<Viaje>> watchViajesActivos() =>
      _remote.watchViajesActivos();

  @override
  Stream<List<Viaje>> watchViajesPorOperador(String operadorId) {
    return _remote.watchViajesPorOperador(operadorId);
  }

  @override
  Stream<List<Viaje>> watchViajesCompletados() {
    return _remote.watchViajesCompletados();
  }

  @override
  Future<Either<Failure, Viaje>> getViaje(String id) async {
    try {
      final model = await _remote.getViaje(id);
      return Right(model);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> crearViaje(Viaje viaje) async {
    try {
      final model = ViajeModel(
        id: viaje.id,
        unidadId: viaje.unidadId,
        operadorId: viaje.operadorId,
        origenDescripcion: viaje.origenDescripcion,
        destinoDescripcion: viaje.destinoDescripcion,
        origenGeo: viaje.origenGeo,
        destinoGeo: viaje.destinoGeo,
        destinos: viaje.destinos,
        estado: viaje.estado,
        fechaInicio: viaje.fechaInicio,
        fechaFin: viaje.fechaFin,
        litrosCargados: viaje.litrosCargados,
        litrosConsumiidosTelemetria: viaje.litrosConsumiidosTelemetria,
        litrosConsumiidosTickets: viaje.litrosConsumiidosTickets,
        varianzaCombustible: viaje.varianzaCombustible,
        nivelAlerta: viaje.nivelAlerta,
        tco: viaje.tco,
        observaciones: viaje.observaciones,
        createdAt: viaje.createdAt,
        updatedAt: viaje.updatedAt,
      );
      final id = await _remote.crearViaje(model);
      return Right(id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> actualizarEstado(
      String viajeId, EstadoViaje nuevoEstado) async {
    try {
      await _remote.actualizarEstadoViaje(viajeId, nuevoEstado);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> asignarViaje(
      String viajeId, String operadorId, String unidadId) async {
    try {
      await _remote.asignarViaje(viajeId, operadorId, unidadId);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> justificarVarianza(
      String viajeId, String motivo) async {
    try {
      await _remote.justificarVarianza(viajeId, motivo);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> actualizarTco(
      String viajeId, TcoViaje tco) async {
    try {
      await _remote.watchViajesActivos().first;
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> marcarBanderaRoja(
      String viajeId, double varianza) async {
    try {
      await _remote.actualizarVarianzaCombustible(viajeId, varianza, true);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
