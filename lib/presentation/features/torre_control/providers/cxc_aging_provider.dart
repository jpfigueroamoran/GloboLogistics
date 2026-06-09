import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/factura_cliente.dart';
import 'factura_cliente_provider.dart';

final cxcAgingProvider = Provider<Map<BucketAging, double>>((ref) {
  final cxc   = ref.watch(cxcProvider);
  final ahora = DateTime.now();
  return {
    for (final b in BucketAging.values)
      b: cxc.fold(0.0, (s, c) => s + c.montoEnBucket(b, ahora)),
  };
});
