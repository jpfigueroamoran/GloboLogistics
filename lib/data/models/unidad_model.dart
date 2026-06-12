import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/unidad.dart';
import '../../domain/entities/viaje.dart';
import 'viaje_model.dart';

class UnidadModel extends Unidad {
  const UnidadModel({
    required super.id,
    required super.placas,
    required super.modelo,
    required super.anio,
    required super.estado,
    super.operadorAsignadoId,
    super.ultimaPosicion,
    super.ultimaActualizacionPosicion,
    required super.odometro,
    required super.capacidadTanqueLitros,
    super.proximoMantenimientoOdometro,
    super.viajeActivoId,
  });

  factory UnidadModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UnidadModel.fromMap(d, doc.id);
  }

  factory UnidadModel.fromMap(Map<String, dynamic> map, String id) {
    GeoPoint? posicion;
    final rawPos = map['ultima_posicion'];
    if (rawPos is Map<String, dynamic>) {
      posicion = GeoPointModel.fromMap(rawPos);
    }

    return UnidadModel(
      id:       id,
      placas:   map['placas'] as String,
      modelo:   map['modelo'] as String? ?? '',
      anio:     (map['anio'] as num?)?.toInt() ?? 0,
      estado:   EstadoUnidad.values.firstWhere(
        (e) => e.name == (map['estado'] as String?),
        orElse: () => EstadoUnidad.activa,
      ),
      operadorAsignadoId: map['operador_asignado_id'] as String?,
      viajeActivoId:      map['viaje_activo_id'] as String?,
      ultimaPosicion:     posicion,
      ultimaActualizacionPosicion:
          (map['ultima_actualizacion_posicion'] as fs.Timestamp?)?.toDate(),
      odometro:            (map['odometro'] as num?)?.toDouble() ?? 0,
      capacidadTanqueLitros:
          (map['capacidad_tanque'] as num?)?.toDouble() ?? 0,
      proximoMantenimientoOdometro:
          (map['proximo_mantenimiento_odometro'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'placas':  placas,
        'modelo':  modelo,
        'anio':    anio,
        'estado':  estado.name,
        'operador_asignado_id': operadorAsignadoId,
        'ultima_posicion': ultimaPosicion != null
            ? GeoPointModel(
                    lat: ultimaPosicion!.lat,
                    lng: ultimaPosicion!.lng)
                .toMap()
            : null,
        'ultima_actualizacion_posicion': ultimaActualizacionPosicion != null
            ? fs.Timestamp.fromDate(ultimaActualizacionPosicion!)
            : null,
        'odometro':        odometro,
        'capacidad_tanque': capacidadTanqueLitros,
        if (proximoMantenimientoOdometro != null)
          'proximo_mantenimiento_odometro': proximoMantenimientoOdometro,
      };
}
