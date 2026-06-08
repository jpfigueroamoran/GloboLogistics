import 'package:dartz/dartz.dart';
import '../../repositories/i_actividad_repository.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/connectivity_service.dart';

class SyncActividadesUsecase {
  final IActividadRepository _repository;
  final ConnectivityService _connectivity;

  const SyncActividadesUsecase(this._repository, this._connectivity);

  Future<Either<Failure, int>> call() async {
    if (!_connectivity.isOnline) {
      return const Left(NetworkFailure());
    }
    final pendientes = await _repository.getActividadesPendientes();
    if (pendientes.isEmpty) return const Right(0);

    final result = await _repository.sincronizarPendientes();
    return result.fold(
      Left.new,
      (_) => Right(pendientes.length),
    );
  }
}
