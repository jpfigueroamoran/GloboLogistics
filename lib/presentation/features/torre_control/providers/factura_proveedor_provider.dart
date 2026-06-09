import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/cuenta_por_pagar.dart';
import '../../../../domain/entities/factura_proveedor.dart';
import '../../../../domain/repositories/i_factura_proveedor_repository.dart';
import '../../../../injection_container.dart';

final facturasProveedorProvider =
    StreamProvider<List<FacturaProveedor>>((ref) {
  return sl<IFacturaProveedorRepository>().watchFacturas();
});

final cxpProvider = Provider<List<CuentaPorPagar>>((ref) {
  final facturas =
      ref.watch(facturasProveedorProvider).valueOrNull ?? [];
  final pendientes = facturas.where((f) => f.esPendienteOVencida).toList();

  final byProveedor = <String, List<FacturaProveedor>>{};
  for (final f in pendientes) {
    byProveedor.putIfAbsent(f.proveedorId, () => []).add(f);
  }

  return byProveedor.entries
      .map((e) => CuentaPorPagar(
            proveedorId:        e.key,
            proveedorNombre:    e.value.first.proveedorNombre,
            tipoProveedor:      e.value.first.tipoProveedor,
            facturasPendientes: e.value,
          ))
      .toList()
    ..sort((a, b) =>
        b.montoPendienteTotal.compareTo(a.montoPendienteTotal));
});

final cxpTotalPendienteProvider = Provider<double>((ref) {
  final cxp = ref.watch(cxpProvider);
  return cxp.fold(0.0, (s, c) => s + c.montoPendienteTotal);
});

final facturasProveedorVencidasCountProvider = Provider<int>((ref) {
  final facturas =
      ref.watch(facturasProveedorProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return facturas
      .where((f) => f.esPendienteOVencida && f.diasVencimiento(ahora) < 0)
      .length;
});

final gastosPagadosMesProvider = Provider<double>((ref) {
  final facturas =
      ref.watch(facturasProveedorProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return facturas
      .where((f) =>
          f.estatus == EstatusFacturaProveedor.pagada &&
          f.fechaPago != null &&
          f.fechaPago!.month == ahora.month &&
          f.fechaPago!.year == ahora.year)
      .fold(0.0, (s, f) => s + (f.montoPagado ?? f.monto));
});

final registrarPagoProveedorProvider = Provider<
    Future<Either<Failure, Unit>> Function(String, double, DateTime)>((ref) {
  return sl<IFacturaProveedorRepository>().registrarPago;
});

final crearFacturaProveedorProvider = Provider<
    Future<Either<Failure, String>> Function(FacturaProveedor)>((ref) {
  return sl<IFacturaProveedorRepository>().crearFactura;
});
