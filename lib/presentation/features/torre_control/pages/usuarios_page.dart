import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../providers/usuarios_provider.dart';

/// Color de chip por rol — consistente en toda la gestión de usuarios.
Color rolColor(RolUsuario r) => switch (r) {
      RolUsuario.administrador => GloboColors.sosPrimary,
      RolUsuario.direccion     => GloboColors.accentBright,
      RolUsuario.supervisor    => GloboColors.primaryAccent,
      RolUsuario.despachador   => GloboColors.info,
      RolUsuario.mantenimiento => GloboColors.warning,
      RolUsuario.operador      => GloboColors.steelGray,
      RolUsuario.solicitante   => GloboColors.success,
    };

class UsuariosPage extends ConsumerWidget {
  const UsuariosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosSP = ref.watch(usuariosStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onAgregar: () => _mostrarDialogoCrear(context, ref)),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: usuariosSP.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (usuarios) => _UsuariosTable(usuarios: usuarios),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCrear(BuildContext context, WidgetRef ref) {
    ref.read(usuariosNotifierProvider.notifier).resetForm();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _CrearUsuarioDialog(),
      ),
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onAgregar;
  const _Header({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestión de Usuarios',
                  style: GloboTypography.headlineMedium),
              Text(
                'Solo el administrador puede crear y modificar accesos',
                style: GloboTypography.bodyMedium,
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Nuevo Usuario'),
          onPressed: onAgregar,
        ),
      ],
    );
  }
}

// ── Tabla de usuarios ─────────────────────────────────────────────────────────

class _UsuariosTable extends ConsumerWidget {
  final List<UsuarioGlobo> usuarios;
  const _UsuariosTable({required this.usuarios});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          // Encabezado de tabla
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(GloboRadius.md),
                topRight: Radius.circular(GloboRadius.md),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                    flex: 3,
                    child: Text('NOMBRE',
                        style: GloboTypography.labelSmall
                            .copyWith(letterSpacing: 1.5))),
                Expanded(
                    flex: 3,
                    child: Text('CORREO',
                        style: GloboTypography.labelSmall
                            .copyWith(letterSpacing: 1.5))),
                Expanded(
                    flex: 2,
                    child: Text('ROL',
                        style: GloboTypography.labelSmall
                            .copyWith(letterSpacing: 1.5))),
                SizedBox(
                    width: 100,
                    child: Text('ESTADO',
                        style: GloboTypography.labelSmall
                            .copyWith(letterSpacing: 1.5))),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: usuarios.isEmpty
                ? const Center(child: Text('Sin usuarios registrados'))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: usuarios.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) =>
                        _UsuarioRow(usuario: usuarios[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioRow extends ConsumerWidget {
  final UsuarioGlobo usuario;
  const _UsuarioRow({required this.usuario});

  Color get _rolColor => rolColor(usuario.rol);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(usuariosNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: Row(
        children: [
          // Avatar con inicial
          CircleAvatar(
            radius: 18,
            backgroundColor: _rolColor.withAlpha(30),
            child: Text(
              usuario.nombre.isNotEmpty
                  ? usuario.nombre[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: _rolColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: GloboSpacing.sm),
          // Nombre
          Expanded(
            flex: 3,
            child: Text(usuario.nombre,
                style: GloboTypography.titleMedium),
          ),
          // Email
          Expanded(
            flex: 3,
            child: Text(
              usuario.email,
              style: GloboTypography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Rol — dropdown inline
          Expanded(
            flex: 2,
            child: _RolDropdown(
              rol: usuario.rol,
              onChanged: (nuevoRol) async {
                final ok = await notifier.actualizarRol(
                    usuario.uid, nuevoRol);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al cambiar rol')),
                  );
                }
              },
            ),
          ),
          // Toggle activo
          SizedBox(
            width: 100,
            child: Switch(
              value: usuario.activo,
              activeThumbColor: GloboColors.successAccent,
              inactiveThumbColor: GloboColors.steelGrayLight,
              onChanged: (v) async {
                final ok =
                    await notifier.toggleActivo(usuario.uid, v);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Error al cambiar estado')),
                  );
                }
              },
            ),
          ),
          // Menú opciones
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: GloboColors.steelGray),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'resetPass',
                  child: Text('Resetear contraseña'),
                ),
              ],
              onSelected: (v) {
                if (v == 'resetPass') {
                  _confirmarResetPassword(context, usuario.email);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarResetPassword(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Text(
            'Se enviará un correo de restablecimiento a $email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // En producción: firebase_auth.sendPasswordResetEmail
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Correo enviado a $email')),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

class _RolDropdown extends StatelessWidget {
  final RolUsuario rol;
  final ValueChanged<RolUsuario> onChanged;
  const _RolDropdown({required this.rol, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: rolColor(rol).withAlpha(20),
        borderRadius: GloboRadius.chipRadius,
        border: Border.all(color: rolColor(rol).withAlpha(60)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RolUsuario>(
          value: rol,
          isDense: true,
          icon: Icon(Icons.expand_more,
              size: 14, color: rolColor(rol)),
          style: GloboTypography.labelSmall.copyWith(color: rolColor(rol)),
          items: RolUsuario.values
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.nombre),
                  ))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

// ── Diálogo Crear Usuario ─────────────────────────────────────────────────────

class _CrearUsuarioDialog extends ConsumerStatefulWidget {
  const _CrearUsuarioDialog();

  @override
  ConsumerState<_CrearUsuarioDialog> createState() =>
      _CrearUsuarioDialogState();
}

class _CrearUsuarioDialogState extends ConsumerState<_CrearUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  RolUsuario _rol = RolUsuario.operador;
  bool _obscurePass = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(usuariosNotifierProvider);

    // Cerrar automáticamente al éxito
    ref.listen<UsuarioFormState>(usuariosNotifierProvider, (_, next) {
      if (next.success && context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Usuario ${_emailCtrl.text} creado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return AlertDialog(
      title: const Text('Nuevo Usuario'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (formState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(GloboSpacing.sm),
                  margin: const EdgeInsets.only(bottom: GloboSpacing.md),
                  decoration: BoxDecoration(
                    color: GloboColors.errorLight,
                    borderRadius: GloboRadius.cardRadius,
                    border: Border.all(
                        color: GloboColors.error.withAlpha(80)),
                  ),
                  child: Text(
                    formState.error!,
                    style: GloboTypography.bodyMedium
                        .copyWith(color: GloboColors.error),
                  ),
                ),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.md),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined, size: 18),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: GloboSpacing.md),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Contraseña temporal',
                  prefixIcon:
                      const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length < 8)
                    return 'Mínimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: GloboSpacing.md),
              // Selector de rol
              DropdownButtonFormField<RolUsuario>(
                value: _rol,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon:
                      Icon(Icons.admin_panel_settings_outlined, size: 18),
                ),
                items: RolUsuario.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.nombre),
                        ))
                    .toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _rol = v) : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: formState.loading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: formState.loading ? null : _submit,
          child: formState.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear Usuario'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(usuariosNotifierProvider.notifier).crearUsuario(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          nombre:   _nombreCtrl.text.trim(),
          rol:      _rol,
        );
  }
}
