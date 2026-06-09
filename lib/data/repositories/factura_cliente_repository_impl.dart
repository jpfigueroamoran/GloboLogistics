import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/factura_cliente.dart';
import '../../domain/repositories/i_factura_cliente_repository.dart';
import '../datasources/remote/factura_cliente_firestore_datasource.dart';
import '../models/factura_cliente_model.dart';

class FacturaClienteRepositoryImpl implements IFacturaClienteRepository {
  final FacturaClienteFirestoreDatasource _ds;
  FacturaClienteRepositoryImpl(this._ds);

  @override
  Stream<List<FacturaCliente>> watchFacturas() => _ds.watchFacturas();

  @override
  Future<Either<Failure, String>> crearFactura(FacturaCliente factura) async {
    try {
      final id = await _ds.crearFactura(
          FacturaClienteModel.fromEntity(factura));
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> registrarCobro(
      String facturaId, double monto, DateTime fecha) async {
    try {
      await _ds.registrarCobro(facturaId, monto, fecha);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelarFactura(String facturaId) async {
    try {
      await _ds.cancelarFactura(facturaId);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> registrarCartaPorte(
      String facturaId, String cartaPorteUuid) async {
    try {
      await _ds.registrarCartaPorte(facturaId, cartaPorteUuid);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
