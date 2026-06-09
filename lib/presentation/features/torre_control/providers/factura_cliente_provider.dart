import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/cuenta_por_cobrar.dart';
import '../../../../domain/entities/factura_cliente.dart';
import '../../../../domain/repositories/i_factura_cliente_repository.dart';
import '../../../../injection_container.dart';

final facturasProvider = StreamProvider<List<FacturaCliente>>((ref) {
  return sl<IFacturaClienteRepository>().watchFacturas();
});

final cxcProvider = Provider<List<CuentaPorCobrar>>((ref) {
  final facturas = ref.watch(facturasProvider).valueOrNull ?? [];
  final pendientes = facturas.where((f) => f.esPendienteOVencida).toList();

  final byClient = <String, List<FacturaCliente>>{};
  for (final f in pendientes) {
    byClient.putIfAbsent(f.clienteId, () => []).add(f);
  }

  return byClient.entries
      .map((e) => CuentaPorCobrar(
            clienteId: e.key,
            clienteNombre: e.value.first.clienteNombre,
            facturasPendientes: e.value,
          ))
      .toList()
    ..sort((a, b) =>
        b.montoPendienteTotal.compareTo(a.montoPendienteTotal));
});

final cxcTotalPendienteProvider = Provider<double>((ref) {
  final cxc = ref.watch(cxcProvider);
  return cxc.fold(0.0, (s, c) => s + c.montoPendienteTotal);
});

final facturasVencidasCountProvider = Provider<int>((ref) {
  final facturas = ref.watch(facturasProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return facturas
      .where((f) => f.esPendienteOVencida && f.diasVencimiento(ahora) < 0)
      .length;
});

final ingresosCobradosMesProvider = Provider<double>((ref) {
  final facturas = ref.watch(facturasProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return facturas
      .where((f) =>
          f.estatus == EstatusFactura.cobrada &&
          f.fechaCobro != null &&
          f.fechaCobro!.month == ahora.month &&
          f.fechaCobro!.year == ahora.year)
      .fold(0.0, (s, f) => s + (f.montoCobrado ?? f.monto));
});

final registrarCartaPorteProvider = Provider<
    Future<Either<Failure, Unit>> Function(String, String)>((ref) {
  return sl<IFacturaClienteRepository>().registrarCartaPorte;
});

final registrarCobroProvider = Provider<
    Future<Either<Failure, Unit>> Function(String, double, DateTime)>((ref) {
  return sl<IFacturaClienteRepository>().registrarCobro;
});

final crearFacturaProvider = Provider<
    Future<Either<Failure, String>> Function(FacturaCliente)>((ref) {
  return sl<IFacturaClienteRepository>().crearFactura;
});
