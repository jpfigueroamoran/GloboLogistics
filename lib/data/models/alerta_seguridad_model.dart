import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/alerta_seguridad.dart';
import '../../domain/entities/viaje.dart';

class AlertaSeguridadModel extends AlertaSeguridad {
  const AlertaSeguridadModel({
    required super.id,
    required super.viajeId,
    required super.operadorId,
    required super.unidadId,
    required super.tipo,
    required super.timestamp,
    required super.posicion,
    super.estado,
    super.atendidaPor,
    super.notas,
    super.metadata,
  });

  factory AlertaSeguridadModel.fromFirestore(fs.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertaSeguridadModel.fromMap(data, id: doc.id);
  }

  factory AlertaSeguridadModel.fromMap(Map<String, dynamic> m,
      {String? id}) {
    GeoPoint posicion = const GeoPoint(lat: 0, lng: 0);
    final rawPos = m['posicion'];
    if (rawPos is Map<String, dynamic>) {
      posicion = GeoPoint(
        lat: (rawPos['lat'] as num?)?.toDouble() ?? 0,
        lng: (rawPos['lng'] as num?)?.toDouble() ?? 0,
      );
    } else if (rawPos is fs.GeoPoint) {
      posicion = GeoPoint(lat: rawPos.latitude, lng: rawPos.longitude);
    }

    return AlertaSeguridadModel(
      id:          id ?? m['id'] as String? ?? '',
      tipo:        _tipoFromString(m['tipo'] as String? ?? 'sos'),
      estado:      _estadoFromString(m['estado'] as String? ?? 'activa'),
      viajeId:     m['viaje_id'] as String? ?? '',
      operadorId:  m['operador_id'] as String? ?? '',
      unidadId:    m['unidad_id'] as String? ?? '',
      timestamp: m['timestamp'] is fs.Timestamp
          ? (m['timestamp'] as fs.Timestamp).toDate()
          : DateTime.tryParse(m['timestamp'] as String? ?? '') ??
              DateTime.now(),
      posicion:    posicion,
      atendidaPor: m['atendida_por'] as String?,
      notas:       m['notas'] as String?,
      metadata:    Map<String, dynamic>.from(
                       m['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'tipo':        tipo.name,
        'estado':      estado.name,
        'viaje_id':    viajeId,
        'operador_id': operadorId,
        'unidad_id':   unidadId,
        'timestamp':   fs.Timestamp.fromDate(timestamp),
        'posicion': {
          'lat': posicion.lat,
          'lng': posicion.lng,
        },
        if (atendidaPor != null) 'atendida_por': atendidaPor,
        if (notas != null)       'notas':        notas,
        if (metadata.isNotEmpty) 'metadata':     metadata,
      };

  static TipoAlerta _tipoFromString(String v) =>
      TipoAlerta.values.firstWhere((e) => e.name == v,
          orElse: () => TipoAlerta.sos);

  static EstadoAlerta _estadoFromString(String v) =>
      EstadoAlerta.values.firstWhere((e) => e.name == v,
          orElse: () => EstadoAlerta.activa);

  AlertaSeguridadModel copyWithEstado({
    required EstadoAlerta estado,
    String? atendidaPor,
    String? notas,
  }) =>
      AlertaSeguridadModel(
        id:          id,
        tipo:        tipo,
        estado:      estado,
        viajeId:     viajeId,
        operadorId:  operadorId,
        unidadId:    unidadId,
        timestamp:   timestamp,
        posicion:    posicion,
        atendidaPor: atendidaPor ?? this.atendidaPor,
        notas:       notas ?? this.notas,
        metadata:    metadata,
      );
}
