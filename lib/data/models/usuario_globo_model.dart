import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/usuario_globo.dart';

class UsuarioGloboModel extends UsuarioGlobo {
  const UsuarioGloboModel({
    required super.uid,
    required super.email,
    required super.nombre,
    required super.rol,
    super.unidadAsignadaId,
    super.activo,
    super.ultimoAcceso,
  });

  factory UsuarioGloboModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UsuarioGloboModel(
      uid:              doc.id,
      email:            d['email'] as String? ?? '',
      nombre:           d['nombre'] as String? ?? '',
      rol:              RolUsuarioExt.fromString(d['rol'] as String?),
      unidadAsignadaId: d['unidad_asignada_id'] as String?,
      activo:           d['activo'] as bool? ?? true,
      ultimoAcceso:
          (d['ultimo_acceso'] as fs.Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email':              email,
        'nombre':             nombre,
        'rol':                rol.name,
        'activo':             activo,
        if (unidadAsignadaId != null)
          'unidad_asignada_id': unidadAsignadaId,
        'ultimo_acceso': fs.FieldValue.serverTimestamp(),
      };
}
