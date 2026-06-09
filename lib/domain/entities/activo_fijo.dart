import 'package:equatable/equatable.dart';

enum MetodoDepreciacion { lineal, aceleradaDobleSaldoDecreciente }

class ActivoFijo extends Equatable {
  final String id;
  final String unidadId;
  final String descripcion;
  final DateTime fechaAdquisicion;
  final double costoAdquisicion;
  final double valorResidual;
  final int vidaUtilAnios;
  final MetodoDepreciacion metodo;

  const ActivoFijo({
    required this.id,
    required this.unidadId,
    required this.descripcion,
    required this.fechaAdquisicion,
    required this.costoAdquisicion,
    required this.valorResidual,
    required this.vidaUtilAnios,
    this.metodo = MetodoDepreciacion.lineal,
  });

  double get depreciacionAnual =>
      (costoAdquisicion - valorResidual) / vidaUtilAnios;

  double get depreciacionMensual => depreciacionAnual / 12;

  double valorLibros(DateTime ahora) {
    final meses = ((ahora.year - fechaAdquisicion.year) * 12 +
            ahora.month -
            fechaAdquisicion.month)
        .clamp(0, vidaUtilAnios * 12);
    return (costoAdquisicion - depreciacionMensual * meses)
        .clamp(valorResidual, costoAdquisicion);
  }

  double porcentajeDepreciado(DateTime ahora) {
    final rango = costoAdquisicion - valorResidual;
    if (rango <= 0) return 1.0;
    return ((costoAdquisicion - valorLibros(ahora)) / rango).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props =>
      [id, unidadId, costoAdquisicion, vidaUtilAnios, metodo];
}
