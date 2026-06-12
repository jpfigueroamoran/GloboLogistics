import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

// Handler de mensajes en background — DEBE ser función top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En background solo loggeamos — la UI maneja la navegación cuando el usuario tapa
  debugPrint('[FCM] Mensaje en background: ${message.messageId}');
}

/// Centraliza toda la lógica de Firebase Cloud Messaging.
///
/// Uso:
///   await FcmService.init();           // en main.dart, después de Firebase.initializeApp
///   FcmService.saveToken();            // llamar cuando el usuario se autentica
///
/// Escucha mensajes en foreground via [foregroundMessages] stream.
class FcmService {
  FcmService._();

  static final _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream de mensajes recibidos con la app en primer plano.
  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  /// Mensaje de notificación que abrió la app desde estado cerrado/background.
  /// Consumir con [consumePendingMessage] para evitar procesar dos veces.
  static RemoteMessage? _pendingMessage;
  static RemoteMessage? consumePendingMessage() {
    final msg = _pendingMessage;
    _pendingMessage = null;
    return msg;
  }

  static Future<void> init() async {
    // FCM no tiene implementación nativa en Windows/Linux
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('[FCM] Push notifications skipped on this desktop platform.');
      return;
    }

    // ── Handler de background (top-level function) ────────────────────────
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    // ── Solicitar permisos (iOS / Web) ────────────────────────────────────
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // iOS — alertas críticas (SOS)
    );

    // ── Guardar token en cada inicio de sesión ────────────────────────────
    // authStateChanges emite el estado actual al suscribirse, así que esto
    // también cubre el caso de sesión ya activa al arrancar la app.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) saveToken();
    });

    // ── Escuchar renovaciones de token ────────────────────────────────────
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => saveToken());

    // ── Mensajes en foreground ────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      _foregroundController.add(message);
    });

    // ── App abierta desde notificación en background ───────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Abierto desde background: ${message.messageId}');
      _pendingMessage = message;
    });

    // ── App abierta desde estado cerrado (terminated) ─────────────────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] Initial message: ${initial.messageId}');
      _pendingMessage = initial;
    }
  }

  /// Guarda el token FCM en Firestore para el usuario autenticado.
  /// Llámalo también desde auth_provider cuando el usuario inicia sesión.
  static Future<void> saveToken() async {
    try {
      // Web push requiere una VAPID key configurada en Firebase Console.
      // Hasta que se configure, omitimos el token en web para evitar el error
      // "applicationServerKey is not valid" en PushManager.subscribe.
      // Tampoco hay soporte nativo en Windows/Linux.
      if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();

      if (token == null) return;

      await FirebaseFirestore.instance
          .collection(AppConstants.colUsuarios)
          .doc(user.uid)
          .update({
        'fcm_token':    token,
        'ultimo_acceso': FieldValue.serverTimestamp(),
      });

      debugPrint('[FCM] Token guardado para ${user.uid}');
    } catch (e) {
      // No es crítico — el usuario puede operar sin notificaciones push
      debugPrint('[FCM] No se pudo guardar token: $e');
    }
  }

  static void dispose() {
    _foregroundController.close();
  }
}
