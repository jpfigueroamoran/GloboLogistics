import 'package:equatable/equatable.dart';

/// Clases de usuario del sistema, ordenadas por tier de operación:
/// CAMPO (móvil): solicitante, operador, mantenimiento
/// CONTROL (tablet/web): despachador, supervisor
/// GESTIÓN (escritorio): direccion (solo lectura), administrador
enum RolUsuario {
  solicitante,
  operador,
  mantenimiento,
  despachador,
  supervisor,
  direccion,
  administrador,
}

extension RolUsuarioExt on RolUsuario {
  String get nombre => switch (this) {
        RolUsuario.solicitante    => 'Solicitante',
        RolUsuario.operador       => 'Operador',
        RolUsuario.mantenimiento  => 'Mantenimiento',
        RolUsuario.despachador    => 'Despachador',
        RolUsuario.supervisor     => 'Supervisor',
        RolUsuario.direccion      => 'Dirección',
        RolUsuario.administrador  => 'Administrador',
      };

  /// Descripción corta del alcance del rol (para selección de usuarios).
  String get descripcion => switch (this) {
        RolUsuario.solicitante   => 'Pide transporte y rastrea su material',
        RolUsuario.operador      => 'Conduce, reporta y captura en ruta',
        RolUsuario.mantenimiento => 'Atiende las unidades en taller',
        RolUsuario.despachador   => 'Asigna unidades y operadores',
        RolUsuario.supervisor    => 'Monitorea la operación en vivo',
        RolUsuario.direccion     => 'Consulta indicadores (solo lectura)',
        RolUsuario.administrador => 'Configura el sistema y los accesos',
      };

  /// Solo supervisor y administrador usan el dashboard completo de Torre.
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
