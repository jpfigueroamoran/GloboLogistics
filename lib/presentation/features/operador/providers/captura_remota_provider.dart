import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

/// Emite la solicitud de captura remota pendiente para [operadorId].
/// Retorna null cuando no hay ninguna solicitud activa (estado ≠ 'pendiente').
final capturaRemotaSolicitudProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, operadorId) {
  return sl<FirestoreDatasource>()
      .watchSolicitudCapturaOperador(operadorId);
});
