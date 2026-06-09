import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/activo_fijo.dart';

class ActivoFijoModel extends ActivoFijo {
  const ActivoFijoModel({
    required super.id,
    required super.unidadId,
    required super.descripcion,
    required super.fechaAdquisicion,
    required super.costoAdquisicion,
    required super.valorResidual,
    required super.vidaUtilAnios,
    super.metodo,
  });

  factory ActivoFijoModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivoFijoModel(
      id: doc.id,
      unidadId: d['unidad_id'] as String? ?? '',
      descripcion: d['descripcion'] as String? ?? '',
      fechaAdquisicion:
          (d['fecha_adquisicion'] as fs.Timestamp).toDate(),
      costoAdquisicion: (d['costo_adquisicion'] as num? ?? 0).toDouble(),
      valorResidual: (d['valor_residual'] as num? ?? 0).toDouble(),
      vidaUtilAnios: (d['vida_util_anios'] as int? ?? 10),
      metodo: MetodoDepreciacion.values.firstWhere(
        (e) => e.name == d['metodo'],
        orElse: () => MetodoDepreciacion.lineal,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'unidad_id': unidadId,
        'descripcion': descripcion,
        'fecha_adquisicion': fs.Timestamp.fromDate(fechaAdquisicion),
        'costo_adquisicion': costoAdquisicion,
        'valor_residual': valorResidual,
        'vida_util_anios': vidaUtilAnios,
        'metodo': metodo.name,
      };

  factory ActivoFijoModel.fromEntity(ActivoFijo e) => ActivoFijoModel(
        id: e.id,
        unidadId: e.unidadId,
        descripcion: e.descripcion,
        fechaAdquisicion: e.fechaAdquisicion,
        costoAdquisicion: e.costoAdquisicion,
        valorResidual: e.valorResidual,
        vidaUtilAnios: e.vidaUtilAnios,
        metodo: e.metodo,
      );
}
