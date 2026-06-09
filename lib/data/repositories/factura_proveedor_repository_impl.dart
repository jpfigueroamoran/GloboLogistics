import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/factura_proveedor.dart';
import '../../domain/repositories/i_factura_proveedor_repository.dart';
import '../datasources/remote/factura_proveedor_firestore_datasource.dart';
import '../models/factura_proveedor_model.dart';

class FacturaProveedorRepositoryImpl implements IFacturaProveedorRepository {
  final FacturaProveedorFirestoreDatasource _ds;
  FacturaProveedorRepositoryImpl(this._ds);

  @override
  Stream<List<FacturaProveedor>> watchFacturas() => _ds.watchFacturas();

  @override
  Future<Either<Failure, String>> crearFactura(
      FacturaProveedor factura) async {
    try {
      final id =
          await _ds.crearFactura(FacturaProveedorModel.fromEntity(factura));
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> registrarPago(
      String facturaId, double monto, DateTime fecha) async {
    try {
      await _ds.registrarPago(facturaId, monto, fecha);
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
}
