import 'package:equatable/equatable.dart';

enum CondicionAlerta {
  varianzaCombustible,
  sosActivados,
  banderasRojas,
  tiempoSinActividad,
  odometroAlto,
}

enum AccionAlerta {
  notificarSupervisor,
  bloquearAsignacion,
  generarAuditoria,
}

class ReglaAlerta extends Equatable {
  final String id;
  final String nombre;
  final CondicionAlerta condicion;
  final double umbral;        // valor numérico de la condición
  final List<AccionAlerta> acciones;
  final bool activa;
  final DateTime? creadaAt;

  const ReglaAlerta({
    required this.id,
    required this.nombre,
    required this.condicion,
    required this.umbral,
    required this.acciones,
    this.activa = true,
    this.creadaAt,
  });

  String get descripcionCondicion {
    switch (condicion) {
      case CondicionAlerta.varianzaCombustible:
        return 'Varianza combustible > ${(umbral * 100).toStringAsFixed(0)} %';
      case CondicionAlerta.sosActivados:
        return 'SOS activados ≥ ${umbral.toStringAsFixed(0)} en el mes';
      case CondicionAlerta.banderasRojas:
        return 'Banderas rojas ≥ ${umbral.toStringAsFixed(0)} consecutivas';
      case CondicionAlerta.tiempoSinActividad:
        return 'Sin GPS > ${umbral.toStringAsFixed(0)} min';
      case CondicionAlerta.odometroAlto:
        return 'Odómetro > ${umbral.toStringAsFixed(0)} km sin servicio';
    }
  }

  ReglaAlerta copyWith({
    String? nombre,
    CondicionAlerta? condicion,
    double? umbral,
    List<AccionAlerta>? acciones,
    bool? activa,
  }) => ReglaAlerta(
    id: id,
    nombre: nombre ?? this.nombre,
    condicion: condicion ?? this.condicion,
    umbral: umbral ?? this.umbral,
    acciones: acciones ?? this.acciones,
    activa: activa ?? this.activa,
    creadaAt: creadaAt,
  );

  @override
  List<Object?> get props => [id, condicion, umbral, activa];
}
