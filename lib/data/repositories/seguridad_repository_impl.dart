import 'package:dartz/dartz.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/alerta_seguridad.dart';
import '../../domain/entities/viaje.dart';
import '../../domain/repositories/i_seguridad_repository.dart';
import '../datasources/remote/firestore_datasource.dart';

class SeguridadRepositoryImpl implements ISeguridadRepository {
  final FirestoreDatasource _remote;

  // ID de la alerta SOS activa (en memoria durante la sesión)
  String? _alertaSosActivaId;

  SeguridadRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, String>> triggerSOS(
    String viajeId,
    String operadorId,
    String unidadId,
    GeoPoint posicion,
  ) async {
    try {
      final alertaId = await _remote.crearAlertaSOS(
        viajeId: viajeId,
        operadorId: operadorId,
        unidadId: unidadId,
        posicion: posicion,
      );
      _alertaSosActivaId = alertaId;
      return Right(alertaId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> enviarPosicionSOS(
    String alertaId,
    GeoPoint posicion,
  ) async {
    try {
      await _remote.actualizarPosicionSOS(alertaId, posicion);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<AlertaSeguridad>> watchAlertasActivas() {
    return _remote.watchAlertasActivas().map((rawList) {
      return rawList.map(_mapToAlerta).toList();
    });
  }

  @override
  Future<Either<Failure, Unit>> atenderAlerta(
    String alertaId,
    String atendidaPor,
    String notas,
  ) async {
    try {
      await _remote.atenderAlerta(alertaId, atendidaPor, notas);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelarAlerta(String alertaId) async {
    try {
      await _remote.cancelarAlertaSOS(alertaId);
      if (_alertaSosActivaId == alertaId) _alertaSosActivaId = null;
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  String? get alertaSosActivaId => _alertaSosActivaId;

  AlertaSeguridad _mapToAlerta(Map<String, dynamic> data) {
    final rawPos = data['posicion'] as Map<String, dynamic>? ?? {};
    return AlertaSeguridad(
      id: data['id'] as String? ?? '',
      viajeId: data['viaje_id'] as String? ?? '',
      operadorId: data['operador_id'] as String? ?? '',
      unidadId: data['unidad_id'] as String? ?? '',
      tipo: TipoAlerta.values.firstWhere(
        (e) => e.name == (data['tipo'] as String?),
        orElse: () => TipoAlerta.sos,
      ),
      timestamp: (data['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      posicion: GeoPoint(
        lat: (rawPos['lat'] as num?)?.toDouble() ?? 0,
        lng: (rawPos['lng'] as num?)?.toDouble() ?? 0,
      ),
      estado: EstadoAlerta.values.firstWhere(
        (e) => e.name == (data['estado'] as String?),
        orElse: () => EstadoAlerta.activa,
      ),
      atendidaPor: data['atendida_por'] as String?,
      notas:       data['notas'] as String?,
      metadata:    Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
    );
  }
}
