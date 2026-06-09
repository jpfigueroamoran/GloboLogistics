import 'package:equatable/equatable.dart';
import 'viaje.dart';

class Cliente extends Equatable {
  final String id;
  final String nombre;
  final String direccion;
  final GeoPoint? posicion;
  final String? rfc;
  final String? telefono;
  final String? contacto;
  final String? notas;
  final bool activo;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.posicion,
    this.rfc,
    this.telefono,
    this.contacto,
    this.notas,
    this.activo = true,
  });

  Cliente copyWith({
    String? nombre,
    String? direccion,
    GeoPoint? posicion,
    String? rfc,
    String? telefono,
    String? contacto,
    String? notas,
    bool? activo,
  }) =>
      Cliente(
        id: id,
        nombre: nombre ?? this.nombre,
        direccion: direccion ?? this.direccion,
        posicion: posicion ?? this.posicion,
        rfc: rfc ?? this.rfc,
        telefono: telefono ?? this.telefono,
        contacto: contacto ?? this.contacto,
        notas: notas ?? this.notas,
        activo: activo ?? this.activo,
      );

  @override
  List<Object?> get props => [id, nombre, direccion];
}
