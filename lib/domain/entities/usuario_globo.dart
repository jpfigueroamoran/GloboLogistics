import 'package:equatable/equatable.dart';

enum RolUsuario { operador, supervisor, administrador }

extension RolUsuarioExt on RolUsuario {
  String get nombre => switch (this) {
        RolUsuario.operador       => 'Operador',
        RolUsuario.supervisor     => 'Supervisor',
        RolUsuario.administrador  => 'Administrador',
      };

  bool get accesoTorreControl =>
      this == RolUsuario.supervisor || this == RolUsuario.administrador;

  static RolUsuario fromString(String? v) =>
      RolUsuario.values.firstWhere(
        (e) => e.name == v,
        orElse: () => RolUsuario.operador,
      );
}

class UsuarioGlobo extends Equatable {
  final String uid;
  final String email;
  final String nombre;
  final RolUsuario rol;
  final String? unidadAsignadaId;
  final bool activo;
  final DateTime? ultimoAcceso;

  const UsuarioGlobo({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
    this.unidadAsignadaId,
    this.activo = true,
    this.ultimoAcceso,
  });

  bool get puedeAccederTorre => rol.accesoTorreControl;
  bool get esOperador => rol == RolUsuario.operador;

  @override
  List<Object?> get props => [uid, rol, activo];
}
