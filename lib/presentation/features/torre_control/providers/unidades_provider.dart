import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../domain/entities/unidad.dart';
import '../../../../injection_container.dart';

final unidadesActivasProvider = StreamProvider<List<Unidad>>((ref) {
  return sl<FirestoreDatasource>().watchUnidades();
});
