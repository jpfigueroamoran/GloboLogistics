import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../domain/entities/solicitud_transporte.dart';
import '../../../../injection_container.dart';

/// Bandeja del solicitante: sus propias solicitudes con estado en vivo.
final misSolicitudesProvider =
    StreamProvider.family<List<SolicitudTransporte>, String>(
  (ref, solicitanteUid) =>
      sl<FirestoreDatasource>().watchSolicitudesPorSolicitante(solicitanteUid),
);

/// Cola del despachador: todas las solicitudes, ordenadas (pendientes primero,
/// luego por prioridad y antigüedad).
final colaSolicitudesProvider =
    StreamProvider<List<SolicitudTransporte>>((ref) {
  return sl<FirestoreDatasource>().watchSolicitudes().map((lista) {
    final ordenadas = [...lista];
    ordenadas.sort((a, b) {
      // Activas antes que cerradas
      final aCerrada = a.esActiva ? 0 : 1;
      final bCerrada = b.esActiva ? 0 : 1;
      if (aCerrada != bCerrada) return aCerrada.compareTo(bCerrada);
      // Pendientes antes que asignadas/en ruta
      final aPend = a.estado == EstadoSolicitud.pendiente ? 0 : 1;
      final bPend = b.estado == EstadoSolicitud.pendiente ? 0 : 1;
      if (aPend != bPend) return aPend.compareTo(bPend);
      // Por prioridad (urgente primero)
      final pri = b.prioridad.peso.compareTo(a.prioridad.peso);
      if (pri != 0) return pri;
      // Por antigüedad (más vieja primero)
      return a.createdAt.compareTo(b.createdAt);
    });
    return ordenadas;
  });
});

/// Cuántas solicitudes pendientes hay (badge del despachador).
final solicitudesPendientesCountProvider = Provider<int>((ref) {
  final lista = ref.watch(colaSolicitudesProvider).valueOrNull ?? [];
  return lista.where((s) => s.estado == EstadoSolicitud.pendiente).length;
});
