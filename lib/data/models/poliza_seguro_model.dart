import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/poliza_seguro.dart';

class PolizaSeguroModel extends PolizaSeguro {
  const PolizaSeguroModel({
    required super.id,
    super.unidadId,
    super.unidadPlacas,
    required super.tipo,
    required super.aseguradora,
    required super.numeroPoliza,
    required super.vigenciaInicio,
    required super.vigenciaFin,
    required super.primaMensual,
    super.modoPago,
    required super.coberturaMaxima,
    required super.deducible,
  });

  factory PolizaSeguroModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PolizaSeguroModel(
      id: doc.id,
      unidadId: d['unidad_id'] as String?,
      unidadPlacas: d['unidad_placas'] as String?,
      tipo: TipoPoliza.values.firstWhere(
        (e) => e.name == d['tipo'],
        orElse: () => TipoPoliza.responsabilidadCivil,
      ),
      aseguradora: d['aseguradora'] as String? ?? '',
      numeroPoliza: d['numero_poliza'] as String? ?? '',
      vigenciaInicio: (d['vigencia_inicio'] as fs.Timestamp).toDate(),
      vigenciaFin: (d['vigencia_fin'] as fs.Timestamp).toDate(),
      primaMensual: (d['prima_mensual'] as num? ?? 0).toDouble(),
      modoPago: ModoPagoSeguro.values.firstWhere(
        (e) => e.name == d['modo_pago'],
        orElse: () => ModoPagoSeguro.mensual,
      ),
      coberturaMaxima: (d['cobertura_maxima'] as num? ?? 0).toDouble(),
      deducible: (d['deducible'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'unidad_id': unidadId,
        'unidad_placas': unidadPlacas,
        'tipo': tipo.name,
        'aseguradora': aseguradora,
        'numero_poliza': numeroPoliza,
        'vigencia_inicio': fs.Timestamp.fromDate(vigenciaInicio),
        'vigencia_fin': fs.Timestamp.fromDate(vigenciaFin),
        'prima_mensual': primaMensual,
        'modo_pago': modoPago.name,
        'cobertura_maxima': coberturaMaxima,
        'deducible': deducible,
      };

  factory PolizaSeguroModel.fromEntity(PolizaSeguro e) => PolizaSeguroModel(
        id: e.id,
        unidadId: e.unidadId,
        unidadPlacas: e.unidadPlacas,
        tipo: e.tipo,
        aseguradora: e.aseguradora,
        numeroPoliza: e.numeroPoliza,
        vigenciaInicio: e.vigenciaInicio,
        vigenciaFin: e.vigenciaFin,
        primaMensual: e.primaMensual,
        modoPago: e.modoPago,
        coberturaMaxima: e.coberturaMaxima,
        deducible: e.deducible,
      );
}
