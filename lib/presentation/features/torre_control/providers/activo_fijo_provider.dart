import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/activo_fijo.dart';
import '../../../../domain/repositories/i_activo_fijo_repository.dart';
import '../../../../injection_container.dart';

final activosFijosProvider = StreamProvider<List<ActivoFijo>>((ref) {
  return sl<IActivoFijoRepository>().watchActivosFijos();
});

final valorFlotaProvider = Provider<double>((ref) {
  final activos = ref.watch(activosFijosProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return activos.fold(0.0, (sum, a) => sum + a.valorLibros(ahora));
});

final depreciacionMensualTotalProvider = Provider<double>((ref) {
  final activos = ref.watch(activosFijosProvider).valueOrNull ?? [];
  return activos.fold(0.0, (sum, a) => sum + a.depreciacionMensual);
});

final activosEnAlertaCountProvider = Provider<int>((ref) {
  final activos = ref.watch(activosFijosProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return activos.where((a) => a.porcentajeDepreciado(ahora) >= 0.8).length;
});
