import 'package:dartz/dartz.dart';
import '../entities/cliente.dart';
import '../../core/errors/failures.dart';

abstract interface class IClienteRepository {
  Stream<List<Cliente>> watchClientes();
  Future<Either<Failure, List<Cliente>>> buscarClientes(String query);
  Future<Either<Failure, String>> crearCliente(Map<String, dynamic> data);
  Future<Either<Failure, void>> actualizarCliente(String id, Map<String, dynamic> data);
}
