import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/item_inventario.dart';
import '../entities/movimiento_inventario.dart';

abstract class IInventarioRepository {
  Stream<List<ItemInventario>> watchItems();
  Future<Either<Failure, Unit>> actualizarStock(
      String itemId, double nuevoStock);
  Future<Either<Failure, String>> registrarMovimiento(
      MovimientoInventario movimiento);
}
