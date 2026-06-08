import 'package:dartz/dartz.dart';
import '../entities/cliente.dart';
import '../../core/errors/failures.dart';

abstract interface class IClienteRepository {
  Stream<List<Cliente>> watchClientes();
  Future<Either<Failure, List<Cliente>>> buscarClientes(String query);
}
