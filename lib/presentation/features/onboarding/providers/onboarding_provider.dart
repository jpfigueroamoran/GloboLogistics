import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

/// Configuración de la empresa. `null` = la app aún no se ha configurado,
/// lo que dispara el wizard de onboarding para el administrador.
final empresaConfigProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  return sl<FirestoreDatasource>().watchEmpresaConfig();
});

/// true cuando hay que mostrar el wizard: config cargada y sin marcar como
/// `configurado`. Mientras carga devuelve null (no decidir todavía).
final necesitaOnboardingProvider = Provider<bool?>((ref) {
  final config = ref.watch(empresaConfigProvider);
  return config.when(
    loading: () => null,
    error: (_, __) => false, // ante error, no bloquear el acceso
    data: (data) => data == null || data['configurado'] != true,
  );
});
