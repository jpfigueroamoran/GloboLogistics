import 'package:dartz/dartz.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/connectivity_service.dart';
import '../../domain/entities/actividad_operativa.dart';
import '../../domain/repositories/i_actividad_repository.dart';
import '../datasources/local/local_queue_datasource.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/actividad_operativa_model.dart';

class ActividadRepositoryImpl implements IActividadRepository {
  final FirestoreDatasource _remote;
  final LocalQueueDatasource _local;
  final ConnectivityService _connectivity;

  const ActividadRepositoryImpl(this._remote, this._local, this._connectivity);

  @override
  Future<Either<Failure, Unit>> logActividad(
      ActividadOperativa actividad) async {
    final model = actividad is ActividadOperativaModel
        ? actividad
        : ActividadOperativaModel(
            id: actividad.id,
            viajeId: actividad.viajeId,
            operadorId: actividad.operadorId,
            tipo: actividad.tipo,
            timestamp: actividad.timestamp,
            posicion: actividad.posicion,
            datos: actividad.datos,
            sincronizado: actividad.sincronizado,
            nuevoEstado: actividad.nuevoEstado,
          );

    // Offline-first: siempre encolar localmente primero (sin Timestamps de Firestore)
    await _local.encolarActividad(model.id, model.toHive());

    // Intentar subir si hay conexión
    if (_connectivity.isOnline) {
      try {
        await _remote.logActividad(model);
        await _local.eliminarActividad(model.id);
        return const Right(unit);
      } on ServerException catch (e) {
        // Queda en cola para sincronización posterior
        return Left(ServerFailure(e.message));
      }
    }

    return const Right(unit); // Guardado localmente
  }

  @override
  Future<Either<Failure, Unit>> sincronizarPendientes() async {
    try {
      final pendientes = _local.getActividadesPendientes();
      if (pendientes.isEmpty) return const Right(unit);

      final modelos = pendientes.entries
          .map((e) => ActividadOperativaModel.fromMap(e.value, e.key))
          .toList();

      await _remote.logActividadBatch(modelos);
      await _local.limpiarActividadesSincronizadas(pendientes.keys.toList());

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<ActividadOperativa>> watchActividadesByViaje(String viajeId) =>
      _remote.watchActividadesByViaje(viajeId);

  @override
  Future<List<ActividadOperativa>> getActividadesPendientes() async {
    final pendientes = _local.getActividadesPendientes();
    return pendientes.entries
        .map((e) => ActividadOperativaModel.fromMap(e.value, e.key))
        .toList();
  }
}
