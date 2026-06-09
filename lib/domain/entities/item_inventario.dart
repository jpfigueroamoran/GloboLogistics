import 'package:equatable/equatable.dart';

enum CategoriaInventario { llantas, refacciones, aceites, herramientas, otro }

extension CategoriaInventarioLabel on CategoriaInventario {
  String get label => switch (this) {
        CategoriaInventario.llantas      => 'Llantas',
        CategoriaInventario.refacciones  => 'Refacciones',
        CategoriaInventario.aceites      => 'Aceites',
        CategoriaInventario.herramientas => 'Herramientas',
        CategoriaInventario.otro         => 'Otro',
      };
}

enum UnidadMedida { piezas, litros, kg, metros }

extension UnidadMedidaLabel on UnidadMedida {
  String get label => switch (this) {
        UnidadMedida.piezas  => 'pzas.',
        UnidadMedida.litros  => 'L',
        UnidadMedida.kg      => 'kg',
        UnidadMedida.metros  => 'm',
      };
}

class ItemInventario extends Equatable {
  final String id;
  final String nombre;
  final CategoriaInventario categoria;
  final UnidadMedida unidadMedida;
  final double stockActual;
  final double stockMinimo;
  final double precioUnitario;
  final String? unidadId;
  final DateTime ultimaActualizacion;

  const ItemInventario({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    required this.precioUnitario,
    this.unidadId,
    required this.ultimaActualizacion,
  });

  bool get esBajoStock => stockActual <= stockMinimo;

  double get valorTotal => stockActual * precioUnitario;

  // 0.0 = empty, 1.0 = at minimum, >1.0 = above minimum
  double get pctStock =>
      stockMinimo > 0 ? (stockActual / stockMinimo).clamp(0.0, 2.0) : 1.0;

  @override
  List<Object?> get props => [id, nombre, stockActual, stockMinimo];
}
