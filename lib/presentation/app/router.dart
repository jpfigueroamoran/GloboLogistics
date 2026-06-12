import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/pages/auth_landing_page.dart';
import '../features/clientes/pages/alta_cliente_page.dart';
import '../features/onboarding/pages/onboarding_wizard_page.dart';
import '../features/operador/pages/iniciar_viaje_page.dart';
import '../features/operador/pages/operador_home_page.dart';
import '../features/operador/pages/sos_page.dart';
import '../features/torre_control/pages/dashboard_page.dart';
import '../features/torre_control/pages/auditoria_page.dart';

/// Clave global del Navigator raíz — usada para mostrar diálogos SOS
/// desde fuera del árbol de widgets (e.g., desde el listener de FCM).
final rootNavigatorKey = GlobalKey<NavigatorState>();

// Rutas nombradas
abstract final class AppRoutes {
  static const auth          = '/';
  static const onboarding    = '/configuracion-inicial';
  static const dashboard     = '/torre-control';
  static const auditoria     = '/torre-control/auditoria';
  static const operador      = '/operador';
  static const sos           = '/operador/sos';
  static const iniciarViaje  = '/operador/iniciar-viaje';
  static const altaCliente   = AltaClientePage.routeName;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.auth,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, __) => const AuthLandingPage(),
      ),

      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingWizardPage(),
      ),

      // Clientes
      GoRoute(
        path: AppRoutes.altaCliente,
        builder: (_, __) => const AltaClientePage(),
      ),

      // Torre de Control (Web / Windows)
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const DashboardPage(),
        routes: [
          GoRoute(
            path: 'auditoria',
            builder: (_, __) => const AuditoriaPage(),
          ),
        ],
      ),

      // Módulo Operador (Mobile)
      GoRoute(
        path: AppRoutes.operador,
        builder: (ctx, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return OperadorHomePage(
            operadorId:     extra['operadorId'] ?? '',
            unidadId:       extra['unidadId']   ?? '',
            nombreOperador: extra['nombreOperador'],
          );
        },
        routes: [
          GoRoute(
            path: 'sos',
            builder: (ctx, state) {
              final extra = state.extra as Map<String, String>? ?? {};
              return SosPage(
                operadorId: extra['operadorId'] ?? '',
                unidadId:   extra['unidadId']   ?? '',
                viajeId:    extra['viajeId']    ?? '',
              );
            },
          ),
          GoRoute(
            path: 'iniciar-viaje',
            builder: (ctx, state) {
              final extra = state.extra as Map<String, String>? ?? {};
              return IniciarViajePage(
                operadorId: extra['operadorId'] ?? '',
                unidadId:   extra['unidadId']   ?? '',
              );
            },
          ),
        ],
      ),
    ],
  );
});
