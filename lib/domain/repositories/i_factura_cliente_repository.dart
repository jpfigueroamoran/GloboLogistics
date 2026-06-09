import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/factura_cliente.dart';

abstract class IFacturaClienteRepository {
  Stream<List<FacturaCliente>> watchFacturas();
  Future<Either<Failure, String>> crearFactura(FacturaCliente factura);
  Future<Either<Failure, Unit>> registrarCobro(
      String facturaId, double monto, DateTime fecha);
  Future<Either<Failure, Unit>> cancelarFactura(String facturaId);
  Future<Either<Failure, Unit>> registrarCartaPorte(
      String facturaId, String cartaPorteUuid);
}
