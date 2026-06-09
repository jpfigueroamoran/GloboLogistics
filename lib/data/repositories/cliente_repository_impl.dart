import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/repositories/i_cliente_repository.dart';
import '../datasources/remote/cliente_firestore_datasource.dart';

class ClienteRepositoryImpl implements IClienteRepository {
  final ClienteFirestoreDatasource _ds;
  ClienteRepositoryImpl(this._ds);

  @override
  Stream<List<Cliente>> watchClientes() => _ds.watchClientes();

  @override
  Future<Either<Failure, List<Cliente>>> buscarClientes(String query) async {
    try {
      return Right(await _ds.buscarClientes(query));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> crearCliente(Map<String, dynamic> data) async {
    try {
      final id = await _ds.crearCliente(data);
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> actualizarCliente(String id, Map<String, dynamic> data) async {
    try {
      await _ds.actualizarCliente(id, data);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
