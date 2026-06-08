import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

final documentosProvider = StreamProvider<List<DocumentoVencimiento>>((ref) {
  return sl<FirestoreDatasource>().watchDocumentos().map((list) => 
    list.map((d) => DocumentoVencimiento.fromFirestore(d)).toList()
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


