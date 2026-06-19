import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/viaje_model.dart';
import '../../models/actividad_operativa_model.dart';
import '../../models/unidad_model.dart';
import '../../../domain/entities/viaje.dart';
import '../../../domain/entities/alerta_seguridad.dart';
import '../../../domain/entities/solicitud_transporte.dart';

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

  /// Todas las unidades sin filtrar por estado — para gestión de flota
  /// (incluye mantenimiento y bajas, que watchUnidades oculta).
  Stream<List<UnidadModel>> watchTodasUnidades() {
    return _db
        .collection(AppConstants.colUnidades)
        .snapshots()
        .map((snap) =>
            snap.docs.map(UnidadModel.fromFirestore).toList()
              ..sort((a, b) => a.placas.compareTo(b.placas)));
  }

  Future<String> crearUnidad(Map<String, dynamic> data) async {
    final ref = _db.collection(AppConstants.colUnidades).doc();
    await ref.set({
      ...data,
      'created_at': fs.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> actualizarUnidad(
      String unidadId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colUnidades).doc(unidadId).update({
      ...data,
      'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
    });
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

  /// Asocia el dispositivo del operador a la unidad que acaba de escanear:
  /// libera la unidad previa (si cambió), reclama la nueva a su nombre y
  /// actualiza su perfil. Cada escritura está permitida por las reglas para
  /// el propio operador. Si los operadores rotan de vehículo, esto mantiene
  /// `operador_asignado_id` correcto (de lo que depende el rastreo GPS).
  Future<void> asociarVehiculoOperador({
    required String operadorUid,
    required String unidadId,
    String? unidadPrevia,
  }) async {
    if (unidadPrevia != null &&
        unidadPrevia.isNotEmpty &&
        unidadPrevia != unidadId) {
      await _db.collection(AppConstants.colUnidades).doc(unidadPrevia).update({
        'operador_asignado_id': null,
      });
    }
    await _db.collection(AppConstants.colUnidades).doc(unidadId).update({
      'operador_asignado_id': operadorUid,
    });
    await _db.collection(AppConstants.colUsuarios).doc(operadorUid).update({
      'unidad_asignada_id': unidadId,
    });
  }

  // ── Solicitudes de transporte (intake interno) ───────────────────────────

  SolicitudTransporte _solicitudFromDoc(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SolicitudTransporte(
      id:                doc.id,
      solicitanteUid:    d['solicitante_uid'] as String? ?? '',
      solicitanteNombre: d['solicitante_nombre'] as String? ?? '',
      material:          d['material'] as String? ?? '',
      origen:            d['origen'] as String? ?? '',
      destino:           d['destino'] as String? ?? '',
      prioridad:
          PrioridadSolicitudExt.fromName(d['prioridad'] as String?),
      notas:             d['notas'] as String?,
      estado:            EstadoSolicitudExt.fromName(d['estado'] as String?),
      viajeId:           d['viaje_id'] as String?,
      motivoRechazo:     d['motivo_rechazo'] as String?,
      createdAt:
          (d['created_at'] as fs.Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<String> crearSolicitudTransporte(Map<String, dynamic> data) async {
    final ref = _db.collection(AppConstants.colSolicitudes).doc();
    await ref.set({
      ...data,
      'estado':     EstadoSolicitud.pendiente.name,
      'created_at': fs.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Solicitudes de un solicitante (su bandeja "Mis solicitudes").
  Stream<List<SolicitudTransporte>> watchSolicitudesPorSolicitante(
      String solicitanteUid) {
    return _db
        .collection(AppConstants.colSolicitudes)
        .where('solicitante_uid', isEqualTo: solicitanteUid)
        .snapshots()
        .map((snap) => snap.docs.map(_solicitudFromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Cola del despachador: todas las solicitudes (ordena en memoria).
  Stream<List<SolicitudTransporte>> watchSolicitudes() {
    return _db
        .collection(AppConstants.colSolicitudes)
        .snapshots()
        .map((snap) => snap.docs.map(_solicitudFromDoc).toList());
  }

  Future<void> actualizarEstadoSolicitud(
    String solicitudId,
    EstadoSolicitud estado, {
    String? viajeId,
    String? motivoRechazo,
  }) async {
    await _db.collection(AppConstants.colSolicitudes).doc(solicitudId).update({
      'estado': estado.name,
      if (viajeId != null) 'viaje_id': viajeId,
      if (motivoRechazo != null) 'motivo_rechazo': motivoRechazo,
      'updated_at': fs.FieldValue.serverTimestamp(),
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

  // ── Configuración de empresa (onboarding) ─────────────────────────────────

  /// Emite la configuración de la empresa; null mientras no exista el doc
  /// (la app no se ha configurado todavía).
  Stream<Map<String, dynamic>?> watchEmpresaConfig() {
    return _db
        .collection(AppConstants.colConfig)
        .doc(AppConstants.docEmpresa)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<void> guardarEmpresaConfig(Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colConfig)
        .doc(AppConstants.docEmpresa)
        .set({
      ...data,
      'actualizado_at': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  Future<void> guardarPricing(Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colConfig)
        .doc(AppConstants.docPricing)
        .set({
      ...data,
      'actualizado_at': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
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

  /// Publica el seguimiento en vivo del operador. NO toca `updated_at` para no
  /// disparar al motor de automatización con cada ping de posición.
  Future<void> setSeguimientoViaje(
      String viajeId, Map<String, dynamic> seguimiento) async {
    await _db
        .collection(AppConstants.colViajes)
        .doc(viajeId)
        .update({
      'seguimiento': {
        ...seguimiento,
        'actualizado_en': fs.FieldValue.serverTimestamp(),
      },
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

  /// El operador cancela su propio SOS — queda registrado como falsa alarma.
  /// Las reglas de Firestore solo permiten al dueño esta transición de estado.
  Future<void> cancelarAlertaSOS(String alertaId) async {
    await _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .update({
      'estado': EstadoAlerta.falsaAlarma.name,
      'notas':  'Cancelada por el operador desde la app.',
    });
  }

  // ── Captura remota de evidencia (activada por supervisor) ────────────────

  Future<void> solicitarCapturaRemota(String alertaId, String tipo) async {
    await _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .update({
      'captura_remota': {
        'tipo':   tipo,         // 'audio' | 'camara'
        'estado': 'pendiente',
        'ts':     fs.FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> completarCapturaRemota(String alertaId) async {
    await _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .update({'captura_remota.estado': 'completada'});
  }

  /// Emite la solicitud pendiente de captura para un operador.
  /// Retorna null cuando no hay ninguna solicitud activa.
  Stream<Map<String, dynamic>?> watchSolicitudCapturaOperador(
      String operadorId) {
    return _db
        .collection(AppConstants.colAlertasSeguridad)
        .where('operador_id', isEqualTo: operadorId)
        .where('estado', isEqualTo: EstadoAlerta.activa.name)
        .snapshots()
        .map((snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final captura =
            data['captura_remota'] as Map<String, dynamic>?;
        if (captura?['estado'] == 'pendiente') {
          return {'alertaId': doc.id, ...captura!};
        }
      }
      return null;
    });
  }

  /// Plan gratuito sin Firebase Storage: la evidencia viaja comprimida en
  /// base64 dentro de una subcolección (1 doc por archivo, máx ~1 MiB), y el
  /// array `evidencias` del padre solo guarda metadatos ligeros para el
  /// contador del panel de alertas.
  Future<void> agregarEvidenciaSOS({
    required String alertaId,
    required String tipo, // 'foto' | 'audio'
    required String datosB64,
  }) async {
    final alertaRef =
        _db.collection(AppConstants.colAlertasSeguridad).doc(alertaId);
    final evidenciaRef = alertaRef.collection('evidencias').doc();
    final ts = DateTime.now().millisecondsSinceEpoch;

    await evidenciaRef.set({
      'tipo':  tipo,
      'datos': datosB64,
      'ts':    ts,
    });
    await alertaRef.update({
      'evidencias': fs.FieldValue.arrayUnion([
        {'id': evidenciaRef.id, 'tipo': tipo, 'ts': ts}
      ]),
    });
  }

  Stream<List<Map<String, dynamic>>> watchEvidenciasSOS(String alertaId) {
    return _db
        .collection(AppConstants.colAlertasSeguridad)
        .doc(alertaId)
        .collection('evidencias')
        .orderBy('ts')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Costos Operativos ────────────────────────────────────────────────────

  Future<String> crearCostoOperativo(Map<String, dynamic> data) async {
    final ref = _db.collection(AppConstants.colCostosOperativos).doc();
    await ref.set(data);
    return ref.id;
  }
}
