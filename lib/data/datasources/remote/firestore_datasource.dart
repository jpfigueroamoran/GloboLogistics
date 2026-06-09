import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/viaje_model.dart';
import '../../models/actividad_operativa_model.dart';
import '../../models/unidad_model.dart';
import '../../../domain/entities/viaje.dart';
import '../../../domain/entities/alerta_seguridad.dart';

class FirestoreDatasource {
  final fs.FirebaseFirestore _db;

  FirestoreDatasource(this._db);

  // ── Unidades ──────────────────────────────────────────────────────────────

  Stream<List<UnidadModel>> watchUnidades() {
    return _db
        .collection(AppConstants.colUnidades)
        .where('estado', isEqualTo: 'activa')
        .snapshots()
        .map((snap) =>
            snap.docs.map(UnidadModel.fromFirestore).toList());
  }

  Future<void> updatePosicionUnidad(
      String unidadId, GeoPoint posicion) async {
    await _db
        .collection(AppConstants.colUnidades)
        .doc(unidadId)
        .update({
      'ultima_posicion': {'lat': posicion.lat, 'lng': posicion.lng},
      'ultima_actualizacion_posicion': fs.FieldValue.serverTimestamp(),
    });
  }

  // ── Documentos y Vencimientos ─────────────────────────────────────────────

  Stream<List<dynamic>> watchDocumentos() {
    return _db
        .collection('documentos')
        .orderBy('fecha_vencimiento', descending: false)
        .snapshots()
        .map((snap) => snap.docs.toList()); // Devolvemos dynamic para parsear en el provider
  }

  Future<String> crearDocumento(Map<String, dynamic> data) async {
    final ref = _db.collection('documentos').doc();
    await ref.set({
      ...data,
      'created_at': fs.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ── Viajes ────────────────────────────────────────────────────────────────

  Stream<List<ViajeModel>> watchViajesActivos() {
    return _db
        .collection(AppConstants.colViajes)
        .where('estado', whereIn: ['enCurso', 'programado'])
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ViajeModel.fromFirestore).toList());
  }

  Stream<List<ViajeModel>> watchViajesCompletados() {
    return _db
        .collection(AppConstants.colViajes)
        .where('estado', isEqualTo: 'completado')
        .orderBy('fecha_fin', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ViajeModel.fromFirestore(doc)).toList());
  }

  Stream<List<ViajeModel>> watchViajesPorOperador(String operadorId) {
    return _db
        .collection(AppConstants.colViajes)
        .where('operador_id', isEqualTo: operadorId)
        .where('estado', whereIn: ['enCurso', 'programado'])
        .snapshots()
        .map((snap) =>
            snap.docs.map(ViajeModel.fromFirestore).toList());
  }

  Future<ViajeModel> getViaje(String id) async {
    final doc =
        await _db.collection(AppConstants.colViajes).doc(id).get();
    if (!doc.exists) throw const ServerException('Viaje no encontrado.');
    return ViajeModel.fromFirestore(doc);
  }

  Future<String> crearViaje(ViajeModel viaje) async {
    final ref = viaje.id.isEmpty
        ? _db.collection(AppConstants.colViajes).doc()
        : _db.collection(AppConstants.colViajes).doc(viaje.id);
    await ref.set(viaje.toFirestore());
    return ref.id;
  }

  Future<void> actualizarEstadoViaje(
      String viajeId, EstadoViaje estado) async {
    await _db
        .collection(AppConstants.colViajes)
        .doc(viajeId)
        .update({
      'estado':     estado.name,
      'updated_at': fs.FieldValue.serverTimestamp(),
      if (estado == EstadoViaje.enCurso)
        'fecha_inicio': fs.FieldValue.serverTimestamp(),
      if (estado == EstadoViaje.completado)
        'fecha_fin': fs.FieldValue.serverTimestamp(),
    });
  }

  Future<void> asignarViaje(String viajeId, String operadorId, String unidadId) async {
    await _db
        .collection(AppConstants.colViajes)
        .doc(viajeId)
        .update({
      'operador_id': operadorId,
      'unidad_id':   unidadId,
      'updated_at':  fs.FieldValue.serverTimestamp(),
    });
  }

  Future<void> justificarVarianza(String viajeId, String motivo) async {
    await _db.collection(AppConstants.colViajes).doc(viajeId).update({
      'justificacion_varianza': motivo,
      'updated_at': fs.FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTcoViaje(
      String viajeId, Map<String, dynamic> tcoMap) async {
    await _db
        .collection(AppConstants.colViajes)
        .doc(viajeId)
        .update({
      'tco':        tcoMap,
      'updated_at': fs.FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarTcoViaje(
      String viajeId, double costoAdicional, String tipoCosto) async {
    final ref = _db.collection(AppConstants.colViajes).doc(viajeId);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      final tcoActual = data['tco'] as Map<String, dynamic>? ?? {};
      
      final double totalActual = (tcoActual['total'] as num?)?.toDouble() ?? 0.0;
      final double costoEspecificoActual = (tcoActual[tipoCosto] as num?)?.toDouble() ?? 0.0;
      
      final Map<String, dynamic> nuevoTco = Map.from(tcoActual);
      nuevoTco['total'] = totalActual + costoAdicional;
      nuevoTco[tipoCosto] = costoEspecificoActual + costoAdicional;
      
      transaction.update(ref, {
        'tco': nuevoTco,
        'updated_at': fs.FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> actualizarVarianzaCombustible(
      String viajeId, double varianza, bool bandejaRoja) async {
    await _db
        .collection(AppConstants.colViajes)
        .doc(viajeId)
        .update({
      'varianza_combustible': varianza,
      'nivel_alerta': bandejaRoja ? 'bandajaRoja' : 'advertencia',
      'updated_at':   fs.FieldValue.serverTimestamp(),
    });
  }

  // ── Actividad Operativa ──────────────────────────────────────────────────

  Future<String> logActividad(
      ActividadOperativaModel actividad) async {
    final ref =
        _db.collection(AppConstants.colActividadOperativa).doc();
    await ref.set(actividad.toFirestore());
    return ref.id;
  }

  Future<void> logActividadBatch(
      List<ActividadOperativaModel> actividades) async {
    final batch = _db.batch();
    for (final a in actividades) {
      final ref =
          _db.collection(AppConstants.colActividadOperativa).doc();
      batch.set(ref, a.toFirestore());
    }
    await batch.commit();
  }

  Stream<List<ActividadOperativaModel>> watchActividadesByViaje(
      String viajeId) {
    return _db
        .collection(AppConstants.colActividadOperativa)
        .where('viaje_id', isEqualTo: viajeId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ActividadOperativaModel.fromFirestore).toList());
  }

  // ── Alertas de Seguridad ─────────────────────────────────────────────────

  Future<String> crearAlertaSOS({
    required String viajeId,
    required String operadorId,
    required String unidadId,
    required GeoPoint posicion,
  }) async {
    final ref =
        _db.collection(AppConstants.colAlertasSeguridad).doc();
    await ref.set({
      'viaje_id':    viajeId,
      'operador_id': operadorId,
      'unidad_id':   unidadId,
      'tipo':        TipoAlerta.sos.name,
      'timestamp':   fs.FieldValue.serverTimestamp(),
      'posicion':    {'lat': posicion.lat, 'lng': posicion.lng},
      'estado':      EstadoAlerta.activa.name,
    });
    return ref.id;
  }

  Future<void> actualizarPosicionSOS(
      String alertaId, GeoPoint posicion) async {
    await _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .update({
      'posicion': {'lat': posicion.lat, 'lng': posicion.lng},
      'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchAlertasActivas() {
    return _db
        .collection(AppConstants.colAlertasSeguridad)
        .where('estado', isEqualTo: EstadoAlerta.activa.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> atenderAlerta(
      String alertaId, String atendidaPor, String notas) async {
    await _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .update({
      'estado':        EstadoAlerta.atendida.name,
      'atendida_por':  atendidaPor,
      'notas':         notas,
      'fecha_atencion': fs.FieldValue.serverTimestamp(),
    });
  }
}
