import 'package:equatable/equatable.dart';

enum TipoDocumento {
  licenciaConducir,
  segurovehiculo,
  verificacionEmision,
  permisoCirculacion,
  polizaTransporte,
  tarjetaCirculacion,
  revisionTecnica,
}

enum SemaforoDocumento { vigente, proximoVencer, vencido }

class DocumentoVencimiento extends Equatable {
  final String id;
  final String entidadId;    // uid del operador o id de unidad
  final String nombreEntidad;
  final TipoDocumento tipo;
  final DateTime fechaVencimiento;
  final bool esDocumentoDeUnidad;   // false = es del operador
  final String? urlArchivo;

  const DocumentoVencimiento({
    required this.id,
    required this.entidadId,
    required this.nombreEntidad,
    required this.tipo,
    required this.fechaVencimiento,
    this.esDocumentoDeUnidad = false,
    this.urlArchivo,
  });

  factory DocumentoVencimiento.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final f = data['fecha_vencimiento'];
    return DocumentoVencimiento(
      id: doc.id,
      entidadId: data['entidad_id'] ?? '',
      nombreEntidad: data['nombre_entidad'] ?? '',
      tipo: TipoDocumento.values.firstWhere((e) => e.name == data['tipo'], orElse: () => TipoDocumento.licenciaConducir),
      fechaVencimiento: f != null ? (f as dynamic).toDate() : DateTime.now(),
      esDocumentoDeUnidad: data['es_unidad'] ?? false,
      urlArchivo: data['url_archivo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'entidad_id': entidadId,
      'nombre_entidad': nombreEntidad,
      'tipo': tipo.name,
      'fecha_vencimiento': fechaVencimiento,
      'es_unidad': esDocumentoDeUnidad,
      'url_archivo': urlArchivo,
    };
  }

  int diasRestantes(DateTime ahora) =>
      fechaVencimiento.difference(ahora).inDays;

  SemaforoDocumento semaforo(DateTime ahora) {
    final dias = diasRestantes(ahora);
    if (dias < 0)   return SemaforoDocumento.vencido;
    if (dias <= 30) return SemaforoDocumento.proximoVencer;
    return SemaforoDocumento.vigente;
  }

  String get tipoLabel {
    switch (tipo) {
      case TipoDocumento.licenciaConducir:    return 'Licencia de Conducir';
      case TipoDocumento.segurovehiculo:      return 'Seguro Vehicular';
      case TipoDocumento.verificacionEmision: return 'Verificación de Emisión';
      case TipoDocumento.permisoCirculacion:  return 'Permiso de Circulación';
      case TipoDocumento.polizaTransporte:    return 'Póliza de Transporte';
      case TipoDocumento.tarjetaCirculacion:  return 'Tarjeta de Circulación';
      case TipoDocumento.revisionTecnica:     return 'Revisión Técnica';
    }
  }

  @override
  List<Object?> get props => [id, tipo, fechaVencimiento];
}
