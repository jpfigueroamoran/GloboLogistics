import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/actividad_operativa.dart';
import '../../domain/entities/viaje.dart';
import 'viaje_model.dart';

class ActividadOperativaModel extends ActividadOperativa {
  const ActividadOperativaModel({
    required super.id,
    required super.viajeId,
    required super.operadorId,
    required super.tipo,
    required super.timestamp,
    super.posicion,
    super.datos,
    super.sincronizado,
    super.nuevoEstado,
  });

  factory ActividadOperativaModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActividadOperativaModel.fromMap(d, doc.id);
  }

  factory ActividadOperativaModel.fromMap(
      Map<String, dynamic> map, String id) {
    GeoPoint? posicion;
    final rawPos = map['posicion'];
    if (rawPos is Map<String, dynamic>) {
      posicion = GeoPointModel.fromMap(rawPos);
    }

    return ActividadOperativaModel(
      id:         id,
      viajeId:    map['viaje_id'] as String,
      operadorId: map['operador_id'] as String,
      tipo: TipoActividad.values.firstWhere(
        (e) => e.name == (map['tipo'] as String?),
        orElse: () => TipoActividad.nota,
      ),
      timestamp: map['timestamp'] is fs.Timestamp
          ? (map['timestamp'] as fs.Timestamp).toDate()
          : DateTime.tryParse(map['timestamp'] as String? ?? '') ??
              DateTime.now(),
      posicion:     posicion,
      datos:        Map<String, dynamic>.from(map['datos'] as Map? ?? {}),
      sincronizado: map['sincronizado'] as bool? ?? false,
      nuevoEstado:  map['nuevo_estado'] != null
          ? EstadoOperador.values
              .firstWhere((e) => e.name == map['nuevo_estado'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'viaje_id':    viajeId,
        'operador_id': operadorId,
        'tipo':        tipo.name,
        'timestamp':   fs.Timestamp.fromDate(timestamp),
        'posicion': posicion != null
            ? GeoPointModel(lat: posicion!.lat, lng: posicion!.lng).toMap()
            : null,
        'datos':        datos,
        'sincronizado': true,
        'nuevo_estado': nuevoEstado?.name,
      };

  Map<String, dynamic> toHive() => {
        'id':          id,
        'viaje_id':    viajeId,
        'operador_id': operadorId,
        'tipo':        tipo.name,
        'timestamp':   timestamp.toIso8601String(),
        'posicion': posicion != null
            ? {'lat': posicion!.lat, 'lng': posicion!.lng}
            : null,
        'datos':        datos,
        'sincronizado': sincronizado,
        'nuevo_estado': nuevoEstado?.name,
      };
}
