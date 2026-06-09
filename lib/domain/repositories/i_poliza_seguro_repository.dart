import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/poliza_seguro.dart';

abstract class IPolizaSeguroRepository {
  Stream<List<PolizaSeguro>> watchPolizas();
  Future<Either<Failure, String>> crearPoliza(PolizaSeguro poliza);
  Future<Either<Failure, Unit>> actualizarPoliza(PolizaSeguro poliza);
  Future<Either<Failure, Unit>> eliminarPoliza(String id);
}
