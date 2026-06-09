import 'package:equatable/equatable.dart';

enum TipoMovimiento { entrada, salida }

class MovimientoInventario extends Equatable {
  final String id;
  final String itemId;
  final TipoMovimiento tipo;
  final double cantidad;
  final double precioUnitario;
  final DateTime fecha;
  final String? viajeId;
  final String? unidadId;
  final String motivo;

  const MovimientoInventario({
    required this.id,
    required this.itemId,
    required this.tipo,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
    this.viajeId,
    this.unidadId,
    required this.motivo,
  });

  double get montoTotal => cantidad * precioUnitario;

  @override
  List<Object?> get props => [id, itemId, tipo, cantidad, fecha];
}
