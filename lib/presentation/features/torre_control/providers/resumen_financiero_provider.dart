import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../domain/entities/factura_cliente.dart';
import '../../../../domain/entities/factura_proveedor.dart';

import 'dashboard_provider.dart';
import 'factura_cliente_provider.dart';
import 'factura_proveedor_provider.dart';

// ── Desglose de TCO ────────────────────────────────────────────────────────────

class TcoDesglose {
  final double combustible;
  final double mantenimiento;
  final double peajes;
  final double otros;

  const TcoDesglose({
    this.combustible  = 0,
    this.mantenimiento = 0,
    this.peajes       = 0,
    this.otros        = 0,
  });

  double get total => combustible + mantenimiento + peajes + otros;
}

final tcoDesgloseProvider = Provider<TcoDesglose>((ref) {
  final viajes =
      ref.watch(viajesCompletadosProvider).valueOrNull ?? [];
  var combustible   = 0.0;
  var mantenimiento = 0.0;
  var peajes        = 0.0;
  var otros         = 0.0;
  for (final v in viajes) {
    combustible   += v.tco.combustible;
    mantenimiento += v.tco.mantenimiento;
    peajes        += v.tco.peajes;
    otros         += v.tco.otros;
  }
  return TcoDesglose(
    combustible:   combustible,
    mantenimiento: mantenimiento,
    peajes:        peajes,
    otros:         otros,
  );
});

// ── Resumen mensual (últimos 5 meses) ─────────────────────────────────────────

class ResumenMensual {
  final String etiqueta;
  final double ingresos;
  final double gastos;

  const ResumenMensual({
    required this.etiqueta,
    required this.ingresos,
    required this.gastos,
  });

  double get flujoNeto => ingresos - gastos;
}

DateTime _mesRelativo(DateTime base, int offset) {
  var m = base.month + offset;
  var y = base.year;
  while (m < 1)  { m += 12; y--; }
  while (m > 12) { m -= 12; y++; }
  return DateTime(y, m, 1);
}

final resumenMensualProvider = Provider<List<ResumenMensual>>((ref) {
  final facturas = ref.watch(facturasProvider).valueOrNull ?? [];
  final facturasProveedor =
      ref.watch(facturasProveedorProvider).valueOrNull ?? [];
  final ahora  = DateTime.now();
  final fmtMes = DateFormat('MMM yy', 'es_MX');

  return List.generate(5, (i) {
    final mes = _mesRelativo(ahora, i - 4);

    final ingresos = facturas
        .where((f) =>
            f.estatus == EstatusFactura.cobrada &&
            f.fechaCobro != null &&
            f.fechaCobro!.month == mes.month &&
            f.fechaCobro!.year == mes.year)
        .fold(0.0, (s, f) => s + (f.montoCobrado ?? f.monto));

    final gastos = facturasProveedor
        .where((f) =>
            f.estatus == EstatusFacturaProveedor.pagada &&
            f.fechaPago != null &&
            f.fechaPago!.month == mes.month &&
            f.fechaPago!.year == mes.year)
        .fold(0.0, (s, f) => s + (f.montoPagado ?? f.monto));

    return ResumenMensual(
      etiqueta: fmtMes.format(mes),
      ingresos: ingresos,
      gastos:   gastos,
    );
  });
});
