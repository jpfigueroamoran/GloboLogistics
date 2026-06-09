import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/cliente.dart';
import '../../../domain/entities/viaje.dart';

class ClienteFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  ClienteFirestoreDatasource(this._db);

  Stream<List<Cliente>> watchClientes() {
    return _db
        .collection(AppConstants.colClientes)
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<Cliente>> buscarClientes(String query) async {
    final norm = query.toLowerCase().trim();
    final snap = await _db
        .collection(AppConstants.colClientes)
        .where('activo', isEqualTo: true)
        .get();
    return snap.docs
        .map(_fromDoc)
        .where((c) =>
            c.nombre.toLowerCase().contains(norm) ||
            c.direccion.toLowerCase().contains(norm))
        .toList();
  }

  Future<String> crearCliente(Map<String, dynamic> data) async {
    final ref = await _db.collection(AppConstants.colClientes).add(data);
    return ref.id;
  }

  Future<void> actualizarCliente(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colClientes).doc(id).update(data);
  }

  Cliente _fromDoc(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Cliente(
      id:        doc.id,
      nombre:    d['nombre']    as String,
      direccion: d['direccion'] as String,
      posicion:  _parseGeo(d['posicion']),
      rfc:       d['rfc']      as String?,
      telefono:  d['telefono'] as String?,
      contacto:  d['contacto'] as String?,
      notas:     d['notas']    as String?,
      activo:    (d['activo'] as bool?) ?? true,
    );
  }

  GeoPoint? _parseGeo(dynamic raw) {
    if (raw is fs.GeoPoint) {
      return GeoPoint(lat: raw.latitude, lng: raw.longitude);
    }
    if (raw is Map<String, dynamic>) {
      return GeoPoint(
        lat: (raw['lat'] as num).toDouble(),
        lng: (raw['lng'] as num).toDouble(),
      );
    }
    return null;
  }
}
