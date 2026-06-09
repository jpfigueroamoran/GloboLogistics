import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/item_inventario.dart';
import '../../domain/entities/movimiento_inventario.dart';
import '../../domain/repositories/i_inventario_repository.dart';
import '../datasources/remote/inventario_firestore_datasource.dart';

class InventarioRepositoryImpl implements IInventarioRepository {
  final InventarioFirestoreDatasource _ds;
  InventarioRepositoryImpl(this._ds);

  @override
  Stream<List<ItemInventario>> watchItems() => _ds.watchItems();

  @override
  Future<Either<Failure, Unit>> actualizarStock(
      String itemId, double nuevoStock) async {
    try {
      await _ds.actualizarStock(itemId, nuevoStock);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> registrarMovimiento(
      MovimientoInventario movimiento) async {
    try {
      final id = await _ds.registrarMovimiento(movimiento);
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
