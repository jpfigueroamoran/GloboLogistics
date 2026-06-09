import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../../../../domain/entities/poliza_seguro.dart';
import '../../../../domain/repositories/i_poliza_seguro_repository.dart';
import '../../../../injection_container.dart';

final polizasProvider = StreamProvider<List<PolizaSeguro>>((ref) {
  return sl<IPolizaSeguroRepository>().watchPolizas();
});

final primaTotalMensualProvider = Provider<double>((ref) {
  final polizas = ref.watch(polizasProvider).valueOrNull ?? [];
  return polizas.fold(0.0, (sum, p) => sum + p.primaMensual);
});

final polizasAlertaCountProvider = Provider<int>((ref) {
  final polizas = ref.watch(polizasProvider).valueOrNull ?? [];
  final ahora = DateTime.now();
  return polizas
      .where((p) => p.semaforo(ahora) != SemaforoDocumento.vigente)
      .length;
});
