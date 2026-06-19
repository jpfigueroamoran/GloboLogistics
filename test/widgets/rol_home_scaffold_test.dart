import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:globo_logistics/presentation/features/auth/widgets/rol_home_scaffold.dart';

/// Smoke test del scaffold base que comparten los dashboards de Despachador,
/// Mantenimiento y Dirección: confirma que se construye en runtime (encabezado,
/// subtítulo, cuerpo y acción de logout) sin lanzar excepciones de layout.
void main() {
  testWidgets('RolHomeScaffold renderiza encabezado, cuerpo y logout',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RolHomeScaffold(
            titulo: 'Centro de Despacho',
            subtitulo: 'Solicitudes → viajes → entregas',
            body: Center(child: Text('cuerpo de prueba')),
          ),
        ),
      ),
    );

    expect(find.text('Centro de Despacho'), findsOneWidget);
    expect(find.text('Solicitudes → viajes → entregas'), findsOneWidget);
    expect(find.text('cuerpo de prueba'), findsOneWidget);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('RolHomeScaffold soporta acciones extra y pestañas (bottom)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: RolHomeScaffold(
              titulo: 'Dirección',
              subtitulo: 'Solo lectura',
              extraActions: const [Icon(Icons.help_outline)],
              bottom: const TabBar(
                tabs: [Tab(text: 'Resumen'), Tab(text: 'Reportes')],
              ),
              body: const Center(child: Text('kpis')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });
}
