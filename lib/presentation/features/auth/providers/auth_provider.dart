import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../data/models/usuario_globo_model.dart';

// ── Firebase Auth state ───────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ── Perfil de usuario (rol desde Firestore) ───────────────────────────────────

/// Estado combinado: autenticación + rol Firestore.
enum AuthStatus {
  /// Determinando estado inicial
  loading,

  /// Sin sesión
  unauthenticated,

  /// Autenticado, cargando perfil desde Firestore
  loadingProfile,

  /// Operador autenticado — debe ir a /operador
  operador,

  /// Supervisor o Administrador — debe ir a /torre-control
  torreControl,

  /// Autenticado pero sin perfil en Firestore (cuenta no configurada)
  sinPerfil,

  /// Cuenta desactivada por administrador
  desactivado,

  /// Error inesperado
  error,
}

class AuthState {
  final AuthStatus status;
  final UsuarioGlobo? usuario;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.usuario,
    this.errorMessage,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated()
      : this(status: AuthStatus.unauthenticated);
}

final userProfileProvider =
    StreamProvider<UsuarioGlobo?>((ref) {
  final authAsync = ref.watch(authUserProvider);

  return authAsync.when(
    loading: () => const Stream.empty(),
    error: (_, __) => Stream.value(null),
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection(AppConstants.colUsuarios)
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return UsuarioGloboModel.fromFirestore(doc);
      });
    },
  );
});

/// Estado calculado — es la fuente de verdad que usa AuthLandingPage.
final authStatusProvider = Provider<AuthState>((ref) {
  final authAsync    = ref.watch(authUserProvider);
  final profileAsync = ref.watch(userProfileProvider);

  // Todavía determinando si hay sesión activa
  if (authAsync.isLoading) return const AuthState.loading();
  if (authAsync.hasError) {
    return AuthState(
        status: AuthStatus.error,
        errorMessage: authAsync.error.toString());
  }

  final user = authAsync.valueOrNull;

  // Sin sesión → mostrar login
  if (user == null) return const AuthState.unauthenticated();

  // Sesión activa pero perfil cargando
  if (profileAsync.isLoading) {
    return const AuthState(status: AuthStatus.loadingProfile);
  }

  final perfil = profileAsync.valueOrNull;

  // Sin documento en Firestore (nunca fue configurado)
  if (perfil == null) {
    return const AuthState(status: AuthStatus.sinPerfil);
  }

  // Cuenta desactivada
  if (!perfil.activo) {
    return const AuthState(status: AuthStatus.desactivado);
  }

  // Rol determina módulo
  if (perfil.esOperador) {
    return AuthState(status: AuthStatus.operador, usuario: perfil);
  }
  return AuthState(status: AuthStatus.torreControl, usuario: perfil);
});

// ── Sign out ──────────────────────────────────────────────────────────────────

Future<void> signOut(FirebaseAuth auth) => auth.signOut();
