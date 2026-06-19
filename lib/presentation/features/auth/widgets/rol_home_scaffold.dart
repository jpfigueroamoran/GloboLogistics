import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../demo/demo_providers.dart'
    show demoUserProvider, appModeProvider;
import '../providers/auth_provider.dart' show signOut, firebaseAuthProvider;

/// Scaffold base para las pantallas de rol simples (despachador, mantenimiento,
/// dirección). Encabezado consistente + cierre de sesión con confirmación,
/// respetando demo vs producción. Mantiene la estética unificada.
class RolHomeScaffold extends ConsumerWidget {
  final String titulo;
  final String subtitulo;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget> extraActions;

  const RolHomeScaffold({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.body,
    this.bottom,
    this.extraActions = const [],
  });

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    if (ref.read(appModeProvider)) {
      ref.read(demoUserProvider.notifier).state = null;
    } else {
      signOut(ref.read(firebaseAuthProvider));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GloboColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(titulo,
                style: GloboTypography.titleMedium
                    .copyWith(color: GloboColors.textOnDark),
                overflow: TextOverflow.ellipsis),
            Text(subtitulo,
                style: GloboTypography.labelSmall.copyWith(
                    color: GloboColors.textOnDarkSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          ...extraActions,
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context, ref),
          ),
        ],
        bottom: bottom,
      ),
      body: body,
    );
  }
}
