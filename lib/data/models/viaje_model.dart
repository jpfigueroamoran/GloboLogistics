import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/viaje.dart';

// GeoPointModel wraps our domain GeoPoint for Firestore serialization.
// Never use cloud_firestore's GeoPoint — we always store as {lat, lng} maps.
class GeoPointModel extends GeoPoint {
  const GeoPointModel({required super.lat, required super.lng});

  factory GeoPointModel.fromMap(Map<String, dynamic> map) => GeoPointModel(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

class TcoViajeModel extends TcoViaje {
  const TcoViajeModel({
    super.combustible,
    super.mantenimiento,
    super.peajes,
    super.otros,
  });

  factory TcoViajeModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TcoViajeModel();
    return TcoViajeModel(
      combustible:   (map['combustible']   as num?)?.toDouble() ?? 0,
      mantenimiento: (map['mantenimiento'] as num?)?.toDouble() ?? 0,
      peajes:        (map['peajes']        as num?)?.toDouble() ?? 0,
      otros:         (map['otros']         as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'combustible':   combustible,
        'mantenimiento': mantenimiento,
        'peajes':        peajes,
        'otros':         otros,
        'total':         total,
      };
}

class DestinoModel extends Destino {
  const DestinoModel({
    required super.clienteId,
    required super.descripcion,
    super.geo,
    super.estado,
    required super.orden,
  });

  factory DestinoModel.fromMap(Map<String, dynamic> map) {
    GeoPoint? parseGeo(dynamic raw) {
      if (raw is Map<String, dynamic>) return GeoPointModel.fromMap(raw);
      return null;
    }
    return DestinoModel(
      clienteId:   map['cliente_id'] as String,
      descripcion: map['descripcion'] as String,
      geo:         parseGeo(map['geo']),
      estado: EstadoDestino.values.firstWhere(
        (e) => e.name == (map['estado'] as String?),
        orElse: () => EstadoDestino.pendiente,
      ),
      orden: (map['orden'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'cliente_id':  clienteId,
        'descripcion': descripcion,
        'geo': geo != null
            ? GeoPointModel(lat: geo!.lat, lng: geo!.lng).toMap()
            : null,
        'estado': estado.name,
        'orden':  orden,
      };
}

class ViajeModel extends Viaje {
  const ViajeModel({
    required super.id,
    required super.unidadId,
    required super.operadorId,
    required super.origenDescripcion,
    required super.destinoDescripcion,
    super.origenGeo,
    super.destinoGeo,
    super.destinos,
    required super.estado,
    super.fechaInicio,
    super.fechaFin,
    super.litrosCargados,
    super.litrosConsumiidosTelemetria,
    super.litrosConsumiidosTickets,
    super.varianzaCombustible,
    super.nivelAlerta,
    required super.tco,
    super.observaciones,
    super.justificacionVarianza,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ViajeModel.fromFirestore(fs.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ViajeModel.fromMap(data, doc.id);
  }

  factory ViajeModel.fromMap(Map<String, dynamic> map, String id) {
    GeoPoint? parseGeo(dynamic raw) {
      if (raw is Map<String, dynamic>) return GeoPointModel.fromMap(raw);
      return null;
    }

    return ViajeModel(
      id:                    id,
      unidadId:              map['unidad_id'] as String,
      operadorId:            map['operador_id'] as String,
      origenDescripcion:     map['origen_descripcion'] as String? ?? '',
      destinoDescripcion:    map['destino_descripcion'] as String? ?? '',
      origenGeo:             parseGeo(map['origen_geo']),
      destinoGeo:            parseGeo(map['destino_geo']),
      estado: EstadoViaje.values.firstWhere(
        (e) => e.name == (map['estado'] as String?),
        orElse: () => EstadoViaje.programado,
      ),
      fechaInicio: (map['fecha_inicio'] as fs.Timestamp?)?.toDate(),
      fechaFin:    (map['fecha_fin']    as fs.Timestamp?)?.toDate(),
      litrosCargados:
          (map['litros_cargados'] as num?)?.toDouble() ?? 0,
      litrosConsumiidosTelemetria:
          (map['litros_consumidos_telemetria'] as num?)?.toDouble() ?? 0,
      litrosConsumiidosTickets:
          (map['litros_consumidos_tickets'] as num?)?.toDouble() ?? 0,
      varianzaCombustible:
          (map['varianza_combustible'] as num?)?.toDouble(),
      nivelAlerta: NivelAlertaViaje.values.firstWhere(
        (e) => e.name == (map['nivel_alerta'] as String?),
        orElse: () => NivelAlertaViaje.ninguna,
      ),
      destinos: (map['destinos'] as List<dynamic>? ?? [])
          .map((d) => DestinoModel.fromMap(d as Map<String, dynamic>))
          .toList(),
      tco: TcoViajeModel.fromMap(map['tco'] as Map<String, dynamic>?),
      observaciones: map['observaciones'] as String?,
      justificacionVarianza: map['justificacion_varianza'] as String?,
      createdAt:
          (map['created_at'] as fs.Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map['updated_at'] as fs.Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    GeoPointModel? geo(GeoPoint? g) =>
        g == null ? null : GeoPointModel(lat: g.lat, lng: g.lng);

    return {
      'unidad_id':            unidadId,
      'operador_id':          operadorId,
      'origen_descripcion':   origenDescripcion,
      'destino_descripcion':  destinoDescripcion,
      'origen_geo':           geo(origenGeo)?.toMap(),
      'destino_geo':          geo(destinoGeo)?.toMap(),
      'estado':               estado.name,
      'fecha_inicio':         fechaInicio != null
          ? fs.Timestamp.fromDate(fechaInicio!) : null,
      'fecha_fin':            fechaFin != null
          ? fs.Timestamp.fromDate(fechaFin!) : null,
      'litros_cargados':               litrosCargados,
      'litros_consumidos_telemetria':  litrosConsumiidosTelemetria,
      'litros_consumidos_tickets':     litrosConsumiidosTickets,
      'varianza_combustible':          varianzaCombustible,
      'nivel_alerta':                  nivelAlerta.name,
      'tco': (tco is TcoViajeModel)
          ? (tco as TcoViajeModel).toMap()
          : TcoViajeModel(
              combustible:   tco.combustible,
              mantenimiento: tco.mantenimiento,
              peajes:        tco.peajes,
              otros:         tco.otros,
            ).toMap(),
      'destinos': destinos
          .map((d) => (d is DestinoModel
              ? d
              : DestinoModel(
                  clienteId:   d.clienteId,
                  descripcion: d.descripcion,
                  geo:         d.geo,
                  estado:      d.estado,
                  orden:       d.orden,
                ))
              .toMap())
          .toList(),
      'observaciones':  observaciones,
      'justificacion_varianza': justificacionVarianza,
      'created_at':     fs.Timestamp.fromDate(createdAt),
      'updated_at':     fs.FieldValue.serverTimestamp(),
    };
  }
}
