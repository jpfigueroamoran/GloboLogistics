import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../app/router.dart';
import '../providers/auth_provider.dart';

class AuthLandingPage extends ConsumerWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);

    switch (auth.status) {
      // ── Cargando sesión / perfil ────────────────────────────────────────
      case AuthStatus.loading:
      case AuthStatus.loadingProfile:
        return const _SplashScreen();

      // ── Sin sesión → mostrar login ──────────────────────────────────────
      case AuthStatus.unauthenticated:
        return const _LoginScreen();

      // ── Sesión activa — redirección según rol ───────────────────────────
      case AuthStatus.operador:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutes.operador, extra: {
            'operadorId':     auth.usuario!.uid,
            'unidadId':       auth.usuario!.unidadAsignadaId ?? '',
            'nombreOperador': auth.usuario!.nombre,
          });
        });
        return const _SplashScreen();

      case AuthStatus.torreControl:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutes.dashboard);
        });
        return const _SplashScreen();

      // ── Errores / estados especiales ────────────────────────────────────
      case AuthStatus.sinPerfil:
        return _StatusScreen(
          icon: Icons.person_off_outlined,
          title: 'Cuenta sin configurar',
          message:
              'Tu cuenta existe pero no está asociada a un perfil.\n'
              'Contacta al administrador de Globo Logistics.',
          onLogout: () =>
              signOut(ref.read(firebaseAuthProvider)),
        );

      case AuthStatus.desactivado:
        return _StatusScreen(
          icon: Icons.block,
          title: 'Cuenta desactivada',
          message:
              'Tu acceso ha sido suspendido.\n'
              'Comunícate con el administrador.',
          onLogout: () =>
              signOut(ref.read(firebaseAuthProvider)),
        );

      case AuthStatus.error:
        return _StatusScreen(
          icon: Icons.error_outline,
          title: 'Error de autenticación',
          message: auth.errorMessage ?? 'Error desconocido.',
          onLogout: () =>
              signOut(ref.read(firebaseAuthProvider)),
        );
    }
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GloboColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GloboLogo(size: 80),
            const SizedBox(height: GloboSpacing.lg),
            const CircularProgressIndicator(
                color: GloboColors.accentGlow),
          ],
        ),
      ),
    );
  }
}

// ── Login ─────────────────────────────────────────────────────────────────────

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool   _loading = false;
  String? _error;
  bool   _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: GloboColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GloboSpacing.xl),
          child: Container(
            width: isWide ? 420 : double.infinity,
            padding: const EdgeInsets.all(GloboSpacing.xl),
            decoration: BoxDecoration(
              color: GloboColors.surface,
              borderRadius: GloboRadius.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _GloboLogo(size: 56)),
                const SizedBox(height: GloboSpacing.md),

                Center(
                  child: Text(
                    'GLOBO LOGISTICS',
                    style: GloboTypography.labelSmall.copyWith(
                      letterSpacing: 3,
                      color: GloboColors.textTertiary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Acceso Seguro',
                    style: GloboTypography.headlineMedium,
                  ),
                ),

                const SizedBox(height: GloboSpacing.xl),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon:
                        Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: GloboSpacing.md),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon:
                        const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onFieldSubmitted: (_) => _login(),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: GloboSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(GloboSpacing.sm),
                    decoration: BoxDecoration(
                      color: GloboColors.errorLight,
                      borderRadius: GloboRadius.buttonRadius,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: GloboColors.error),
                        const SizedBox(width: GloboSpacing.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GloboTypography.bodyMedium
                                .copyWith(color: GloboColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: GloboSpacing.xl),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Iniciar Sesión'),
                  ),
                ),

                const SizedBox(height: GloboSpacing.md),

                // Indicador de rol esperado
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 13,
                          color: GloboColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        'El acceso se determina por tu rol asignado',
                        style: GloboTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // authStatusProvider reacciona automáticamente y redirige
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mensajeError(String code) => switch (code) {
        'user-not-found'    => 'Usuario no encontrado.',
        'wrong-password'    => 'Contraseña incorrecta.',
        'invalid-credential'=> 'Credenciales inválidas.',
        'invalid-email'     => 'Correo no válido.',
        'user-disabled'     => 'Cuenta deshabilitada.',
        'too-many-requests' =>
            'Demasiados intentos. Espera un momento.',
        _                   => 'Error de autenticación.',
      };

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}

// ── Status screen (sin perfil / desactivado / error) ─────────────────────────

class _StatusScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onLogout;

  const _StatusScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GloboColors.primary,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(GloboSpacing.xl),
          margin: const EdgeInsets.all(GloboSpacing.xl),
          decoration: BoxDecoration(
            color: GloboColors.surface,
            borderRadius: GloboRadius.cardRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: GloboColors.steelGray),
              const SizedBox(height: GloboSpacing.md),
              Text(title, style: GloboTypography.headlineMedium),
              const SizedBox(height: GloboSpacing.sm),
              Text(
                message,
                style: GloboTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GloboSpacing.xl),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _GloboLogo extends StatelessWidget {
  final double size;
  const _GloboLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GloboColors.primary,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          'GL',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            letterSpacing: size * 0.04,
          ),
        ),
      ),
    );
  }
}
