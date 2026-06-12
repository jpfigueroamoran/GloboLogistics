import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

DocumentoVencimiento docFromSnapshot(dynamic doc) {
  final d = doc as fs.DocumentSnapshot;
  final data = d.data() as Map<String, dynamic>;
  final f = data['fecha_vencimiento'];
  return DocumentoVencimiento(
    id: d.id,
    entidadId: data['entidad_id'] as String? ?? '',
    nombreEntidad: data['nombre_entidad'] as String? ?? '',
    tipo: TipoDocumento.values.firstWhere(
      (e) => e.name == (data['tipo'] as String?),
      orElse: () => TipoDocumento.licenciaConducir,
    ),
    fechaVencimiento: f != null ? (f as fs.Timestamp).toDate() : DateTime.now(),
    esDocumentoDeUnidad: data['es_unidad'] as bool? ?? false,
    urlArchivo: data['url_archivo'] as String?,
  );
}

final documentosProvider = StreamProvider<List<DocumentoVencimiento>>((ref) {
  return sl<FirestoreDatasource>().watchDocumentos().map((list) =>
    list.map(docFromSnapshot).toList()
  );
});

final documentosVencidosCountProvider = Provider<int>((ref) {
  final ahora = DateTime.now();
  final docs = ref.watch(documentosProvider).valueOrNull ?? [];
  return docs
      .where((d) => d.semaforo(ahora) == SemaforoDocumento.vencido)
      .length;
});

final documentosProximosCountProvider = Provider<int>((ref) {
  final ahora = DateTime.now();
  final docs = ref.watch(documentosProvider).valueOrNull ?? [];
  return docs
      .where((d) => d.semaforo(ahora) == SemaforoDocumento.proximoVencer)
      .length;
});


