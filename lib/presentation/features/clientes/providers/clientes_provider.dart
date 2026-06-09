import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';

final clientesStreamProvider = StreamProvider<List<Cliente>>((ref) {
  return GetIt.instance<IClienteRepository>().watchClientes();
});

final clientesBusquedaProvider =
    FutureProvider.family<List<Cliente>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return ref.watch(clientesStreamProvider).valueOrNull ?? [];
  }
  final result = await GetIt.instance<IClienteRepository>().buscarClientes(query);
  return result.fold((_) => [], (list) => list);
});
