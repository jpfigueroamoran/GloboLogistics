import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/item_inventario.dart';
import '../../../../domain/repositories/i_inventario_repository.dart';
import '../../../../injection_container.dart';

final inventarioProvider = StreamProvider<List<ItemInventario>>((ref) {
  return sl<IInventarioRepository>().watchItems();
});

final itemsBajoStockProvider = Provider<List<ItemInventario>>((ref) {
  final items = ref.watch(inventarioProvider).valueOrNull ?? [];
  return items.where((i) => i.esBajoStock).toList()
    ..sort((a, b) => a.pctStock.compareTo(b.pctStock));
});

final itemsBajoStockCountProvider = Provider<int>((ref) {
  return ref.watch(itemsBajoStockProvider).length;
});

final valorTotalInventarioProvider = Provider<double>((ref) {
  final items = ref.watch(inventarioProvider).valueOrNull ?? [];
  return items.fold(0.0, (s, i) => s + i.valorTotal);
});

final actualizarStockProvider = Provider<
    Future<Either<Failure, Unit>> Function(String, double)>((ref) {
  return sl<IInventarioRepository>().actualizarStock;
});
