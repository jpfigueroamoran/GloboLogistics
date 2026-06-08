import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/usuario_globo_model.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../firebase_options.dart';

// ── Stream de todos los usuarios ──────────────────────────────────────────────

final usuariosStreamProvider = StreamProvider<List<UsuarioGlobo>>((ref) {
  return FirebaseFirestore.instance
      .collection('usuarios')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => UsuarioGloboModel.fromFirestore(d))
          .toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre)));
});

// ── Estado del formulario ─────────────────────────────────────────────────────

class UsuarioFormState {
  final bool loading;
  final String? error;
  final bool success;

  const UsuarioFormState({
    this.loading = false,
    this.error,
    this.success = false,
  });

  UsuarioFormState copyWith({bool? loading, String? error, bool? success}) =>
      UsuarioFormState(
        loading: loading ?? this.loading,
        error: error,
        success: success ?? this.success,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class UsuariosNotifier extends StateNotifier<UsuarioFormState> {
  UsuariosNotifier() : super(const UsuarioFormState());

  /// Crea usuario usando una segunda instancia de FirebaseApp para no
  /// cerrar la sesión del admin. Luego escribe el documento en Firestore.
  Future<bool> crearUsuario({
    required String email,
    required String password,
    required String nombre,
    required RolUsuario rol,
  }) async {
    state = state.copyWith(loading: true, error: null, success: false);

    FirebaseApp? secondaryApp;
    try {
      // Inicializar app secundaria con nombre único por timestamp
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Crear cuenta en la app secundaria — no afecta la sesión del admin
      final credential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Cerrar sesión de la app secundaria y eliminarla
      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
      await secondaryApp.delete();
      secondaryApp = null;

      // Escribir documento en Firestore (admin tiene permiso de create)
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'email':         email,
        'nombre':        nombre,
        'rol':           rol.name,
        'activo':        true,
        'ultimo_acceso': null,
      });

      state = state.copyWith(loading: false, success: true);
      return true;

    } on FirebaseAuthException catch (e) {
      await secondaryApp?.delete();
      final msg = _mensajeAuth(e.code);
      state = state.copyWith(loading: false, error: msg);
      return false;
    } catch (e) {
      await secondaryApp?.delete();
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// Actualiza rol directamente en Firestore — admin tiene permiso.
  Future<bool> actualizarRol(String uid, RolUsuario nuevoRol) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .update({'rol': nuevoRol.name});
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Activa o desactiva un usuario en Firestore.
  Future<bool> toggleActivo(String uid, bool nuevoEstado) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .update({'activo': nuevoEstado});
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void resetForm() => state = const UsuarioFormState();

  String _mensajeAuth(String code) => switch (code) {
        'email-already-in-use' => 'Este correo ya tiene una cuenta registrada.',
        'invalid-email'        => 'El correo no tiene un formato válido.',
        'weak-password'        => 'La contraseña debe tener al menos 6 caracteres.',
        'operation-not-allowed' => 'Registro de usuarios deshabilitado en Firebase.',
        _ => 'Error al crear usuario ($code).',
      };
}

final usuariosNotifierProvider =
    StateNotifierProvider<UsuariosNotifier, UsuarioFormState>(
  (_) => UsuariosNotifier(),
);
