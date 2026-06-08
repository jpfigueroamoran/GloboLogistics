import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/costo_operativo.dart';

class CostoOperativoModel extends CostoOperativo {
  const CostoOperativoModel({
    required super.id,
    required super.viajeId,
    required super.unidadId,
    required super.tipo,
    required super.monto,
    required super.proveedor,
    required super.folio,
    required super.fecha,
    super.datosOcr,
    super.imagenUrl,
    super.verificado,
    super.sincronizado,
  });

  factory CostoOperativoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CostoOperativoModel.fromMap(data, id: doc.id);
  }

  factory CostoOperativoModel.fromMap(Map<String, dynamic> m,
      {String? id}) {
    DatosOcr? datosOcr;
    final rawOcr = m['datos_ocr'] as Map<String, dynamic>?;
    if (rawOcr != null) {
      datosOcr = DatosOcr(
        textoCompleto:   rawOcr['texto_completo'] as String?,
        montoDetectado:  (rawOcr['monto_detectado'] as num?)?.toDouble(),
        litrosDetectados:(rawOcr['litros_detectados'] as num?)?.toDouble(),
        foliDetectado:   rawOcr['folio_detectado'] as String?,
        confianza:       (rawOcr['confianza'] as num?)?.toDouble(),
      );
    }

    return CostoOperativoModel(
      id:          id ?? m['id'] as String? ?? '',
      viajeId:     m['viaje_id'] as String? ?? '',
      unidadId:    m['unidad_id'] as String? ?? '',
      tipo:        _tipoFromString(m['tipo'] as String? ?? 'otro'),
      monto:       (m['monto'] as num?)?.toDouble() ?? 0,
      proveedor:   m['proveedor'] as String? ?? '',
      folio:       m['folio'] as String? ?? '',
      fecha: m['fecha'] is Timestamp
          ? (m['fecha'] as Timestamp).toDate()
          : DateTime.tryParse(m['fecha'] as String? ?? '') ?? DateTime.now(),
      datosOcr:   datosOcr,
      imagenUrl:  m['imagen_url'] as String?,
      verificado: m['verificado'] as bool? ?? false,
      sincronizado: m['sincronizado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'viaje_id':    viajeId,
        'unidad_id':   unidadId,
        'tipo':        tipo.name,
        'monto':       monto,
        'proveedor':   proveedor,
        'folio':       folio,
        'fecha':       Timestamp.fromDate(fecha),
        if (imagenUrl != null) 'imagen_url': imagenUrl,
        'verificado':   verificado,
        'sincronizado': true,
        if (datosOcr != null)
          'datos_ocr': {
            if (datosOcr!.textoCompleto != null)
              'texto_completo': datosOcr!.textoCompleto,
            if (datosOcr!.montoDetectado != null)
              'monto_detectado': datosOcr!.montoDetectado,
            if (datosOcr!.litrosDetectados != null)
              'litros_detectados': datosOcr!.litrosDetectados,
            if (datosOcr!.foliDetectado != null)
              'folio_detectado': datosOcr!.foliDetectado,
            if (datosOcr!.confianza != null)
              'confianza': datosOcr!.confianza,
          },
      };

  Map<String, dynamic> toHive() => {
        'id':          id,
        'viaje_id':    viajeId,
        'unidad_id':   unidadId,
        'tipo':        tipo.name,
        'monto':       monto,
        'proveedor':   proveedor,
        'folio':       folio,
        'fecha':       fecha.toIso8601String(),
        if (imagenUrl != null) 'imagen_url': imagenUrl,
        'verificado':    verificado,
        'sincronizado':  sincronizado,
        if (datosOcr != null)
          'datos_ocr': {
            if (datosOcr!.textoCompleto != null)
              'texto_completo': datosOcr!.textoCompleto,
            if (datosOcr!.montoDetectado != null)
              'monto_detectado': datosOcr!.montoDetectado,
            if (datosOcr!.litrosDetectados != null)
              'litros_detectados': datosOcr!.litrosDetectados,
            if (datosOcr!.foliDetectado != null)
              'folio_detectado': datosOcr!.foliDetectado,
            if (datosOcr!.confianza != null)
              'confianza': datosOcr!.confianza,
          },
      };

  CostoOperativoModel copyWith({bool? sincronizado, bool? verificado}) =>
      CostoOperativoModel(
        id:          id,
        viajeId:     viajeId,
        unidadId:    unidadId,
        tipo:        tipo,
        monto:       monto,
        proveedor:   proveedor,
        folio:       folio,
        fecha:       fecha,
        datosOcr:    datosOcr,
        imagenUrl:   imagenUrl,
        verificado:  verificado  ?? this.verificado,
        sincronizado: sincronizado ?? this.sincronizado,
      );

  static TipoCosto _tipoFromString(String v) =>
      TipoCosto.values.firstWhere((e) => e.name == v,
          orElse: () => TipoCosto.otro);
}
