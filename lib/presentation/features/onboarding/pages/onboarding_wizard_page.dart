import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../domain/entities/usuario_globo.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';
import '../../../../injection_container.dart';
import '../../../app/router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../operador/providers/clientes_provider.dart';
import '../../torre_control/providers/unidades_provider.dart';
import '../../torre_control/providers/usuarios_provider.dart';
import '../providers/onboarding_provider.dart';
import '../services/csv_import_service.dart';

/// Asistente de configuración inicial (primera vez que entra el admin).
/// Cubre empresa, equipo, flota, clientes y parámetros de facturación.
class OnboardingWizardPage extends ConsumerStatefulWidget {
  const OnboardingWizardPage({super.key});

  @override
  ConsumerState<OnboardingWizardPage> createState() =>
      _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends ConsumerState<OnboardingWizardPage> {
  final _pageCtrl = PageController();
  int _step = 0;

  static const _titulos = [
    'Bienvenido',
    'Datos de la empresa',
    'Tu equipo',
    'Flota de unidades',
    'Cartera de clientes',
    'Facturación',
    '¡Todo listo!',
  ];

  int get _totalPasos => _titulos.length;

  void _avanzar() {
    if (_step < _totalPasos - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut);
    }
  }

  void _retroceder() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut);
    }
  }

  Future<void> _finalizar() async {
    await sl<FirestoreDatasource>().guardarEmpresaConfig({'configurado': true});
    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Candado de rol: el wizard escribe usuarios, flota y configuración —
    // solo el administrador puede ejecutarlo, aunque navegue directo a la ruta
    final auth = ref.watch(authStatusProvider);
    if (auth.usuario?.rol != RolUsuario.administrador) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.dashboard);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: GloboColors.backgroundSecondary,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: _step,
              total: _totalPasos,
              titulo: _titulos[_step],
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PasoBienvenida(onEmpezar: _avanzar),
                  _PasoEmpresa(onContinuar: _avanzar),
                  _PasoEquipo(onContinuar: _avanzar),
                  _PasoFlota(onContinuar: _avanzar),
                  _PasoClientes(onContinuar: _avanzar),
                  _PasoFacturacion(onContinuar: _avanzar),
                  _PasoFinal(onFinalizar: _finalizar),
                ],
              ),
            ),
            if (_step > 0 && _step < _totalPasos - 1)
              _BarraNavegacion(
                onAtras: _retroceder,
                puedeOmitir: _step == 3 || _step == 4, // flota / clientes
                onOmitir: _avanzar,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header con progreso ───────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step;
  final int total;
  final String titulo;

  const _WizardHeader({
    required this.step,
    required this.total,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          GloboSpacing.lg, GloboSpacing.lg, GloboSpacing.lg, GloboSpacing.md),
      color: GloboColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CONFIGURACIÓN INICIAL',
                style: GloboTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                'Paso ${step + 1} de $total',
                style: GloboTypography.caption.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: GloboSpacing.sm),
          Text(titulo,
              style: GloboTypography.headlineMedium
                  .copyWith(color: Colors.white)),
          const SizedBox(height: GloboSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation(GloboColors.accentGlow),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra inferior (atrás / omitir) ───────────────────────────────────────────

class _BarraNavegacion extends StatelessWidget {
  final VoidCallback onAtras;
  final bool puedeOmitir;
  final VoidCallback onOmitir;

  const _BarraNavegacion({
    required this.onAtras,
    required this.puedeOmitir,
    required this.onOmitir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GloboColors.divider)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onAtras,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Atrás'),
          ),
          const Spacer(),
          if (puedeOmitir)
            TextButton(
              onPressed: onOmitir,
              child: Text('Omitir por ahora',
                  style: GloboTypography.bodyMedium
                      .copyWith(color: GloboColors.textTertiary)),
            ),
        ],
      ),
    );
  }
}

// ── Paso 0: Bienvenida ────────────────────────────────────────────────────────

class _PasoBienvenida extends StatelessWidget {
  final VoidCallback onEmpezar;
  const _PasoBienvenida({required this.onEmpezar});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: GloboSpacing.lg),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: GloboColors.primary.withAlpha(18),
              borderRadius: GloboRadius.cardRadius,
            ),
            child: const Icon(Icons.rocket_launch_outlined,
                size: 36, color: GloboColors.primary),
          ),
          const SizedBox(height: GloboSpacing.lg),
          Text('Pongamos en marcha tu operación',
              style: GloboTypography.headlineLarge),
          const SizedBox(height: GloboSpacing.sm),
          Text(
            'En unos minutos vamos a configurar lo esencial para empezar a '
            'operar: los datos de tu empresa, tu equipo, las unidades, los '
            'clientes y cómo se factura. Puedes omitir pasos y completarlos '
            'después desde Torre de Control.',
            style: GloboTypography.bodyMedium
                .copyWith(color: GloboColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: GloboSpacing.xl),
          ..._items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: GloboSpacing.md),
                child: Row(children: [
                  Icon(e.$1, size: 20, color: GloboColors.primary),
                  const SizedBox(width: GloboSpacing.md),
                  Expanded(
                      child: Text(e.$2, style: GloboTypography.bodyMedium)),
                ]),
              )),
          const SizedBox(height: GloboSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEmpezar,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Comenzar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<(IconData, String)> _items = [
    (Icons.business_outlined, 'Datos fiscales de tu empresa'),
    (Icons.group_outlined, 'Operadores y supervisores'),
    (Icons.local_shipping_outlined, 'Tu flota de unidades'),
    (Icons.handshake_outlined, 'Clientes y destinos'),
    (Icons.receipt_long_outlined, 'Folios, margen e impuestos'),
  ];
}

// ── Paso 1: Empresa ───────────────────────────────────────────────────────────

class _PasoEmpresa extends ConsumerStatefulWidget {
  final VoidCallback onContinuar;
  const _PasoEmpresa({required this.onContinuar});

  @override
  ConsumerState<_PasoEmpresa> createState() => _PasoEmpresaState();
}

class _PasoEmpresaState extends ConsumerState<_PasoEmpresa> {
  final _formKey = GlobalKey<FormState>();
  final _razonCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Pre-cargar si el admin retoma el wizard con datos ya guardados
    final cfg = ref.read(empresaConfigProvider).valueOrNull;
    if (cfg != null) {
      _razonCtrl.text = cfg['razon_social'] as String? ?? '';
      _rfcCtrl.text = cfg['rfc'] as String? ?? '';
      _dirCtrl.text = cfg['direccion'] as String? ?? '';
      _telCtrl.text = cfg['telefono'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _razonCtrl.dispose();
    _rfcCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await sl<FirestoreDatasource>().guardarEmpresaConfig({
        'razon_social': _razonCtrl.text.trim(),
        'rfc': _rfcCtrl.text.trim().toUpperCase(),
        'direccion': _dirCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
      });
      widget.onContinuar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estos datos aparecen en las facturas que genera el sistema.',
                style: GloboTypography.bodyMedium
                    .copyWith(color: GloboColors.textSecondary)),
            const SizedBox(height: GloboSpacing.lg),
            TextFormField(
              controller: _razonCtrl,
              decoration: const InputDecoration(
                  labelText: 'Razón social / Nombre comercial *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: GloboSpacing.md),
            TextFormField(
              controller: _rfcCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'RFC'),
            ),
            const SizedBox(height: GloboSpacing.md),
            TextFormField(
              controller: _dirCtrl,
              decoration:
                  const InputDecoration(labelText: 'Dirección fiscal'),
            ),
            const SizedBox(height: GloboSpacing.md),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: GloboSpacing.xl),
            _BotonContinuar(cargando: _guardando, onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}

// ── Paso 2: Equipo ────────────────────────────────────────────────────────────

class _PasoEquipo extends ConsumerWidget {
  final VoidCallback onContinuar;
  const _PasoEquipo({required this.onContinuar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosStreamProvider).valueOrNull ?? [];
    final operadores =
        usuarios.where((u) => u.rol == RolUsuario.operador).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GloboSpacing.xl),
            children: [
              Text(
                'Agrega operadores y supervisores. Cada uno recibe correo y '
                'contraseña para entrar a la app.',
                style: GloboTypography.bodyMedium
                    .copyWith(color: GloboColors.textSecondary),
              ),
              const SizedBox(height: GloboSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _NuevoUsuarioDialog(),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Agregar persona'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: GloboSpacing.lg),
              if (usuarios.isEmpty)
                const _VacioMini(
                  icon: Icons.group_outlined,
                  texto: 'Aún no has agregado a nadie',
                )
              else
                ...usuarios.map((u) => _PersonaTile(usuario: u)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GloboSpacing.xl),
          child: _BotonContinuar(
            etiqueta: operadores > 0
                ? 'Continuar'
                : 'Continuar sin operadores',
            onPressed: onContinuar,
          ),
        ),
      ],
    );
  }
}

class _PersonaTile extends StatelessWidget {
  final UsuarioGlobo usuario;
  const _PersonaTile({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (usuario.rol) {
      RolUsuario.administrador => (GloboColors.accentBright, 'Admin'),
      RolUsuario.direccion     => (GloboColors.primaryAccent, 'Dirección'),
      RolUsuario.supervisor    => (GloboColors.primary, 'Supervisor'),
      RolUsuario.despachador   => (GloboColors.info, 'Despachador'),
      RolUsuario.mantenimiento => (GloboColors.warning, 'Mantto.'),
      RolUsuario.operador      => (GloboColors.estadoTransito, 'Operador'),
      RolUsuario.solicitante   => (GloboColors.success, 'Solicitante'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(20),
          child: Text(
            usuario.nombre.isNotEmpty
                ? usuario.nombre.characters.first.toUpperCase()
                : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(usuario.nombre, style: GloboTypography.titleMedium),
        subtitle: Text(usuario.email, style: GloboTypography.caption),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: GloboRadius.chipRadius,
          ),
          child: Text(label,
              style: GloboTypography.labelSmall.copyWith(color: color)),
        ),
      ),
    );
  }
}

class _NuevoUsuarioDialog extends ConsumerStatefulWidget {
  const _NuevoUsuarioDialog();

  @override
  ConsumerState<_NuevoUsuarioDialog> createState() =>
      _NuevoUsuarioDialogState();
}

class _NuevoUsuarioDialogState extends ConsumerState<_NuevoUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  RolUsuario _rol = RolUsuario.operador;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final ok = await ref.read(usuariosNotifierProvider.notifier).crearUsuario(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          nombre: _nombreCtrl.text.trim(),
          rol: _rol,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_nombreCtrl.text.trim()} agregado'),
        backgroundColor: GloboColors.success,
      ));
    } else {
      final err = ref.read(usuariosNotifierProvider).error;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'No se pudo crear el usuario'),
        backgroundColor: GloboColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva persona'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre completo *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo *'),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Correo no válido'
                    : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña temporal *'),
                validator: (v) => v == null || v.length < 6
                    ? 'Mínimo 6 caracteres'
                    : null,
              ),
              const SizedBox(height: GloboSpacing.md),
              DropdownButtonFormField<RolUsuario>(
                initialValue: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(
                      value: RolUsuario.operador, child: Text('Operador')),
                  DropdownMenuItem(
                      value: RolUsuario.supervisor,
                      child: Text('Supervisor')),
                  DropdownMenuItem(
                      value: RolUsuario.administrador,
                      child: Text('Administrador')),
                ],
                onChanged: (v) => setState(() => _rol = v!),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _crear,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }
}

// ── Paso 3: Flota ─────────────────────────────────────────────────────────────

class _PasoFlota extends ConsumerWidget {
  final VoidCallback onContinuar;
  const _PasoFlota({required this.onContinuar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidades = ref.watch(todasUnidadesProvider).valueOrNull ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GloboSpacing.xl),
            children: [
              Text(
                'Da de alta tus unidades una por una o importa un CSV con '
                'toda la flota.',
                style: GloboTypography.bodyMedium
                    .copyWith(color: GloboColors.textSecondary),
              ),
              const SizedBox(height: GloboSpacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _NuevaUnidadDialog(),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: _BotonImportarCsv(tipo: TipoImportacion.unidades),
                ),
              ]),
              const SizedBox(height: GloboSpacing.md),
              _AyudaCsv(
                columnas: 'placas, modelo, anio, odometro, capacidad_tanque',
                tipo: TipoImportacion.unidades,
              ),
              const SizedBox(height: GloboSpacing.lg),
              if (unidades.isEmpty)
                const _VacioMini(
                  icon: Icons.local_shipping_outlined,
                  texto: 'Aún no hay unidades',
                )
              else
                ...unidades.map((u) => Card(
                      margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping_outlined,
                            color: GloboColors.primary),
                        title: Text(u.placas,
                            style: GloboTypography.titleMedium),
                        subtitle: Text(
                          '${u.modelo}${u.anio > 0 ? ' · ${u.anio}' : ''}',
                          style: GloboTypography.caption,
                        ),
                      ),
                    )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GloboSpacing.xl),
          child: _BotonContinuar(
            etiqueta: unidades.isEmpty ? 'Continuar sin flota' : 'Continuar',
            onPressed: onContinuar,
          ),
        ),
      ],
    );
  }
}

class _NuevaUnidadDialog extends StatefulWidget {
  const _NuevaUnidadDialog();

  @override
  State<_NuevaUnidadDialog> createState() => _NuevaUnidadDialogState();
}

class _NuevaUnidadDialogState extends State<_NuevaUnidadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _placasCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _tanqueCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _placasCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _odoCtrl.dispose();
    _tanqueCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await sl<FirestoreDatasource>().crearUnidad({
        'placas': _placasCtrl.text.trim().toUpperCase(),
        'modelo': _modeloCtrl.text.trim(),
        'anio': int.tryParse(_anioCtrl.text) ?? 0,
        'estado': 'activa',
        'odometro': double.tryParse(_odoCtrl.text) ?? 0,
        'capacidad_tanque': double.tryParse(_tanqueCtrl.text) ?? 0,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva unidad'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _placasCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration:
                        const InputDecoration(labelText: 'Placas *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: GloboSpacing.sm),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _anioCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Año'),
                  ),
                ),
              ]),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _modeloCtrl,
                decoration:
                    const InputDecoration(labelText: 'Modelo / Marca'),
              ),
              const SizedBox(height: GloboSpacing.sm),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _odoCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Odómetro (km)'),
                  ),
                ),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _tanqueCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Tanque (L)'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _crear,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Agregar'),
        ),
      ],
    );
  }
}

// ── Paso 4: Clientes ──────────────────────────────────────────────────────────

class _PasoClientes extends ConsumerWidget {
  final VoidCallback onContinuar;
  const _PasoClientes({required this.onContinuar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientes = ref.watch(clientesStreamProvider).valueOrNull ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GloboSpacing.xl),
            children: [
              Text(
                'Registra tus clientes. La dirección se geocodifica sola para '
                'el cierre automático de viajes por geocerca.',
                style: GloboTypography.bodyMedium
                    .copyWith(color: GloboColors.textSecondary),
              ),
              const SizedBox(height: GloboSpacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _NuevoClienteDialog(),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: _BotonImportarCsv(tipo: TipoImportacion.clientes),
                ),
              ]),
              const SizedBox(height: GloboSpacing.md),
              _AyudaCsv(
                columnas: 'nombre, direccion, rfc, telefono, contacto',
                tipo: TipoImportacion.clientes,
              ),
              const SizedBox(height: GloboSpacing.lg),
              if (clientes.isEmpty)
                const _VacioMini(
                  icon: Icons.handshake_outlined,
                  texto: 'Aún no hay clientes',
                )
              else
                ...clientes.map((c) => Card(
                      margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          c.posicion != null
                              ? Icons.location_on
                              : Icons.location_off_outlined,
                          color: c.posicion != null
                              ? GloboColors.success
                              : GloboColors.warning,
                        ),
                        title: Text(c.nombre,
                            style: GloboTypography.titleMedium),
                        subtitle: Text(c.direccion,
                            style: GloboTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GloboSpacing.xl),
          child: _BotonContinuar(
            etiqueta:
                clientes.isEmpty ? 'Continuar sin clientes' : 'Continuar',
            onPressed: onContinuar,
          ),
        ),
      ],
    );
  }
}

class _NuevoClienteDialog extends StatefulWidget {
  const _NuevoClienteDialog();

  @override
  State<_NuevoClienteDialog> createState() => _NuevoClienteDialogState();
}

class _NuevoClienteDialogState extends State<_NuevoClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    Map<String, dynamic>? posicion;
    final dir = _dirCtrl.text.trim();
    if (dir.isNotEmpty) {
      try {
        final res = await sl<GeocodingService>().buscarDireccion(dir);
        if (res.isNotEmpty) {
          posicion = {'lat': res.first.lat, 'lng': res.first.lng};
        }
      } catch (_) {/* sin coordenadas */}
    }

    final result = await sl<IClienteRepository>().crearCliente({
      'nombre': _nombreCtrl.text.trim(),
      'direccion': dir,
      'telefono': _telCtrl.text.trim(),
      'activo': true,
      if (posicion != null) 'posicion': posicion,
    });

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${failure.message}')),
        );
      },
      (_) => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo cliente'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre / Razón social *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _dirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  helperText: 'Se geocodifica automáticamente',
                ),
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _crear,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Agregar'),
        ),
      ],
    );
  }
}

// ── Paso 5: Facturación ───────────────────────────────────────────────────────

class _PasoFacturacion extends ConsumerStatefulWidget {
  final VoidCallback onContinuar;
  const _PasoFacturacion({required this.onContinuar});

  @override
  ConsumerState<_PasoFacturacion> createState() => _PasoFacturacionState();
}

class _PasoFacturacionState extends ConsumerState<_PasoFacturacion> {
  final _formKey = GlobalKey<FormState>();
  final _serieCtrl = TextEditingController(text: 'GL');
  final _margenCtrl = TextEditingController(text: '15');
  final _ivaCtrl = TextEditingController(text: '16');
  final _diasCtrl = TextEditingController(text: '30');
  bool _guardando = false;

  @override
  void dispose() {
    _serieCtrl.dispose();
    _margenCtrl.dispose();
    _ivaCtrl.dispose();
    _diasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await sl<FirestoreDatasource>().guardarPricing({
        'serie_folio': _serieCtrl.text.trim().toUpperCase(),
        'margen_pct': (double.tryParse(_margenCtrl.text) ?? 15) / 100,
        'iva_pct': (double.tryParse(_ivaCtrl.text) ?? 16) / 100,
        'dias_credito': int.tryParse(_diasCtrl.text) ?? 30,
      });
      widget.onContinuar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cómo se genera cada factura automática al completar un viaje.',
              style: GloboTypography.bodyMedium
                  .copyWith(color: GloboColors.textSecondary),
            ),
            const SizedBox(height: GloboSpacing.lg),
            TextFormField(
              controller: _serieCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Serie de folio',
                helperText: 'Ej. "GL" genera GL-2026-0001',
              ),
            ),
            const SizedBox(height: GloboSpacing.md),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _margenCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Margen %',
                    helperText: 'Sobre el costo (TCO)',
                  ),
                ),
              ),
              const SizedBox(width: GloboSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _ivaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'IVA %'),
                ),
              ),
            ]),
            const SizedBox(height: GloboSpacing.md),
            TextFormField(
              controller: _diasCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Días de crédito',
                helperText: 'Plazo de vencimiento de las facturas',
              ),
            ),
            const SizedBox(height: GloboSpacing.xl),
            _BotonContinuar(cargando: _guardando, onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}

// ── Paso 6: Final ─────────────────────────────────────────────────────────────

class _PasoFinal extends StatelessWidget {
  final VoidCallback onFinalizar;
  const _PasoFinal({required this.onFinalizar});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: GloboSpacing.xxl),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: GloboColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 56, color: GloboColors.success),
          ),
          const SizedBox(height: GloboSpacing.xl),
          Text('Configuración completa', style: GloboTypography.headlineLarge),
          const SizedBox(height: GloboSpacing.sm),
          Text(
            'Tu operación está lista. Puedes ajustar todo en cualquier momento '
            'desde Torre de Control: flota, clientes, equipo y facturación.',
            style: GloboTypography.bodyMedium
                .copyWith(color: GloboColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GloboSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onFinalizar,
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Ir a Torre de Control'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Componentes compartidos ───────────────────────────────────────────────────

class _BotonContinuar extends StatelessWidget {
  final VoidCallback onPressed;
  final bool cargando;
  final String etiqueta;

  const _BotonContinuar({
    required this.onPressed,
    this.cargando = false,
    this.etiqueta = 'Continuar',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(etiqueta),
      ),
    );
  }
}

class _BotonImportarCsv extends ConsumerStatefulWidget {
  final TipoImportacion tipo;
  const _BotonImportarCsv({required this.tipo});

  @override
  ConsumerState<_BotonImportarCsv> createState() => _BotonImportarCsvState();
}

class _BotonImportarCsvState extends ConsumerState<_BotonImportarCsv> {
  bool _importando = false;

  Future<void> _importar() async {
    setState(() => _importando = true);
    try {
      final filas = await CsvImportService.elegirYParsear();
      if (filas == null) {
        if (mounted) setState(() => _importando = false);
        return;
      }
      if (filas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El CSV no tiene filas de datos')),
          );
          setState(() => _importando = false);
        }
        return;
      }

      final res = widget.tipo == TipoImportacion.unidades
          ? await CsvImportService.importarUnidades(filas)
          : await CsvImportService.importarClientes(filas);

      if (!mounted) return;
      setState(() => _importando = false);
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(children: [
            Icon(
              res.errores.isEmpty
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              color: res.errores.isEmpty
                  ? GloboColors.success
                  : GloboColors.warning,
            ),
            const SizedBox(width: GloboSpacing.sm),
            const Text('Importación'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${res.creados} creados · ${res.omitidos} omitidos',
                  style: GloboTypography.titleMedium),
              if (res.errores.isNotEmpty) ...[
                const SizedBox(height: GloboSpacing.sm),
                Text('Detalles:', style: GloboTypography.labelLarge),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(
                      res.errores.take(20).join('\n'),
                      style: GloboTypography.caption,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _importando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _importando ? null : _importar,
      icon: _importando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upload_file_outlined, size: 18),
      label: const Text('Importar CSV'),
    );
  }
}

class _AyudaCsv extends StatelessWidget {
  final String columnas;
  final TipoImportacion tipo;
  const _AyudaCsv({required this.columnas, required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.sm),
      decoration: BoxDecoration(
        color: GloboColors.infoLight,
        borderRadius: GloboRadius.buttonRadius,
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 15, color: GloboColors.info),
        const SizedBox(width: GloboSpacing.sm),
        Expanded(
          child: Text(
            'Columnas del CSV: $columnas',
            style: GloboTypography.caption.copyWith(color: GloboColors.info),
          ),
        ),
        TextButton.icon(
          onPressed: () => CsvImportService.descargarMachote(tipo),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.download, size: 14, color: GloboColors.accent),
          label: Text(
            'Descargar Machote',
            style: GloboTypography.caption.copyWith(
              color: GloboColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ]),
    );
  }
}

class _VacioMini extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _VacioMini({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GloboSpacing.xl),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 36, color: GloboColors.textTertiary),
          const SizedBox(height: GloboSpacing.sm),
          Text(texto, style: GloboTypography.caption),
        ]),
      ),
    );
  }
}
