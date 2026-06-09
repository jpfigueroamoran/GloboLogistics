import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/poliza_seguro.dart';
import '../../domain/repositories/i_poliza_seguro_repository.dart';
import '../datasources/remote/poliza_seguro_firestore_datasource.dart';
import '../models/poliza_seguro_model.dart';

class PolizaSeguroRepositoryImpl implements IPolizaSeguroRepository {
  final PolizaSeguroFirestoreDatasource _ds;
  PolizaSeguroRepositoryImpl(this._ds);

  @override
  Stream<List<PolizaSeguro>> watchPolizas() => _ds.watchPolizas();

  @override
  Future<Either<Failure, String>> crearPoliza(PolizaSeguro poliza) async {
    try {
      final id = await _ds.crearPoliza(PolizaSeguroModel.fromEntity(poliza));
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> actualizarPoliza(PolizaSeguro poliza) async {
    try {
      await _ds.actualizarPoliza(
          poliza.id, PolizaSeguroModel.fromEntity(poliza).toFirestore());
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> eliminarPoliza(String id) async {
    try {
      await _ds.eliminarPoliza(id);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
