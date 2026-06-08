import 'package:equatable/equatable.dart';
import 'viaje.dart';

class Cliente extends Equatable {
  final String id;
  final String nombre;
  final String direccion;
  final GeoPoint? posicion;
  final String? telefono;
  final String? contacto;
  final bool activo;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.posicion,
    this.telefono,
    this.contacto,
    this.activo = true,
  });

  @override
  List<Object?> get props => [id, nombre, direccion];
}
