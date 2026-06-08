import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/services/fcm_service.dart';
import 'router.dart';
import 'sos_overlay.dart';

// Provider que expone el stream de mensajes FCM en foreground
final fcmForegroundProvider = StreamProvider<RemoteMessage?>((ref) {
  return FcmService.foregroundMessages.map((m) => m);
});

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class GloboApp extends ConsumerWidget {
  const GloboApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen<AsyncValue<RemoteMessage?>>(fcmForegroundProvider, (_, next) {
      next.whenData((message) {
        if (message == null) return;
        if (message.data['tipo'] == 'sos') {
          _showSosOverlay(message);
        } else {
          _showFcmBanner(message);
        }
      });
    });

    return MaterialApp.router(
      title:                      'Globo Logistics',
      debugShowCheckedModeBanner: false,
      theme:                      GloboTheme.light,
      darkTheme:                  GloboTheme.dark,
      themeMode:                  themeMode,
      scaffoldMessengerKey:       _scaffoldMessengerKey,
      routerConfig:               router,
    );
  }

  void _showSosOverlay(RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    SosOverlay.show(
      context,
      titulo:     message.notification?.title ?? '🚨 PROTOCOLO SOS ACTIVADO',
      cuerpo:     message.notification?.body  ?? '',
      operadorId: message.data['operador_id'] ?? '—',
      unidadId:   message.data['unidad_id']   ?? '—',
    );
  }

  void _showFcmBanner(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _scaffoldMessengerKey.currentState
      ?..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: GloboColors.primary,
          leading: const Icon(
            Icons.notifications_active,
            color: Colors.white,
            size: 24,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notification.title ?? 'Globo Logistics',
                style: GloboTypography.labelLarge
                    .copyWith(color: Colors.white),
              ),
              if (notification.body != null)
                Text(
                  notification.body!,
                  style: GloboTypography.caption
                      .copyWith(color: Colors.white70),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _scaffoldMessengerKey.currentState
                  ?.hideCurrentMaterialBanner(),
              child: Text(
                'CERRAR',
                style: TextStyle(color: GloboColors.accentGlow),
              ),
            ),
          ],
        ),
      );

    Future.delayed(const Duration(seconds: 6), () {
      _scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    });
  }
}
