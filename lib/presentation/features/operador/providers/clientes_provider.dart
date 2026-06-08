import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';
import '../../../../injection_container.dart';

final clientesStreamProvider = StreamProvider<List<Cliente>>((ref) {
  return sl<IClienteRepository>().watchClientes();
});

class ClientesBusquedaNotifier extends StateNotifier<List<Cliente>> {
  final IClienteRepository _repo;
  ClientesBusquedaNotifier(this._repo) : super([]);

  Future<void> buscar(String query) async {
    if (query.trim().isEmpty) {
      state = [];
      return;
    }
    final result = await _repo.buscarClientes(query);
    result.fold((_) => null, (clientes) => state = clientes);
  }

  void limpiar() => state = [];
}

final clientesBusquedaProvider =
    StateNotifierProvider<ClientesBusquedaNotifier, List<Cliente>>(
  (ref) => ClientesBusquedaNotifier(sl<IClienteRepository>()),
);
