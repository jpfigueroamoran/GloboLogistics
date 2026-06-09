import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/entities/cliente.dart';
import '../pages/alta_cliente_page.dart';
import '../providers/clientes_provider.dart';

/// Botón/campo que muestra el cliente seleccionado y al tocar abre
/// un bottom sheet de búsqueda con opción de registrar uno nuevo.
class ClienteSelectorWidget extends ConsumerStatefulWidget {
  final Cliente? initial;
  final void Function(Cliente) onSelected;
  final String label;

  const ClienteSelectorWidget({
    super.key,
    this.initial,
    required this.onSelected,
    this.label = 'Cliente',
  });

  @override
  ConsumerState<ClienteSelectorWidget> createState() =>
      _ClienteSelectorWidgetState();
}

class _ClienteSelectorWidgetState
    extends ConsumerState<ClienteSelectorWidget> {
  Cliente? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  void _abrirSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ClienteSelectorSheet(
        onSelected: (c) {
          setState(() => _selected = c);
          widget.onSelected(c);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _abrirSelector,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _selected?.nombre ?? 'Seleccionar cliente...',
          style: _selected == null
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor)
              : theme.textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ClienteSelectorSheet extends ConsumerStatefulWidget {
  final void Function(Cliente) onSelected;

  const _ClienteSelectorSheet({required this.onSelected});

  @override
  ConsumerState<_ClienteSelectorSheet> createState() =>
      _ClienteSelectorSheetState();
}

class _ClienteSelectorSheetState
    extends ConsumerState<_ClienteSelectorSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesSP = ref.watch(clientesStreamProvider);

    final allClientes = clientesSP.valueOrNull ?? [];
    final filtered = _query.isEmpty
        ? allClientes
        : allClientes
            .where((c) =>
                c.nombre.toLowerCase().contains(_query.toLowerCase()) ||
                c.direccion.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: clientesSP.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No hay clientes registrados'
                            : 'Sin resultados para "$_query"',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.business, size: 18),
                          ),
                          title: Text(c.nombre),
                          subtitle: Text(
                            c.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: c.telefono != null
                              ? Text(
                                  c.telefono!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                )
                              : null,
                          onTap: () => widget.onSelected(c),
                        );
                      },
                    ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_business_outlined),
            title: const Text('Registrar nuevo cliente'),
            onTap: () async {
              Navigator.pop(context);
              await context.push(AltaClientePage.routeName);
            },
          ),
        ],
      ),
    );
  }
}
