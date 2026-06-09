import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/factura_proveedor.dart';

abstract class IFacturaProveedorRepository {
  Stream<List<FacturaProveedor>> watchFacturas();
  Future<Either<Failure, String>> crearFactura(FacturaProveedor factura);
  Future<Either<Failure, Unit>> registrarPago(
      String facturaId, double monto, DateTime fecha);
  Future<Either<Failure, Unit>> cancelarFactura(String facturaId);
}
